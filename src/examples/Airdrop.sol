// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import {Merkle} from "murky/Merkle.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {DelegateAirdrop} from "src/examples/DelegateAirdrop.sol";

contract Airdrop is ERC20, DelegateAirdrop {
    Merkle public immutable merkle;

    bytes32 public immutable merkleRoot;

    mapping(address vault => uint256 claimed) public claimed;

    constructor(address registry_, address referenceToken_, uint256 totalSupply_, bytes32 merkleRoot_, address merkle_)
        ERC20("Airdrop", "Air")
        DelegateAirdrop(registry_, referenceToken_)
    {
        _mint(address(this), totalSupply_);
        merkleRoot = merkleRoot_;
        merkle = Merkle(merkle_);
    }

    function claim(uint256 claimAmount, address vault, uint256 airdropSize, bytes32[] calldata merkleProof) external {
        // First verify that airdrop for vault of amount airdropSize exists
        require(merkle.verifyProof(merkleRoot, merkleProof, keccak256(abi.encodePacked(vault, airdropSize))), "Invalid Proof");
        // Set claimable to the minimum of claimAmount and the maximum remaining airdrop tokens that can be claimed by the vault
        uint256 claimable = Math.min(claimAmount, airdropSize - claimed[vault]);
        // If msg.sender != vault, check balance delegation instead
        if (msg.sender != vault) claimable = delegateClaimable(vault, claimable);
        // Increment claimed
        claimed[vault] += claimable;
        // Transfer tokens to msg.sender
        _transfer(address(this), msg.sender, claimable);
    }
}
