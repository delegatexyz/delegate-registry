// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {RegistryOps as Ops} from "src/libraries/RegistryOps.sol";

contract RegistryOpsTests is Test {
    function _brutalizeBool(bool x) internal view returns (bool result) {
        assembly {
            mstore(0x00, gas())
            result := mul(iszero(iszero(x)), shl(128, keccak256(0x00, 0x20)))
        }
    }

    function _brutalizeUint32(uint32 x) internal view returns (uint32 result) {
        assembly {
            mstore(0x00, gas())
            result := or(x, shl(32, keccak256(0x00, 0x20)))
        }
    }

    function testMaxDifferential(uint256 x, uint256 y) public {
        assertEq(Ops.max(x, y), x > y ? x : y);
    }

    function testMaxDifferential(uint32 x, uint32 y) public {
        assertEq(Ops.max(_brutalizeUint32(x), _brutalizeUint32(y)), x > y ? x : y);
    }

    function testAndDifferential(bool x, bool y) public {
        assertEq(Ops.and(_brutalizeBool(x), _brutalizeBool(y)), x && y);
    }

    function testOrDifferential(bool x, bool y) public {
        assertEq(Ops.or(_brutalizeBool(x), _brutalizeBool(y)), x || y);
    }

    function testTruthyness(uint256 x, uint256 y) public {
        bool xCasted;
        bool yCasted;
        assembly {
            xCasted := x
            yCasted := y
        }
        assertEq(xCasted, x != 0);
        assertTrue(xCasted == (x != 0));
        assertEq(Ops.or(xCasted, yCasted), x != 0 || y != 0);
        assertTrue(Ops.or(xCasted, yCasted) == (x != 0 || y != 0));
        if (Ops.or(xCasted, yCasted)) if (!(x != 0 || y != 0)) revert();
        if (x != 0 || y != 0) if (!Ops.or(xCasted, yCasted)) revert();
        assertEq(Ops.and(xCasted, yCasted), x != 0 && y != 0);
        assertTrue(Ops.and(xCasted, yCasted) == (x != 0 && y != 0));
        if (Ops.and(xCasted, yCasted)) if (!(x != 0 && y != 0)) revert();
        if (x != 0 && y != 0) if (!Ops.and(xCasted, yCasted)) revert();
    }

    function testTruthyness(bool x, bool y) public {
        bool xCasted;
        bool yCasted;
        assembly {
            mstore(0x00, gas())
            xCasted := mul(iszero(iszero(x)), shl(128, keccak256(0x00, 0x20)))
            mstore(0x00, gas())
            yCasted := mul(iszero(iszero(y)), shl(128, keccak256(0x00, 0x20)))
        }
        assertEq(x, xCasted);
        assertEq(y, yCasted);
        assembly {
            if and(0xff, xCasted) { revert(0x00, 0x00) }
            if and(0xff, yCasted) { revert(0x00, 0x00) }
        }
        assertEq(Ops.or(xCasted, yCasted), x || y);
        assertTrue(Ops.or(xCasted, yCasted) == (x || y));
        if (Ops.or(xCasted, yCasted)) if (!(x || y)) revert();
        if (x || y) if (!Ops.or(xCasted, yCasted)) revert();
        assertEq(Ops.and(xCasted, yCasted), x && y);
        assertTrue(Ops.and(xCasted, yCasted) == (x && y));
        if (Ops.and(xCasted, yCasted)) if (!(x && y)) revert();
        if (x && y) if (!Ops.and(xCasted, yCasted)) revert();
    }

    function testTruthyness(bool x) public {
        bool casted;
        if (casted) revert();
        assertEq(casted, false);
        assertTrue(casted == false);
        assembly {
            if x {
                mstore(0x00, gas())
                casted := mul(iszero(iszero(x)), shl(128, keccak256(0x00, 0x20)))
            }
        }
        assertEq(x, casted);
        assertTrue(x == casted);
        if (x) if (!casted) revert();
        if (casted) if (!x) revert();
    }
}
