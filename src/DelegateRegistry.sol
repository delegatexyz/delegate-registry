// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IDelegateRegistry} from "./IDelegateRegistry.sol";

/**
 * DONE:
 * - batch delegation and test
 * - rename getDelegatesByDelegate() to getDelegatesForDelegate()
 * - rename revokeAllDelegates() to revokeAllDelegations()
 * - add getDelegatesForVault() method, remove getContractLevelDelegations() & getTokenLevelDelegations()
 * - remove getDelegatesForAll() & getDelegatesForContract() & getDelegatesForToken()
 * - bump compiler version and compiler runs
 * - named mappings
 * - fixed broken event param
 * - added indexing to event params
 * - clearer naming for internal mappings
 * - combined duplicate logic into _filterHash internal function
 * - rewrite tests to use new enumerations
 * - delegateDelegationHashes isn't a strong DDoS vector bc users can call `revokeVault()`
 * - remove revokeDelegate() & revokeSelf() bc mainnet usage misunderstands it, batching mostly replaces this
 * - remove revokeAllDelegations() bc batching gets you similar costs on revocation and far cheaper to not fetch vaultVersions from storage
 * - data param attached to the delegation for splitting up rights like licensing, governance, and yield to different people
 * - delegation balance splitting for ERC20s and ERC1155s, rename delegateForToken() to delegateForERC721/20/1155
 * - rename DelegateRegistry to DelegateRegistry
 * - remove ERC165 import for fewer files
 * TODO:
 * - code example of using the data param for multiple IP licensing and governance/yield splitting
 * - identity clusters
 * - crosschain support using LayerZero?
 * - get rid of delegateForContract? Hardly used, only 8% of volume, but also good fallback for new token types. Let's keep it
 * - we could bitmask contract address, token id, balance, data into a hash func? brings us back to onchain enumerability
 * STRETCH
 * - zk attestations
 * - account abstraction
 */

/**
 * For NFTs, we did a specific separate method that specifies a tokenId. And then the app can mark that one as "used" when they claim utility.
 * How does Snapshot distinguish amounts that have been voted? Either a snapshot or a lockup. For a lockup you would need to mark certain tokens as used.
 * How would you split something in half? Could run a percentage basis. But then the amounts can change.
 *
 *  More broadly speaking, snapshot requires a snapshot in time. Sudo did a lockdrop.
 *
 *  The ERC20 usecase is actually identical to ERC721 if you take a snapshot approach, just decrement balances once used
 *  Another adjustment is that ERC721s are FCFS, while snapshots let you change your vote. if both holder & delegate vote then delegate overridden
 *  this is only possible bc there's no tradeable result while voting is happening, unlike NFT mint
 *  escrow could guarantee you play by the rules
 *
 *  Ontology is more important than implementation details right now. Don't worry about how to revoke.
 *  There are tiers like identity/wallet/contract/token
 *  And identity is a way of restricting one-to-one, while subdelegations are a way of splitting up one delegation into many parts
 *  Maybe we bitmask to apply balances?
 *
 * Add an "exclusive" bool parameter to delegations, if true then pushes out the rest. Liquid Delegates does exclusivity. Vault can always transfer. Apps shouldn't depend on this.
 * Many-to-one is used for account aggregation. What about one-to-many, what's this used for?
 *
 * Maybe we just hardcode ERC20, ERC721, ERC1155 usecases. There aren't that many standards. delegateForERC20, delegateForERC721, delegateForERC1155
 *
 * Liquid Delegate could enable the user to create multiple delegations with the data param being set differently.
 * Maybe one principal token and many delegation tokens. Whoever owns the principal can create new delegation tokens expiring later in the future.
 *
 * There could be an extension contract letting people register their own definitions for keys and values?
 * Having numerical (balance 3600) and string ("IP licensing for bookstore") values in same slot feels ugly
 *
 * DATA ONTOLOGY
 * balance will always be capped at a uint256, same with tokenId
 * ERC20 = no tokenId, yes balance
 * ERC721: yes tokenId, no balance
 * ERC1155: yes tokenId, yes balance
 *
 * Bubbling specific data fields into "all" feels messy, if someone delegates for all then it shouldn't matter which param gets passed
 */

/**
 * @title DelegateRegistry
 * @custom:version 2.0
 * @custom:author foobar (0xfoobar)
 * @notice A standalone immutable registry storing delegated permissions from one wallet to another
 */
contract DelegateRegistry is IDelegateRegistry {
    /// @dev Only this mapping should be used to verify delegations; the other mappings are for record keeping only
    mapping(bytes32 delegationHash => bytes32[6] delegationStorage) private _delegations;

    /// @dev vault delegation outbox, for pushing new hashes only
    mapping(address vault => bytes32[] delegationHashes) private _vaultDelegationHashes;

    /// @dev delegate delegation inbox, for pushing new hashes only
    mapping(address delegate => bytes32[] delegationHashes) private _delegateDelegationHashes;

    /// @notice Query if a contract implements an ERC-165 interface
    /// @param interfaceId The interface identifier
    /// @return bool Whether the queried interface is supported
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IDelegateRegistry).interfaceId || interfaceId == 0x01ffc9a7;
    }

    /**
     * ----------- WRITE -----------
     */

    /// @inheritdoc IDelegateRegistry
    function batchDelegate(BatchDelegation[] calldata delegations) external override {
        for (uint256 i = 0; i < delegations.length; ++i) {
            if (delegations[i].type_ == DelegationType.ALL) {
                delegateForAll(delegations[i].delegate, delegations[i].rights, delegations[i].enable);
            } else if (delegations[i].type_ == DelegationType.CONTRACT) {
                delegateForContract(delegations[i].delegate, delegations[i].contract_, delegations[i].rights, delegations[i].enable);
            } else if (delegations[i].type_ == DelegationType.ERC721) {
                delegateForERC721(delegations[i].delegate, delegations[i].contract_, delegations[i].tokenId, delegations[i].rights, delegations[i].enable);
            } else if (delegations[i].type_ == DelegationType.ERC20) {
                delegateForERC20(delegations[i].delegate, delegations[i].contract_, delegations[i].balance, delegations[i].rights, delegations[i].enable);
            } else if (delegations[i].type_ == DelegationType.ERC1155) {
                delegateForERC1155(
                    delegations[i].delegate,
                    delegations[i].contract_,
                    delegations[i].tokenId,
                    delegations[i].balance,
                    delegations[i].rights,
                    delegations[i].enable
                );
            }
        }
    }

    /// @inheritdoc IDelegateRegistry
    function delegateForAll(address delegate, bytes32 rights, bool enable) public override {
        bytes32 hash = _computeDelegationHashForAll(delegate, rights, msg.sender);
        bytes32 location = _computeDelegationLocation(hash);
        emit AllDelegated(msg.sender, delegate, rights, enable);
        if (enable) {
            if (_loadDelegationBytes32(location, StoragePositions.vault) == "") _pushDelegationHashes(msg.sender, delegate, hash);
            _writeDelegation(location, StoragePositions.delegate, delegate);
            _writeDelegation(location, StoragePositions.vault, msg.sender);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.delegate, "");
            _writeDelegation(location, StoragePositions.vault, 1);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
    }

    /// @inheritdoc IDelegateRegistry
    function delegateForContract(address delegate, address contract_, bytes32 rights, bool enable) public override {
        bytes32 hash = _computeDelegationHashForContract(contract_, delegate, rights, msg.sender);
        bytes32 location = _computeDelegationLocation(hash);
        emit ContractDelegated(msg.sender, delegate, contract_, rights, enable);
        if (enable) {
            if (_loadDelegationBytes32(location, StoragePositions.vault) == "") _pushDelegationHashes(msg.sender, delegate, hash);
            _writeDelegation(location, StoragePositions.contract_, contract_);
            _writeDelegation(location, StoragePositions.delegate, delegate);
            _writeDelegation(location, StoragePositions.vault, msg.sender);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.contract_, "");
            _writeDelegation(location, StoragePositions.delegate, "");
            _writeDelegation(location, StoragePositions.vault, 1);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
    }

    /// @inheritdoc IDelegateRegistry
    function delegateForERC721(address delegate, address contract_, uint256 tokenId, bytes32 rights, bool enable) public override {
        bytes32 hash = _computeDelegationHashForERC721(contract_, delegate, rights, tokenId, msg.sender);
        bytes32 location = _computeDelegationLocation(hash);
        emit ERC721Delegated(msg.sender, delegate, contract_, tokenId, rights, enable);
        if (enable) {
            if (_loadDelegationBytes32(location, StoragePositions.vault) == "") _pushDelegationHashes(msg.sender, delegate, hash);
            _writeDelegation(location, StoragePositions.contract_, contract_);
            _writeDelegation(location, StoragePositions.delegate, delegate);
            _writeDelegation(location, StoragePositions.vault, msg.sender);
            _writeDelegation(location, StoragePositions.tokenId, tokenId);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.contract_, "");
            _writeDelegation(location, StoragePositions.delegate, "");
            _writeDelegation(location, StoragePositions.vault, 1);
            _writeDelegation(location, StoragePositions.tokenId, "");
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
    }

    /**
     * @inheritdoc IDelegateRegistry
     * @dev the actual balance is not encoded in the hash, just the existence of a balance (since it is an upper bound)
     */
    function delegateForERC20(address delegate, address contract_, uint256 balance, bytes32 rights, bool enable) public override {
        bytes32 hash = _computeDelegationHashForERC20(contract_, delegate, rights, msg.sender);
        bytes32 location = _computeDelegationLocation(hash);
        emit ERC20Delegated(msg.sender, delegate, contract_, balance, rights, enable);
        if (enable) {
            if (_loadDelegationBytes32(location, StoragePositions.vault) == "") _pushDelegationHashes(msg.sender, delegate, hash);
            _writeDelegation(location, StoragePositions.contract_, contract_);
            _writeDelegation(location, StoragePositions.delegate, delegate);
            _writeDelegation(location, StoragePositions.vault, msg.sender);
            _writeDelegation(location, StoragePositions.balance, balance);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.contract_, "");
            _writeDelegation(location, StoragePositions.delegate, "");
            _writeDelegation(location, StoragePositions.vault, 1);
            _writeDelegation(location, StoragePositions.balance, "");
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
    }

    /**
     * @inheritdoc IDelegateRegistry
     * @dev the actual balance is not encoded in the hash, just the existence of a balance (since it is an upper bound)
     */
    function delegateForERC1155(address delegate, address contract_, uint256 tokenId, uint256 balance, bytes32 rights, bool enable) public override {
        bytes32 hash = _computeDelegationHashForERC1155(contract_, delegate, rights, tokenId, msg.sender);
        bytes32 location = _computeDelegationLocation(hash);
        emit ERC1155Delegated(msg.sender, delegate, contract_, tokenId, balance, rights, enable);
        if (enable) {
            if (_loadDelegationBytes32(location, StoragePositions.vault) == "") _pushDelegationHashes(msg.sender, delegate, hash);
            _writeDelegation(location, StoragePositions.contract_, contract_);
            _writeDelegation(location, StoragePositions.delegate, delegate);
            _writeDelegation(location, StoragePositions.vault, msg.sender);
            _writeDelegation(location, StoragePositions.balance, balance);
            _writeDelegation(location, StoragePositions.tokenId, tokenId);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.contract_, "");
            _writeDelegation(location, StoragePositions.delegate, "");
            _writeDelegation(location, StoragePositions.vault, 1);
            _writeDelegation(location, StoragePositions.balance, "");
            _writeDelegation(location, StoragePositions.tokenId, "");
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
    }

    /**
     * ----------- Consumable -----------
     */

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForAll(address delegate, address vault, bytes32 rights) public view override returns (bool valid) {
        bytes32 location = _computeDelegationLocation(_computeDelegationHashForAll(delegate, "", vault));
        valid = _loadDelegationAddress(location, StoragePositions.vault) == vault;
        if (rights != "" && !valid) {
            location = _computeDelegationLocation(_computeDelegationHashForAll(delegate, rights, vault));
            valid = _loadDelegationAddress(location, StoragePositions.vault) == vault;
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForContract(address delegate, address vault, address contract_, bytes32 rights) public view override returns (bool valid) {
        bytes32 location = _computeDelegationLocation(_computeDelegationHashForContract(contract_, delegate, "", vault));
        valid = checkDelegateForAll(delegate, vault, "") || _loadDelegationAddress(location, StoragePositions.vault) == vault;
        if (rights != "" && !valid) {
            location = _computeDelegationLocation(_computeDelegationHashForContract(contract_, delegate, rights, vault));
            valid = checkDelegateForAll(delegate, vault, rights) || _loadDelegationAddress(location, StoragePositions.vault) == vault;
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC20(address delegate, address vault, address contract_, bytes32 rights) external view override returns (uint256 balance) {
        bytes32 location = _computeDelegationLocation(_computeDelegationHashForERC20(contract_, delegate, "", vault));
        balance = checkDelegateForContract(delegate, vault, contract_, "")
            ? type(uint256).max
            : (_loadDelegationAddress(location, StoragePositions.vault) == vault ? _loadDelegationUint(location, StoragePositions.balance) : 0);
        if (rights != "" && balance != type(uint256).max) {
            location = _computeDelegationLocation(_computeDelegationHashForERC20(contract_, delegate, rights, vault));
            uint256 rightsBalance = checkDelegateForContract(delegate, vault, contract_, rights)
                ? type(uint256).max
                : (_loadDelegationAddress(location, StoragePositions.vault) == vault ? _loadDelegationUint(location, StoragePositions.balance) : 0);
            balance = rightsBalance > balance ? rightsBalance : balance;
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC721(address delegate, address vault, address contract_, uint256 tokenId, bytes32 rights)
        external
        view
        override
        returns (bool valid)
    {
        bytes32 location = _computeDelegationLocation(_computeDelegationHashForERC721(contract_, delegate, "", tokenId, vault));
        valid = checkDelegateForContract(delegate, vault, contract_, "") || _loadDelegationAddress(location, StoragePositions.vault) == vault;
        if (rights != "" && !valid) {
            location = _computeDelegationLocation(_computeDelegationHashForERC721(contract_, delegate, rights, tokenId, vault));
            valid = checkDelegateForContract(delegate, vault, contract_, rights) || _loadDelegationAddress(location, StoragePositions.vault) == vault;
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC1155(address delegate, address vault, address contract_, uint256 tokenId, bytes32 rights)
        external
        view
        override
        returns (uint256 balance)
    {
        bytes32 location = _computeDelegationLocation(_computeDelegationHashForERC1155(contract_, delegate, "", tokenId, vault));
        balance = checkDelegateForContract(delegate, vault, contract_, "")
            ? type(uint256).max
            : (_loadDelegationAddress(location, StoragePositions.vault) == vault ? _loadDelegationUint(location, StoragePositions.balance) : 0);
        if (rights != "" && balance != type(uint256).max) {
            location = _computeDelegationLocation(_computeDelegationHashForERC1155(contract_, delegate, rights, tokenId, vault));
            uint256 rightsBalance = checkDelegateForContract(delegate, vault, contract_, rights)
                ? type(uint256).max
                : (_loadDelegationAddress(location, StoragePositions.vault) == vault ? _loadDelegationUint(location, StoragePositions.balance) : 0);
            balance = rightsBalance > balance ? rightsBalance : balance;
        }
    }

    /**
     * ----------- READ -----------
     */

    /// @inheritdoc IDelegateRegistry
    function getDelegationsForDelegate(address delegate) external view override returns (Delegation[] memory delegations) {
        return getDelegationsFromHashes(_filterDelegationHashes(_delegateDelegationHashes[delegate]));
    }

    /// @inheritdoc IDelegateRegistry
    function getDelegationsForVault(address vault) external view returns (Delegation[] memory) {
        return getDelegationsFromHashes(_filterDelegationHashes(_vaultDelegationHashes[vault]));
    }

    /// @dev Helper function that takes an array of delegation hashes and returns an array of Delegation structs with their on chain information
    function getDelegationsFromHashes(bytes32[] memory hashes) public view returns (Delegation[] memory delegations) {
        delegations = new Delegation[](hashes.length);
        bytes32 location;
        bytes32 hash;
        address vault;
        for (uint256 i = 0; i < hashes.length; i++) {
            hash = hashes[i];
            location = _computeDelegationLocation(hash);
            vault = _loadDelegationAddress(location, StoragePositions.vault);
            delegations[i] = Delegation({
                type_: _decodeLastByteToType(hash),
                enable: vault != address(0),
                delegate: _loadDelegationAddress(location, StoragePositions.delegate),
                vault: vault,
                rights: _loadDelegationBytes32(location, StoragePositions.rights),
                balance: _loadDelegationUint(location, StoragePositions.balance),
                contract_: _loadDelegationAddress(location, StoragePositions.contract_),
                tokenId: _loadDelegationUint(location, StoragePositions.tokenId)
            });
        }
    }

    /**
     * ----------- Private -----------
     */

    /// @dev Helper function to push new delegation hashes to the delegate and vault hashes mappings
    function _pushDelegationHashes(address vault, address delegate, bytes32 delegationHash) private {
        _vaultDelegationHashes[vault].push(delegationHash);
        _delegateDelegationHashes[delegate].push(delegationHash);
    }

    /// @dev Helper function to compute delegation hash for all delegation
    function _computeDelegationHashForAll(address delegate, bytes32 rights, address vault) private pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(delegate, vault, rights)), DelegationType.ALL);
    }

    /// @dev Helper function to compute delegation hash for contract delegation
    function _computeDelegationHashForContract(address contract_, address delegate, bytes32 rights, address vault) private pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, delegate, rights, vault)), DelegationType.CONTRACT);
    }

    /// @dev Helper function to compute delegation hash for ERC20 delegation
    function _computeDelegationHashForERC20(address contract_, address delegate, bytes32 rights, address vault) private pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, delegate, rights, vault)), DelegationType.ERC20);
    }

    /// @dev Helper function to compute delegation hash for ERC721 delegation
    function _computeDelegationHashForERC721(address contract_, address delegate, bytes32 rights, uint256 tokenId, address vault)
        private
        pure
        returns (bytes32)
    {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, delegate, rights, tokenId, vault)), DelegationType.ERC721);
    }

    /// @dev Helper function to compute delegation hash for ERC1155 delegation
    function _computeDelegationHashForERC1155(address contract_, address delegate, bytes32 rights, uint256 tokenId, address vault)
        private
        pure
        returns (bytes32)
    {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, delegate, rights, tokenId, vault)), DelegationType.ERC1155);
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

    /// @dev Helper function to encode the last byte of a delegation hash to its type
    function _encodeLastByteWithType(bytes32 _input, DelegationType _type) private pure returns (bytes32) {
        return (_input & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00) | bytes32(uint256(_type));
    }

    /// @dev Helper function to decode last byte of a delegation hash to obtain its type
    function _decodeLastByteToType(bytes32 _input) private pure returns (DelegationType) {
        return DelegationType(uint8(uint256(_input) & 0xFF));
    }

    /// @dev Helper function that filters an array of delegation hashes by removing disabled delegations
    function _filterDelegationHashes(bytes32[] memory array_) private view returns (bytes32[] memory) {
        uint256 count = 0;
        uint256 vault;
        bytes32[] memory tempArray = new bytes32[](array_.length);

        for (uint256 i = 0; i < array_.length; i++) {
            vault = uint256(_delegations[array_[i]][uint256(StoragePositions.vault)]);
            if (vault != 0 && vault != 1) {
                tempArray[count] = array_[i];
                count++;
            }
        }

        bytes32[] memory newArray = new bytes32[](count);

        for (uint256 i = 0; i < count; i++) {
            newArray[i] = tempArray[i];
        }

        return newArray;
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

    /// @dev Helper function that computes the data location of a particular delegation hash
    function _computeDelegationLocation(bytes32 hash) private pure returns (bytes32 location) {
        location = keccak256(abi.encode(hash, 0)); // _delegations mapping is at slot 0
    }
}
