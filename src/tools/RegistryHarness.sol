// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {DelegateRegistry} from "src/DelegateRegistry.sol";

import {RegistryHashes} from "../libraries/RegistryHashes.sol";

/// @dev harness contract that exposes internal registry methods as external ones
contract RegistryHarness is DelegateRegistry {
    constructor() {
        delegations[0][0] = 0;
    }

    bytes32[] temporaryStorage;

    function exposedDelegations(bytes32 hash) external view returns (bytes32[5] memory) {
        return delegations[hash];
    }

    function exposedOutgoingDelegationHashes(address vault) external view returns (bytes32[] memory) {
        return outgoingDelegationHashes[vault];
    }

    function exposedIncomingDelegationHashes(address delegate) external view returns (bytes32[] memory) {
        return incomingDelegationHashes[delegate];
    }

    function exposedDelegationEmpty() external pure returns (address) {
        return DELEGATION_EMPTY;
    }

    function exposedDelegationRevoked() external pure returns (address) {
        return DELEGATION_REVOKED;
    }

    function exposedComputeHashForAll(address delegate, bytes32 rights, address vault) external pure returns (bytes32) {
        return RegistryHashes._computeAll(delegate, rights, vault);
    }

    function exposedComputeHashForContract(address contract_, address delegate, bytes32 rights, address vault) external pure returns (bytes32) {
        return RegistryHashes._computeContract(contract_, delegate, rights, vault);
    }

    function exposedComputeHashForERC721(address contract_, address delegate, bytes32 rights, uint256 tokenId, address vault) external pure returns (bytes32) {
        return RegistryHashes._computeERC721(contract_, delegate, rights, tokenId, vault);
    }

    function exposedComputeHashForERC20(address contract_, address delegate, bytes32 rights, address vault) external pure returns (bytes32) {
        return RegistryHashes._computeERC20(contract_, delegate, rights, vault);
    }

    function exposedComputeHashForERC1155(address contract_, address delegate, bytes32 rights, uint256 tokenId, address vault) external pure returns (bytes32) {
        return RegistryHashes._computeERC1155(contract_, delegate, rights, tokenId, vault);
    }

    function exposedPushDelegationHashes(address from, address to, bytes32 delegationHash) external {
        _pushDelegationHashes(from, to, delegationHash);
    }

    function exposedWriteDelegation(bytes32 location, StoragePositions position, bytes32 data) external {
        _writeDelegation(location, position, data);
    }

    function exposedWriteDelegation(bytes32 location, StoragePositions position, uint256 data) external {
        _writeDelegation(location, position, data);
    }

    function exposedWriteDelegationAddresses(bytes32 location, StoragePositions firstPacked, StoragePositions secondPacked, address from, address to, address contract_)
        external
    {
        _writeDelegationAddresses(location, firstPacked, secondPacked, from, to, contract_);
    }

    function exposedGetValidDelegationsFromHashes(bytes32[] calldata hashes) external returns (Delegation[] memory delegations_) {
        temporaryStorage = hashes;
        delegations_ = _getValidDelegationsFromHashes(temporaryStorage);
        delete temporaryStorage;
    }

    function exposedGetValidDelegationHashesFromHashes(bytes32[] calldata hashes) external returns (bytes32[] memory validHashes) {
        temporaryStorage = hashes;
        validHashes = _getValidDelegationHashesFromHashes(temporaryStorage);
        delete temporaryStorage;
    }

    function exposedLoadDelegationBytes32(bytes32 location, StoragePositions position) external view returns (bytes32 data) {
        return _loadDelegationBytes32(location, position);
    }

    function exposedLoadDelegationUint(bytes32 location, StoragePositions position) external view returns (uint256 data) {
        return _loadDelegationUint(location, position);
    }

    function exposedLoadFrom(bytes32 location, StoragePositions firstPacked) external view returns (address from) {
        return _loadFrom(location, firstPacked);
    }

    function exposedLoadDelegationAddresses(bytes32 location, StoragePositions firstPacked, StoragePositions secondPacked)
        external
        view
        returns (address from, address to, address contract_)
    {
        return _loadDelegationAddresses(location, firstPacked, secondPacked);
    }

    function exposedValidateDelegation(bytes32 location, address from) external view returns (bool) {
        return _validateDelegation(location, from);
    }

    // Relics moved to library

    function exposedEncodeLastByteWithType(bytes32 input, DelegationType type_) external pure returns (bytes32) {
        return RegistryHashes._encodeLastByteWithType(input, type_);
    }

    function exposedDecodeLastByteToType(bytes32 input) external pure returns (DelegationType) {
        return RegistryHashes._decodeLastByteToType(input);
    }

    function exposedComputeLocation(bytes32 hash) external pure returns (bytes32 location) {
        return RegistryHashes._computeLocation(hash);
    }
}
