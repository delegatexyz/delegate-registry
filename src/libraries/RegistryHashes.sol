// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {IDelegateRegistry} from "../IDelegateRegistry.sol";

/**
 * @title Library for calculating the hashes and storage locations used in the delegate registry
 *
 * The encoding for the 5 types of delegate registry hashes should be as follows
 *
 * ALL:         keccak256(abi.encodePacked(rights, from, to))
 * CONTRACT:    keccak256(abi.encodePacked(rights, from, to, contract_))
 * ERC721:      keccak256(abi.encodePacked(rights, from, to, contract_, tokenId))
 * ERC20:       keccak256(abi.encodePacked(rights, from, to, contract_))
 * ERC1155:     keccak256(abi.encodePacked(rights, from, to, contract_, tokenId))
 *
 * To avoid collisions between the hashes with respect to type, the hash is shifted left by one byte and the last byte is then encoded with a unique number for the
 * delegation type.
 *
 */
library RegistryHashes {
    /// @dev Used to delete everything but the last byte of a 32 byte word with and(word, EXTRACT_LAST_BYTE)
    uint256 internal constant EXTRACT_LAST_BYTE = 0xff;
    /// @dev uint256 constant for the delegate registry delegation type enumeration, related unit test should fail if these mismatch
    uint256 internal constant ALL_TYPE = 1;
    uint256 internal constant CONTRACT_TYPE = 2;
    uint256 internal constant ERC721_TYPE = 3;
    uint256 internal constant ERC20_TYPE = 4;
    uint256 internal constant ERC1155_TYPE = 5;
    /// @dev uint256 constant for the location of the delegations array in the delegate registry, assumed to be zero
    uint256 internal constant DELEGATION_SLOT = 0;

    /**
     * @notice Helper function to decode last byte of a delegation hash to obtain its delegation type
     * @param inputHash to decode the type from
     * @return decodedType of the delegation
     * @dev function itself will not revert if decodedType > type(IDelegateRegistry.DelegationType).max
     * @dev may lead to a revert with Conversion into non-existent enum type after the function is called if inputHash was encoded with type outside the DelegationType
     * enum range
     */
    function decodeType(bytes32 inputHash) internal pure returns (IDelegateRegistry.DelegationType decodedType) {
        assembly {
            decodedType := and(inputHash, EXTRACT_LAST_BYTE)
        }
    }

    /**
     * @notice Helper function that computes the storage location of a particular delegation array
     * @param inputHash is the hash of the delegation
     * @return computedLocation is the storage key of the delegation array at position 0
     * @dev Storage keys further down the array can be obtained by adding computedLocation with the element position
     * @dev Follows the solidity storage location encoding for a mapping(bytes32 => fixedArray) at the position of the delegationSlot
     */
    function location(bytes32 inputHash) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            // This block only allocates memory in the scratch space
            mstore(0, inputHash)
            mstore(32, DELEGATION_SLOT)
            computedLocation := keccak256(0, 64) // Run keccak256 over bytes in scratch space to obtain the storage key
        }
    }

    /**
     * @notice Helper function to compute delegation hash for all delegation
     * @param from is the address making the delegation
     * @param rights it the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @return hash of the delegation parameters encoded with ALL_TYPE
     * @dev returned hash should be equivalent to keccak256(abi.encodePacked(rights, from, to)) followed by a shift left by 1 byte and writing the delegation type to the
     * cleaned last byte
     * @dev will not revert if from or to are > uint160, any input larger than uint160 for from and to will be cleaned to their last 20 bytes
     */
    function allHash(address from, bytes32 rights, address to) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer
            let ptr := mload(64) // Load the free memory pointer
            // Layout the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 40), to)
            mstore(add(ptr, 20), from)
            mstore(ptr, rights)
            hash := or(shl(8, keccak256(ptr, 72)), ALL_TYPE) // Runs keccak over the packed encoding, shifts left by one byte, then writes the type to the last
                // byte
        }
    }

    /**
     * @notice Helper function to compute delegation location for all delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @return computedLocation is the storage location of the all delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(allHash(rights, from, to)) would
     * @dev will not revert if from or to are > uint160, any input larger than uint160 for from and to will be cleaned to their last 20 bytes
     */
    function allLocation(address from, bytes32 rights, address to) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer and in the scratch space
            let ptr := mload(64) // Load the free memory pointer
            // Layout the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 40), to)
            mstore(add(ptr, 20), from)
            mstore(ptr, rights)
            mstore(0, or(shl(8, keccak256(ptr, 72)), ALL_TYPE)) // Runs keccak over the packed encoding, shifts left by one byte, then writes the type to the
                // last byte, and stores the result in the scratch space
            mstore(32, DELEGATION_SLOT)
            computedLocation := keccak256(0, 64) // Runs keccak over the scratch space to obtain the storage key
        }
    }

    /**
     * @notice Helper function to compute delegation hash for contract delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the address of the contract specified by the delegation
     * @return hash of the delegation parameters encoded with CONTRACT_TYPE
     * @dev returned hash should be equivalent to keccak256(abi.encodePacked(rights, from, to, contract_)) with the last byte overwritten with CONTRACT_TYPE
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function contractHash(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer
            let ptr := mload(64) // Load the free memory pointer
            // Layout the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 60), contract_)
            mstore(add(ptr, 40), to)
            mstore(add(ptr, 20), from)
            mstore(ptr, rights)
            hash := or(shl(8, keccak256(ptr, 92)), CONTRACT_TYPE) // Runs keccak over the packed encoding, shifts left by one byte, then writes the type to the last byte
        }
    }

    /**
     * @notice Helper function to compute delegation location for contract delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the address of the contract specified by the delegation
     * @return computedLocation is the storage location of the contract delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(contractHash(rights, from, to, contract_)) would
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function contractLocation(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer and in the scratch space
            let ptr := mload(64) // Load free memory pointer
            // Layout the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 60), contract_)
            mstore(add(ptr, 40), to)
            mstore(add(ptr, 20), from)
            mstore(ptr, rights)
            mstore(0, or(shl(8, keccak256(ptr, 92)), CONTRACT_TYPE)) // Runs keccak over the packed encoding, shifts left by one byte, then writes the type to the
                // last byte, and stores the result in the scratch space
            mstore(32, DELEGATION_SLOT)
            computedLocation := keccak256(0, 64) // Runs keccak over the scratch space to obtain the storage key
        }
    }

    /**
     * @notice Helper function to compute delegation hash for ERC721 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param tokenId is the id of the token specified by the delegation
     * @param contract_ is the address of the contract specified by the delegation
     * @return hash of the parameters encoded with ERC721_TYPE
     * @dev returned hash should be equivalent to keccak256(abi.encodePacked(rights, from, to, contract_, tokenId)) with the last byte overwritten with ERC721_TYPE
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc721Hash(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer
            let ptr := mload(64) // Cache the free memory pointer.
            // Layout the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 92), tokenId)
            mstore(add(ptr, 60), contract_)
            mstore(add(ptr, 40), to)
            mstore(add(ptr, 20), from)
            mstore(ptr, rights)
            hash := or(shl(8, keccak256(ptr, 124)), ERC721_TYPE) // Runs keccak over the packed encoding, shifts left by one byte, then writes the type to the last byte
        }
    }

    /**
     * @notice Helper function to compute delegation location for ERC721 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param tokenId is the id of the erc721 token
     * @param contract_ is the address of the erc721 token contract
     * @return computedLocation is the storage location of the erc721 delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(erc721Hash(rights, from, to, contract_, tokenId)) would
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc721Location(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer and in the scratch space
            let ptr := mload(64) // Cache the free memory pointer.
            // Layout the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 92), tokenId)
            mstore(add(ptr, 60), contract_)
            mstore(add(ptr, 40), to)
            mstore(add(ptr, 20), from)
            mstore(ptr, rights)
            mstore(0, or(shl(8, keccak256(ptr, 124)), ERC721_TYPE)) // Runs keccak over the packed encoding, shifts left by one byte, then writes the type to the
                // last byte, and stores the result in the scratch space
            mstore(32, DELEGATION_SLOT)
            computedLocation := keccak256(0, 64) // Runs keccak256 over the scratch space to obtain the storage key
        }
    }

    /**
     * @notice Helper function to compute delegation hash for ERC20 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the address of the erc20 token contract
     * @return hash of the parameters encoded with ERC20_TYPE
     * @dev returned hash should be equivalent to keccak256(abi.encodePacked(rights, from, to, contract_)) with the last byte overwritten with ERC20_TYPE
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc20Hash(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer
            let ptr := mload(64) // Load free memory pointer
            // Layout the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 60), contract_)
            mstore(add(ptr, 40), to)
            mstore(add(ptr, 20), from)
            mstore(ptr, rights)
            hash := or(shl(8, keccak256(ptr, 92)), ERC20_TYPE) // Runs keccak over the packed encoding, shifts left by one byte, then writes the type to the last byte
        }
    }

    /**
     * @notice Helper function to compute delegation location for ERC20 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the address of the erc20 token contract
     * @return computedLocation is the storage location of the erc20 delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(erc20Hash(rights, from, to, contract_)) would
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc20Location(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer and in the scratch space
            let ptr := mload(64) // Loads the free memory pointer
            // Layout the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 60), contract_)
            mstore(add(ptr, 40), to)
            mstore(add(ptr, 20), from)
            mstore(ptr, rights)
            mstore(0, or(shl(8, keccak256(ptr, 92)), ERC20_TYPE)) // Runs keccak over the packed encoding, shifts left by one byte, then writes the type to the
                // last byte, and stores the result in the scratch space
            mstore(32, DELEGATION_SLOT)
            computedLocation := keccak256(0, 64) // Runs keccak over the scratch space to obtain the storage key
        }
    }

    /**
     * @notice Helper function to compute delegation hash for ERC1155 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param tokenId is the id of the erc1155 token
     * @param contract_ is the address of the erc1155 token contract
     * @return hash of the parameters encoded with ERC1155_TYPE
     * @dev returned hash should be equivalent to keccak256(abi.encodePacked(rights, from, to, contract_, tokenId)) with the last byte overwritten with ERC1155_TYPE
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc1155Hash(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer
            let ptr := mload(64) // Load the free memory pointer.
            // Layout the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 92), tokenId)
            mstore(add(ptr, 60), contract_)
            mstore(add(ptr, 40), to)
            mstore(add(ptr, 20), from)
            mstore(ptr, rights)
            hash := or(shl(8, keccak256(ptr, 124)), ERC1155_TYPE) // Runs keccak over the packed encoding, shifts left by one byte, then writes the type to the last byte
        }
    }

    /**
     * @notice Helper function to compute delegation hash for ERC1155 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param tokenId is the id of the erc1155 token
     * @param contract_ is the address of the erc1155 token contract
     * @return computedLocation is the storage location of the erc1155 delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(erc1155Hash(rights, from, to, contract_, tokenId)) would
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc1155Location(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer and in the scratch space
            let ptr := mload(64) // Cache the free memory pointer.
            // Layout the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 92), tokenId)
            mstore(add(ptr, 60), contract_)
            mstore(add(ptr, 40), to)
            mstore(add(ptr, 20), from)
            mstore(ptr, rights)
            mstore(0, or(shl(8, keccak256(ptr, 124)), ERC1155_TYPE)) // Runs keccak over the packed encoding, shifts left by one byte, then writes the type to the
                // last byte, and stores the result in the scratch space
            mstore(32, DELEGATION_SLOT)
            computedLocation := keccak256(0, 64) // Runs keccak over the scratch space to obtain the storage key
        }
    }
}
