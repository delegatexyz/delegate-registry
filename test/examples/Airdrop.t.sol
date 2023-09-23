// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Merkle} from "murky/Merkle.sol";
import {Airdrop} from "src/examples/Airdrop.sol";
import {DelegateRegistry} from "src/DelegateRegistry.sol";
import {Math} from "openzeppelin/utils/math/Math.sol";

contract AirdropTest is Test {
    Merkle public merkle;

    DelegateRegistry public registry;

    struct AirdropRecord {
        address receiver;
        uint256 amount;
    }

    uint256 public constant MAX_AIRDROP_SIZE = 100;

    uint256 public constant MAX_AMOUNT = 2 ** 200;

    Airdrop public airdrop;

    AirdropRecord[] public airdropData;

    bytes32[] public airdropHashes;

    bytes32 public merkleRoot;

    bytes32 public acceptableRight;

    struct Delegate {
        address delegate;
        uint256 allowance;
        bytes32 rights;
    }

    Delegate[] public delegateData;

    function setUp() public {
        merkle = new Merkle();
        registry = new DelegateRegistry();
        acceptableRight = "airdrop";
    }

    function _createAirdrop(uint256 addressSeed, uint256 amountSeed, uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            (,, bytes32 data, AirdropRecord memory record) = _generateAirdropRecord(addressSeed, amountSeed, i);
            // Append to list
            airdropHashes.push(data);
            // Add to airdrop mapping
            airdropData.push(record);
        }
        merkleRoot = merkle.getRoot(airdropHashes);
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
        AirdropRecord memory record = airdropData[x];
        bytes32 data = keccak256(abi.encodePacked(receiver, amount));
        assertEq(amount, record.amount);
        assertEq(receiver, record.receiver);
        assertEq(data, airdropHashes[x]);
        // Generate proof and verify
        bytes32[] memory proof = merkle.getProof(airdropHashes, x);
        assertTrue(merkle.verifyProof(merkleRoot, proof, data));
    }

    function testAirdropWithoutDelegate(uint256 addressSeed, uint256 amountSeed, uint256 n, address referenceToken) public {
        vm.assume(referenceToken != address(0));
        vm.assume(n > 1 && n < MAX_AIRDROP_SIZE && addressSeed != amountSeed);
        _createAirdrop(addressSeed, amountSeed, n);
        // Calculate total tokens to mint
        uint256 totalSupply_;
        for (uint256 i; i < n; i++) {
            totalSupply_ += airdropData[i].amount;
        }
        // Create airdrop token
        airdrop = new Airdrop(address(registry), referenceToken, acceptableRight, totalSupply_, merkleRoot);
        // Check data is stored correctly in token
        assertEq(address(registry), address(airdrop.delegateRegistry()));
        assertEq(merkleRoot, airdrop.merkleRoot());
        assertEq(referenceToken, airdrop.referenceToken());
        // Test that total supply is expected
        assertEq(totalSupply_, airdrop.balanceOf(address(airdrop)));
        // Try to claim with bogus proof
        for (uint256 i = 0; i < n; i++) {
            (uint256 bogusAmount, address bogusReceiver,,) = _generateAirdropRecord(amountSeed, addressSeed, i);
            bytes32[] memory proof = merkle.getProof(airdropHashes, i);
            vm.startPrank(bogusReceiver);
            vm.expectRevert("Invalid Proof");
            airdrop.claim(bogusReceiver, bogusAmount, bogusAmount, proof);
            vm.stopPrank();
        }
        // Claim airdrop for every receiver
        for (uint256 i = 0; i < n; i++) {
            address claimant = airdropData[i].receiver;
            uint256 amount = airdropData[i].amount;
            bytes32[] memory proof = merkle.getProof(airdropHashes, i);
            vm.startPrank(claimant);
            airdrop.claim(claimant, amount, amount, proof);
            // Claim again to ensure accounting is working
            airdrop.claim(claimant, amount, amount, proof);
            vm.stopPrank();
            // Check that tokens are received
            assertEq(amount, airdrop.balanceOf(claimant));
            // Check that claimed mapping is updated
            assertEq(amount, airdrop.claimed(claimant));
        }
        // Verify that contract no longer has any tokens
        assertEq(0, airdrop.balanceOf(address(airdrop)));
    }

    function _createDelegates(uint256 delegateSeed, uint256 allowanceSeed, uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            uint256 allowance = uint256(keccak256(abi.encode(allowanceSeed, i))) % MAX_AMOUNT;
            if (allowance == 0) allowance += 1;
            address delegate = address(bytes20(keccak256(abi.encode(delegateSeed, i))));
            bytes32 rights = allowance % 2 == 0 ? bytes32(0) : acceptableRight;
            delegateData.push(Delegate({delegate: delegate, allowance: allowance, rights: rights}));
        }
    }

    function testAirdropWithDelegate(uint256 addressSeed, uint256 amountSeed, uint256 n, address referenceToken, uint256 delegateSeed, uint256 allowanceSeed) public {
        vm.assume(referenceToken != address(0));
        vm.assume(n > 1 && n < MAX_AIRDROP_SIZE && addressSeed != amountSeed && addressSeed != delegateSeed && addressSeed != allowanceSeed);
        vm.assume(amountSeed != delegateSeed && amountSeed != allowanceSeed);
        vm.assume(delegateSeed != allowanceSeed);
        _createAirdrop(addressSeed, amountSeed, n);
        // Calculate total tokens to mint
        uint256 totalSupply_;
        for (uint256 i; i < n; i++) {
            totalSupply_ += airdropData[i].amount;
        }
        // Create airdrop token
        airdrop = new Airdrop(address(registry), referenceToken, acceptableRight, totalSupply_, merkleRoot);
        // Create delegates
        _createDelegates(delegateSeed, allowanceSeed, n);
        // Try to claim with delegate
        // Try to claim every airdrop with delegate
        for (uint256 i = 0; i < n; i++) {
            address claimant = airdropData[i].receiver;
            uint256 amount = airdropData[i].amount;
            bytes32[] memory proof = merkle.getProof(airdropHashes, i);
            vm.startPrank(delegateData[i].delegate);
            vm.expectRevert("Insufficient Delegation");
            airdrop.claim(claimant, amount, amount, proof);
            vm.stopPrank();
        }
        // Delegate and claim airdrop
        for (uint256 i = 0; i < n; i++) {
            // Delegate
            vm.startPrank(airdropData[i].receiver);
            registry.delegateERC20(delegateData[i].delegate, referenceToken, delegateData[i].rights, delegateData[i].allowance);
            vm.stopPrank();
            // Delegate claims airdrop
            vm.startPrank(delegateData[i].delegate);
            bytes32[] memory proof = merkle.getProof(airdropHashes, i);
            airdrop.claim(airdropData[i].receiver, airdropData[i].amount, airdropData[i].amount, proof);
            vm.stopPrank();
            uint256 claimed = Math.min(delegateData[i].allowance, airdropData[i].amount);
            // Check that claimed is as expected
            assertEq(claimed, airdrop.claimed(airdropData[i].receiver));
            // Check that beneficiary claimed is as expected
            assertEq(claimed, airdrop.delegateClaimed(airdropData[i].receiver, delegateData[i].delegate));
            // Expect that token balance is claimed
            assertEq(claimed, airdrop.balanceOf(delegateData[i].delegate));
            // If claimed is airdrop amount, delegate tries to claim again but they receive no further tokens
            if (claimed == airdropData[i].amount) {
                vm.startPrank(delegateData[i].delegate);
                airdrop.claim(airdropData[i].receiver, airdropData[i].amount, airdropData[i].amount, proof);
                vm.stopPrank();
            }
            // Otherwise expect insufficient delegation error on further claim attempts
            else {
                vm.startPrank(delegateData[i].delegate);
                vm.expectRevert("Insufficient Delegation");
                airdrop.claim(airdropData[i].receiver, airdropData[i].amount, airdropData[i].amount, proof);
                vm.stopPrank();
            }
            // Check that claimed amounts are still the same for both cases
            assertEq(claimed, airdrop.claimed(airdropData[i].receiver));
            assertEq(claimed, airdrop.delegateClaimed(airdropData[i].receiver, delegateData[i].delegate));
            assertEq(claimed, airdrop.balanceOf(delegateData[i].delegate));
            // Get vault to claim remaining tokens
            uint256 remainingClaim = airdropData[i].amount - airdrop.claimed(airdropData[i].receiver);
            vm.startPrank(airdropData[i].receiver);
            airdrop.claim(airdropData[i].receiver, airdropData[i].amount, airdropData[i].amount, proof);
            vm.stopPrank();
            // Check balances for vault and delegate (again)
            assertEq(claimed + remainingClaim, airdrop.claimed(airdropData[i].receiver));
            assertEq(claimed, airdrop.delegateClaimed(airdropData[i].receiver, delegateData[i].delegate));
            assertEq(claimed, airdrop.balanceOf(delegateData[i].delegate));
            assertEq(remainingClaim, airdrop.balanceOf(airdropData[i].receiver));
        }
        // Verify that contract no longer has any tokens
        assertEq(0, airdrop.balanceOf(address(airdrop)));
    }
}
