// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {IDelegateRegistry as IDelegateRegistry} from "./IDelegateRegistry.sol";
import {RegistryHashes as Hashes} from "./libraries/RegistryHashes.sol";
import {RegistryStorage as Storage} from "./libraries/RegistryStorage.sol";

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

    /// @dev Delegate enumeration inbox, for pushing new hashes only
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
                //slither-disable-next-line calls-loop
                (success, results[i]) = address(this).delegatecall(data[i]);
                if (!success) revert MulticallFailed();
            }
        }
    }

    /// @inheritdoc IDelegateRegistry
    function delegateAll(address to, bytes32 rights, bool enable) external override returns (bytes32 hash) {
        hash = Hashes.allHash(msg.sender, rights, to);
        bytes32 location = Hashes.location(hash);
        if (_loadFrom(location, Storage.Positions.firstPacked) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, Storage.Positions.firstPacked, Storage.Positions.secondPacked, msg.sender, to, address(0));
            if (rights != "") _writeDelegation(location, Storage.Positions.rights, rights);
        } else {
            _writeDelegationAddresses(location, Storage.Positions.firstPacked, Storage.Positions.secondPacked, DELEGATION_REVOKED, address(0), address(0));
            if (rights != "") _writeDelegation(location, Storage.Positions.rights, "");
        }
        emit DelegateAll(msg.sender, to, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateContract(address to, address contract_, bytes32 rights, bool enable) external override returns (bytes32 hash) {
        hash = Hashes.contractHash(msg.sender, rights, to, contract_);
        bytes32 location = Hashes.location(hash);
        if (_loadFrom(location, Storage.Positions.firstPacked) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, Storage.Positions.firstPacked, Storage.Positions.secondPacked, msg.sender, to, contract_);
            if (rights != "") _writeDelegation(location, Storage.Positions.rights, rights);
        } else {
            _writeDelegationAddresses(location, Storage.Positions.firstPacked, Storage.Positions.secondPacked, DELEGATION_REVOKED, address(0), address(0));
            if (rights != "") _writeDelegation(location, Storage.Positions.rights, "");
        }
        emit DelegateContract(msg.sender, to, contract_, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateERC721(address to, address contract_, uint256 tokenId, bytes32 rights, bool enable) external override returns (bytes32 hash) {
        hash = Hashes.erc721Hash(msg.sender, rights, to, tokenId, contract_);
        bytes32 location = Hashes.location(hash);
        if (_loadFrom(location, Storage.Positions.firstPacked) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, Storage.Positions.firstPacked, Storage.Positions.secondPacked, msg.sender, to, contract_);
            _writeDelegation(location, Storage.Positions.tokenId, tokenId);
            if (rights != "") _writeDelegation(location, Storage.Positions.rights, rights);
        } else {
            _writeDelegationAddresses(location, Storage.Positions.firstPacked, Storage.Positions.secondPacked, DELEGATION_REVOKED, address(0), address(0));
            _writeDelegation(location, Storage.Positions.tokenId, "");
            if (rights != "") _writeDelegation(location, Storage.Positions.rights, "");
        }
        emit DelegateERC721(msg.sender, to, contract_, tokenId, rights, enable);
    }

    // @inheritdoc IDelegateRegistry
    function delegateERC20(address to, address contract_, uint256 amount, bytes32 rights, bool enable) external override returns (bytes32 hash) {
        hash = Hashes.erc20Hash(msg.sender, rights, to, contract_);
        bytes32 location = Hashes.location(hash);
        if (_loadFrom(location, Storage.Positions.firstPacked) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, Storage.Positions.firstPacked, Storage.Positions.secondPacked, msg.sender, to, contract_);
            _writeDelegation(location, Storage.Positions.amount, amount);
            if (rights != "") _writeDelegation(location, Storage.Positions.rights, rights);
        } else {
            _writeDelegationAddresses(location, Storage.Positions.firstPacked, Storage.Positions.secondPacked, DELEGATION_REVOKED, address(0), address(0));
            _writeDelegation(location, Storage.Positions.amount, "");
            if (rights != "") _writeDelegation(location, Storage.Positions.rights, "");
        }
        emit DelegateERC20(msg.sender, to, contract_, amount, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateERC1155(address to, address contract_, uint256 tokenId, uint256 amount, bytes32 rights, bool enable) external override returns (bytes32 hash) {
        hash = Hashes.erc1155Hash(msg.sender, rights, to, tokenId, contract_);
        bytes32 location = Hashes.location(hash);
        if (_loadFrom(location, Storage.Positions.firstPacked) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, Storage.Positions.firstPacked, Storage.Positions.secondPacked, msg.sender, to, contract_);
            _writeDelegation(location, Storage.Positions.amount, amount);
            _writeDelegation(location, Storage.Positions.tokenId, tokenId);
            if (rights != "") _writeDelegation(location, Storage.Positions.rights, rights);
        } else {
            _writeDelegationAddresses(location, Storage.Positions.firstPacked, Storage.Positions.secondPacked, DELEGATION_REVOKED, address(0), address(0));
            _writeDelegation(location, Storage.Positions.amount, "");
            _writeDelegation(location, Storage.Positions.tokenId, "");
            if (rights != "") _writeDelegation(location, Storage.Positions.rights, "");
        }
        emit DelegateERC1155(msg.sender, to, contract_, tokenId, amount, rights, enable);
    }

    /**
     * ----------- CHECKS -----------
     */

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForAll(address to, address from, bytes32 rights) external view override returns (bool valid) {
        valid = _validateDelegation(Hashes.allLocation(from, "", to), from);
        if (rights != "" && !valid) valid = _validateDelegation(Hashes.allLocation(from, rights, to), from);
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForContract(address to, address from, address contract_, bytes32 rights) external view override returns (bool valid) {
        valid = _validateDelegation(Hashes.allLocation(from, "", to), from) || _validateDelegation(Hashes.contractLocation(from, "", to, contract_), from);
        if (rights != "" && !valid) {
            valid = _validateDelegation(Hashes.allLocation(from, rights, to), from) || _validateDelegation(Hashes.contractLocation(from, rights, to, contract_), from);
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC721(address to, address from, address contract_, uint256 tokenId, bytes32 rights) external view override returns (bool valid) {
        valid = _validateDelegation(Hashes.allLocation(from, "", to), from) || _validateDelegation(Hashes.contractLocation(from, "", to, contract_), from)
            || _validateDelegation(Hashes.erc721Location(from, "", to, tokenId, contract_), from);
        if (rights != "" && !valid) {
            valid = _validateDelegation(Hashes.allLocation(from, rights, to), from) || _validateDelegation(Hashes.contractLocation(from, rights, to, contract_), from)
                || _validateDelegation(Hashes.erc721Location(from, rights, to, tokenId, contract_), from);
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC20(address to, address from, address contract_, bytes32 rights) external view override returns (uint256 amount) {
        bytes32 location = Hashes.erc20Location(from, "", to, contract_);
        amount = (_validateDelegation(Hashes.allLocation(from, "", to), from) || _validateDelegation(Hashes.contractLocation(from, "", to, contract_), from))
            ? type(uint256).max
            : (_validateDelegation(location, from) ? _loadDelegationUint(location, Storage.Positions.amount) : 0);
        if (rights != "" && amount != type(uint256).max) {
            location = Hashes.erc20Location(from, rights, to, contract_);
            uint256 rightsBalance = (
                _validateDelegation(Hashes.allLocation(from, rights, to), from) || _validateDelegation(Hashes.contractLocation(from, rights, to, contract_), from)
            ) ? type(uint256).max : (_validateDelegation(location, from) ? _loadDelegationUint(location, Storage.Positions.amount) : 0);
            amount = rightsBalance > amount ? rightsBalance : amount;
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC1155(address to, address from, address contract_, uint256 tokenId, bytes32 rights) external view override returns (uint256 amount) {
        bytes32 location = Hashes.erc1155Location(from, "", to, tokenId, contract_);
        amount = (_validateDelegation(Hashes.allLocation(from, "", to), from) || _validateDelegation(Hashes.contractLocation(from, "", to, contract_), from))
            ? type(uint256).max
            : (_validateDelegation(location, from) ? _loadDelegationUint(location, Storage.Positions.amount) : 0);
        if (rights != "" && amount != type(uint256).max) {
            location = Hashes.erc1155Location(from, rights, to, tokenId, contract_);
            uint256 rightsBalance = (
                _validateDelegation(Hashes.allLocation(from, rights, to), from) || _validateDelegation(Hashes.contractLocation(from, rights, to, contract_), from)
            ) ? type(uint256).max : (_validateDelegation(location, from) ? _loadDelegationUint(location, Storage.Positions.amount) : 0);
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
                bytes32 location = Hashes.location(hashes[i]);
                address from = _loadFrom(location, Storage.Positions.firstPacked);
                if (from == DELEGATION_EMPTY || from == DELEGATION_REVOKED) {
                    delegations_[i] = Delegation({type_: DelegationType.NONE, to: address(0), from: address(0), rights: "", amount: 0, contract_: address(0), tokenId: 0});
                } else {
                    (, address to, address contract_) = _loadDelegationAddresses(location, Storage.Positions.firstPacked, Storage.Positions.secondPacked);
                    delegations_[i] = Delegation({
                        type_: Hashes.decodeType(hashes[i]),
                        to: to,
                        from: from,
                        rights: _loadDelegationBytes32(location, Storage.Positions.rights),
                        amount: _loadDelegationUint(location, Storage.Positions.amount),
                        contract_: contract_,
                        tokenId: _loadDelegationUint(location, Storage.Positions.tokenId)
                    });
                }
            }
        }
    }

    /**
     * ----------- EXTERNAL STORAGE ACCESS -----------
     */

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
     * ----------- INTERNAL -----------
     */

    /// @dev Helper function to push new delegation hashes to the incoming and outgoing hashes mappings
    function _pushDelegationHashes(address from, address to, bytes32 delegationHash) internal {
        outgoingDelegationHashes[from].push(delegationHash);
        incomingDelegationHashes[to].push(delegationHash);
    }

    /// @dev Helper function that writes bytes32 data to delegation data location at array position
    function _writeDelegation(bytes32 location, Storage.Positions position, bytes32 data) internal {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that writes uint256 data to delegation data location at array position
    function _writeDelegation(bytes32 location, Storage.Positions position, uint256 data) internal {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that writes addresses according to the packing rule for delegation storage
    function _writeDelegationAddresses(bytes32 location, Storage.Positions firstPacked, Storage.Positions secondPacked, address from, address to, address contract_)
        internal
    {
        (bytes32 firstSlot, bytes32 secondSlot) = Storage.packAddresses(from, to, contract_);
        assembly {
            sstore(add(location, firstPacked), firstSlot)
            sstore(add(location, secondPacked), secondSlot)
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
                if (_loadFrom(Hashes.location(hash), Storage.Positions.firstPacked) > DELEGATION_REVOKED) filteredHashes[count++] = hash;
            }
            delegations_ = new Delegation[](count);
            bytes32 location;
            for (uint256 i = 0; i < count; ++i) {
                hash = filteredHashes[i];
                location = Hashes.location(hash);
                (address from, address to, address contract_) = _loadDelegationAddresses(location, Storage.Positions.firstPacked, Storage.Positions.secondPacked);
                delegations_[i] = Delegation({
                    type_: Hashes.decodeType(hash),
                    to: to,
                    from: from,
                    rights: _loadDelegationBytes32(location, Storage.Positions.rights),
                    amount: _loadDelegationUint(location, Storage.Positions.amount),
                    contract_: contract_,
                    tokenId: _loadDelegationUint(location, Storage.Positions.tokenId)
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
                if (_loadFrom(Hashes.location(hash), Storage.Positions.firstPacked) > DELEGATION_REVOKED) filteredHashes[count++] = hash;
            }
            validHashes = new bytes32[](count);
            for (uint256 i = 0; i < count; ++i) {
                validHashes[i] = filteredHashes[i];
            }
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as bytes32
    function _loadDelegationBytes32(bytes32 location, Storage.Positions position) internal view returns (bytes32 data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as uint256
    function _loadDelegationUint(bytes32 location, Storage.Positions position) internal view returns (uint256 data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    // @dev Helper function that loads the from address from storage according to the packing rule for delegation storage
    function _loadFrom(bytes32 location, Storage.Positions firstPacked) internal view returns (address) {
        bytes32 data;
        assembly {
            data := sload(add(location, firstPacked))
        }
        return Storage.unpackAddress(data);
    }

    /// @dev Helper function that loads the address for the delegation according to the packing rule for delegation storage
    function _loadDelegationAddresses(bytes32 location, Storage.Positions firstPacked, Storage.Positions secondPacked)
        internal
        view
        returns (address from, address to, address contract_)
    {
        bytes32 firstSlot;
        bytes32 secondSlot;
        assembly {
            firstSlot := sload(add(location, firstPacked))
            secondSlot := sload(add(location, secondPacked))
        }
        (from, to, contract_) = Storage.unpackAddresses(firstSlot, secondSlot);
    }

    /// @dev Helper function to establish whether a delegation is enabled
    function _validateDelegation(bytes32 location, address from) internal view returns (bool) {
        return (_loadFrom(location, Storage.Positions.firstPacked) == from && from > DELEGATION_REVOKED);
    }
}
