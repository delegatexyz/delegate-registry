// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

library RegistryStorage {
    /// @dev Standardizes storage positions of delegation data
    enum Positions {
        firstPacked, //     | 4 bytes empty | first 8 bytes of contract address | 20 bytes of from address |
        secondPacked, //    |        last 12 bytes of contract address          | 20 bytes of to address   |
        rights,
        tokenId,
        amount
    }

    /// @dev Used to clean address types of dirty bits with and(address, CLEAN_ADDRESS)
    uint256 internal constant CLEAN_ADDRESS = 0x00ffffffffffffffffffffffffffffffffffffffff;

    /// @dev Used to clean everything but the first 8 bytes of an address
    uint256 internal constant CLEAN_FIRST8_BYTES_ADDRESS = 0xffffffffffffffff << 96;

    /// @dev Used to clean everything but the last 12 bytes of an address
    uint256 internal constant CLEAN_LAST12_BYTES_ADDRESS = 0xffffffffffffffffffffffff;

    /// @dev Used to clean everything but the first 8 bytes of an address in the packed position
    uint256 internal constant CLEAN_PACKED8_BYTES_ADDRESS = 0xffffffffffffffff << 160;

    /**
     * @notice Helper function that packs from, to, and contract_ address to into the two slot configuration
     * @param from is the address making the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the contract address associated with the delegation (optional)
     * @return firstPacked is the firstPacked storage configured with the parameters
     * @return secondPacked is the secondPacked storage configured with the parameters
     * @dev will not revert if from, to, and contract_ are > uint160, any inputs with dirty bits outside the last 20 bytes will be cleaned
     */
    function packAddresses(address from, address to, address contract_) internal pure returns (bytes32 firstPacked, bytes32 secondPacked) {
        assembly {
            firstPacked := or(shl(64, and(contract_, CLEAN_FIRST8_BYTES_ADDRESS)), and(from, CLEAN_ADDRESS))
            secondPacked := or(shl(160, contract_), and(to, CLEAN_ADDRESS))
        }
    }

    /**
     * @notice Helper function that unpacks from, to, and contract_ address inside the firstPacked secondPacked storage configuration
     * @param firstPacked is the firstPacked storage to be decoded
     * @param secondPacked is the secondPacked storage to be decoded
     * @return from is the address making the delegation
     * @return to is the address receiving the delegation
     * @return contract_ is the contract address associated with the delegation
     * @dev will not revert if from, to, and contract_ are > uint160, any inputs with dirty bits outside the last 20 bytes will be cleaned
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
     * @param packedSlot is the slot containing the from or to address
     * @return unpacked from or to address
     * @dev will not work if you want to obtain the contract address, use unpackAddresses
     */
    function unpackAddress(bytes32 packedSlot) internal pure returns (address unpacked) {
        assembly {
            unpacked := and(packedSlot, CLEAN_ADDRESS)
        }
    }
}
