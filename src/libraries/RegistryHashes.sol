// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IDelegateRegistry} from "../IDelegateRegistry.sol";

library RegistryHashes {
    /// @dev Helper function to compute delegation hash for all delegation
    function _computeAll(address to, bytes32 rights, address from) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(to, rights, from)), IDelegateRegistry.DelegationType.ALL);
    }

    /// @dev Helper function to compute delegation hash for contract delegation
    function _computeContract(address contract_, address to, bytes32 rights, address from) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, to, rights, from)), IDelegateRegistry.DelegationType.CONTRACT);
    }

    /// @dev Helper function to compute delegation hash for ERC721 delegation
    function _computeERC721(address contract_, address to, bytes32 rights, uint256 tokenId, address from) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, to, rights, tokenId, from)), IDelegateRegistry.DelegationType.ERC721);
    }

    /// @dev Helper function to compute delegation hash for ERC20 delegation
    function _computeERC20(address contract_, address to, bytes32 rights, address from) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, to, rights, from)), IDelegateRegistry.DelegationType.ERC20);
    }

    /// @dev Helper function to compute delegation hash for ERC1155 delegation
    function _computeERC1155(address contract_, address to, bytes32 rights, uint256 tokenId, address from) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, to, rights, tokenId, from)), IDelegateRegistry.DelegationType.ERC1155);
    }

    /// @dev Helper function to encode the last byte of a delegation hash to its type
    function _encodeLastByteWithType(bytes32 _input, IDelegateRegistry.DelegationType _type) internal pure returns (bytes32) {
        return (_input & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00) | bytes32(uint256(_type));
    }

    /// @dev Helper function to decode last byte of a delegation hash to obtain its type
    function _decodeLastByteToType(bytes32 _input) internal pure returns (IDelegateRegistry.DelegationType) {
        return IDelegateRegistry.DelegationType(uint8(uint256(_input) & 0xFF));
    }

    /// @dev Helper function that computes the data location of a particular delegation hash
    function _computeLocation(bytes32 hash) internal pure returns (bytes32 location) {
        location = keccak256(abi.encode(hash, 0)); // delegations mapping is at slot 0
    }
}
