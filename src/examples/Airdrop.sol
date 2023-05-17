// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import {IDelegationRegistry} from "../IDelegationRegistry.sol";

import {Merkle} from "murky/Merkle.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract Airdrop is ERC20 {
    Merkle m;

    IDelegationRegistry r;

    bytes32 public immutable merkleRoot;

    address public immutable referenceToken;

    mapping(address claimant => uint256 claimed) claimed;

    mapping(address claimant => mapping(address beneficiary => uint256 claimed)) beneficiaryClaimed;

    error InvalidProof(bytes32 merkleRoot, bytes32[] merkleProof, bytes32 leaf);

    error InsufficientDelegation(uint256 delegationAmount, uint256 alreadyClaimed);

    event Claim(address indexed claimant, uint256 indexed amount, address beneficiary, uint256 received);

    constructor(uint256 totalSupply_, bytes32 merkleRoot_, address referenceToken_, address registry) ERC20("Airdrop", "Air") {
        _mint(address(this), totalSupply_);
        merkleRoot = merkleRoot_;
        referenceToken = referenceToken_;
        m = new Merkle();
        r = IDelegationRegistry(registry);
    }

    function claim(address claimant, uint256 amount, bytes32[] calldata merkleProof) external {
        // First verify that airdrop for claimant for amount exists
        if (!m.verifyProof(merkleRoot, merkleProof, keccak256(abi.encodePacked(claimant, amount)))) {
            revert InvalidProof(merkleRoot, merkleProof, keccak256(abi.encodePacked(claimant, amount)));
        }
        // Now calculate remaining tokens that can be claimed
        uint256 remainingTokens = amount - claimed[claimant];
        // If msg.sender != claimant, check delegation instead
        if (msg.sender != claimant) {
            uint256 allowance = r.checkDelegateForBalance(msg.sender, claimant, referenceToken, "");
            uint256 alreadyClaimed = beneficiaryClaimed[claimant][msg.sender];
            if (alreadyClaimed >= allowance) {
                revert InsufficientDelegation(allowance, alreadyClaimed);
            }
            uint256 remainingLimit = allowance - alreadyClaimed;
            remainingTokens = Math.min(remainingTokens, remainingLimit);
            // Decrement beneficiaryClaimed
            beneficiaryClaimed[claimant][msg.sender] -= remainingTokens;
        }
        // Increment claimed
        claimed[claimant] += remainingTokens;
        emit Claim(claimant, amount, msg.sender, remainingTokens);
        // Transfer tokens
        _transfer(address(this), msg.sender, remainingTokens);
    }
}
