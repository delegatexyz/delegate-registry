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
 * TODO:
 * - let people delegate specific amounts that snapshot can mark as used
 * - arbitrary data attached to the delegation, for licensing and governance/yield splitting
 * - add native ERC1155 support, splitting
 * - add native ERC20 support, splitting
 * - how to support fungible token governance? split up assets
 * - identity clusters require that one vault only points to one delegate, not many
 * - hard to check validity of a delegation in one go
 * STRETCH
 * - zk attestations
 * - account abstraction
 * - multicall instead of batchDelegate
 */

/**
 * For NFTs, we did a specific separate method that specifies a tokenId. And then the app can mark that one as "used" when they claim utility.
 * How does Snapshot distinguish amounts that have been voted? Either a snapshot or a lockup. For a lockup you would need to mark certain tokens as used.
 * How would you split something in half? Could run a percentage basis. But then the amounts can change.
 * 
 *  More broadly speaking, snapshot requires a snapshot in time. Sudo did a lockdrop. 
 * 
 * For arbitrary data, do we want it to be machine-readable? for staking usecases, yes. so strings won't work. But we also want strings for licensing usecases
 *  
 *  You could snapshot user balances and then decrement it as delegations get used piecemeal. 
 *  The ERC20 usecase is actually identical to ERC721 if you take a snapshot approach, just decrement balances once used
 *  Delegate *amounts* for ERC20/ERC1155
 *  Another adjustment is that ERC721s are FCFS, while snapshots let you change your vote. if both holder & delegate vote then delegate overridden
 *  this is only possible bc there's no tradeable result while voting is happening, unlike NFT mint
 *  escrow could guarantee you play by the rules
 *  We just need a "balance" parameter. How to make it work for 721s, 20s, and 1155s?
 * 
 *  Ontology is more important than implementation details right now. Don't wory about how to revoke. 
 *  There are tiers like identity/wallet/contract/token
 *  But also overlapping attributes. Balance can apply to contract + token. And we want to apply arbitrary data to each
 *  And identity is a way of restricting one-to-one, while subdelegations are a way of splitting up one delegation into many parts
 *  Maybe we bitmask to apply balances?
 * 
 * Need a generalizable data schema. Study the history of past successes. Not sure where to start. 
 * Add an "exclusive" bool parameter to delegations, if true then pushes out the rest.
 * subdelegations would also want an exclusivity parameter
 * Is one-to-many that useful?
 * 
 * There should be a data field attached to each delegation. That means there can be two delegations with same params but diff data, must return both.
 *  Maybe we just hardcode ERC20, ERC721, ERC1155 usecases. There aren't that many standards. delegateForERC20, delegateForERC721, delegateForERC1155
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

    /// @dev A secondary mapping to enumerate a delegate's incoming delegations, should be filtered for validity via vaultDelegationHashes
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

    /**
     * @inheritdoc IDelegationRegistry
     */
    function batchDelegate(IDelegationRegistry.DelegationInfo[] calldata details, bool[] calldata values)
        external
        override
    {
        uint256 detailsLength = details.length;
        for (uint256 i = 0; i < detailsLength; ++i) {
            IDelegationRegistry.DelegationInfo memory info = details[i];
            if (info.type_ == IDelegationRegistry.DelegationType.ALL) {
                delegateForAll(info.delegate, values[i]);
            } else if (info.type_ == IDelegationRegistry.DelegationType.CONTRACT) {
                delegateForContract(info.delegate, info.contract_, values[i]);
            } else if (info.type_ == IDelegationRegistry.DelegationType.TOKEN) {
                delegateForToken(info.delegate, info.contract_, info.tokenId, values[i]);
            }
        }
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function delegateForAll(address delegate, bool value) public override {
        bytes32 delegationHash = _computeDelegationHashForAll(msg.sender, delegate);
        _setDelegationValues(
            delegate, delegationHash, value, IDelegationRegistry.DelegationType.ALL, msg.sender, address(0), 0
        );
        emit IDelegationRegistry.DelegateForAll(msg.sender, delegate, value);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function delegateForContract(address delegate, address contract_, bool value) public override {
        bytes32 delegationHash = _computeDelegationHashForContract(msg.sender, delegate, contract_);
        _setDelegationValues(
            delegate, delegationHash, value, IDelegationRegistry.DelegationType.CONTRACT, msg.sender, contract_, 0
        );
        emit IDelegationRegistry.DelegateForContract(msg.sender, delegate, contract_, value);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function delegateForToken(address delegate, address contract_, uint256 tokenId, bool value) public override {
        bytes32 delegationHash = _computeDelegationHashForToken(msg.sender, delegate, contract_, tokenId);
        _setDelegationValues(
            delegate, delegationHash, value, IDelegationRegistry.DelegationType.TOKEN, msg.sender, contract_, tokenId
        );
        emit IDelegationRegistry.DelegateForToken(msg.sender, delegate, contract_, tokenId, value);
    }

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
        uint256 tokenId
    ) internal {
        if (value) {
            vaultDelegationHashes[vault].add(delegationHash);
            delegateDelegationHashes[delegate].add(delegationHash);
            delegationInfo[delegationHash] =
                DelegationInfo({vault: vault, delegate: delegate, type_: type_, contract_: contract_, tokenId: tokenId});
        } else {
            vaultDelegationHashes[vault].remove(delegationHash);
            delegateDelegationHashes[delegate].remove(delegationHash);
            delete delegationInfo[delegationHash];
        }
    }

    /**
     * @dev Helper function to compute delegation hash for wallet delegation
     */
    function _computeDelegationHashForAll(address vault, address delegate) internal view returns (bytes32) {
        return keccak256(abi.encode(delegate, vault));
    }

    /**
     * @dev Helper function to compute delegation hash for contract delegation
     */
    function _computeDelegationHashForContract(address vault, address delegate, address contract_)
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(delegate, vault, contract_));
    }

    /**
     * @dev Helper function to compute delegation hash for token delegation
     */
    function _computeDelegationHashForToken(address vault, address delegate, address contract_, uint256 tokenId)
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(delegate, vault, contract_, tokenId));
    }

    /**
     * ----------- READ -----------
     */

    /**
     * @inheritdoc IDelegationRegistry
     */
    function getDelegationsForDelegate(address delegate)
        external
        view
        returns (IDelegationRegistry.DelegationInfo[] memory)
    {
        return _filterHashes(delegateDelegationHashes[delegate]);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function getDelegationsForVault(address vault)
        external
        view
        returns (IDelegationRegistry.DelegationInfo[] memory)
    {
        return _filterHashes(vaultDelegationHashes[vault]);
    }

    function _filterHashes(EnumerableSet.Bytes32Set storage potentialDelegationHashes)
        internal
        view
        returns (IDelegationRegistry.DelegationInfo[] memory validDelegations)
    {
        uint256 potentialDelegationHashesLength = potentialDelegationHashes.length();
        uint256 delegationCount = 0;
        validDelegations = new IDelegationRegistry.DelegationInfo[](potentialDelegationHashesLength);
        for (uint256 i = 0; i < potentialDelegationHashesLength; ++i) {
            bytes32 delegationHash = potentialDelegationHashes.at(i);
            IDelegationRegistry.DelegationInfo memory delegationInfo_ = delegationInfo[delegationHash];
            address vault = delegationInfo_.vault;
            address delegate = delegationInfo_.delegate;
            IDelegationRegistry.DelegationType type_ = delegationInfo_.type_;
            if (type_ == IDelegationRegistry.DelegationType.ALL) {
                if (delegationHash == _computeDelegationHashForAll(vault, delegate)) {
                    validDelegations[delegationCount++] = delegationInfo_;
                }
            } else if (type_ == IDelegationRegistry.DelegationType.CONTRACT) {
                if (delegationHash == _computeDelegationHashForContract(vault, delegate, delegationInfo_.contract_)) {
                    validDelegations[delegationCount++] = delegationInfo_;
                }
            } else if (type_ == IDelegationRegistry.DelegationType.TOKEN) {
                if (
                    delegationHash
                        == _computeDelegationHashForToken(
                            vault, delegate, delegationInfo_.contract_, delegationInfo_.tokenId
                        )
                ) {
                    validDelegations[delegationCount++] = delegationInfo_;
                }
            }
        }
        if (potentialDelegationHashesLength > delegationCount) {
            assembly {
                let decrease := sub(potentialDelegationHashesLength, delegationCount)
                mstore(validDelegations, sub(mload(validDelegations), decrease))
            }
        }
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function checkDelegateForAll(address delegate, address vault) public view override returns (bool) {
        bytes32 delegationHash = keccak256(abi.encode(delegate, vault));
        return vaultDelegationHashes[vault].contains(delegationHash);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function checkDelegateForContract(address delegate, address vault, address contract_)
        public
        view
        override
        returns (bool)
    {
        bytes32 delegationHash = keccak256(abi.encode(delegate, vault, contract_));
        return vaultDelegationHashes[vault].contains(delegationHash)
            ? true
            : checkDelegateForAll(delegate, vault);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function checkDelegateForToken(address delegate, address vault, address contract_, uint256 tokenId)
        external
        view
        override
        returns (bool)
    {
        bytes32 delegationHash = keccak256(abi.encode(delegate, vault, contract_, tokenId));
        return vaultDelegationHashes[vault].contains(delegationHash)
            ? true
            : checkDelegateForContract(delegate, vault, contract_);
    }
}
