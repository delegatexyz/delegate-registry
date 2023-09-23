// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {RegistryStorage as Storage} from "src/libraries/RegistryStorage.sol";
import {RegistryHarness as Harness} from "./tools/RegistryHarness.sol";

contract RegistryStorageTests is Test {
    Harness harness;

    function setUp() public {
        harness = new Harness();
    }

    /// @dev Check that storage positions match up with the expect form of the delegations array
    function testStoragePositions() public {
        assertEq(Storage.POSITIONS_FIRST_PACKED, 0);
        assertEq(Storage.POSITIONS_SECOND_PACKED, 1);
        assertEq(Storage.POSITIONS_RIGHTS, 2);
        assertEq(Storage.POSITIONS_TOKEN_ID, 3);
        assertEq(Storage.POSITIONS_AMOUNT, 4);
    }

    /// @dev Check that storage library constants are as intended
    function testStorageConstants() public {
        assertEq(Storage.CLEAN_ADDRESS, uint256(type(uint160).max));
        assertEq(Storage.CLEAN_FIRST8_BYTES_ADDRESS, uint256(type(uint64).max) << 96);
        assertEq(Storage.CLEAN_PACKED8_BYTES_ADDRESS, uint256(type(uint64).max) << 160);
        assertEq(Storage.DELEGATION_EMPTY, address(0));
        assertEq(Storage.DELEGATION_REVOKED, address(1));
    }

    /// @dev Check that pack addresses works as intended
    function testPackAddresses(address from, address to, address contract_) public {
        (bytes32 firstPacked, bytes32 secondPacked) = Storage.packAddresses(from, to, contract_);
        assertEq(from, address(uint160(uint256(firstPacked))));
        assertEq(to, address(uint160(uint256(secondPacked))));
        // Check that there is 4 bytes of zeros at the start of first packed
        assertEq(0, uint256(firstPacked) >> 224);
        // Check contract is stored correctly
        assertEq(uint256(uint160(contract_)) >> 96, uint256(firstPacked) >> 160);
        assertEq((uint256(uint160(contract_)) << 160) >> 160, uint256(secondPacked) >> 160);
        // Check that unpackAddresses inverts correctly
        (address checkFrom, address checkTo, address checkContract_) = Storage.unpackAddresses(firstPacked, secondPacked);
        assertEq(from, checkFrom);
        assertEq(to, checkTo);
        assertEq(contract_, checkContract_);
        // Check that unpackAddress inverts correctly
        (checkFrom) = Storage.unpackAddress(firstPacked);
        (checkTo) = Storage.unpackAddress(secondPacked);
        assertEq(checkFrom, from);
        assertEq(checkTo, to);
    }

    function testPackAddressesLargeInputs(uint256 from, uint256 to, uint256 contract_) public {
        uint256 minSize = type(uint160).max;
        vm.assume(from > minSize && to > minSize && contract_ > minSize);
        address largeFrom;
        address largeTo;
        address largeContract_;
        assembly {
            largeFrom := from
            largeTo := to
            largeContract_ := contract_
        }
        uint256 testLargeFrom;
        uint256 testLargeTo;
        uint256 testLargeContract_;
        assembly {
            testLargeFrom := largeFrom
            testLargeTo := largeTo
            testLargeContract_ := largeContract_
        }
        assertEq(testLargeFrom, from);
        assertEq(testLargeTo, to);
        assertEq(testLargeContract_, contract_);
        bytes32 firstPacked;
        bytes32 secondPacked;
        (firstPacked, secondPacked) = Storage.packAddresses(largeFrom, largeTo, largeContract_);
        // Check that there is 4 bytes of zeros at the start of first packed
        assertEq(0, uint256(firstPacked) >> 224);
        // Check that large numbers do not match
        assertFalse(uint160(uint256(firstPacked)) == from);
        assertFalse(uint160(uint256(secondPacked)) == to);
        // Check that large numbers were correctly cleaned
        assertEq(uint160(uint256(firstPacked)), uint160(from));
        assertEq(uint160(uint256(secondPacked)), uint160(to));
        // unpackAddress and check they do not equal inputs
        (largeFrom, largeTo, largeContract_) = Storage.unpackAddresses(firstPacked, secondPacked);

        assembly {
            testLargeFrom := largeFrom
            testLargeTo := largeTo
            testLargeContract_ := largeContract_
        }
        // Assert that clean unpacked does not equal large inputs
        assertFalse(from == testLargeFrom);
        assertFalse(to == testLargeTo);
        assertFalse(contract_ == testLargeContract_);
        // Assert that clean unpacked matches cleaned inputs
        assertEq(address(uint160(from)), largeFrom);
        assertEq(address(uint160(to)), largeTo);
        assertEq(address(uint160(contract_)), largeContract_);
        // unpackAddress and check they do not equal inputs
        (largeFrom) = Storage.unpackAddress(firstPacked);
        (largeTo) = Storage.unpackAddress(secondPacked);
        assembly {
            testLargeFrom := largeFrom
            testLargeTo := largeTo
        }
        // Assert that clean unpacked does not equal large inputs
        assertFalse(from == testLargeFrom);
        assertFalse(to == testLargeTo);
        // Assert that clean unpacked matches cleaned inputs
        assertEq(address(uint160(from)), largeFrom);
        assertEq(address(uint160(to)), largeTo);
    }
}
