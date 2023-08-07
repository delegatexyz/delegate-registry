// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IDelegateRegistry as IRegistry} from "src/IDelegateRegistry.sol";
import {RegistryOps as Ops} from "src/libraries/RegistryOps.sol";

contract RegistryOpsTests is Test {
    function _brutalizeBool(bool x) internal view returns (bool result) {
        assembly {
            mstore(0x00, gas())
            result := mul(iszero(iszero(x)), keccak256(0x00, 0x20))
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
}
