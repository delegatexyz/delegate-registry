// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import {IDelegationRegistry} from "../IDelegationRegistry.sol";

import {Merkle} from "murky/Merkle.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract DelegateAirdrop is ERC20 {
    Merkle public immutable merkle;

    IDelegationRegistry public immutable registry;

    bytes32 public immutable merkleRoot;

    address public immutable referenceToken;

    mapping(address vault => uint256 claimed) public claimed;

    mapping(address vault => mapping(address delegate => uint256 claimed)) public delegateClaimed;

    error InvalidProof(bytes32 merkleRoot, bytes32[] merkleProof, bytes32 merkleLeaf);

    error InsufficientDelegation(uint256 delegationAmount, uint256 delegateClaimed);

    event DelegateClaim(address indexed vault, uint256 indexed airdropSize, address indexed delegate, uint256 delegateClaimed);

    event Claim(address indexed claimant, uint256 indexed airdropSize, uint256 claimable);

    constructor(address registry_, uint256 totalSupply_, address referenceToken_, bytes32 merkleRoot_, address merkle_) ERC20("Airdrop", "Air") {
        _mint(address(this), totalSupply_);
        merkleRoot = merkleRoot_;
        referenceToken = referenceToken_;
        merkle = Merkle(merkle_);
        registry = IDelegationRegistry(registry_);
    }

    function claim(address vault, uint256 airdropSize, bytes32[] calldata merkleProof) external {
        // First verify that airdrop for vault of amount airdropSize exists
        if (!merkle.verifyProof(merkleRoot, merkleProof, keccak256(abi.encodePacked(vault, airdropSize)))) {
            revert InvalidProof(merkleRoot, merkleProof, keccak256(abi.encodePacked(vault, airdropSize)));
        }
        // Now calculate remaining airdrop tokens that can be claimed by the vault
        uint256 claimable = airdropSize - claimed[vault];
        // If msg.sender != claimant, check balance delegation instead
        if (msg.sender != vault) {
            // Fetch the referenceToken balance delegated by the vault to msg.sender from the delegate registry
            uint256 balance = registry.checkDelegateForBalance(msg.sender, vault, referenceToken, "");
            // Load the amount tokens already claimed by msg.sender on behalf of the vault
            uint256 alreadyClaimed = delegateClaimed[vault][msg.sender];
            // Revert if msg.sender has already used up all the delegated balance
            if (alreadyClaimed >= balance) {
                revert InsufficientDelegation(balance, alreadyClaimed);
            }
            // The maximum further tokens that can be claimed by msg.sender on behalf of vault
            uint256 remainingLimit = balance - alreadyClaimed;
            // Reduce claimable to remainingLimit if the limit is smaller
            claimable = Math.min(claimable, remainingLimit);
            // Increment beneficiaryClaimed by this amount
            delegateClaimed[vault][msg.sender] += claimable;
            emit DelegateClaim(vault, airdropSize, msg.sender, claimable);
        } else {
            emit Claim(vault, airdropSize, claimable);
        }
        // Increment claimed
        claimed[vault] += claimable;
        // Transfer tokens to msg.sender
        _transfer(address(this), msg.sender, claimable);
    }
}
