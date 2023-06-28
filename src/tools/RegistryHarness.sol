// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {DelegateRegistry} from "src/DelegateRegistry.sol";

/// @dev harness contract that exposes internal registry methods as external ones
contract RegistryHarness is DelegateRegistry {
    constructor() {
        delegations[0][0] = 0;
    }

    function exposedDelegations(bytes32 hash) external view returns (bytes32[6] memory) {
        return delegations[hash];
    }

    function exposedOutgoingDelegationHashes(address vault) external view returns (bytes32[] memory) {
        return outgoingDelegationHashes[vault];
    }

    function exposedIncomingDelegationHashes(address delegate) external view returns (bytes32[] memory) {
        return incomingDelegationHashes[delegate];
    }

    function exposedComputeHashForAll(address delegate, bytes32 rights, address vault) external pure returns (bytes32) {
        return _computeHashForAll(delegate, rights, vault);
    }

    function exposedComputeHashForContract(address contract_, address delegate, bytes32 rights, address vault) external pure returns (bytes32) {
        return _computeHashForContract(contract_, delegate, rights, vault);
    }

    function exposedComputeHashForERC721(address contract_, address delegate, bytes32 rights, uint256 tokenId, address vault) external pure returns (bytes32) {
        return _computeHashForERC721(contract_, delegate, rights, tokenId, vault);
    }

    function exposedComputeHashForERC20(address contract_, address delegate, bytes32 rights, address vault) external pure returns (bytes32) {
        return _computeHashForERC20(contract_, delegate, rights, vault);
    }

    function exposedComputeHashForERC1155(address contract_, address delegate, bytes32 rights, uint256 tokenId, address vault) external pure returns (bytes32) {
        return _computeHashForERC1155(contract_, delegate, rights, tokenId, vault);
    }

    function exposedEncodeLastByteWithType(bytes32 input, DelegationType type_) external pure returns (bytes32) {
        return _encodeLastByteWithType(input, type_);
    }

    function exposedDecodeLastByteToType(bytes32 input) external pure returns (DelegationType) {
        return _decodeLastByteToType(input);
    }

    function exposedComputeLocation(bytes32 hash) external pure returns (bytes32 location) {
        return _computeLocation(hash);
    }
}
