// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {DelegateRegistry} from "src/DelegateRegistry.sol";

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

    function exposedPushDelegationHashes(address from, address to, bytes32 delegationHash) external {
        _pushDelegationHashes(from, to, delegationHash);
    }

    function exposedWriteDelegation(bytes32 location, uint256 position, bytes32 data) external {
        _writeDelegation(location, position, data);
    }

    function exposedWriteDelegation(bytes32 location, uint256 position, uint256 data) external {
        _writeDelegation(location, position, data);
    }

    function exposedWriteDelegationAddresses(bytes32 location, address from, address to, address contract_) external {
        _writeDelegationAddresses(location, from, to, contract_);
    }

    function exposedGetValidDelegationsFromHashes(bytes32[] calldata hashes) external returns (Delegation[] memory delegations_) {
        temporaryStorage = hashes;
        return _getValidDelegationsFromHashes(temporaryStorage);
    }

    function exposedGetValidDelegationHashesFromHashes(bytes32[] calldata hashes) external returns (bytes32[] memory validHashes) {
        temporaryStorage = hashes;
        return _getValidDelegationHashesFromHashes(temporaryStorage);
    }

    function exposedLoadDelegationBytes32(bytes32 location, uint256 position) external view returns (bytes32 data) {
        return _loadDelegationBytes32(location, position);
    }

    function exposedLoadDelegationUint(bytes32 location, uint256 position) external view returns (uint256 data) {
        return _loadDelegationUint(location, position);
    }

    function exposedLoadFrom(bytes32 location) external view returns (address from) {
        return _loadFrom(location);
    }

    function exposedValidateFrom(bytes32 location, address from) external view returns (bool) {
        return _validateFrom(location, from);
    }

    function exposedLoadDelegationAddresses(bytes32 location) external view returns (address from, address to, address contract_) {
        return _loadDelegationAddresses(location);
    }
}
