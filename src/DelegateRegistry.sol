// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IDelegateRegistry} from "./IDelegateRegistry.sol";

import {RegistryHashes} from "./libraries/RegistryHashes.sol";

/**
 * @title DelegateRegistry
 * @custom:version 2.0
 * @custom:coauthor foobar (0xfoobar)
 * @custom:coauthor mireynolds
 * @notice A standalone immutable registry storing delegated permissions from one address to another
 */
contract DelegateRegistry is IDelegateRegistry {
    /// @dev Only this mapping should be used to verify delegations; the other mapping arrays are for enumerations
    mapping(bytes32 delegationHash => bytes32[5] delegationStorage) internal delegations;

    /// @dev Vault delegation enumeration outbox, for pushing new hashes only
    mapping(address from => bytes32[] delegationHashes) internal outgoingDelegationHashes;

    /// @dev Delegate delegation enumeration inbox, for pushing new hashes only
    mapping(address to => bytes32[] delegationHashes) internal incomingDelegationHashes;

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
                // Disabling as this loop does not lead to a DOS since the registry is delegateCalling itself
                //slither-disable-next-line calls-loop
                (success, results[i]) = address(this).delegatecall(data[i]);
                if (!success) revert MulticallFailed();
            }
        }
    }

    /// @inheritdoc IDelegateRegistry
    function delegateAll(address to, bytes32 rights, bool enable) external override returns (bytes32 hash) {
        hash = RegistryHashes._computeAll(to, rights, msg.sender);
        bytes32 location = RegistryHashes._computeLocation(hash);
        if (_loadFrom(location, StoragePositions.firstPacked) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, StoragePositions.firstPacked, StoragePositions.secondPacked, msg.sender, to, address(0));
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegationAddresses(location, StoragePositions.firstPacked, StoragePositions.secondPacked, DELEGATION_REVOKED, address(0), address(0));
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
        emit DelegateAll(msg.sender, to, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateContract(address to, address contract_, bytes32 rights, bool enable) external override returns (bytes32 hash) {
        hash = RegistryHashes._computeContract(contract_, to, rights, msg.sender);
        bytes32 location = RegistryHashes._computeLocation(hash);
        if (_loadFrom(location, StoragePositions.firstPacked) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, StoragePositions.firstPacked, StoragePositions.secondPacked, msg.sender, to, contract_);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegationAddresses(location, StoragePositions.firstPacked, StoragePositions.secondPacked, DELEGATION_REVOKED, address(0), address(0));
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
        emit DelegateContract(msg.sender, to, contract_, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateERC721(address to, address contract_, uint256 tokenId, bytes32 rights, bool enable) external override returns (bytes32 hash) {
        hash = RegistryHashes._computeERC721(contract_, to, rights, tokenId, msg.sender);
        bytes32 location = RegistryHashes._computeLocation(hash);
        if (_loadFrom(location, StoragePositions.firstPacked) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, StoragePositions.firstPacked, StoragePositions.secondPacked, msg.sender, to, contract_);
            _writeDelegation(location, StoragePositions.tokenId, tokenId);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegationAddresses(location, StoragePositions.firstPacked, StoragePositions.secondPacked, DELEGATION_REVOKED, address(0), address(0));
            _writeDelegation(location, StoragePositions.tokenId, "");
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
        emit DelegateERC721(msg.sender, to, contract_, tokenId, rights, enable);
    }

    // @inheritdoc IDelegateRegistry
    function delegateERC20(address to, address contract_, uint256 amount, bytes32 rights, bool enable) external override returns (bytes32 hash) {
        hash = RegistryHashes._computeERC20(contract_, to, rights, msg.sender);
        bytes32 location = RegistryHashes._computeLocation(hash);
        if (_loadFrom(location, StoragePositions.firstPacked) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, StoragePositions.firstPacked, StoragePositions.secondPacked, msg.sender, to, contract_);
            _writeDelegation(location, StoragePositions.amount, amount);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegationAddresses(location, StoragePositions.firstPacked, StoragePositions.secondPacked, DELEGATION_REVOKED, address(0), address(0));
            _writeDelegation(location, StoragePositions.amount, "");
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
        emit DelegateERC20(msg.sender, to, contract_, amount, rights, enable);
    }

    /**
     * @inheritdoc IDelegateRegistry
     * @dev The actual amount is not encoded in the hash, just the existence of a amount (since it is an upper bound)
     */
    function delegateERC1155(address to, address contract_, uint256 tokenId, uint256 amount, bytes32 rights, bool enable) external override returns (bytes32 hash) {
        hash = RegistryHashes._computeERC1155(contract_, to, rights, tokenId, msg.sender);
        bytes32 location = RegistryHashes._computeLocation(hash);
        if (_loadFrom(location, StoragePositions.firstPacked) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, StoragePositions.firstPacked, StoragePositions.secondPacked, msg.sender, to, contract_);
            _writeDelegation(location, StoragePositions.amount, amount);
            _writeDelegation(location, StoragePositions.tokenId, tokenId);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegationAddresses(location, StoragePositions.firstPacked, StoragePositions.secondPacked, DELEGATION_REVOKED, address(0), address(0));
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
        valid = _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeAll(to, "", from)), from);
        if (rights != "" && !valid) valid = _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeAll(to, rights, from)), from);
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForContract(address to, address from, address contract_, bytes32 rights) external view override returns (bool valid) {
        valid = _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeAll(to, "", from)), from)
            || _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeContract(contract_, to, "", from)), from);
        if (rights != "" && !valid) {
            valid = _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeAll(to, rights, from)), from)
                || _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeContract(contract_, to, rights, from)), from);
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC721(address to, address from, address contract_, uint256 tokenId, bytes32 rights) external view override returns (bool valid) {
        valid = _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeAll(to, "", from)), from)
            || _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeContract(contract_, to, "", from)), from)
            || _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeERC721(contract_, to, "", tokenId, from)), from);
        if (rights != "" && !valid) {
            valid = _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeAll(to, rights, from)), from)
                || _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeContract(contract_, to, rights, from)), from)
                || _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeERC721(contract_, to, rights, tokenId, from)), from);
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC20(address to, address from, address contract_, bytes32 rights) external view override returns (uint256 amount) {
        bytes32 location = RegistryHashes._computeLocation(RegistryHashes._computeERC20(contract_, to, "", from));
        amount = (
            _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeAll(to, "", from)), from)
                || _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeContract(contract_, to, "", from)), from)
        ) ? type(uint256).max : (_validateDelegation(location, from) ? _loadDelegationUint(location, StoragePositions.amount) : 0);
        if (rights != "" && amount != type(uint256).max) {
            location = RegistryHashes._computeLocation(RegistryHashes._computeERC20(contract_, to, rights, from));
            uint256 rightsBalance = (
                _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeAll(to, rights, from)), from)
                    || _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeContract(contract_, to, rights, from)), from)
            ) ? type(uint256).max : (_validateDelegation(location, from) ? _loadDelegationUint(location, StoragePositions.amount) : 0);
            amount = rightsBalance > amount ? rightsBalance : amount;
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC1155(address to, address from, address contract_, uint256 tokenId, bytes32 rights) external view override returns (uint256 amount) {
        bytes32 location = RegistryHashes._computeLocation(RegistryHashes._computeERC1155(contract_, to, "", tokenId, from));
        amount = (
            _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeAll(to, "", from)), from)
                || _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeContract(contract_, to, "", from)), from)
        ) ? type(uint256).max : (_validateDelegation(location, from) ? _loadDelegationUint(location, StoragePositions.amount) : 0);
        if (rights != "" && amount != type(uint256).max) {
            location = RegistryHashes._computeLocation(RegistryHashes._computeERC1155(contract_, to, rights, tokenId, from));
            uint256 rightsBalance = (
                _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeAll(to, rights, from)), from)
                    || _validateDelegation(RegistryHashes._computeLocation(RegistryHashes._computeContract(contract_, to, rights, from)), from)
            ) ? type(uint256).max : (_validateDelegation(location, from) ? _loadDelegationUint(location, StoragePositions.amount) : 0);
            amount = rightsBalance > amount ? rightsBalance : amount;
        }
    }

    /**
     * ----------- ENUMERATIONS -----------
     */

    /// @inheritdoc IDelegateRegistry
    function getIncomingDelegations(address to) external view override returns (Delegation[] memory delegations_) {
        delegations_ = _getValidDelegationsFromHashes(incomingDelegationHashes[to]);
    }

    /// @inheritdoc IDelegateRegistry
    function getOutgoingDelegations(address from) external view returns (Delegation[] memory delegations_) {
        delegations_ = _getValidDelegationsFromHashes(outgoingDelegationHashes[from]);
    }

    /// @inheritdoc IDelegateRegistry
    function getIncomingDelegationHashes(address to) external view returns (bytes32[] memory delegationHashes) {
        delegationHashes = _getValidDelegationHashesFromHashes(incomingDelegationHashes[to]);
    }

    /// @inheritdoc IDelegateRegistry
    function getOutgoingDelegationHashes(address from) external view returns (bytes32[] memory delegationHashes) {
        delegationHashes = _getValidDelegationHashesFromHashes(outgoingDelegationHashes[from]);
    }

    /// @inheritdoc IDelegateRegistry
    function getDelegationsFromHashes(bytes32[] calldata hashes) external view returns (Delegation[] memory delegations_) {
        delegations_ = new Delegation[](hashes.length);
        unchecked {
            for (uint256 i = 0; i < hashes.length; ++i) {
                bytes32 location = RegistryHashes._computeLocation(hashes[i]);
                address from = _loadFrom(location, StoragePositions.firstPacked);
                if (from == DELEGATION_EMPTY || from == DELEGATION_REVOKED) {
                    delegations_[i] = Delegation({type_: DelegationType.NONE, to: address(0), from: address(0), rights: "", amount: 0, contract_: address(0), tokenId: 0});
                } else {
                    (, address to, address contract_) = _loadDelegationAddresses(location, StoragePositions.firstPacked, StoragePositions.secondPacked);
                    delegations_[i] = Delegation({
                        type_: RegistryHashes._decodeLastByteToType(hashes[i]),
                        to: to,
                        from: from,
                        rights: _loadDelegationBytes32(location, StoragePositions.rights),
                        amount: _loadDelegationUint(location, StoragePositions.amount),
                        contract_: contract_,
                        tokenId: _loadDelegationUint(location, StoragePositions.tokenId)
                    });
                }
            }
        }
    }

    /**
     * ----------- EXTERNAL STORAGE ACCESS -----------
     */

    // WEN EXTSLOAD :(

    function readSlot(bytes32 location) external view returns (bytes32 contents) {
        assembly {
            contents := sload(location)
        }
    }

    function readSlots(bytes32[] calldata locations) external view returns (bytes32[] memory contents) {
        uint256 length = locations.length;
        contents = new bytes32[](length);
        assembly {
            for { let i := 0 } lt(i, length) { i := add(i, 1) } { mstore(add(contents, mul(add(i, 1), 32)), sload(calldataload(add(68, mul(i, 32))))) }
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
     * ----------- Internal -----------
     */

    /// @dev Helper function to push new delegation hashes to the incoming and outgoing hashes mappings
    function _pushDelegationHashes(address from, address to, bytes32 delegationHash) internal {
        outgoingDelegationHashes[from].push(delegationHash);
        incomingDelegationHashes[to].push(delegationHash);
    }

    /// @dev Helper function that writes bytes32 data to delegation data location at array position
    function _writeDelegation(bytes32 location, StoragePositions position, bytes32 data) internal {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that writes uint256 data to delegation data location at array position
    function _writeDelegation(bytes32 location, StoragePositions position, uint256 data) internal {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that writes addresses according to the packing rule for delegation storage
    function _writeDelegationAddresses(bytes32 location, StoragePositions firstPacked, StoragePositions secondPacked, address from, address to, address contract_)
        internal
    {
        assembly {
            sstore(add(location, firstPacked), or(shl(160, shr(96, shr(96,shl(96,contract_)))), shr(96,shl(96,from))))
            sstore(add(location, secondPacked), or(shl(160, shr(96,shl(96,contract_))), shr(96,shl(96,to))))
        }
    }

    /// @dev Helper function that takes an array of delegation hashes and returns an array of Delegation structs with their onchain information
    function _getValidDelegationsFromHashes(bytes32[] storage hashes) internal view returns (Delegation[] memory delegations_) {
        uint256 count = 0;
        uint256 hashesLength = hashes.length;
        bytes32 hash;
        bytes32[] memory filteredHashes = new bytes32[](hashesLength);
        unchecked {
            for (uint256 i = 0; i < hashesLength; ++i) {
                hash = hashes[i];
                if (_loadFrom(RegistryHashes._computeLocation(hash), StoragePositions.firstPacked) > DELEGATION_REVOKED) filteredHashes[count++] = hash;
            }
            delegations_ = new Delegation[](count);
            bytes32 location;
            for (uint256 i = 0; i < count; ++i) {
                hash = filteredHashes[i];
                location = RegistryHashes._computeLocation(hash);
                (address from, address to, address contract_) = _loadDelegationAddresses(location, StoragePositions.firstPacked, StoragePositions.secondPacked);
                delegations_[i] = Delegation({
                    type_: RegistryHashes._decodeLastByteToType(hash),
                    to: to,
                    from: from,
                    rights: _loadDelegationBytes32(location, StoragePositions.rights),
                    amount: _loadDelegationUint(location, StoragePositions.amount),
                    contract_: contract_,
                    tokenId: _loadDelegationUint(location, StoragePositions.tokenId)
                });
            }
        }
    }

    /// @dev Helper function that takes an array of delegation hashes and returns an array of valid delegation hashes
    function _getValidDelegationHashesFromHashes(bytes32[] storage hashes) internal view returns (bytes32[] memory validHashes) {
        uint256 count = 0;
        uint256 hashesLength = hashes.length;
        bytes32 hash;
        bytes32[] memory filteredHashes = new bytes32[](hashesLength);
        unchecked {
            for (uint256 i = 0; i < hashesLength; ++i) {
                hash = hashes[i];
                if (_loadFrom(RegistryHashes._computeLocation(hash), StoragePositions.firstPacked) > DELEGATION_REVOKED) filteredHashes[count++] = hash;
            }
            validHashes = new bytes32[](count);
            for (uint256 i = 0; i < count; ++i) {
                validHashes[i] = filteredHashes[i];
            }
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as bytes32
    function _loadDelegationBytes32(bytes32 location, StoragePositions position) internal view returns (bytes32 data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as uint256
    function _loadDelegationUint(bytes32 location, StoragePositions position) internal view returns (uint256 data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    // @dev Helper function that loads the from address from storage according to the packing rule for delegation storage
    function _loadFrom(bytes32 location, StoragePositions firstPacked) internal view returns (address from) {
        assembly {
            from := shr(96, shl(96, sload(add(location, firstPacked))))
        }
    }

    /// @dev Helper function that loads the address for the delegation according to the packing rule for delegation storage
    function _loadDelegationAddresses(bytes32 location, StoragePositions firstPacked, StoragePositions secondPacked)
        internal
        view
        returns (address from, address to, address contract_)
    {
        assembly {
            let firstSlot := sload(add(location, firstPacked))
            let secondSlot := sload(add(location, secondPacked))

            from := shr(96, shl(96, firstSlot))
            to := shr(96, shl(96, secondSlot))
            contract_ := or(shl(96, shr(160, shr(32,shl(32,firstSlot)))), shr(160, secondSlot))
        }
    }

    /// @dev Helper function to establish whether a delegation is enabled
    function _validateDelegation(bytes32 location, address from) internal view returns (bool) {
        return (_loadFrom(location, StoragePositions.firstPacked) == from && from > DELEGATION_REVOKED);
    }
}
