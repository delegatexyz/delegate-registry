// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {DelegateRegistry} from "src/DelegateRegistry.sol";

/// @dev harness contract that exposes internal registry methods as external ones
contract RegistryHarness is DelegateRegistry {
    function exposed_delegations(bytes32 hash) external view returns (bytes32[6] memory) {
        return _delegations[hash];
    }

    function exposed_vaultDelegationHashes(address vault) external view returns (bytes32[] memory) {
        return _vaultDelegationHashes[vault];
    }

    function exposed_delegateDelegationHashes(address delegate) external view returns (bytes32[] memory) {
        return _delegateDelegationHashes[delegate];
    }

    function exposed_computeDelegationHashForAll(address delegate, bytes32 rights, address vault) external pure returns (bytes32) {
        return _computeDelegationHashForAll(delegate, rights, vault);
    }

    function exposed_computeDelegationHashForContract(address contract_, address delegate, bytes32 rights, address vault) external pure returns (bytes32) {
        return _computeDelegationHashForContract(contract_, delegate, rights, vault);
    }

    function exposed_computeDelegationHashForERC721(address contract_, address delegate, bytes32 rights, uint256 tokenId, address vault)
        external
        pure
        returns (bytes32)
    {
        return _computeDelegationHashForERC721(contract_, delegate, rights, tokenId, vault);
    }

    function exposed_computeDelegationHashForERC20(address contract_, address delegate, bytes32 rights, address vault) external pure returns (bytes32) {
        return _computeDelegationHashForERC20(contract_, delegate, rights, vault);
    }

    function exposed_computeDelegationHashForERC1155(address contract_, address delegate, bytes32 rights, uint256 tokenId, address vault)
        external
        pure
        returns (bytes32)
    {
        return _computeDelegationHashForERC1155(contract_, delegate, rights, tokenId, vault);
    }

    function exposed_encodeLastByteWithType(bytes32 _input, DelegationType _type) external pure returns (bytes32) {
        return _encodeLastByteWithType(_input, _type);
    }

    function exposed_decodeLastByteToType(bytes32 _input) external pure returns (DelegationType) {
        return _decodeLastByteToType(_input);
    }

    function exposed_computeDelegationLocation(bytes32 hash) external pure returns (bytes32 location) {
        return _computeDelegationLocation(hash);
    }
}
