// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IDelegateRegistry} from "../IDelegateRegistry.sol";

/**
 * @title Library for calculating the hashes and storage locations used in the delegate registry
 *
 * The encoding for the 5 types of delegate registry hashes should be as follows
 *
 * ALL:         keccak256(abi.encode(from, rights, to))
 * CONTRACT:    keccak256(abi.encode(from, rights, to, contract_))
 * ERC721:      keccak256(abi.encode(from, rights, to, tokenId, contract_))
 * ERC20:       keccak256(abi.encode(from, rights, to, contract_))
 * ERC1155:     keccak256(abi.encode(from, rights, to, tokenId, contract_))
 *
 * To avoid collisions between the hashes with respect to type, the last byte of the hash is encoded with a unique number representing the type of delegation.
 *
 */
library RegistryHashes {
    /// @dev Used to delete the last byte of a 32 byte word with and(word, deleteLastByte)
    bytes32 internal constant deleteLastByte = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00;
    /// @dev Used to clean address types of dirty bits with and(address, cleanAddress)
    bytes32 internal constant cleanAddress = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Used to delete everything but the last byte of a 32 byte word with and(word, extractLastByte)
    uint256 internal constant extractLastByte = 0xFF;
    /// @dev uint256 constant for the delegate registry delegation type enumeration, related unit test should fail if these mismatch
    uint256 internal constant allType = 1;
    uint256 internal constant contractType = 2;
    uint256 internal constant erc721Type = 3;
    uint256 internal constant erc20Type = 4;
    uint256 internal constant erc1155Type = 5;
    /// @dev uint256 constant for the location of the delegations array in the delegate registry, assumed to be zero
    uint256 internal constant delegationSlot = 0;

    /**
     * @notice Helper function to encode the last byte of a delegation hash with a delegation type
     * @param inputHash is the hash to encode the type in
     * @param inputType is the type to encode in the hash
     * @dev Will not revert for inputType larger than type(IDelegationRegistry.DelegationType).max, and any inputType larger than uint8 will be cleaned to its byte
     * furthest to the right
     * @return outputHash is inputHash with its last byte overwritten with the inputType
     */
    function encodeType(bytes32 inputHash, uint256 inputType) internal pure returns (bytes32 outputHash) {
        assembly {
            outputHash := or(and(inputHash, deleteLastByte), and(inputType, extractLastByte))
        }
    }

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
            decodedType := and(inputHash, extractLastByte)
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
            mstore(0, inputHash) // Store hash in scratch space
            mstore(32, delegationSlot) // Store delegationSlot after hash in scratch space
            computedLocation := keccak256(0, 64) // Run keccak256 over bytes in scratch space to obtain the storage key
        }
    }

    /**
     * @notice Helper function to compute delegation hash for all delegation
     * @param from is the address making the delegation
     * @param rights it the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @return hash of the delegation parameters encoded with allType
     * @dev returned hash should be equivalent to keccak256(abi.encode(from, rights, to)) with the last byte overwritten with allType
     * @dev will not revert if from or to are > uint160, any input larger than uint160 for from and to will be cleaned to their last 20 bytes
     */
    function allHash(address from, bytes32 rights, address to) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Set ptr to the free memory location
            mstore(ptr, and(from, cleanAddress)) // Cleans and stores from
            mstore(add(ptr, 32), rights) // Store rights
            mstore(add(ptr, 64), and(to, cleanAddress)) // Cleans and stores to
            hash := or(and(keccak256(ptr, 96), deleteLastByte), allType) // Runs keccak256 on the 96 bytes at ptr, and then encodes the last byte of that hash with
                // allType
        }
    }

    /**
     * @notice Helper function to compute delegation location for all delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @return computedLocation is the storage location of the all delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(allHash(from, rights, to)) would
     * @dev will not revert if from or to are > uint160, any input larger than uint160 for from and to will be cleaned to their last 20 bytes
     */
    function allLocation(address from, bytes32 rights, address to) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Set ptr to the free memory location
            mstore(ptr, and(from, cleanAddress)) // Cleans and stores from
            mstore(add(ptr, 32), rights) // Store rights
            mstore(add(ptr, 64), and(to, cleanAddress)) // Cleans and stores to
            mstore(ptr, or(and(keccak256(ptr, 96), deleteLastByte), allType)) // Store allHash at ptr location
            mstore(add(ptr, 32), delegationSlot) // Store delegationSlot after allHash at ptr location
            computedLocation := keccak256(ptr, 64) // Runs keccak256 on the 64 bytes at ptr to obtain the location
        }
    }

    /**
     * @notice Helper function to compute delegation hash for contract delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the address of the contract specified by the delegation
     * @return hash of the delegation parameters encoded with contractType
     * @dev returned hash should be equivalent to keccak256(abi.encode(from, rights, to, contract_)) with the last byte overwritten with contractType
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function contractHash(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Set ptr to the free memory location
            mstore(ptr, and(from, cleanAddress)) // Cleans and stores from
            mstore(add(ptr, 32), rights) // Store rights
            mstore(add(ptr, 64), and(to, cleanAddress)) // Cleans and stores to
            mstore(add(ptr, 96), and(contract_, cleanAddress)) // Cleans and store contract_
            hash := or(and(keccak256(ptr, 128), deleteLastByte), contractType) // Run keccak256 on the 128 bytes at ptr, and then encodes the last byte of that hash with
                // contractType
        }
    }

    /**
     * @notice Helper function to compute delegation location for contract delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the address of the contract specified by the delegation
     * @return computedLocation is the storage location of the contract delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(contractHash(from, rights, to, contract_)) would
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function contractLocation(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Set ptr to the free memory location
            mstore(ptr, and(from, cleanAddress)) // Cleans and stores from
            mstore(add(ptr, 32), rights) // Store rights
            mstore(add(ptr, 64), and(to, cleanAddress)) // Cleans and stores to
            mstore(add(ptr, 96), and(contract_, cleanAddress)) // Cleans and store contract_
            mstore(ptr, or(and(keccak256(ptr, 128), deleteLastByte), contractType)) // Store contractHash
            mstore(add(ptr, 32), delegationSlot) // Store delegationSlot after hash
            computedLocation := keccak256(ptr, 64) // Run keccak256 on the 64 bytes at ptr to obtain the location
        }
    }

    /**
     * @notice Helper function to compute delegation hash for ERC721 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param tokenId is the id of the token specified by the delegation
     * @param contract_ is the address of the contract specified by the delegation
     * @return hash of the parameters encoded with erc721Type
     * @dev returned hash should be equivalent to keccak256(abi.encode(from, rights, to, tokenId, contract_)) with the last byte overwritten with erc721Type
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc721Hash(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Set ptr to the free memory location
            mstore(ptr, and(from, cleanAddress)) // Cleans and stores from
            mstore(add(ptr, 32), rights) // Store rights
            mstore(add(ptr, 64), and(to, cleanAddress)) // Cleans and stores to
            mstore(add(ptr, 96), tokenId) // Stores tokenId
            mstore(add(ptr, 128), and(contract_, cleanAddress)) // Cleans and store contract_
            hash := or(and(keccak256(ptr, 160), deleteLastByte), erc721Type) // Run keccak256 on the 160 bytes at ptr, and then encodes the last byte of that hash with
                // erc721Type
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
     * @dev gives the same location hash as location(erc721Hash(from, rights, to, tokenId, contract_)) would
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc721Location(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Set ptr to the free memory location
            mstore(ptr, and(from, cleanAddress)) // Cleans and stores from
            mstore(add(ptr, 32), rights) // Store rights
            mstore(add(ptr, 64), and(to, cleanAddress)) // Cleans and stores to
            mstore(add(ptr, 96), tokenId) // Stores tokenId
            mstore(add(ptr, 128), and(contract_, cleanAddress)) // Cleans and store contract_
            mstore(ptr, or(and(keccak256(ptr, 160), deleteLastByte), erc721Type)) // Store erc721Hash
            mstore(add(ptr, 32), delegationSlot) // Stores delegationSlot
            computedLocation := keccak256(ptr, 64)
        }
    }

    /**
     * @notice Helper function to compute delegation hash for ERC20 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the address of the erc20 token contract
     * @return hash of the parameters encoded with erc20Type
     * @dev returned hash should be equivalent to keccak256(abi.encode(from, rights, to, contract_)) with the last byte overwritten with erc20Type
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc20Hash(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Set ptr to the free memory location
            mstore(ptr, and(from, cleanAddress)) // Cleans and stores from
            mstore(add(ptr, 32), rights) // Stores rights
            mstore(add(ptr, 64), and(to, cleanAddress)) // Cleans and stores to
            mstore(add(ptr, 96), and(contract_, cleanAddress)) // Cleans and stores contract_
            hash := or(and(keccak256(ptr, 128), deleteLastByte), erc20Type) // Runs keccak256 on 128 bytes at ptr and encodes that hash with erc20Type
        }
    }

    /**
     * @notice Helper function to compute delegation location for ERC20 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the address of the erc20 token contract
     * @return computedLocation is the storage location of the erc20 delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(erc20Hash(from, rights, to, contract_)) would
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc20Location(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Set ptr to the free memory location
            mstore(ptr, and(from, cleanAddress)) // Cleans and stores from
            mstore(add(ptr, 32), rights) // Store rights
            mstore(add(ptr, 64), and(to, cleanAddress)) // Cleans and stores to
            mstore(add(ptr, 96), and(contract_, cleanAddress)) // Cleans and store contract_
            mstore(ptr, or(and(keccak256(ptr, 128), deleteLastByte), erc20Type)) // Store erc20Hash
            mstore(add(ptr, 32), delegationSlot) // Store delegationSlot
            computedLocation := keccak256(ptr, 64) // Runs keccak256 on the 64 bytes at ptr to get the location
        }
    }

    /**
     * @notice Helper function to compute delegation hash for ERC1155 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param tokenId is the id of the erc1155 token
     * @param contract_ is the address of the erc1155 token contract
     * @return hash of the parameters encoded with erc1155Type
     * @dev returned hash should be equivalent to keccak256(abi.encode(from, rights, to, tokenId, contract_)) with the last byte overwritten with erc1155Type
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc1155Hash(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Set ptr to the free memory location
            mstore(ptr, and(from, cleanAddress)) // Cleans and stores from
            mstore(add(ptr, 32), rights) // Store rights
            mstore(add(ptr, 64), and(to, cleanAddress)) // Cleans and stores to
            mstore(add(ptr, 96), tokenId) // Stores tokenId
            mstore(add(ptr, 128), and(contract_, cleanAddress)) // Cleans and store contract_
            hash := or(and(keccak256(ptr, 160), deleteLastByte), erc1155Type) // Runs keccak256 on 160 bytes at ptr and encodes the last byte of that hash with
                // erc1155Type
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
     * @dev gives the same location hash as location(erc1155Hash(from, rights, to, tokenId, contract_)) would
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc1155Location(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Set ptr to the free memory location
            mstore(ptr, and(from, cleanAddress)) // Cleans and stores from
            mstore(add(ptr, 32), rights) // Store rights
            mstore(add(ptr, 64), and(to, cleanAddress)) // Cleans and stores to
            mstore(add(ptr, 96), tokenId) // Stores tokenId
            mstore(add(ptr, 128), and(contract_, cleanAddress)) // Cleans and store contract_
            mstore(ptr, or(and(keccak256(ptr, 160), deleteLastByte), erc1155Type)) // Stores erc1155Hash
            mstore(add(ptr, 32), delegationSlot) // Store delegationSlot
            computedLocation := keccak256(ptr, 64) // Runs keccak256 on 64 bytes at ptr to obtain the location
        }
    }
}
