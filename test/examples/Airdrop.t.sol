// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Merkle} from "murky/Merkle.sol";
import {Airdrop} from "../../src/examples/Airdrop.sol";
import {DelegationRegistry} from "src/DelegationRegistry.sol";

contract AirdropTest is Test {
    Merkle m;

    DelegationRegistry r;

    struct AirdropRecord {
        address receiver;
        uint256 amount;
    }

    uint256 constant maxAirdropSize = 100;

    Airdrop a;

    AirdropRecord[] airdrop;

    bytes32[] airdropData;

    bytes32 root;

    function setUp() public {
        m = new Merkle();
        r = new DelegationRegistry();
    }

    function createAirdrop(uint256 addressSeed, uint256 amountSeed, uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            (,, bytes32 data, AirdropRecord memory record) = generateAirdropRecord(addressSeed, amountSeed, i);
            // Append to list
            airdropData.push(data);
            // Add to airdrop mapping
            airdrop.push(record);
        }
        root = m.getRoot(airdropData);
    }

    function generateAirdropRecord(uint256 addressSeed, uint256 amountSeed, uint256 i)
        internal
        pure
        returns (uint256 amount, address receiver, bytes32 data, AirdropRecord memory record)
    {
        amount = 1 + (uint256(keccak256(abi.encode(amountSeed, i))) % 2 ** 200);
        receiver = address(bytes20(keccak256(abi.encode(addressSeed, i))));
        data = keccak256(abi.encodePacked(receiver, amount));
        record = AirdropRecord({receiver: receiver, amount: amount});
    }

    function testCreateAirdrop(uint256 addressSeed, uint256 amountSeed, uint256 n, uint256 x) public {
        vm.assume(n > 1 && n < maxAirdropSize);
        createAirdrop(addressSeed, amountSeed, n);
        // Test random value
        vm.assume(x < n);
        (uint256 amount, address receiver,,) = generateAirdropRecord(addressSeed, amountSeed, x);
        // Load struct and data from storage
        AirdropRecord memory record = airdrop[x];
        bytes32 data = keccak256(abi.encodePacked(receiver, amount));
        assertEq(amount, record.amount);
        assertEq(receiver, record.receiver);
        assertEq(data, airdropData[x]);
        // Generate proof and verify
        bytes32[] memory proof = m.getProof(airdropData, x);
        assertTrue(m.verifyProof(root, proof, data));
    }

    function testAirdropWithoutDelegate(uint256 addressSeed, uint256 amountSeed, uint256 n, address referenceToken) public {
        vm.assume(n > 1 && n < maxAirdropSize && addressSeed != amountSeed);
        createAirdrop(addressSeed, amountSeed, n);
        // Calculate total tokens to mint
        uint256 totalSupply_;
        for (uint256 i; i < n; i++) {
            totalSupply_ += airdrop[i].amount;
        }
        // Create airdrop token
        a = new Airdrop(address(r), totalSupply_, referenceToken, root, address(m));
        // Check data is stored correctly in token
        assertEq(address(m), address(a.m()));
        assertEq(address(r), address(a.r()));
        assertEq(root, a.merkleRoot());
        assertEq(referenceToken, a.referenceToken());
        // Test that total supply is expected
        assertEq(totalSupply_, a.balanceOf(address(a)));
        // Try to claim with bogus proof
        for (uint256 i=0; i<n; i++) {
            (uint256 bogusAmount, address bogusReceiver, bytes32 bogusData,) =
            generateAirdropRecord(amountSeed, addressSeed, i);
            bytes32[] memory proof = m.getProof(airdropData, i);
            vm.startPrank(bogusReceiver);
            vm.expectRevert(abi.encodeWithSelector(Airdrop.InvalidProof.selector, root,  proof, bogusData));
            a.claim(bogusReceiver, bogusAmount, proof);
            vm.stopPrank();
        }
        // Claim airdrop for every receiver
        for (uint256 i = 0; i < n; i++) {
            address claimant = airdrop[i].receiver;
            uint256 amount = airdrop[i].amount;
            bytes32[] memory proof = m.getProof(airdropData, i);
            vm.startPrank(claimant);
            a.claim(claimant, amount, proof);
            // Claim again to ensure accounting is working
            a.claim(claimant, amount, proof);
            vm.stopPrank();
            // Check that tokens are received
            assertEq(amount, a.balanceOf(claimant));
            // Check that claimed mapping is updated
            assertEq(amount, a.claimed(claimant));
        }
        // Verify that contract no longer has any tokens
        assertEq(0, a.balanceOf(address(a)));
    }
}
