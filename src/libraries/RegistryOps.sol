// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

library RegistryOps {
    /// @dev `x > y ? x : y`.
    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            // `gt(y, x)` will evaluate to 1 if `y > x`, else 0.
            //
            // If `y > x`:
            //     `x ^ ((x ^ y) * 1) = x ^ (x ^ y) = (x ^ x) ^ y = 0 ^ y = y`.
            // otherwise:
            //     `x ^ ((x ^ y) * 0) = x ^ 0 = x`.
            z := xor(x, mul(xor(x, y), gt(y, x)))
        }
    }

    /// @dev `x & y`.
    function and(bool x, bool y) internal pure returns (bool z) {
        assembly {
            // Any non-zero 256 bit word is true, else false.
            z := iszero(or(iszero(x), iszero(y)))
        }
    }

    /// @dev `x | y`.
    function or(bool x, bool y) internal pure returns (bool z) {
        assembly {
            // Any non-zero 256 bit word is true, else false.
            z := iszero(and(iszero(x), iszero(y)))
        }
    }
}
