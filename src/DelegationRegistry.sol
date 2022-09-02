// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IDelegationRegistry} from "./IDelegationRegistry.sol";

/** 
* @title An immutable registry contract to be deployed as a standalone primitive
* @dev New project launches can read previous cold wallet -> hot wallet delegations from here and integrate those permissions into their flow
* contributors: foobar (0xfoobar), punk6529 (open metaverse), loopify (loopiverse), andy8052 (fractional), purplehat (artblocks), emiliano (nftrentals),
*               arran (proof), james (collabland), john (gnosis safe), wwhchung (manifoldxyz) tally labs and many more
*/

contract DelegationRegistry is IDelegationRegistry, ERC165 {

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @notice The global mapping and single source of truth for delegations
    mapping(bytes32 => bool) private delegations;

    /// @notice A mapping of wallets to versions (for cheap revocation)
    mapping(address => uint256) private vaultVersion;

    /// @notice A mapping of wallets to delegates to versions (for cheap revocation)
    mapping(address => mapping(address => uint256)) private delegateVersion;

    /// @notice A secondary mapping to return onchain enumerability of wallet-level delegations
    /// @notice vault -> vaultVersion -> delegates
    mapping(address => mapping (uint256 => EnumerableSet.AddressSet)) private delegationsForAll;

    /// @notice A secondary mapping to return onchain enumerability of contract-level delegations
    /// @notice vault -> vaultVersion -> contract -> delegates
    mapping(address => mapping (uint256 => mapping(address => EnumerableSet.AddressSet))) private delegationsForContract;

    /// @notice A secondary mapping to return onchain enumerability of token-level delegations
    /// @notice vault -> vaultVersion -> contract -> tokenId -> delegates
    mapping(address => mapping (uint256 => mapping(address => mapping(uint256 => EnumerableSet.AddressSet)))) internal delegationsForToken;

    /// @notice A secondary mapping to return onchain enumerability of delegations that a given address can perform
    /// @notice delegate -> delegationHashes
    mapping(address => EnumerableSet.Bytes32Set) internal delegationHashes;

    /// @notice A secondary mapping used to return delegation information about a delegation
    /// @notice delegationHash -> DelegateInfo
    mapping(bytes32 => IDelegationRegistry.DelegationInfo) internal delegationInfo;

    /** 
    * See {IERC165-supportsInterface}.
    */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return interfaceId == type(IDelegationRegistry).interfaceId || super.supportsInterface(interfaceId);
    }

    /** -----------  WRITE ----------- */

    /** 
    * See {IDelegationRegistry-delegateForAll}.
    */
    function delegateForAll(address delegate, bool value) external override {
        uint256 vaultVersion_ = vaultVersion[msg.sender];
        uint256 delegateVersion_ = delegateVersion[msg.sender][delegate];
        bytes32 delegateHash = keccak256(abi.encode(delegate, msg.sender, vaultVersion_, delegateVersion_));
        _setDelegationValues(delegate, delegateHash, value, IDelegationRegistry.DelegationType.ALL, msg.sender, address(0), 0);
        _setDelegationEnumeration(delegationsForAll[msg.sender][vaultVersion_], delegate, value);
        emit IDelegationRegistry.DelegateForAll(msg.sender, delegate, value);
    }

    /** 
    * See {IDelegationRegistry-delegateForContract}.
    */
    function delegateForContract(address delegate, address contract_, bool value) external override {
        uint256 vaultVersion_ = vaultVersion[msg.sender];
        uint256 delegateVersion_ = delegateVersion[msg.sender][delegate];
        bytes32 delegateHash = keccak256(abi.encode(delegate, msg.sender, contract_, vaultVersion_, delegateVersion_));
        _setDelegationValues(delegate, delegateHash, value, IDelegationRegistry.DelegationType.CONTRACT, msg.sender, contract_, 0);
        _setDelegationEnumeration(delegationsForContract[msg.sender][vaultVersion_][contract_], delegate, value);
        emit IDelegationRegistry.DelegateForContract(msg.sender, delegate, contract_, value);
    }

    /** 
    * See {IDelegationRegistry-delegateForToken}.
    */
    function delegateForToken(address delegate, address contract_, uint256 tokenId, bool value) external override {
        uint256 vaultVersion_ = vaultVersion[msg.sender];
        uint256 delegateVersion_ = delegateVersion[msg.sender][delegate];
        bytes32 delegateHash = keccak256(abi.encode(delegate, msg.sender, contract_, tokenId, vaultVersion_, delegateVersion_));
        _setDelegationValues(delegate, delegateHash, value, IDelegationRegistry.DelegationType.TOKEN, msg.sender, contract_, tokenId);
        _setDelegationEnumeration(delegationsForToken[msg.sender][vaultVersion_][contract_][tokenId], delegate, value);
        emit IDelegationRegistry.DelegateForToken(msg.sender, delegate, contract_, tokenId, value);
    }

    function _setDelegationValues(address delegate, bytes32 delegateHash, bool value, IDelegationRegistry.DelegationType type_, address vault, address contract_, uint256 tokenId) internal {
        delegations[delegateHash] = value;
        if (value) {
            delegationHashes[delegate].add(delegateHash);
            delegationInfo[delegateHash] = DelegationInfo({
                vault: vault,
                type_: type_,
                contract_: contract_,
                tokenId: tokenId
            });
        } else {
            delegationHashes[delegate].remove(delegateHash);
            delete delegationInfo[delegateHash];
        }
    }

    function _setDelegationEnumeration(EnumerableSet.AddressSet storage set, address delegate, bool value) internal {
        if (value) {
            set.add(delegate);
        } else {
            set.remove(delegate);
        }
    }

    /**
    * See {IDelegationRegistry-revokeAllDelegates}.
    */
    function revokeAllDelegates() external override {
        vaultVersion[msg.sender]++;
        emit IDelegationRegistry.RevokeAllDelegates(msg.sender);
    }

    /**
    * See {IDelegationRegistry-revokeDelegate}.
    */
    function revokeDelegate(address delegate) external override {
        _revokeDelegate(delegate, msg.sender);
    }

    /**
    * See {IDelegationRegistry-revokeSelf}.
    */
    function revokeSelf(address vault) external override {
        _revokeDelegate(msg.sender, vault);
    }

    function _revokeDelegate(address delegate, address vault) internal {
        delegateVersion[vault][delegate]++;
        // Remove delegate from enumerations
        delegationsForAll[vault][vaultVersion[vault]].remove(delegate);
        // For delegationsForContract and delegationsForToken, filter in the view
        // functions
        emit IDelegationRegistry.RevokeDelegate(vault, msg.sender);
    }

    /** -----------  READ ----------- */

    /**
     * See {IDelegationRegistry-getDelegations}.
     */
    function getDelegationsForDelegate(address delegate) external view returns (IDelegationRegistry.DelegationInfo[] memory info) {
        EnumerableSet.Bytes32Set storage potentialDelegationHashes = delegationHashes[delegate];
        uint256 potentialDelegationHashesLength = potentialDelegationHashes.length();
        uint256 delegationCount = 0;
        info = new IDelegationRegistry.DelegationInfo[](potentialDelegationHashesLength);
        for (uint256 i = 0; i < potentialDelegationHashesLength;) {
            bytes32 delegateHash = potentialDelegationHashes.at(i);
            IDelegationRegistry.DelegationInfo memory delegationInfo_ = delegationInfo[delegateHash];
            address vault = delegationInfo_.vault;
            IDelegationRegistry.DelegationType type_ = delegationInfo_.type_;
            uint256 vaultVersion_ = vaultVersion[vault];
            uint256 delegateVersion_ = delegateVersion[vault][delegate];
            bool valid = false;
            if (type_ == IDelegationRegistry.DelegationType.ALL) {
                if (delegateHash == keccak256(abi.encode(delegate, vault, vaultVersion_, delegateVersion_))) {
                    valid = true;
                }
            } else if (type_ == IDelegationRegistry.DelegationType.CONTRACT) {
                if (delegateHash == keccak256(abi.encode(delegate, vault, delegationInfo_.contract_, vaultVersion_, delegateVersion_))) {
                    valid = true;
                }
            } else if (type_ == IDelegationRegistry.DelegationType.TOKEN) {
                if (delegateHash == keccak256(abi.encode(delegate, vault, delegationInfo_.contract_, delegationInfo_.tokenId, vaultVersion_, delegateVersion_))) {
                    valid = true;
                }
            }
            if (valid) {
                info[delegationCount] = delegationInfo_;
                delegationCount++;
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
    * See {IDelegationRegistry-getDelegationsForAll}.
    */
    function getDelegationsForAll(address vault) external view returns (address[] memory) {
        return delegationsForAll[vault][vaultVersion[vault]].values();
    }

    /**
    * See {IDelegationRegistry-getDelegationsForContract}.
    */
    function getDelegationsForContract(address vault, address contract_) external view override returns (address[] memory delegates) {
        EnumerableSet.AddressSet storage potentialDelegates = delegationsForContract[vault][vaultVersion[vault]][contract_];
        uint256 potentialDelegatesLength = potentialDelegates.length();
        uint256 delegateCount = 0;
        delegates = new address[](potentialDelegatesLength);
        for (uint256 i = 0; i < potentialDelegatesLength;) {
            if (checkDelegateForContract(potentialDelegates.at(i), vault, contract_)) {
                delegates[delegateCount] = potentialDelegates.at(i);
                delegateCount++;
            }
            unchecked {
                ++i;
            }
        }
        if (potentialDelegatesLength > delegateCount) {
            assembly { 
                let decrease := sub(potentialDelegatesLength, delegateCount)
                mstore(delegates, sub(mload(delegates), decrease))
            }
        }
    }

    /**
    * See {IDelegationRegistry-getDelegationsForToken}.
    */
    function getDelegationsForToken(address vault, address contract_, uint256 tokenId) external view override returns (address[] memory delegates) {
        // Since we cannot easily invalidate delegates on the enumeration (see revokeDelegates)
        // we will need to filter out invalid entries
        EnumerableSet.AddressSet storage potentialDelegates = delegationsForToken[vault][vaultVersion[vault]][contract_][tokenId];
        uint256 potentialDelegatesLength = potentialDelegates.length();
        uint256 delegateCount = 0;
        delegates = new address[](potentialDelegatesLength);
        for (uint256 i = 0; i < potentialDelegatesLength;) {
            if (checkDelegateForToken(potentialDelegates.at(i), vault, contract_, tokenId)) {
                delegates[delegateCount] = potentialDelegates.at(i);
                delegateCount++;
            }
            unchecked {
                ++i;
            }
        }
        if (potentialDelegatesLength > delegateCount) {
            assembly { 
                let decrease := sub(potentialDelegatesLength, delegateCount)
                mstore(delegates, sub(mload(delegates), decrease))
            }
        }
    }

    /** 
    * See {IDelegationRegistry-checkDelegateForAll}.
    */
    function checkDelegateForAll(address delegate, address vault) public view override returns (bool) {
        bytes32 delegateHash = keccak256(abi.encode(delegate, vault, vaultVersion[vault], delegateVersion[vault][delegate]));
        return delegations[delegateHash];
    }

    /** 
    * See {IDelegationRegistry-checkDelegateForAll}.
    */ 
    function checkDelegateForContract(address delegate, address vault, address contract_) public view override returns (bool) {
        bytes32 delegateHash = keccak256(abi.encode(delegate, vault, contract_, vaultVersion[vault], delegateVersion[vault][delegate]));
        return delegations[delegateHash] ? true : checkDelegateForAll(delegate, vault);
    }
    
    /** 
    * See {IDelegationRegistry-checkDelegateForToken}.
    */
    function checkDelegateForToken(address delegate, address vault, address contract_, uint256 tokenId) public view override returns (bool) {
        bytes32 delegateHash = keccak256(abi.encode(delegate, vault, contract_, tokenId, vaultVersion[vault], delegateVersion[vault][delegate]));
        return delegations[delegateHash] ? true : checkDelegateForContract(delegate, vault, contract_);
    }
}
