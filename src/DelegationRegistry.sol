// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import {IDelegationRegistry} from "./IDelegationRegistry.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
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
 * TODO:
 * - arbitrary data attached to the delegation, for licensing and governance/yield splitting
 * - delegation balance splitting for ERC20s and ERC1155s
 * - identity clusters
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
 *  Ontology is more important than implementation details right now. Don't wory about how to revoke.
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
 * @title DelegationRegistry
 * @custom:version 2.0
 * @custom:author foobar (0xfoobar)
 * @notice An immutable registry contract to be deployed as a standalone primitive.
 * @dev See EIP-5639, new project launches can read previous cold wallet -> hot wallet vaultDelegationHashes
 * from here and integrate those permissions into their flow.
 */
contract DelegationRegistry is IDelegationRegistry, ERC165 {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @dev Connects a delegationHash and its struct fields, an inverse hash function
    mapping(bytes32 delegationHash => IDelegationRegistry.DelegationInfo delegationInfo) internal delegationInfo;

    /// @dev The primary mapping to enumerate a vault's outgoing delegations, used to create and revoke individual delegations
    mapping(address vault => EnumerableSet.Bytes32Set hashes) internal vaultDelegationHashes;

    /// @dev A secondary mapping to enumerate a delegate's incoming delegations
    mapping(address delegate => EnumerableSet.Bytes32Set hashes) internal delegateDelegationHashes;

    /**
     * @inheritdoc ERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return interfaceId == type(IDelegationRegistry).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * ----------- WRITE -----------
     */

    /// @inheritdoc IDelegationRegistry
    function batchDelegate(IDelegationRegistry.DelegationInfo[] calldata details, bool[] calldata values) external override {
        uint256 detailsLength = details.length;
        for (uint256 i = 0; i < detailsLength; ++i) {
            if (details[i].type_ == IDelegationRegistry.DelegationType.ALL) {
                delegateForAll(details[i].delegate, values[i], details[i].data);
            } else if (details[i].type_ == IDelegationRegistry.DelegationType.CONTRACT) {
                delegateForContract(details[i].delegate, details[i].contract_, values[i], details[i].data);
            } else if (details[i].type_ == IDelegationRegistry.DelegationType.TOKEN) {
                delegateForToken(details[i].delegate, details[i].contract_, details[i].tokenId, values[i], details[i].data);
            }
        }
    }

    /// @inheritdoc IDelegationRegistry
    function delegateForAll(address delegate, bool value, bytes32 data) public override {
        bytes32 delegationHash = _computeDelegationHashForAll(msg.sender, delegate, data);
        _setDelegationValues(delegate, delegationHash, value, IDelegationRegistry.DelegationType.ALL, msg.sender, address(0), 0, data);
        emit IDelegationRegistry.DelegateForAll(msg.sender, delegate, value, data);
    }

    /// @inheritdoc IDelegationRegistry
    function delegateForContract(address delegate, address contract_, bool value, bytes32 data) public override {
        bytes32 delegationHash = _computeDelegationHashForContract(msg.sender, delegate, contract_, data);
        _setDelegationValues(delegate, delegationHash, value, IDelegationRegistry.DelegationType.CONTRACT, msg.sender, contract_, 0, data);
        emit IDelegationRegistry.DelegateForContract(msg.sender, delegate, contract_, value, data);
    }

    function delegateForContract2(address delegate, address contract_, uint256 tokenId, uint256 amount, bool value, bytes32 data) public {
        // what can we use for our placeholder value? 0 or max(uint256)
    }

    /// @inheritdoc IDelegationRegistry
    function delegateForToken(address delegate, address contract_, uint256 tokenId, bool value, bytes32 data) public override {
        bytes32 delegationHash = _computeDelegationHashForToken(msg.sender, delegate, contract_, tokenId, data);
        _setDelegationValues(delegate, delegationHash, value, IDelegationRegistry.DelegationType.TOKEN, msg.sender, contract_, tokenId, data);
        emit IDelegationRegistry.DelegateForToken(msg.sender, delegate, contract_, tokenId, value, data);
    }

    // /**
    //  * @notice Delegate for an ERC20
    //  */
    // function delegateForFungibleToken(address delegate, address contract_, uint256 amount, bool value, bytes32 data) public {
    //     bytes32 delegationHash = _compute
    // }

    /**
     * @dev Helper function to set all delegation values and enumeration sets
     */
    function _setDelegationValues(
        address delegate,
        bytes32 delegationHash,
        bool value,
        IDelegationRegistry.DelegationType type_,
        address vault,
        address contract_,
        uint256 tokenId,
        bytes32 data
    ) internal {
        if (value) {
            vaultDelegationHashes[vault].add(delegationHash);
            delegateDelegationHashes[delegate].add(delegationHash);
            delegationInfo[delegationHash] =
                DelegationInfo({vault: vault, delegate: delegate, type_: type_, contract_: contract_, tokenId: tokenId, data: data});
        } else {
            vaultDelegationHashes[vault].remove(delegationHash);
            delegateDelegationHashes[delegate].remove(delegationHash);
            delete delegationInfo[delegationHash];
        }
    }

    /**
     * @dev Helper function to compute delegation hash for wallet delegation
     */
    function _computeDelegationHashForAll(address vault, address delegate, bytes32 data) internal pure returns (bytes32) {
        return keccak256(abi.encode(delegate, vault, data));
    }

    /**
     * @dev Helper function to compute delegation hash for contract delegation
     */
    function _computeDelegationHashForContract(address vault, address delegate, address contract_, bytes32 data) internal pure returns (bytes32) {
        return keccak256(abi.encode(delegate, vault, contract_, data));
    }

    /**
     * @dev Helper function to compute delegation hash for token delegation
     */
    function _computeDelegationHashForToken(address vault, address delegate, address contract_, uint256 tokenId, bytes32 data)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(delegate, vault, contract_, tokenId, data));
    }

    /**
     * ----------- READ -----------
     */

    /**
     * @inheritdoc IDelegationRegistry
     */
    function getDelegationsForDelegate(address delegate) external view returns (IDelegationRegistry.DelegationInfo[] memory) {
        return _lookupHashes(delegateDelegationHashes[delegate]);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function getDelegationsForVault(address vault) external view returns (IDelegationRegistry.DelegationInfo[] memory) {
        return _lookupHashes(vaultDelegationHashes[vault]);
    }

    function _lookupHashes(EnumerableSet.Bytes32Set storage delegationHashes)
        internal
        view
        returns (IDelegationRegistry.DelegationInfo[] memory validDelegations)
    {
        uint256 length = delegationHashes.length();
        validDelegations = new IDelegationRegistry.DelegationInfo[](length);
        for (uint256 i = 0; i < length; ++i) {
            validDelegations[i] = delegationInfo[delegationHashes.at(i)];
        }
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function checkDelegateForAll(address delegate, address vault, bytes32 data) public view override returns (bool) {
        bytes32 delegationHash = keccak256(abi.encode(delegate, vault, data));
        return vaultDelegationHashes[vault].contains(delegationHash);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function checkDelegateForContract(address delegate, address vault, address contract_, bytes32 data) public view override returns (bool) {
        bytes32 delegationHash = keccak256(abi.encode(delegate, vault, contract_, data));
        return vaultDelegationHashes[vault].contains(delegationHash) ? true : checkDelegateForAll(delegate, vault, data);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function checkDelegateForToken(address delegate, address vault, address contract_, uint256 tokenId, bytes32 data) external view override returns (bool) {
        bytes32 delegationHash = keccak256(abi.encode(delegate, vault, contract_, tokenId, data));
        return vaultDelegationHashes[vault].contains(delegationHash) ? true : checkDelegateForContract(delegate, vault, contract_, data);
    }
}
