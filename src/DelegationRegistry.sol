// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import {IDelegationRegistry} from "./IDelegationRegistry.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

/**
 * DONE:
 * - batch delegation and test
 * - rename getDelegatesByDelegate method to getDelegatesForDelegate
 * - add getDelegatesForVault method
 * - remove getDelegatesForAll/Contract/Token
 * - remove getContractLevelDelegations and getTokenLevelDelegations
 * - bump compiler version and compiler runs
 * - named mappings
 * - fixed broken event param
 * - added indexing to event params
 * - clearer naming for internal mappings
 * TODO:
 * - zk attestations
 * - add native ERC1155 support, splitting
 * - add native ERC20 support, splitting
 * - rewrite tests to use new enumerations
 * - explore potential DDoS vector on delegateDelegationHashes never incrementing
 * - remove revoked delegates in getDelegationsForVault
 * - how to support fungible token governance? split up assets
 * - arbitrary data attached to the delegation, for licensing usecases
 * - segmenting rights within a token, for licensing usecases
 * - account abstraction
 */

/**
 * @title DelegationRegistry
 * @custom:version 1.1
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
    mapping(address vault => mapping(uint256 version => EnumerableSet.Bytes32Set hashes)) internal vaultDelegationHashes;

    /// @dev A secondary mapping to enumerate a delegate's incoming delegations, should be filtered for validity via vaultDelegationHashes
    mapping(address delegate => EnumerableSet.Bytes32Set hashes) internal delegateDelegationHashes;

    /// @dev Vault versions are monotonically increasing and used to revoke all delegations for a vault at once
    mapping(address vault => uint256 version) internal vaultVersion;

    /// @dev Vaults also have versions for each of their delegates and used to revoke individual delegates for a vault
    mapping(address vault => mapping(address delegate => uint256 version)) internal delegateVersion;

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
            vaultDelegationHashes[vault][vaultVersion[vault]].add(delegationHash);
            delegateDelegationHashes[delegate].add(delegationHash);
            delegationInfo[delegationHash] =
                DelegationInfo({vault: vault, delegate: delegate, type_: type_, contract_: contract_, tokenId: tokenId});
        } else {
            vaultDelegationHashes[vault][vaultVersion[vault]].remove(delegationHash);
            delegateDelegationHashes[delegate].remove(delegationHash);
            delete delegationInfo[delegationHash];
        }
    }

    /**
     * @dev Helper function to compute delegation hash for wallet delegation
     */
    function _computeDelegationHashForAll(address vault, address delegate) internal view returns (bytes32) {
        return keccak256(abi.encode(delegate, vault, vaultVersion[vault], delegateVersion[vault][delegate]));
    }

    /**
     * @dev Helper function to compute delegation hash for contract delegation
     */
    function _computeDelegationHashForContract(address vault, address delegate, address contract_)
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(delegate, vault, contract_, vaultVersion[vault], delegateVersion[vault][delegate]));
    }

    /**
     * @dev Helper function to compute delegation hash for token delegation
     */
    function _computeDelegationHashForToken(address vault, address delegate, address contract_, uint256 tokenId)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(delegate, vault, contract_, tokenId, vaultVersion[vault], delegateVersion[vault][delegate])
        );
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function revokeAllDelegates() external override {
        // Gas refund from deleting the old EnumerableSet before incrementing to the new one
        delete vaultDelegationHashes[msg.sender][vaultVersion[msg.sender]++];
        emit IDelegationRegistry.RevokeAllDelegates(msg.sender);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function revokeDelegate(address delegate) external override {
        _revokeDelegate(msg.sender, delegate);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function revokeSelf(address vault) external override {
        _revokeDelegate(vault, msg.sender);
    }

    /**
     * @dev Revoke the `delegate` hotwallet from the `vault` coldwallet.
     */
    function _revokeDelegate(address vault, address delegate) internal {
        ++delegateVersion[vault][delegate];
        emit IDelegationRegistry.RevokeDelegate(vault, delegate);
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
        returns (IDelegationRegistry.DelegationInfo[] memory info)
    {
        EnumerableSet.Bytes32Set storage potentialDelegationHashes = delegateDelegationHashes[delegate];
        uint256 potentialDelegationHashesLength = potentialDelegationHashes.length();
        uint256 delegationCount = 0;
        info = new IDelegationRegistry.DelegationInfo[](potentialDelegationHashesLength);
        for (uint256 i = 0; i < potentialDelegationHashesLength; ++i) {
            bytes32 delegationHash = potentialDelegationHashes.at(i);
            IDelegationRegistry.DelegationInfo memory delegationInfo_ = delegationInfo[delegationHash];
            address vault = delegationInfo_.vault;
            IDelegationRegistry.DelegationType type_ = delegationInfo_.type_;
            if (type_ == IDelegationRegistry.DelegationType.ALL) {
                if (delegationHash == _computeDelegationHashForAll(vault, delegate)) {
                    info[delegationCount++] = delegationInfo_;
                }
            } else if (type_ == IDelegationRegistry.DelegationType.CONTRACT) {
                if (delegationHash == _computeDelegationHashForContract(vault, delegate, delegationInfo_.contract_)) {
                    info[delegationCount++] = delegationInfo_;
                }
            } else if (type_ == IDelegationRegistry.DelegationType.TOKEN) {
                if (
                    delegationHash
                        == _computeDelegationHashForToken(
                            vault, delegate, delegationInfo_.contract_, delegationInfo_.tokenId
                        )
                ) {
                    info[delegationCount++] = delegationInfo_;
                }
            }
        }
        if (potentialDelegationHashesLength > delegationCount) {
            assembly {
                let decrease := sub(potentialDelegationHashesLength, delegationCount)
                mstore(info, sub(mload(info), decrease))
            }
        }
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function getDelegationsForVault(address vault)
        external
        view
        returns (IDelegationRegistry.DelegationInfo[] memory info)
    {
        EnumerableSet.Bytes32Set storage delegateDelegationHashes_ = vaultDelegationHashes[vault][vaultVersion[vault]];
        uint256 delegatesLength = delegateDelegationHashes_.length();
        uint256 delegatesCount = 0;
        info = new IDelegationRegistry.DelegationInfo[](delegatesLength);
        for (uint256 i = 0; i < delegatesLength;) {
            info[i++] = delegationInfo[delegateDelegationHashes_.at(i)];
        }
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function checkDelegateForAll(address delegate, address vault) public view override returns (bool) {
        bytes32 delegationHash =
            keccak256(abi.encode(delegate, vault, vaultVersion[vault], delegateVersion[vault][delegate]));
        return vaultDelegationHashes[vault][vaultVersion[vault]].contains(delegationHash);
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
        bytes32 delegationHash =
            keccak256(abi.encode(delegate, vault, contract_, vaultVersion[vault], delegateVersion[vault][delegate]));
        return vaultDelegationHashes[vault][vaultVersion[vault]].contains(delegationHash)
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
        bytes32 delegationHash = keccak256(
            abi.encode(delegate, vault, contract_, tokenId, vaultVersion[vault], delegateVersion[vault][delegate])
        );
        return vaultDelegationHashes[vault][vaultVersion[vault]].contains(delegationHash)
            ? true
            : checkDelegateForContract(delegate, vault, contract_);
    }
}
