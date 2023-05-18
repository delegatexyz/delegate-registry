// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Merkle} from "murky/Merkle.sol";
import {Airdrop} from "src/examples/Airdrop.sol";
import {DelegationRegistry} from "src/DelegationRegistry.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract AirdropTest is Test {
    Merkle public m;

    DelegationRegistry public r;

    struct AirdropRecord {
        address receiver;
        uint256 amount;
    }

    uint256 public constant MAX_AIRDROP_SIZE = 100;

    uint256 public constant MAX_AMOUNT = 2 ** 200;

    Airdrop public a;

    AirdropRecord[] public airdrop;

    bytes32[] public airdropData;

    bytes32 public root;

    struct Delegate {
        address delegate;
        uint256 allowance;
    }

    Delegate[] public delegates;

    function setUp() public {
        m = new Merkle();
        r = new DelegationRegistry();
    }

    function _createAirdrop(uint256 addressSeed, uint256 amountSeed, uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            (,, bytes32 data, AirdropRecord memory record) = _generateAirdropRecord(addressSeed, amountSeed, i);
            // Append to list
            airdropData.push(data);
            // Add to airdrop mapping
            airdrop.push(record);
        }
        root = m.getRoot(airdropData);
    }

    function _generateAirdropRecord(uint256 addressSeed, uint256 amountSeed, uint256 i)
        internal
        pure
        returns (uint256 amount, address receiver, bytes32 data, AirdropRecord memory record)
    {
        amount = (uint256(keccak256(abi.encode(amountSeed, i))) % MAX_AMOUNT);
        if (amount == 0) amount += 1;
        receiver = address(bytes20(keccak256(abi.encode(addressSeed, i))));
        data = keccak256(abi.encodePacked(receiver, amount));
        record = AirdropRecord({receiver: receiver, amount: amount});
    }

    function testCreateAirdrop(uint256 addressSeed, uint256 amountSeed, uint256 n, uint256 x) public {
        vm.assume(n > 1 && n < MAX_AIRDROP_SIZE);
        _createAirdrop(addressSeed, amountSeed, n);
        // Test random value
        vm.assume(x < n);
        (uint256 amount, address receiver,,) = _generateAirdropRecord(addressSeed, amountSeed, x);
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
        vm.assume(n > 1 && n < MAX_AIRDROP_SIZE && addressSeed != amountSeed);
        _createAirdrop(addressSeed, amountSeed, n);
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
        for (uint256 i = 0; i < n; i++) {
            (uint256 bogusAmount, address bogusReceiver, bytes32 bogusData,) = _generateAirdropRecord(amountSeed, addressSeed, i);
            bytes32[] memory proof = m.getProof(airdropData, i);
            vm.startPrank(bogusReceiver);
            vm.expectRevert(abi.encodeWithSelector(Airdrop.InvalidProof.selector, root, proof, bogusData));
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

    function _createDelegates(uint256 delegateSeed, uint256 allowanceSeed, uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            uint256 allowance = uint256(keccak256(abi.encode(allowanceSeed, i))) % MAX_AMOUNT;
            if (allowance == 0) allowance += 1;
            address delegate = address(bytes20(keccak256(abi.encode(delegateSeed, i))));
            delegates.push(Delegate({delegate: delegate, allowance: allowance}));
        }
    }

    function testAirdropWithDelegateBalance(
        uint256 addressSeed,
        uint256 amountSeed,
        uint256 n,
        address referenceToken,
        uint256 delegateSeed,
        uint256 allowanceSeed
    ) public {
        vm.assume(n > 1 && n < MAX_AIRDROP_SIZE && addressSeed != amountSeed && addressSeed != delegateSeed && addressSeed != allowanceSeed);
        vm.assume(amountSeed != delegateSeed && amountSeed != allowanceSeed);
        vm.assume(delegateSeed != allowanceSeed);
        _createAirdrop(addressSeed, amountSeed, n);
        // Calculate total tokens to mint
        uint256 totalSupply_;
        for (uint256 i; i < n; i++) {
            totalSupply_ += airdrop[i].amount;
        }
        // Create airdrop token
        a = new Airdrop(address(r), totalSupply_, referenceToken, root, address(m));
        // Create delegates
        _createDelegates(delegateSeed, allowanceSeed, n);
        // Try to claim with delegate
        // Try to claim every airdrop with delegate
        for (uint256 i = 0; i < n; i++) {
            address claimant = airdrop[i].receiver;
            uint256 amount = airdrop[i].amount;
            bytes32[] memory proof = m.getProof(airdropData, i);
            vm.startPrank(delegates[i].delegate);
            vm.expectRevert(abi.encodeWithSelector(Airdrop.InsufficientDelegation.selector, 0, 0));
            a.claim(claimant, amount, proof);
            vm.stopPrank();
        }
        // Delegate and claim airdrop
        for (uint256 i = 0; i < n; i++) {
            // Delegate
            vm.startPrank(airdrop[i].receiver);
            r.delegateForBalance(delegates[i].delegate, referenceToken, delegates[i].allowance, true, "");
            vm.stopPrank();
            // Delegate claims airdrop
            vm.startPrank(delegates[i].delegate);
            bytes32[] memory proof = m.getProof(airdropData, i);
            a.claim(airdrop[i].receiver, airdrop[i].amount, proof);
            vm.stopPrank();
            uint256 claimed = Math.min(delegates[i].allowance, airdrop[i].amount);
            // Check that claimed is as expected
            assertEq(claimed, a.claimed(airdrop[i].receiver));
            // Check that beneficiary claimed is as expected
            assertEq(claimed, a.beneficiaryClaimed(airdrop[i].receiver, delegates[i].delegate));
            // Expect that token balance is claimed
            assertEq(claimed, a.balanceOf(delegates[i].delegate));
            // If claimed is airdrop amount, delegate tries to claim again but they receive no further tokens
            if (claimed == airdrop[i].amount) {
                vm.startPrank(delegates[i].delegate);
                a.claim(airdrop[i].receiver, airdrop[i].amount, proof);
                vm.stopPrank();
            }
            // Otherwise expect insufficient delegation error on further claim attempts
            else {
                vm.startPrank(delegates[i].delegate);
                vm.expectRevert(abi.encodeWithSelector(Airdrop.InsufficientDelegation.selector, delegates[i].allowance, claimed));
                a.claim(airdrop[i].receiver, airdrop[i].amount, proof);
                vm.stopPrank();
            }
            // Check that claimed amounts are still the same for both cases
            assertEq(claimed, a.claimed(airdrop[i].receiver));
            assertEq(claimed, a.beneficiaryClaimed(airdrop[i].receiver, delegates[i].delegate));
            assertEq(claimed, a.balanceOf(delegates[i].delegate));
        }
    }
}
