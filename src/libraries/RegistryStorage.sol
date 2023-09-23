// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

library RegistryStorage {
    /// @dev Standardizes `from` storage flags to prevent double-writes in the delegation in/outbox if the same delegation is revoked and rewritten
    address internal constant DELEGATION_EMPTY = address(0);
    address internal constant DELEGATION_REVOKED = address(1);

    /// @dev Standardizes storage positions of delegation data
    uint256 internal constant POSITIONS_FIRST_PACKED = 0; //  | 4 bytes empty | first 8 bytes of contract address | 20 bytes of from address |
    uint256 internal constant POSITIONS_SECOND_PACKED = 1; // |        last 12 bytes of contract address          | 20 bytes of to address   |
    uint256 internal constant POSITIONS_RIGHTS = 2;
    uint256 internal constant POSITIONS_TOKEN_ID = 3;
    uint256 internal constant POSITIONS_AMOUNT = 4;

    /// @dev Used to clean address types of dirty bits with `and(address, CLEAN_ADDRESS)`
    uint256 internal constant CLEAN_ADDRESS = 0x00ffffffffffffffffffffffffffffffffffffffff;

    /// @dev Used to clean everything but the first 8 bytes of an address
    uint256 internal constant CLEAN_FIRST8_BYTES_ADDRESS = 0xffffffffffffffff << 96;

    /// @dev Used to clean everything but the first 8 bytes of an address in the packed position
    uint256 internal constant CLEAN_PACKED8_BYTES_ADDRESS = 0xffffffffffffffff << 160;

    /**
     * @notice Helper function that packs from, to, and contract_ address to into the two slot configuration
     * @param from The address making the delegation
     * @param to The address receiving the delegation
     * @param contract_ The contract address associated with the delegation (optional)
     * @return firstPacked The firstPacked storage configured with the parameters
     * @return secondPacked The secondPacked storage configured with the parameters
     * @dev Will not revert if `from`, `to`, and `contract_` are > uint160, any inputs with dirty bits outside the last 20 bytes will be cleaned
     */
    function packAddresses(address from, address to, address contract_) internal pure returns (bytes32 firstPacked, bytes32 secondPacked) {
        assembly {
            firstPacked := or(shl(64, and(contract_, CLEAN_FIRST8_BYTES_ADDRESS)), and(from, CLEAN_ADDRESS))
            secondPacked := or(shl(160, contract_), and(to, CLEAN_ADDRESS))
        }
    }

    /**
     * @notice Helper function that unpacks from, to, and contract_ address inside the firstPacked secondPacked storage configuration
     * @param firstPacked The firstPacked storage to be decoded
     * @param secondPacked The secondPacked storage to be decoded
     * @return from The address making the delegation
     * @return to The address receiving the delegation
     * @return contract_ The contract address associated with the delegation
     * @dev Will not revert if `from`, `to`, and `contract_` are > uint160, any inputs with dirty bits outside the last 20 bytes will be cleaned
     */
    function unpackAddresses(bytes32 firstPacked, bytes32 secondPacked) internal pure returns (address from, address to, address contract_) {
        assembly {
            from := and(firstPacked, CLEAN_ADDRESS)
            to := and(secondPacked, CLEAN_ADDRESS)
            contract_ := or(shr(64, and(firstPacked, CLEAN_PACKED8_BYTES_ADDRESS)), shr(160, secondPacked))
        }
    }

    /**
     * @notice Helper function that can unpack the from or to address from their respective packed slots in the registry
     * @param packedSlot The slot containing the from or to address
     * @return unpacked The `from` or `to` address
     * @dev Will not work if you want to obtain the contract address, use unpackAddresses
     */
    function unpackAddress(bytes32 packedSlot) internal pure returns (address unpacked) {
        assembly {
            unpacked := and(packedSlot, CLEAN_ADDRESS)
        }
    }
}
