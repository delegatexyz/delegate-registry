// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {MerkleProof} from "openzeppelin/utils/cryptography/MerkleProof.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {Math} from "openzeppelin/utils/math/Math.sol";
import {DelegateClaim} from "src/examples/DelegateClaim.sol";

/**
 * @title Airdrop
 * @notice A contract for distributing tokens through a merkle tree-based airdrop mechanism.
 * @dev Inherits the DelegateClaim contract to allow delegates to claim on behalf of vaults.
 */
contract Airdrop is ERC20, DelegateClaim {
    bytes32 public immutable merkleRoot;
    mapping(address vault => uint256 claimed) public claimed;

    /**
     * @notice Initializes the Airdrop contract.
     * @param registry_ The address of the v2 delegation registry contract.
     * @param referenceToken_ The address of the reference token used by delegateClaimable inherited from DelegateClaim.
     * @param totalSupply_ The total supply of the airdrop token.
     * @param merkleRoot_ The root hash of the merkle tree representing the airdrop.
     */
    constructor(address registry_, address referenceToken_, bytes32 airdropRight, uint256 totalSupply_, bytes32 merkleRoot_)
        ERC20("Airdrop", "Air")
        DelegateClaim(registry_, referenceToken_, airdropRight)
    {
        _mint(address(this), totalSupply_);
        merkleRoot = merkleRoot_;
    }

    /**
     * @notice Allows the caller to claim tokens from the airdrop based on the merkle proof, and if they aren't the
     * vault, claim tokens on behalf of vault if they have a delegation.
     * @param vault The address of the vault.
     * @param claimAmount The amount of tokens to claim from the airdrop.
     * @param airdropSize The total size of the airdrop for the vault.
     * @param merkleProof The merkle proof to verify the airdrop allocation for vault of airdropSize.
     */
    function claim(address vault, uint256 claimAmount, uint256 airdropSize, bytes32[] calldata merkleProof) external {
        // First verify that airdrop for vault of amount airdropSize exists
        require(MerkleProof.verifyCalldata(merkleProof, merkleRoot, keccak256(abi.encodePacked(vault, airdropSize))), "Invalid Proof");
        // Set claimable to the minimum of claimAmount and the maximum remaining airdrop tokens that can be claimed by
        // the vault
        uint256 claimable = Math.min(claimAmount, airdropSize - claimed[vault]);
        // If msg.sender != vault, check balance delegation instead
        if (msg.sender != vault) claimable = _delegateClaimable(vault, claimable);
        // Increment claimed
        claimed[vault] += claimable;
        // Transfer tokens to msg.sender
        _transfer(address(this), msg.sender, claimable);
    }
}
