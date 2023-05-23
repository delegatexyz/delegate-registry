// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IDelegateRegistry} from "./IDelegateRegistry.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

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
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @dev Connects a delegationHash and its struct fields, an inverse hash function
    mapping(bytes32 delegationHash => IDelegateRegistry.DelegationInfo delegationInfo) internal delegationInfo;

    /// @dev The primary mapping to enumerate a vault's outgoing delegations, used to create and revoke individual delegations
    mapping(address vault => EnumerableSet.Bytes32Set hashes) internal vaultDelegationHashes;

    /// @dev A secondary mapping to enumerate a delegate's incoming delegations
    mapping(address delegate => EnumerableSet.Bytes32Set hashes) internal delegateDelegationHashes;

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
    function batchDelegate(IDelegateRegistry.DelegationInfo[] calldata details, bool[] calldata values) external override {
        uint256 detailsLength = details.length;
        for (uint256 i = 0; i < detailsLength; ++i) {
            if (details[i].type_ == IDelegateRegistry.DelegationType.ALL) {
                delegateForAll(details[i].delegate, values[i], details[i].data);
            } else if (details[i].type_ == IDelegateRegistry.DelegationType.CONTRACT) {
                delegateForContract(details[i].delegate, details[i].contract_, values[i], details[i].data);
            } else if (details[i].type_ == IDelegateRegistry.DelegationType.ERC721) {
                delegateForERC721(details[i].delegate, details[i].contract_, details[i].tokenId, values[i], details[i].data);
            } else if (details[i].type_ == IDelegateRegistry.DelegationType.ERC20) {
                delegateForERC20(details[i].delegate, details[i].contract_, details[i].balance, values[i], details[i].data);
            } else if (details[i].type_ == IDelegateRegistry.DelegationType.ERC1155) {
                delegateForERC1155(details[i].delegate, details[i].contract_, details[i].tokenId, details[i].balance, values[i], details[i].data);
            }
        }
    }

    /// @inheritdoc IDelegateRegistry
    function delegateForAll(address delegate, bool value, bytes32 data) public override {
        bytes32 delegationHash = _computeDelegationHashForAll(msg.sender, delegate, data);
        _setDelegationValues(delegate, delegationHash, value, IDelegateRegistry.DelegationType.ALL, msg.sender, address(0), 0, 0, data);
        emit IDelegateRegistry.DelegateForAll(msg.sender, delegate, value, data);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateForContract(address delegate, address contract_, bool value, bytes32 data) public override {
        bytes32 delegationHash = _computeDelegationHashForContract(msg.sender, delegate, contract_, data);
        _setDelegationValues(delegate, delegationHash, value, IDelegateRegistry.DelegationType.CONTRACT, msg.sender, contract_, 0, 0, data);
        emit IDelegateRegistry.DelegateForContract(msg.sender, delegate, contract_, value, data);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateForERC721(address delegate, address contract_, uint256 tokenId, bool value, bytes32 data) public override {
        bytes32 delegationHash = _computeDelegationHashForERC721(msg.sender, delegate, contract_, tokenId, data);
        _setDelegationValues(delegate, delegationHash, value, IDelegateRegistry.DelegationType.ERC721, msg.sender, contract_, tokenId, 0, data);
        emit IDelegateRegistry.DelegateForERC721(msg.sender, delegate, contract_, tokenId, value, data);
    }

    /**
     * @inheritdoc IDelegateRegistry
     * @dev collides with delegateForERC1155 method with tokenId = 0, but shouldn't be problem given contract_ encoding
     * @dev the actual balance is not encoded in the hash, just the existence of a balance (since it is an upper bound)
     */
    function delegateForERC20(address delegate, address contract_, uint256 balance, bool value, bytes32 data) public override {
        bytes32 delegationHash = _computeDelegationHashForERC1155(msg.sender, delegate, contract_, 0, data);
        _setDelegationValues(delegate, delegationHash, value, IDelegateRegistry.DelegationType.ERC20, msg.sender, contract_, 0, balance, data);
        emit IDelegateRegistry.DelegateForERC20(msg.sender, delegate, contract_, balance, value, data);
    }

    /**
     * @inheritdoc IDelegateRegistry
     * @dev collides with delegateForERC20 method with tokenId = 0, but shouldn't be problem given contract_ encoding
     * @dev the actual balance is not encoded in the hash, just the existence of a balance (since it is an upper bound)
     */
    function delegateForERC1155(address delegate, address contract_, uint256 tokenId, uint256 balance, bool value, bytes32 data) public override {
        bytes32 delegationHash = _computeDelegationHashForERC1155(msg.sender, delegate, contract_, tokenId, data);
        _setDelegationValues(delegate, delegationHash, value, IDelegateRegistry.DelegationType.ERC20, msg.sender, contract_, tokenId, balance, data);
        emit IDelegateRegistry.DelegateForERC1155(msg.sender, delegate, contract_, tokenId, balance, value, data);
    }

    /// @dev Helper function to set all delegation values and enumeration sets
    function _setDelegationValues(
        address delegate,
        bytes32 delegationHash,
        bool value,
        IDelegateRegistry.DelegationType type_,
        address vault,
        address contract_,
        uint256 tokenId,
        uint256 balance,
        bytes32 data
    ) internal {
        if (value) {
            vaultDelegationHashes[vault].add(delegationHash);
            delegateDelegationHashes[delegate].add(delegationHash);
            delegationInfo[delegationHash] =
                DelegationInfo({vault: vault, delegate: delegate, type_: type_, contract_: contract_, tokenId: tokenId, balance: balance, data: data});
        } else {
            vaultDelegationHashes[vault].remove(delegationHash);
            delegateDelegationHashes[delegate].remove(delegationHash);
            delete delegationInfo[delegationHash];
        }
    }

    /// @dev Helper function to compute delegation hash for wallet delegation
    function _computeDelegationHashForAll(address vault, address delegate, bytes32 data) internal pure returns (bytes32) {
        return keccak256(abi.encode(delegate, vault, data));
    }

    /// @dev Helper function to compute delegation hash for contract delegation
    function _computeDelegationHashForContract(address vault, address delegate, address contract_, bytes32 data) internal pure returns (bytes32) {
        return keccak256(abi.encode(delegate, vault, contract_, data));
    }

    /// @dev Helper function to compute delegation hash for token delegation
    function _computeDelegationHashForERC721(address vault, address delegate, address contract_, uint256 tokenId, bytes32 data)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(delegate, vault, contract_, tokenId, data));
    }

    /**
     * @dev Helper function to compute delegation hash for balance delegation
     * @dev balance for erc20 encoded with tokenId 0, collision with tokenId 0 shouldn't be meaningful due to contract_ encoding
     */
    function _computeDelegationHashForERC1155(address vault, address delegate, address contract_, uint256 tokenId, bytes32 data)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(delegate, vault, contract_, tokenId, 0, data));
    }

    /**
     * ----------- READ -----------
     */

    /// @inheritdoc IDelegateRegistry
    function getDelegationsForDelegate(address delegate) external view returns (IDelegateRegistry.DelegationInfo[] memory) {
        return _lookupHashes(delegateDelegationHashes[delegate]);
    }

    /// @inheritdoc IDelegateRegistry
    function getDelegationsForVault(address vault) external view returns (IDelegateRegistry.DelegationInfo[] memory) {
        return _lookupHashes(vaultDelegationHashes[vault]);
    }

    /// @dev Helper function to filter delegationHashes by validity, then convert them into an array of delegation structs
    function _lookupHashes(EnumerableSet.Bytes32Set storage delegationHashes)
        internal
        view
        returns (IDelegateRegistry.DelegationInfo[] memory validDelegations)
    {
        uint256 length = delegationHashes.length();
        validDelegations = new IDelegateRegistry.DelegationInfo[](length);
        for (uint256 i = 0; i < length; ++i) {
            validDelegations[i] = delegationInfo[delegationHashes.at(i)];
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForAll(address delegate, address vault, bytes32 data) public view override returns (bool) {
        return vaultDelegationHashes[vault].contains(_computeDelegationHashForAll(vault, delegate, data));
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForContract(address delegate, address vault, address contract_, bytes32 data) public view override returns (bool) {
        return vaultDelegationHashes[vault].contains(_computeDelegationHashForContract(vault, delegate, contract_, data))
            ? true
            : checkDelegateForAll(delegate, vault, data);
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC721(address delegate, address vault, address contract_, uint256 tokenId, bytes32 data) public view override returns (bool) {
        return vaultDelegationHashes[vault].contains(_computeDelegationHashForERC721(vault, delegate, contract_, tokenId, data))
            ? true
            : checkDelegateForContract(delegate, vault, contract_, data);
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC20(address delegate, address vault, address contract_, bytes32 data) external view override returns (uint256) {
        // TODO (mireynolds): should this have a balance within the function params for simplest checking?
        // TODO (mireynolds): should this have its own compute method instead of piggybacking on ERC1155?
        bytes32 delegationHash = _computeDelegationHashForERC1155(vault, delegate, contract_, 0, data);
        return vaultDelegationHashes[vault].contains(delegationHash)
            ? delegationInfo[delegationHash].balance
            : (checkDelegateForContract(delegate, vault, contract_, data) ? type(uint256).max : 0);
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC1155(address delegate, address vault, address contract_, uint256 tokenId, bytes32 data)
        external
        view
        override
        returns (uint256)
    {
        bytes32 delegationHash = _computeDelegationHashForERC1155(vault, delegate, contract_, tokenId, data);
        // TODO (mireynolds): Why are we falling back to 721 checks instead of to contract checks?
        return vaultDelegationHashes[vault].contains(delegationHash)
            ? delegationInfo[delegationHash].balance
            : (checkDelegateForContract(delegate, vault, contract_, data) ? type(uint256).max : 0);
    }
}
