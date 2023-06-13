// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {DelegateRegistry} from "src/DelegateRegistry.sol";

/// @dev harness contract that exposes internal registry methods as external ones
contract RegistryHarness is DelegateRegistry {
    function exposed_delegations(bytes32 hash) external view returns (bytes32[6] memory) {
        return _delegations[hash];
    }

    function exposed_outgoingDelegationHashes(address vault) external view returns (bytes32[] memory) {
        return _outgoingDelegationHashes[vault];
    }

    function exposed_incomingDelegationHashes(address delegate) external view returns (bytes32[] memory) {
        return _incomingDelegationHashes[delegate];
    }

    function exposed_computeHashForAll(address delegate, bytes32 rights, address vault) external pure returns (bytes32) {
        return _computeHashForAll(delegate, rights, vault);
    }

    function exposed_computeHashForContract(address contract_, address delegate, bytes32 rights, address vault) external pure returns (bytes32) {
        return _computeHashForContract(contract_, delegate, rights, vault);
    }

    function exposed_computeHashForERC721(address contract_, address delegate, bytes32 rights, uint256 tokenId, address vault)
        external
        pure
        returns (bytes32)
    {
        return _computeHashForERC721(contract_, delegate, rights, tokenId, vault);
    }

    function exposed_computeHashForERC20(address contract_, address delegate, bytes32 rights, address vault) external pure returns (bytes32) {
        return _computeHashForERC20(contract_, delegate, rights, vault);
    }

    function exposed_computeHashForERC1155(address contract_, address delegate, bytes32 rights, uint256 tokenId, address vault)
        external
        pure
        returns (bytes32)
    {
        return _computeHashForERC1155(contract_, delegate, rights, tokenId, vault);
    }

    function exposed_encodeLastByteWithType(bytes32 _input, DelegationType _type) external pure returns (bytes32) {
        return _encodeLastByteWithType(_input, _type);
    }

    function exposed_decodeLastByteToType(bytes32 _input) external pure returns (DelegationType) {
        return _decodeLastByteToType(_input);
    }

    function exposed_computeLocation(bytes32 hash) external pure returns (bytes32 location) {
        return _computeLocation(hash);
    }
}
