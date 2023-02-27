// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import {IDelegationRegistry} from "./IDelegationRegistry.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

/**
 * TODO:
 * - delegation batching
 * - zk attestations
 * - remove getDelegatesForAll/Contract/Token, we need to query getDelegatesForDelegate and parse offchain
 * - have a getDelegatesByVault in addition to getDelegatesByDelegate method, cleaner offchain parsing
 * - remove getContractLevelDelegations and getTokenLevelDelegations
 * - add native ERC1155 support
 * - the interaction point is the hotwallet, not the delegate. offchain enumeration should focus on that. we can do vault forward connections on our frontend
 * - if token bubbles up, then we shouldn't expose an interface to get just contract-level delegations
 */

/**
 * @title DelegationRegistry
 * @custom:version 1.1
 * @custom:author foobar (0xfoobar)
 * @notice An immutable registry contract to be deployed as a standalone primitive.
 * @dev See EIP-5639, new project launches can read previous cold wallet -> hot wallet delegations
 * from here and integrate those permissions into their flow.
 */
contract DelegationRegistry is IDelegationRegistry, ERC165 {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @notice The global mapping and single source of truth for delegations
    mapping(address vault => mapping(uint256 version => EnumerableSet.Bytes32Set delegationHashes)) internal delegations;

    /// @notice A mapping of wallets to versions (for cheap revocation)
    mapping(address vault => uint256 version) internal vaultVersion;

    /// @notice A mapping of wallets to delegates to versions (for cheap revocation)
    mapping(address vault => mapping(address delegate => uint256 version)) internal delegateVersion;

    /// @notice A secondary mapping to return onchain enumerability of delegations that a given address can perform
    mapping(address delegate => EnumerableSet.Bytes32Set delegationHashes) internal delegationHashes;

    /// @notice A secondary mapping used to return delegation information about a delegation
    mapping(bytes32 delegationHash => IDelegationRegistry.DelegationInfo delegateInfo) internal delegationInfo;

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
    function delegateForAll(address delegate, bool value) external override {
        bytes32 delegationHash = _computeAllDelegationHash(msg.sender, delegate);
        _setDelegationValues(
            delegate, delegationHash, value, IDelegationRegistry.DelegationType.ALL, msg.sender, address(0), 0
        );
        emit IDelegationRegistry.DelegateForAll(msg.sender, delegate, value);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function delegateForContract(address delegate, address contract_, bool value) external override {
        bytes32 delegationHash = _computeContractDelegationHash(msg.sender, delegate, contract_);
        _setDelegationValues(
            delegate, delegationHash, value, IDelegationRegistry.DelegationType.CONTRACT, msg.sender, contract_, 0
        );
        emit IDelegationRegistry.DelegateForContract(msg.sender, delegate, contract_, value);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function delegateForToken(address delegate, address contract_, uint256 tokenId, bool value) external override {
        bytes32 delegationHash = _computeTokenDelegationHash(msg.sender, delegate, contract_, tokenId);
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
        bytes32 delegateHash,
        bool value,
        IDelegationRegistry.DelegationType type_,
        address vault,
        address contract_,
        uint256 tokenId
    ) internal {
        if (value) {
            delegations[vault][vaultVersion[vault]].add(delegateHash);
            delegationHashes[delegate].add(delegateHash);
            delegationInfo[delegateHash] =
                DelegationInfo({vault: vault, delegate: delegate, type_: type_, contract_: contract_, tokenId: tokenId});
        } else {
            delegations[vault][vaultVersion[vault]].remove(delegateHash);
            delegationHashes[delegate].remove(delegateHash);
            delete delegationInfo[delegateHash];
        }
    }

    /**
     * @dev Helper function to compute delegation hash for wallet delegation
     */
    function _computeAllDelegationHash(address vault, address delegate) internal view returns (bytes32) {
        uint256 vaultVersion_ = vaultVersion[vault];
        uint256 delegateVersion_ = delegateVersion[vault][delegate];
        return keccak256(abi.encode(delegate, vault, vaultVersion_, delegateVersion_));
    }

    /**
     * @dev Helper function to compute delegation hash for contract delegation
     */
    function _computeContractDelegationHash(address vault, address delegate, address contract_)
        internal
        view
        returns (bytes32)
    {
        uint256 vaultVersion_ = vaultVersion[vault];
        uint256 delegateVersion_ = delegateVersion[vault][delegate];
        return keccak256(abi.encode(delegate, vault, contract_, vaultVersion_, delegateVersion_));
    }

    /**
     * @dev Helper function to compute delegation hash for token delegation
     */
    function _computeTokenDelegationHash(address vault, address delegate, address contract_, uint256 tokenId)
        internal
        view
        returns (bytes32)
    {
        uint256 vaultVersion_ = vaultVersion[vault];
        uint256 delegateVersion_ = delegateVersion[vault][delegate];
        return keccak256(abi.encode(delegate, vault, contract_, tokenId, vaultVersion_, delegateVersion_));
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function revokeAllDelegates() external override {
        ++vaultVersion[msg.sender];
        emit IDelegationRegistry.RevokeAllDelegates(msg.sender);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function revokeDelegate(address delegate) external override {
        _revokeDelegate(delegate, msg.sender);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function revokeSelf(address vault) external override {
        _revokeDelegate(msg.sender, vault);
    }

    /**
     * @dev Revoke the `delegate` hotwallet from the `vault` coldwallet.
     */
    function _revokeDelegate(address delegate, address vault) internal {
        ++delegateVersion[vault][delegate];
        // For enumerations, filter in the view functions
        emit IDelegationRegistry.RevokeDelegate(vault, delegate);
    }

    /**
     * ----------- READ -----------
     */

    /**
     * @inheritdoc IDelegationRegistry
     */
    function getDelegationsByDelegate(address delegate)
        external
        view
        returns (IDelegationRegistry.DelegationInfo[] memory info)
    {
        EnumerableSet.Bytes32Set storage potentialDelegationHashes = delegationHashes[delegate];
        uint256 potentialDelegationHashesLength = potentialDelegationHashes.length();
        uint256 delegationCount = 0;
        info = new IDelegationRegistry.DelegationInfo[](potentialDelegationHashesLength);
        for (uint256 i = 0; i < potentialDelegationHashesLength;) {
            bytes32 delegateHash = potentialDelegationHashes.at(i);
            IDelegationRegistry.DelegationInfo memory delegationInfo_ = delegationInfo[delegateHash];
            address vault = delegationInfo_.vault;
            IDelegationRegistry.DelegationType type_ = delegationInfo_.type_;
            bool valid = false;
            if (type_ == IDelegationRegistry.DelegationType.ALL) {
                if (delegateHash == _computeAllDelegationHash(vault, delegate)) {
                    valid = true;
                }
            } else if (type_ == IDelegationRegistry.DelegationType.CONTRACT) {
                if (delegateHash == _computeContractDelegationHash(vault, delegate, delegationInfo_.contract_)) {
                    valid = true;
                }
            } else if (type_ == IDelegationRegistry.DelegationType.TOKEN) {
                if (
                    delegateHash
                        == _computeTokenDelegationHash(vault, delegate, delegationInfo_.contract_, delegationInfo_.tokenId)
                ) {
                    valid = true;
                }
            }
            if (valid) {
                info[delegationCount++] = delegationInfo_;
            }
            unchecked {
                ++i;
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
    function getDelegationsByVault(address vault)
        external
        view
        returns (IDelegationRegistry.DelegationInfo[] memory info)
    {
        EnumerableSet.Bytes32Set storage delegationHashes_ = delegations[vault][vaultVersion[vault]];
        uint256 delegatesLength = delegationHashes_.length();
        uint256 delegatesCount = 0;
        info = new IDelegationRegistry.DelegationInfo[](delegatesLength);
        for (uint256 i = 0; i < delegatesLength;) {
            info[i++] = delegationInfo[delegationHashes_.at(i)];
        }
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function checkDelegateForAll(address delegate, address vault) public view override returns (bool) {
        bytes32 delegateHash =
            keccak256(abi.encode(delegate, vault, vaultVersion[vault], delegateVersion[vault][delegate]));
        return delegations[vault][vaultVersion[vault]].contains(delegateHash);
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
        bytes32 delegateHash =
            keccak256(abi.encode(delegate, vault, contract_, vaultVersion[vault], delegateVersion[vault][delegate]));
        return
            delegations[vault][vaultVersion[vault]].contains(delegateHash) ? true : checkDelegateForAll(delegate, vault);
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
        bytes32 delegateHash = keccak256(
            abi.encode(delegate, vault, contract_, tokenId, vaultVersion[vault], delegateVersion[vault][delegate])
        );
        return delegations[vault][vaultVersion[vault]].contains(delegateHash)
            ? true
            : checkDelegateForContract(delegate, vault, contract_);
    }
}
