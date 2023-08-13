// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {IDelegateRegistry as IDelegateRegistry} from "./IDelegateRegistry.sol";
import {RegistryHashes as Hashes} from "./libraries/RegistryHashes.sol";
import {RegistryStorage as Storage} from "./libraries/RegistryStorage.sol";
import {RegistryOps as Ops} from "./libraries/RegistryOps.sol";

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
    function multicall(bytes[] calldata data) external payable override returns (bytes[] memory results) {
        results = new bytes[](data.length);
        bool success;
        unchecked {
            for (uint256 i = 0; i < data.length; ++i) {
                //slither-disable-next-line calls-loop,delegatecall-loop
                (success, results[i]) = address(this).delegatecall(data[i]);
                if (!success) revert MulticallFailed();
            }
        }
    }

    /// @inheritdoc IDelegateRegistry
    function delegateAll(address to, bytes32 rights, bool enable) external payable override returns (bytes32 hash) {
        hash = Hashes.allHash(msg.sender, rights, to);
        bytes32 location = Hashes.location(hash);
        if (_loadFrom(location) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, msg.sender, to, address(0));
            if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, rights);
        } else {
            _writeDelegationAddresses(location, DELEGATION_REVOKED, address(0), address(0));
            if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, "");
        }
        emit DelegateAll(msg.sender, to, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateContract(address to, address contract_, bytes32 rights, bool enable) external payable override returns (bytes32 hash) {
        hash = Hashes.contractHash(msg.sender, rights, to, contract_);
        bytes32 location = Hashes.location(hash);
        if (_loadFrom(location) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, msg.sender, to, contract_);
            if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, rights);
        } else {
            _writeDelegationAddresses(location, DELEGATION_REVOKED, address(0), address(0));
            if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, "");
        }
        emit DelegateContract(msg.sender, to, contract_, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateERC721(address to, address contract_, uint256 tokenId, bytes32 rights, bool enable) external payable override returns (bytes32 hash) {
        hash = Hashes.erc721Hash(msg.sender, rights, to, tokenId, contract_);
        bytes32 location = Hashes.location(hash);
        if (_loadFrom(location) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, msg.sender, to, contract_);
            _writeDelegation(location, Storage.POSITIONS_TOKEN_ID, tokenId);
            if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, rights);
        } else {
            _writeDelegationAddresses(location, DELEGATION_REVOKED, address(0), address(0));
            _writeDelegation(location, Storage.POSITIONS_TOKEN_ID, "");
            if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, "");
        }
        emit DelegateERC721(msg.sender, to, contract_, tokenId, rights, enable);
    }

    // @inheritdoc IDelegateRegistry
    function delegateERC20(address to, address contract_, uint256 amount, bytes32 rights, bool enable) external payable override returns (bytes32 hash) {
        hash = Hashes.erc20Hash(msg.sender, rights, to, contract_);
        bytes32 location = Hashes.location(hash);
        if (_loadFrom(location) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, msg.sender, to, contract_);
            _writeDelegation(location, Storage.POSITIONS_AMOUNT, amount);
            if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, rights);
        } else {
            _writeDelegationAddresses(location, DELEGATION_REVOKED, address(0), address(0));
            _writeDelegation(location, Storage.POSITIONS_AMOUNT, "");
            if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, "");
        }
        emit DelegateERC20(msg.sender, to, contract_, amount, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateERC1155(address to, address contract_, uint256 tokenId, uint256 amount, bytes32 rights, bool enable)
        external
        payable
        override
        returns (bytes32 hash)
    {
        hash = Hashes.erc1155Hash(msg.sender, rights, to, tokenId, contract_);
        bytes32 location = Hashes.location(hash);
        if (_loadFrom(location) == DELEGATION_EMPTY) _pushDelegationHashes(msg.sender, to, hash);
        if (enable) {
            _writeDelegationAddresses(location, msg.sender, to, contract_);
            _writeDelegation(location, Storage.POSITIONS_AMOUNT, amount);
            _writeDelegation(location, Storage.POSITIONS_TOKEN_ID, tokenId);
            if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, rights);
        } else {
            _writeDelegationAddresses(location, DELEGATION_REVOKED, address(0), address(0));
            _writeDelegation(location, Storage.POSITIONS_AMOUNT, "");
            _writeDelegation(location, Storage.POSITIONS_TOKEN_ID, "");
            if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, "");
        }
        emit DelegateERC1155(msg.sender, to, contract_, tokenId, amount, rights, enable);
    }

    /// @dev Transfer native token out
    function sweep() external {
        // TODO: Replace this with CREATE2-counterfactual smart contract wallet address
        //slither-disable-next-line unchecked-lowlevel
        0x0000000000000000000000000000000000000000.call{value: address(this).balance}("");
    }

    /**
     * ----------- CHECKS -----------
     */

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForAll(address to, address from, bytes32 rights) external view override returns (bool valid) {
        valid = _validateDelegation(Hashes.allLocation(from, "", to), from);
        if (!Ops.or(rights == "", valid)) valid = _validateDelegation(Hashes.allLocation(from, rights, to), from);
        assembly ("memory-safe") {
            // Only first 32 bytes of scratch space is accessed
            mstore(0, iszero(iszero(valid))) // Compiler cleans ditry booleans on the stack to 1, so we're doing the same here
            return(0, 32) // Direct return. Skips Solidity's redundant copying to save gas.
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForContract(address to, address from, address contract_, bytes32 rights) external view override returns (bool valid) {
        valid = _validateDelegation(Hashes.allLocation(from, "", to), from) || _validateDelegation(Hashes.contractLocation(from, "", to, contract_), from);
        if (!Ops.or(rights == "", valid)) {
            valid = _validateDelegation(Hashes.allLocation(from, rights, to), from) || _validateDelegation(Hashes.contractLocation(from, rights, to, contract_), from);
        }
        assembly ("memory-safe") {
            // Only first 32 bytes of scratch space is accessed
            mstore(0, iszero(iszero(valid))) // Compiler cleans dirty booleans on the stack to 1, so we're doing the same here
            return(0, 32) // Direct return. Skips Solidity's redundant copying to save gas.
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC721(address to, address from, address contract_, uint256 tokenId, bytes32 rights) external view override returns (bool valid) {
        valid = _validateDelegation(Hashes.allLocation(from, "", to), from) || _validateDelegation(Hashes.contractLocation(from, "", to, contract_), from)
            || _validateDelegation(Hashes.erc721Location(from, "", to, tokenId, contract_), from);
        if (!Ops.or(rights == "", valid)) {
            valid = _validateDelegation(Hashes.allLocation(from, rights, to), from) || _validateDelegation(Hashes.contractLocation(from, rights, to, contract_), from)
                || _validateDelegation(Hashes.erc721Location(from, rights, to, tokenId, contract_), from);
        }
        assembly ("memory-safe") {
            // Only first 32 bytes of scratch space is accessed
            mstore(0, iszero(iszero(valid))) // Compiler cleans dirty booleans on the stack to 1, so we're doing the same here
            return(0, 32) // Direct return. Skips Solidity's redundant copying to save gas.
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC20(address to, address from, address contract_, bytes32 rights) external view override returns (uint256 amount) {
        bytes32 location = Hashes.erc20Location(from, "", to, contract_);
        amount = (_validateDelegation(Hashes.allLocation(from, "", to), from) || _validateDelegation(Hashes.contractLocation(from, "", to, contract_), from))
            ? type(uint256).max
            : (_validateDelegation(location, from) ? _loadDelegationUint(location, Storage.POSITIONS_AMOUNT) : 0);
        if (!Ops.or(rights == "", amount == type(uint256).max)) {
            location = Hashes.erc20Location(from, rights, to, contract_);
            uint256 rightsBalance = (
                _validateDelegation(Hashes.allLocation(from, rights, to), from) || _validateDelegation(Hashes.contractLocation(from, rights, to, contract_), from)
            ) ? type(uint256).max : (_validateDelegation(location, from) ? _loadDelegationUint(location, Storage.POSITIONS_AMOUNT) : 0);
            amount = Ops.max(rightsBalance, amount);
        }
        assembly ("memory-safe") {
            mstore(0, amount) // Only first 32 bytes of scratch space being accessed
            return(0, 32) // Direct return. Skips Solidity's redundant copying to save gas.
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC1155(address to, address from, address contract_, uint256 tokenId, bytes32 rights) external view override returns (uint256 amount) {
        bytes32 location = Hashes.erc1155Location(from, "", to, tokenId, contract_);
        amount = (_validateDelegation(Hashes.allLocation(from, "", to), from) || _validateDelegation(Hashes.contractLocation(from, "", to, contract_), from))
            ? type(uint256).max
            : (_validateDelegation(location, from) ? _loadDelegationUint(location, Storage.POSITIONS_AMOUNT) : 0);
        if (!Ops.or(rights == "", amount == type(uint256).max)) {
            location = Hashes.erc1155Location(from, rights, to, tokenId, contract_);
            uint256 rightsBalance = (
                _validateDelegation(Hashes.allLocation(from, rights, to), from) || _validateDelegation(Hashes.contractLocation(from, rights, to, contract_), from)
            ) ? type(uint256).max : (_validateDelegation(location, from) ? _loadDelegationUint(location, Storage.POSITIONS_AMOUNT) : 0);
            amount = Ops.max(rightsBalance, amount);
        }
        assembly ("memory-safe") {
            mstore(0, amount) // Only first 32 bytes of scratch space is accessed
            return(0, 32) // Direct return. Skips Solidity's redundant copying to save gas.
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
                address from = _loadFrom(location);
                if (Ops.or(from == DELEGATION_EMPTY, from == DELEGATION_REVOKED)) {
                    delegations_[i] = Delegation({type_: DelegationType.NONE, to: address(0), from: address(0), rights: "", amount: 0, contract_: address(0), tokenId: 0});
                } else {
                    (, address to, address contract_) = _loadDelegationAddresses(location);
                    delegations_[i] = Delegation({
                        type_: Hashes.decodeType(hashes[i]),
                        to: to,
                        from: from,
                        rights: _loadDelegationBytes32(location, Storage.POSITIONS_RIGHTS),
                        amount: _loadDelegationUint(location, Storage.POSITIONS_AMOUNT),
                        contract_: contract_,
                        tokenId: _loadDelegationUint(location, Storage.POSITIONS_TOKEN_ID)
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
        bytes32 tempLocation;
        bytes32 tempValue;
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                tempLocation = locations[i];
                assembly {
                    tempValue := sload(tempLocation)
                }
                contents[i] = tempValue;
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
        return Ops.or(interfaceId == type(IDelegateRegistry).interfaceId, interfaceId == 0x01ffc9a7);
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
    function _writeDelegation(bytes32 location, uint256 position, bytes32 data) internal {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that writes uint256 data to delegation data location at array position
    function _writeDelegation(bytes32 location, uint256 position, uint256 data) internal {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that writes addresses according to the packing rule for delegation storage
    function _writeDelegationAddresses(bytes32 location, address from, address to, address contract_) internal {
        (bytes32 firstSlot, bytes32 secondSlot) = Storage.packAddresses(from, to, contract_);
        uint256 firstPacked = Storage.POSITIONS_FIRST_PACKED;
        uint256 secondPacked = Storage.POSITIONS_SECOND_PACKED;
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
                if (_loadFrom(Hashes.location(hash)) > DELEGATION_REVOKED) filteredHashes[count++] = hash;
            }
            delegations_ = new Delegation[](count);
            bytes32 location;
            for (uint256 i = 0; i < count; ++i) {
                hash = filteredHashes[i];
                location = Hashes.location(hash);
                (address from, address to, address contract_) = _loadDelegationAddresses(location);
                delegations_[i] = Delegation({
                    type_: Hashes.decodeType(hash),
                    to: to,
                    from: from,
                    rights: _loadDelegationBytes32(location, Storage.POSITIONS_RIGHTS),
                    amount: _loadDelegationUint(location, Storage.POSITIONS_AMOUNT),
                    contract_: contract_,
                    tokenId: _loadDelegationUint(location, Storage.POSITIONS_TOKEN_ID)
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
                if (_loadFrom(Hashes.location(hash)) > DELEGATION_REVOKED) filteredHashes[count++] = hash;
            }
            validHashes = new bytes32[](count);
            for (uint256 i = 0; i < count; ++i) {
                validHashes[i] = filteredHashes[i];
            }
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as bytes32
    function _loadDelegationBytes32(bytes32 location, uint256 position) internal view returns (bytes32 data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as uint256
    function _loadDelegationUint(bytes32 location, uint256 position) internal view returns (uint256 data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    // @dev Helper function that loads the from address from storage according to the packing rule for delegation storage
    function _loadFrom(bytes32 location) internal view returns (address) {
        bytes32 data;
        uint256 firstPacked = Storage.POSITIONS_FIRST_PACKED;
        assembly {
            data := sload(add(location, firstPacked))
        }
        return Storage.unpackAddress(data);
    }

    /// @dev Helper function that loads the address for the delegation according to the packing rule for delegation storage
    function _loadDelegationAddresses(bytes32 location) internal view returns (address from, address to, address contract_) {
        bytes32 firstSlot;
        bytes32 secondSlot;
        uint256 firstPacked = Storage.POSITIONS_FIRST_PACKED;
        uint256 secondPacked = Storage.POSITIONS_SECOND_PACKED;
        assembly {
            firstSlot := sload(add(location, firstPacked))
            secondSlot := sload(add(location, secondPacked))
        }
        (from, to, contract_) = Storage.unpackAddresses(firstSlot, secondSlot);
    }

    /// @dev Helper function to establish whether a delegation is enabled
    function _validateDelegation(bytes32 location, address from) internal view returns (bool result) {
        uint256 loaded = uint256(uint160(_loadFrom(location)));
        uint256 revoked = uint256(uint160(DELEGATION_REVOKED));
        uint256 fromCasted = uint256(uint160(from));
        assembly {
            result := and(eq(fromCasted, loaded), gt(fromCasted, revoked))
        }
    }
}
