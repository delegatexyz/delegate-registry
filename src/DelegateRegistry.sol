// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IDelegateRegistry} from "./IDelegateRegistry.sol";

/**
 * @title DelegateRegistry
 * @custom:version 2.0
 * @custom:coauthor foobar (0xfoobar)
 * @custom:coauthor mireynolds
 * @notice A standalone immutable registry storing delegated permissions from one address to another
 */
contract DelegateRegistry is IDelegateRegistry {
    /// @dev Only this mapping should be used to verify delegations; the other mapping arrays are for enumerations
    mapping(bytes32 delegationHash => bytes32[6] delegationStorage) internal _delegations;

    /// @dev Vault delegation enumeration outbox, for pushing new hashes only
    mapping(address from => bytes32[] delegationHashes) internal _outgoingDelegationHashes;

    /// @dev Delegate delegation enumeration inbox, for pushing new hashes only
    mapping(address to => bytes32[] delegationHashes) internal _incomingDelegationHashes;

    /// @dev Standardizes storage positions of delegation data
    enum StoragePositions {
        to,
        from,
        rights,
        contract_,
        tokenId,
        amount
    }

    /// @dev Standardizes from storage flags to prevent double-writes in the delegation in/outbox if the same delegation is revoked and rewritten
    address internal constant DELEGATION_EMPTY = address(0);
    address internal constant DELEGATION_REVOKED = address(1);

    /**
     * ----------- WRITE -----------
     */

    /// @inheritdoc IDelegateRegistry
    function multicall(bytes[] calldata data) external override returns (bytes[] memory results) {
        results = new bytes[](data.length);
        bool success;
        unchecked {
            for (uint256 i = 0; i < data.length; ++i) {
                (success, results[i]) = address(this).delegatecall(data[i]);
                if (!success) revert MulticallFailed();
            }
        }
    }

    /// @inheritdoc IDelegateRegistry
    function delegateAll(address to, bytes32 rights, bool enable) external override {
        bytes32 hash = _computeHashForAll(to, rights, msg.sender);
        bytes32 location = _computeLocation(hash);
        if (_loadDelegationAddress(location, StoragePositions.from) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegation(location, StoragePositions.to, to);
            _writeDelegation(location, StoragePositions.from, msg.sender);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.to, "");
            _writeDelegation(location, StoragePositions.from, DELEGATION_REVOKED);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
        emit DelegateAll(msg.sender, to, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateContract(address to, address contract_, bytes32 rights, bool enable) external override {
        bytes32 hash = _computeHashForContract(contract_, to, rights, msg.sender);
        bytes32 location = _computeLocation(hash);
        if (_loadDelegationAddress(location, StoragePositions.from) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegation(location, StoragePositions.contract_, contract_);
            _writeDelegation(location, StoragePositions.to, to);
            _writeDelegation(location, StoragePositions.from, msg.sender);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.contract_, "");
            _writeDelegation(location, StoragePositions.to, "");
            _writeDelegation(location, StoragePositions.from, DELEGATION_REVOKED);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
        emit DelegateContract(msg.sender, to, contract_, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateERC721(address to, address contract_, uint256 tokenId, bytes32 rights, bool enable) external override {
        bytes32 hash = _computeHashForERC721(contract_, to, rights, tokenId, msg.sender);
        bytes32 location = _computeLocation(hash);
        if (_loadDelegationAddress(location, StoragePositions.from) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegation(location, StoragePositions.contract_, contract_);
            _writeDelegation(location, StoragePositions.to, to);
            _writeDelegation(location, StoragePositions.from, msg.sender);
            _writeDelegation(location, StoragePositions.tokenId, tokenId);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.contract_, "");
            _writeDelegation(location, StoragePositions.to, "");
            _writeDelegation(location, StoragePositions.from, DELEGATION_REVOKED);
            _writeDelegation(location, StoragePositions.tokenId, "");
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
        emit DelegateERC721(msg.sender, to, contract_, tokenId, rights, enable);
    }

    // @inheritdoc IDelegateRegistry
    function delegateERC20(address to, address contract_, uint256 amount, bytes32 rights, bool enable) external override {
        bytes32 hash = _computeHashForERC20(contract_, to, rights, msg.sender);
        bytes32 location = _computeLocation(hash);
        if (_loadDelegationAddress(location, StoragePositions.from) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegation(location, StoragePositions.contract_, contract_);
            _writeDelegation(location, StoragePositions.to, to);
            _writeDelegation(location, StoragePositions.from, msg.sender);
            _writeDelegation(location, StoragePositions.amount, amount);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.contract_, "");
            _writeDelegation(location, StoragePositions.to, "");
            _writeDelegation(location, StoragePositions.from, DELEGATION_REVOKED);
            _writeDelegation(location, StoragePositions.amount, "");
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
        emit DelegateERC20(msg.sender, to, contract_, amount, rights, enable);
    }

    /**
     * @inheritdoc IDelegateRegistry
     * @dev The actual amount is not encoded in the hash, just the existence of a amount (since it is an upper bound)
     */
    function delegateERC1155(address to, address contract_, uint256 tokenId, uint256 amount, bytes32 rights, bool enable) external override {
        bytes32 hash = _computeHashForERC1155(contract_, to, rights, tokenId, msg.sender);
        bytes32 location = _computeLocation(hash);
        if (_loadDelegationAddress(location, StoragePositions.from) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegation(location, StoragePositions.contract_, contract_);
            _writeDelegation(location, StoragePositions.to, to);
            _writeDelegation(location, StoragePositions.from, msg.sender);
            _writeDelegation(location, StoragePositions.amount, amount);
            _writeDelegation(location, StoragePositions.tokenId, tokenId);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.contract_, "");
            _writeDelegation(location, StoragePositions.to, "");
            _writeDelegation(location, StoragePositions.from, DELEGATION_REVOKED);
            _writeDelegation(location, StoragePositions.amount, "");
            _writeDelegation(location, StoragePositions.tokenId, "");
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
        emit DelegateERC1155(msg.sender, to, contract_, tokenId, amount, rights, enable);
    }

    /**
     * ----------- CHECKS -----------
     */

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForAll(address to, address from, bytes32 rights) external view override returns (bool valid) {
        valid = _validateDelegation(_computeLocation(_computeHashForAll(to, "", from)), from);
        if (rights != "" && !valid) valid = _validateDelegation(_computeLocation(_computeHashForAll(to, rights, from)), from);
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForContract(address to, address from, address contract_, bytes32 rights) external view override returns (bool valid) {
        valid = _validateDelegation(_computeLocation(_computeHashForAll(to, "", from)), from)
            || _validateDelegation(_computeLocation(_computeHashForContract(contract_, to, "", from)), from);
        if (rights != "" && !valid) {
            valid = _validateDelegation(_computeLocation(_computeHashForAll(to, rights, from)), from)
                || _validateDelegation(_computeLocation(_computeHashForContract(contract_, to, rights, from)), from);
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC721(address to, address from, address contract_, uint256 tokenId, bytes32 rights) external view override returns (bool valid) {
        valid = _validateDelegation(_computeLocation(_computeHashForAll(to, "", from)), from)
            || _validateDelegation(_computeLocation(_computeHashForContract(contract_, to, "", from)), from)
            || _validateDelegation(_computeLocation(_computeHashForERC721(contract_, to, "", tokenId, from)), from);
        if (rights != "" && !valid) {
            valid = _validateDelegation(_computeLocation(_computeHashForAll(to, rights, from)), from)
                || _validateDelegation(_computeLocation(_computeHashForContract(contract_, to, rights, from)), from)
                || _validateDelegation(_computeLocation(_computeHashForERC721(contract_, to, rights, tokenId, from)), from);
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC20(address to, address from, address contract_, bytes32 rights) external view override returns (uint256 amount) {
        bytes32 location = _computeLocation(_computeHashForERC20(contract_, to, "", from));
        amount = (
            _validateDelegation(_computeLocation(_computeHashForAll(to, "", from)), from)
                || _validateDelegation(_computeLocation(_computeHashForContract(contract_, to, "", from)), from)
        ) ? type(uint256).max : (_validateDelegation(location, from) ? _loadDelegationUint(location, StoragePositions.amount) : 0);
        if (rights != "" && amount != type(uint256).max) {
            location = _computeLocation(_computeHashForERC20(contract_, to, rights, from));
            uint256 rightsBalance = (
                _validateDelegation(_computeLocation(_computeHashForAll(to, rights, from)), from)
                    || _validateDelegation(_computeLocation(_computeHashForContract(contract_, to, rights, from)), from)
            ) ? type(uint256).max : (_validateDelegation(location, from) ? _loadDelegationUint(location, StoragePositions.amount) : 0);
            amount = rightsBalance > amount ? rightsBalance : amount;
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC1155(address to, address from, address contract_, uint256 tokenId, bytes32 rights) external view override returns (uint256 amount) {
        bytes32 location = _computeLocation(_computeHashForERC1155(contract_, to, "", tokenId, from));
        amount = (
            _validateDelegation(_computeLocation(_computeHashForAll(to, "", from)), from)
                || _validateDelegation(_computeLocation(_computeHashForContract(contract_, to, "", from)), from)
        ) ? type(uint256).max : (_validateDelegation(location, from) ? _loadDelegationUint(location, StoragePositions.amount) : 0);
        if (rights != "" && amount != type(uint256).max) {
            location = _computeLocation(_computeHashForERC1155(contract_, to, rights, tokenId, from));
            uint256 rightsBalance = (
                _validateDelegation(_computeLocation(_computeHashForAll(to, rights, from)), from)
                    || _validateDelegation(_computeLocation(_computeHashForContract(contract_, to, rights, from)), from)
            ) ? type(uint256).max : (_validateDelegation(location, from) ? _loadDelegationUint(location, StoragePositions.amount) : 0);
            amount = rightsBalance > amount ? rightsBalance : amount;
        }
    }

    /**
     * ----------- ENUMERATIONS -----------
     */

    /// @inheritdoc IDelegateRegistry
    function getIncomingDelegations(address to) external view override returns (Delegation[] memory delegations) {
        delegations = _getValidDelegationsFromHashes(_incomingDelegationHashes[to]);
    }

    /// @inheritdoc IDelegateRegistry
    function getOutgoingDelegations(address from) external view returns (Delegation[] memory delegations) {
        delegations = _getValidDelegationsFromHashes(_outgoingDelegationHashes[from]);
    }

    /// @inheritdoc IDelegateRegistry
    function getIncomingDelegationHashes(address to) external view returns (bytes32[] memory delegationHashes) {
        delegationHashes = _getValidDelegationHashesFromHashes(_incomingDelegationHashes[to]);
    }

    /// @inheritdoc IDelegateRegistry
    function getOutgoingDelegationHashes(address from) external view returns (bytes32[] memory delegationHashes) {
        delegationHashes = _getValidDelegationHashesFromHashes(_outgoingDelegationHashes[from]);
    }

    /// @inheritdoc IDelegateRegistry
    function getDelegationsFromHashes(bytes32[] calldata hashes) external view returns (Delegation[] memory delegations) {
        delegations = new Delegation[](hashes.length);
        bytes32 location;
        address from;
        unchecked {
            for (uint256 i = 0; i < hashes.length; ++i) {
                location = _computeLocation(hashes[i]);
                from = _loadDelegationAddress(location, StoragePositions.from);
                if (from == DELEGATION_EMPTY || from == DELEGATION_REVOKED) {
                    delegations[i] = Delegation({type_: DelegationType.NONE, to: address(0), from: address(0), rights: "", amount: 0, contract_: address(0), tokenId: 0});
                } else {
                    delegations[i] = Delegation({
                        type_: _decodeLastByteToType(hashes[i]),
                        to: _loadDelegationAddress(location, StoragePositions.to),
                        from: from,
                        rights: _loadDelegationBytes32(location, StoragePositions.rights),
                        amount: _loadDelegationUint(location, StoragePositions.amount),
                        contract_: _loadDelegationAddress(location, StoragePositions.contract_),
                        tokenId: _loadDelegationUint(location, StoragePositions.tokenId)
                    });
                }
            }
        }
    }

    /**
     * ----------- ERC165 -----------
     */

    /// @notice Query if a contract implements an ERC-165 interface
    /// @param interfaceId The interface identifier
    /// @return valid Whether the queried interface is supported
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IDelegateRegistry).interfaceId || interfaceId == 0x01ffc9a7;
    }

    /**
     * ----------- INTERNAL -----------
     */

    /// @dev Helper function to compute delegation hash for all delegation
    function _computeHashForAll(address to, bytes32 rights, address from) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(to, rights, from)), DelegationType.ALL);
    }

    /// @dev Helper function to compute delegation hash for contract delegation
    function _computeHashForContract(address contract_, address to, bytes32 rights, address from) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, to, rights, from)), DelegationType.CONTRACT);
    }

    /// @dev Helper function to compute delegation hash for ERC721 delegation
    function _computeHashForERC721(address contract_, address to, bytes32 rights, uint256 tokenId, address from) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, to, rights, tokenId, from)), DelegationType.ERC721);
    }

    /// @dev Helper function to compute delegation hash for ERC20 delegation
    function _computeHashForERC20(address contract_, address to, bytes32 rights, address from) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, to, rights, from)), DelegationType.ERC20);
    }

    /// @dev Helper function to compute delegation hash for ERC1155 delegation
    function _computeHashForERC1155(address contract_, address to, bytes32 rights, uint256 tokenId, address from) internal pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, to, rights, tokenId, from)), DelegationType.ERC1155);
    }

    /// @dev Helper function to encode the last byte of a delegation hash to its type
    function _encodeLastByteWithType(bytes32 _input, DelegationType _type) internal pure returns (bytes32) {
        return (_input & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00) | bytes32(uint256(_type));
    }

    /// @dev Helper function to decode last byte of a delegation hash to obtain its type
    function _decodeLastByteToType(bytes32 _input) internal pure returns (DelegationType) {
        return DelegationType(uint8(uint256(_input) & 0xFF));
    }

    /// @dev Helper function that computes the data location of a particular delegation hash
    function _computeLocation(bytes32 hash) internal pure returns (bytes32 location) {
        location = keccak256(abi.encode(hash, 0)); // _delegations mapping is at slot 0
    }

    /**
     * ----------- PRIVATE -----------
     */

    /// @dev Helper function to push new delegation hashes to the incoming and outgoing hashes mappings
    function _pushDelegationHashes(address from, address to, bytes32 delegationHash) private {
        _outgoingDelegationHashes[from].push(delegationHash);
        _incomingDelegationHashes[to].push(delegationHash);
    }

    /// @dev Helper function that writes bytes32 data to delegation data location at array position
    function _writeDelegation(bytes32 location, StoragePositions position, bytes32 data) private {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that writes uint256 data to delegation data location at array position
    function _writeDelegation(bytes32 location, StoragePositions position, uint256 data) private {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that writes address data to delegation data location at array position
    function _writeDelegation(bytes32 location, StoragePositions position, address data) private {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that takes an array of delegation hashes and returns an array of Delegation structs with their onchain information
    function _getValidDelegationsFromHashes(bytes32[] storage hashes) private view returns (Delegation[] memory delegations) {
        uint256 count = 0;
        uint256 hashesLength = hashes.length;
        bytes32 hash;
        bytes32[] memory filteredHashes = new bytes32[](hashesLength);
        unchecked {
            for (uint256 i = 0; i < hashesLength; ++i) {
                hash = hashes[i];
                if (_loadDelegationAddress(_computeLocation(hash), StoragePositions.from) > DELEGATION_REVOKED) filteredHashes[count++] = hash;
            }
            delegations = new Delegation[](count);
            bytes32 location;
            address from;
            for (uint256 i = 0; i < count; ++i) {
                hash = filteredHashes[i];
                location = _computeLocation(hash);
                from = _loadDelegationAddress(location, StoragePositions.from);
                delegations[i] = Delegation({
                    type_: _decodeLastByteToType(hash),
                    to: _loadDelegationAddress(location, StoragePositions.to),
                    from: from,
                    rights: _loadDelegationBytes32(location, StoragePositions.rights),
                    amount: _loadDelegationUint(location, StoragePositions.amount),
                    contract_: _loadDelegationAddress(location, StoragePositions.contract_),
                    tokenId: _loadDelegationUint(location, StoragePositions.tokenId)
                });
            }
        }
    }

    /// @dev Helper function that takes an array of delegation hashes and returns an array of valid delegation hashes
    function _getValidDelegationHashesFromHashes(bytes32[] storage hashes) private view returns (bytes32[] memory validHashes) {
        uint256 count = 0;
        uint256 hashesLength = hashes.length;
        bytes32 hash;
        bytes32[] memory filteredHashes = new bytes32[](hashesLength);
        unchecked {
            for (uint256 i = 0; i < hashesLength; ++i) {
                hash = hashes[i];
                if (_loadDelegationAddress(_computeLocation(hash), StoragePositions.from) > DELEGATION_REVOKED) {
                    filteredHashes[count] = hash;
                    ++count;
                }
            }
            validHashes = new bytes32[](count);
            for (uint256 i = 0; i < count; ++i) {
                validHashes[i] = filteredHashes[i];
            }
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as bytes32
    function _loadDelegationBytes32(bytes32 location, StoragePositions position) private view returns (bytes32 data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as uint256
    function _loadDelegationUint(bytes32 location, StoragePositions position) private view returns (uint256 data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as address
    function _loadDelegationAddress(bytes32 location, StoragePositions position) private view returns (address data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    /// @dev Helper function to establish whether a delegation is enabled
    function _validateDelegation(bytes32 location, address from) private view returns (bool) {
        return (_loadDelegationAddress(location, StoragePositions.from) == from && from > DELEGATION_REVOKED);
    }
}
