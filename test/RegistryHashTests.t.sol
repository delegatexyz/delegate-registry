// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {IDelegateRegistry as IRegistry} from "src/IDelegateRegistry.sol";
import {RegistryHashes as Hashes} from "src/libraries/RegistryHashes.sol";

contract RegistryHashTests is Test {
    /// @dev used to cross check internal constant in registry hashes with intended values
    function testRegistryHashConstant() public {
        assertEq(Hashes.EXTRACT_LAST_BYTE, type(uint8).max);
        assertEq(Hashes.ALL_TYPE, uint256(IRegistry.DelegationType.ALL));
        assertEq(Hashes.CONTRACT_TYPE, uint256(IRegistry.DelegationType.CONTRACT));
        assertEq(Hashes.ERC721_TYPE, uint256(IRegistry.DelegationType.ERC721));
        assertEq(Hashes.ERC20_TYPE, uint256(IRegistry.DelegationType.ERC20));
        assertEq(Hashes.ERC1155_TYPE, uint256(IRegistry.DelegationType.ERC1155));
        assertEq(Hashes.DELEGATION_SLOT, 0);
    }

    /// @dev used to generate random delegation type within enum range
    function _selectRandomType(uint256 seed) internal pure returns (IRegistry.DelegationType) {
        if (seed % 6 == 0) return IRegistry.DelegationType.NONE;
        if (seed % 6 == 1) return IRegistry.DelegationType.ALL;
        if (seed % 6 == 2) return IRegistry.DelegationType.CONTRACT;
        if (seed % 6 == 3) return IRegistry.DelegationType.ERC721;
        if (seed % 6 == 4) return IRegistry.DelegationType.ERC20;
        else return IRegistry.DelegationType.ERC1155;
    }

    /// @dev tests methods against previously used solidity methods
    function testRegistryHashes(bytes32 _input, uint256 seed, address from, bytes32 rights, address to, address contract_, uint256 tokenId) public {
        IRegistry.DelegationType _type = _selectRandomType(seed);
        bytes32 decodeTest = _encodeLastByteWithType(_input, _type);
        assertEq(uint256(Hashes.decodeType(decodeTest)), uint256(_decodeLastByteToType(decodeTest)));
        assertEq(Hashes.location(_input), _computeLocation(_input));
        assertEq(Hashes.allHash(from, rights, to), _computeAll(from, rights, to));
        assertEq(Hashes.allLocation(from, rights, to), _computeLocation(_computeAll(from, rights, to)));
        assertEq(Hashes.contractHash(from, rights, to, contract_), _computeContract(from, rights, to, contract_));
        assertEq(Hashes.contractLocation(from, rights, to, contract_), _computeLocation(_computeContract(from, rights, to, contract_)));
        assertEq(Hashes.erc721Hash(from, rights, to, tokenId, contract_), _computeERC721(from, rights, to, tokenId, contract_));
        assertEq(Hashes.erc721Location(from, rights, to, tokenId, contract_), _computeLocation(_computeERC721(from, rights, to, tokenId, contract_)));
        assertEq(Hashes.erc20Hash(from, rights, to, contract_), _computeERC20(from, rights, to, contract_));
        assertEq(Hashes.erc20Location(from, rights, to, contract_), _computeLocation(_computeERC20(from, rights, to, contract_)));
        assertEq(Hashes.erc1155Hash(from, rights, to, tokenId, contract_), _computeERC1155(from, rights, to, tokenId, contract_));
        assertEq(Hashes.erc1155Location(from, rights, to, tokenId, contract_), _computeLocation(_computeERC1155(from, rights, to, tokenId, contract_)));
    }

    /// @dev used to cross check that location by type method gives the same result as location(hash for type) method
    function testRegistryHashesLocationEquivalence(address from, bytes32 rights, address to, uint256 tokenId, address contract_) public {
        assertEq(Hashes.allLocation(from, rights, to), Hashes.location(Hashes.allHash(from, rights, to)));
        assertEq(Hashes.contractLocation(from, rights, to, contract_), Hashes.location(Hashes.contractHash(from, rights, to, contract_)));
        assertEq(Hashes.erc721Location(from, rights, to, tokenId, contract_), Hashes.location(Hashes.erc721Hash(from, rights, to, tokenId, contract_)));
        assertEq(Hashes.erc20Location(from, rights, to, contract_), Hashes.location(Hashes.erc20Hash(from, rights, to, contract_)));
        assertEq(Hashes.erc1155Location(from, rights, to, tokenId, contract_), Hashes.location(Hashes.erc1155Hash(from, rights, to, tokenId, contract_)));
    }

    /// @dev tests for storage collisions between hashes, only holding from != notFrom as a constant
    function testRegistryHashesForStorageCollisions(
        address from,
        bytes32 rights,
        address to,
        uint256 tokenId,
        address contract_,
        address notFrom,
        bytes32 searchRights,
        address searchTo,
        uint256 searchTokenId,
        address searchContract_
    ) public {
        vm.assume(from != notFrom);
        bytes32[] memory uniqueHashes = new bytes32[](10);
        uniqueHashes[0] = Hashes.allLocation(from, rights, to);
        uniqueHashes[1] = Hashes.allLocation(notFrom, searchRights, searchTo);
        uniqueHashes[2] = Hashes.contractLocation(from, rights, to, contract_);
        uniqueHashes[3] = Hashes.contractLocation(notFrom, searchRights, searchTo, searchContract_);
        uniqueHashes[4] = Hashes.erc721Location(from, rights, to, tokenId, contract_);
        uniqueHashes[5] = Hashes.erc721Location(notFrom, searchRights, searchTo, searchTokenId, searchContract_);
        uniqueHashes[6] = Hashes.erc20Location(from, rights, to, contract_);
        uniqueHashes[7] = Hashes.erc20Location(notFrom, searchRights, searchTo, searchContract_);
        uniqueHashes[8] = Hashes.erc1155Location(from, rights, to, tokenId, contract_);
        uniqueHashes[9] = Hashes.erc1155Location(notFrom, searchRights, searchTo, searchTokenId, searchContract_);
        for (uint256 i = 0; i < uniqueHashes.length; i++) {
            for (uint256 j = 0; j < uniqueHashes.length; j++) {
                if (j != i) assertTrue(uniqueHashes[i] != uniqueHashes[j]);
                else assertEq(uniqueHashes[i], uniqueHashes[j]);
            }
        }
    }

    /// @dev tests for collisions between the types, additionally searches for collisions by holding from != notFrom constant and fuzzes variations of the other
    /// parameters
    function testRegistryHashesForTypeCollisions(
        address from,
        bytes32 rights,
        address to,
        uint256 tokenId,
        address contract_,
        address notFrom,
        bytes32 searchRights,
        address searchTo,
        uint256 searchTokenId,
        address searchContract_
    ) public {
        vm.assume(from != notFrom);
        bytes32[] memory uniqueHashes = new bytes32[](10);
        uniqueHashes[0] = Hashes.allHash(from, rights, to);
        uniqueHashes[1] = Hashes.allHash(notFrom, searchRights, searchTo);
        uniqueHashes[2] = Hashes.contractHash(from, rights, to, contract_);
        uniqueHashes[3] = Hashes.contractHash(notFrom, searchRights, searchTo, searchContract_);
        uniqueHashes[4] = Hashes.erc721Hash(from, rights, to, tokenId, contract_);
        uniqueHashes[5] = Hashes.erc721Hash(notFrom, searchRights, searchTo, searchTokenId, searchContract_);
        uniqueHashes[6] = Hashes.erc20Hash(from, rights, to, contract_);
        uniqueHashes[7] = Hashes.erc20Hash(notFrom, searchRights, searchTo, searchContract_);
        uniqueHashes[8] = Hashes.erc1155Hash(from, rights, to, tokenId, contract_);
        uniqueHashes[9] = Hashes.erc1155Hash(notFrom, searchRights, searchTo, searchTokenId, searchContract_);
        for (uint256 i = 0; i < uniqueHashes.length; i++) {
            for (uint256 j = 0; j < uniqueHashes.length; j++) {
                if (j != i) assertTrue(uniqueHashes[i] != uniqueHashes[j]);
                else assertEq(uniqueHashes[i], uniqueHashes[j]);
            }
        }
    }

    /// @dev Test for registry hash functions that could be impacted by incorrect inputs
    function testRegistryHashesLargeInputs(uint256 from, bytes32 rights, uint256 to, uint256 tokenId, uint256 contract_) public {
        uint256 minSize = type(uint160).max;
        vm.assume(from > minSize && to > minSize && contract_ > minSize);
        // Create address types from large inputs
        address largeFrom;
        address cleanedFrom;
        address largeTo;
        address cleanedTo;
        address largeContract;
        address cleanedContract;
        assembly {
            largeFrom := from
            largeTo := to
            largeContract := contract_
            cleanedFrom := shr(96, shl(96, from))
            cleanedTo := shr(96, shl(96, to))
            cleanedContract := shr(96, shl(96, contract_))
        }
        // Assert that hashes and locations of cleaned & not cleaned still give the same output
        assertEq(Hashes.allHash(largeFrom, rights, largeTo), Hashes.allHash(cleanedFrom, rights, cleanedTo));
        assertEq(Hashes.allLocation(largeFrom, rights, largeTo), Hashes.allLocation(cleanedFrom, rights, cleanedTo));
        assertEq(Hashes.contractHash(largeFrom, rights, largeTo, largeContract), Hashes.contractHash(cleanedFrom, rights, cleanedTo, cleanedContract));
        assertEq(Hashes.contractLocation(largeFrom, rights, largeTo, largeContract), Hashes.contractLocation(cleanedFrom, rights, cleanedTo, cleanedContract));
        assertEq(Hashes.erc721Hash(largeFrom, rights, largeTo, tokenId, largeContract), Hashes.erc721Hash(cleanedFrom, rights, cleanedTo, tokenId, cleanedContract));
        assertEq(Hashes.erc721Location(largeFrom, rights, largeTo, tokenId, largeContract), Hashes.erc721Location(cleanedFrom, rights, cleanedTo, tokenId, cleanedContract));
        assertEq(Hashes.erc20Hash(largeFrom, rights, largeTo, largeContract), Hashes.erc20Hash(cleanedFrom, rights, cleanedTo, cleanedContract));
        assertEq(Hashes.erc20Location(largeFrom, rights, largeTo, largeContract), Hashes.erc20Location(cleanedFrom, rights, cleanedTo, cleanedContract));
        assertEq(Hashes.erc1155Hash(largeFrom, rights, largeTo, tokenId, largeContract), Hashes.erc1155Hash(cleanedFrom, rights, cleanedTo, tokenId, cleanedContract));
        assertEq(Hashes.erc1155Location(largeFrom, rights, largeTo, tokenId, largeContract), Hashes.erc1155Location(cleanedFrom, rights, cleanedTo, tokenId, cleanedContract));
    }

    /// @dev internal functions of the original registry hash specification to test optimized methods work as intended
    function _computeAll(address from, bytes32 rights, address to) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encodePacked(rights, from, to)), IRegistry.DelegationType.ALL);
    }

    function _computeContract(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encodePacked(rights, from, to, contract_)), IRegistry.DelegationType.CONTRACT);
    }

    function _computeERC721(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encodePacked(rights, from, to, contract_, tokenId)), IRegistry.DelegationType.ERC721);
    }

    function _computeERC20(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encodePacked(rights, from, to, contract_)), IRegistry.DelegationType.ERC20);
    }

    function _computeERC1155(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encodePacked(rights, from, to, contract_, tokenId)), IRegistry.DelegationType.ERC1155);
    }

    function _encodeLastByteWithType(bytes32 _input, IRegistry.DelegationType _type) internal pure returns (bytes32) {
        return bytes32((uint256(_input) << 8) | uint256(_type));
    }

    function _decodeLastByteToType(bytes32 _input) internal pure returns (IRegistry.DelegationType) {
        return IRegistry.DelegationType(uint8(uint256(_input) & 0xFF));
    }

    function _computeLocation(bytes32 hash) internal pure returns (bytes32 location) {
        location = keccak256(abi.encode(hash, 0)); // delegations mapping is at slot 0
    }
}
