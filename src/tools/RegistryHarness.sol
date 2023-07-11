// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {DelegateRegistry} from "src/DelegateRegistry.sol";

import {RegistryStorage} from "src/libraries/RegistryStorage.sol";

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

    function exposedPushDelegationHashes(address from, address to, bytes32 delegationHash) external {
        _pushDelegationHashes(from, to, delegationHash);
    }

    function exposedWriteDelegation(bytes32 location, RegistryStorage.Positions position, bytes32 data) external {
        _writeDelegation(location, position, data);
    }

    function exposedWriteDelegation(bytes32 location, RegistryStorage.Positions position, uint256 data) external {
        _writeDelegation(location, position, data);
    }

    function exposedWriteDelegationAddresses(
        bytes32 location,
        RegistryStorage.Positions firstPacked,
        RegistryStorage.Positions secondPacked,
        address from,
        address to,
        address contract_
    ) external {
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

    function exposedLoadDelegationBytes32(bytes32 location, RegistryStorage.Positions position) external view returns (bytes32 data) {
        return _loadDelegationBytes32(location, position);
    }

    function exposedLoadDelegationUint(bytes32 location, RegistryStorage.Positions position) external view returns (uint256 data) {
        return _loadDelegationUint(location, position);
    }

    function exposedLoadFrom(bytes32 location, RegistryStorage.Positions firstPacked) external view returns (address from) {
        return _loadFrom(location, firstPacked);
    }

    function exposedLoadDelegationAddresses(bytes32 location, RegistryStorage.Positions firstPacked, RegistryStorage.Positions secondPacked)
        external
        view
        returns (address from, address to, address contract_)
    {
        return _loadDelegationAddresses(location, firstPacked, secondPacked);
    }

    function exposedValidateDelegation(bytes32 location, address from) external view returns (bool) {
        return _validateDelegation(location, from);
    }
}
