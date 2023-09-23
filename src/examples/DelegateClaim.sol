// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {IDelegateRegistry} from "src/IDelegateRegistry.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

/**
 * @title DelegateClaim
 * @dev A contract for claiming tokens on behalf of a vault using the v2 delegation registry.
 */
contract DelegateClaim {
    IDelegateRegistry public immutable delegateRegistry;
    address public immutable referenceToken;
    bytes32 public immutable acceptedRight;
    /**
     * @dev stores accounting for the tokens claimed by a delegate on behalf of a vault.
     */
    mapping(address vault => mapping(address delegate => uint256 claimed)) public delegateClaimed;

    /**
     * @param registry_ The address of the v2 delegation registry contract.
     * @param referenceToken_ The address of the reference token.
     */
    constructor(address registry_, address referenceToken_, bytes32 acceptedRight_) {
        require(registry_ != address(0), "RegistryZero");
        require(referenceToken_ != address(0), "ReferenceTokenZero");
        delegateRegistry = IDelegateRegistry(registry_);
        referenceToken = referenceToken_;
        acceptedRight = acceptedRight_;
    }

    /**
     * @dev Calculates the claimable tokens for a specific vault and claimable amount.
     * @param vault The address of the vault.
     * @param claimable The amount of tokens that can be claimed by vault.
     * @return The actual amount of tokens that can be claimed by the caller on behalf of vault.
     */
    function _delegateClaimable(address vault, uint256 claimable) internal returns (uint256) {
        // Fetch the referenceToken balance delegated by the vault to msg.sender from the delegate registry
        uint256 balance = delegateRegistry.checkDelegateForERC20(msg.sender, vault, referenceToken, acceptedRight);
        // Load the amount tokens already claimed by msg.sender on behalf of the vault
        uint256 alreadyClaimed = delegateClaimed[vault][msg.sender];
        // Revert if msg.sender has already used up all the delegated balance
        require(balance > alreadyClaimed, "Insufficient Delegation");
        // Calculate maximum further tokens that can be claimed by msg.sender on behalf of vault
        uint256 remainingLimit = balance - alreadyClaimed;
        // Reduce claimable to remainingLimit if the limit is smaller
        claimable = Math.min(claimable, remainingLimit);
        // Increment beneficiaryClaimed by this amount
        delegateClaimed[vault][msg.sender] += claimable;
        return claimable;
    }
}
