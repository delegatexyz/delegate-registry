// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IDelegationRegistry} from "./IDelegationRegistry.sol";

/** 
* @title An immutable registry contract to be deployed as a standalone primitive
* @dev New project launches can read previous cold wallet -> hot wallet delegations from here and integrate those permissions into their flow
* contributors: foobar (0xfoobar), punk6529 (open metaverse), loopify (loopiverse), andy8052 (fractional), purplehat (artblocks), emiliano (nftrentals),
*               arran (proof), james (collabland), john (gnosis safe), wwhchung (manifoldxyz), rusowsky (0xrusowsky), tally labs and many more
*/

contract DelegationRegistry is IDelegationRegistry, ERC165 {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The global mapping and single source of truth for delegations
    mapping(bytes32 => uint256) private delegations;

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
    function delegateForAll(address delegate, uint256 expiry) external override {
        require(block.timestamp < expiry || expiry == 0, "INVALID_EXPIRY");
        bytes32 delegateHash = keccak256(abi.encode(delegate, msg.sender, vaultVersion[msg.sender], delegateVersion[msg.sender][delegate]));
        delegations[delegateHash] = expiry;
        _setDelegationEnumeration(delegationsForAll[msg.sender][vaultVersion[msg.sender]], delegate, expiry);
        emit IDelegationRegistry.DelegateForAll(msg.sender, delegate, expiry);
    }

    /** 
    * See {IDelegationRegistry-delegateForContract}.
    */
    function delegateForContract(address delegate, address contract_, uint256 expiry) external override {
        require(block.timestamp < expiry || expiry == 0, "INVALID_EXPIRY");
        bytes32 delegateHash = keccak256(abi.encode(delegate, msg.sender, contract_, vaultVersion[msg.sender], delegateVersion[msg.sender][delegate]));
        delegations[delegateHash] = expiry;
        _setDelegationEnumeration(delegationsForContract[msg.sender][vaultVersion[msg.sender]][contract_], delegate, expiry);
        emit IDelegationRegistry.DelegateForContract(msg.sender, delegate, contract_, expiry);
    }

    /** 
    * See {IDelegationRegistry-delegateForToken}.
    */
    function delegateForToken(address delegate, address contract_, uint256 tokenId, uint256 expiry) external override {
        require(block.timestamp < expiry || expiry == 0, "INVALID_EXPIRY");
        bytes32 delegateHash = keccak256(abi.encode(delegate, msg.sender, contract_, tokenId, vaultVersion[msg.sender], delegateVersion[msg.sender][delegate]));
        delegations[delegateHash] = expiry;
        _setDelegationEnumeration(delegationsForToken[msg.sender][vaultVersion[msg.sender]][contract_][tokenId], delegate, expiry);
        emit IDelegationRegistry.DelegateForToken(msg.sender, delegate, contract_, tokenId, expiry);
    }

    function _setDelegationEnumeration(EnumerableSet.AddressSet storage set, address key, uint256 expiry) internal {
        if (expiry != 0) {
            set.add(key);
        } else {
            set.remove(key);
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
    * See {IDelegationRegistry-getDelegationsForAll}.
    */
    function getDelegationsForAll(address vault) external view returns (address[] memory delegates) {
        EnumerableSet.AddressSet storage potentialDelegates = delegationsForAll[vault][vaultVersion[vault]];
        uint256 potentialDelegatesLength = potentialDelegates.length();
        uint256 delegateCount = 0;
        delegates = new address[](potentialDelegatesLength);
        for (uint256 i = 0; i < potentialDelegatesLength;) {
            if (checkDelegateForAll(potentialDelegates.at(i), vault)) {
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
        return delegations[delegateHash] > block.timestamp ? true : false;
    }

    /** 
    * See {IDelegationRegistry-checkDelegateForAll}.
    */ 
    function checkDelegateForContract(address delegate, address vault, address contract_) public view override returns (bool) {
        bytes32 delegateHash = keccak256(abi.encode(delegate, vault, contract_, vaultVersion[vault], delegateVersion[vault][delegate]));
        return delegations[delegateHash] > block.timestamp ? true : checkDelegateForAll(delegate, vault);
    }
    
    /** 
    * See {IDelegationRegistry-checkDelegateForToken}.
    */
    function checkDelegateForToken(address delegate, address vault, address contract_, uint256 tokenId) public view override returns (bool) {
        bytes32 delegateHash = keccak256(abi.encode(delegate, vault, contract_, tokenId, vaultVersion[vault], delegateVersion[vault][delegate]));
        return delegations[delegateHash] > block.timestamp ? true : checkDelegateForContract(delegate, vault, contract_);
    }
}