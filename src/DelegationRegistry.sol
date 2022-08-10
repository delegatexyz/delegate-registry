// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title An immutable registry contract to be deployed as a standalone primitive
/// @author foobar
/// @dev New project launches can read previous cold wallet -> hot wallet delegations from here and integrate those permissions into their flow
contract DelegationRegistry {

    /// @notice The global mapping and single source of truth for delegations
    mapping(bytes32 => bool) delegations;

    event DelegateForAll(address _vault, address _delegate, bytes32 _role, bool _value);
    event DelegateForCollection(address _vault, address _delegate, bytes32 _role, address _collection, bool _value);
    event DelegateForToken(address _vault, address _delegate, bytes32 _role, address _collection, uint256 _tokenId, bool _value);

    ///////////
    // WRITE //
    ///////////

    /// @notice Allow the delegate to act on your behalf for all NFT collections
    function delegateForAll(address _delegate, bytes32 _role, bool _value) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(_delegate, _role, msg.sender));
        delegations[delegateHash] = _value;
        emit DelegateForAll(msg.sender, _delegate, _role, _value);
    }

    /// @notice Allow the delegate to act on your behalf for a specific NFT collection
    function delegateForCollection(address _delegate, bytes32 _role, address _collection, bool _value) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(_delegate, _role, msg.sender, _collection));
        delegations[delegateHash] = _value;
        emit DelegateForCollection(msg.sender, _delegate, _role, _collection, _value);
    }

    /// @notice Allow the delegate to act on your behalf for a specific token, supports 721 and 1155
    function delegateForToken(address _delegate, bytes32 _role, address _collection, uint256 _tokenId, bool _value) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(_delegate, _role, msg.sender, _collection, _tokenId));
        delegations[delegateHash] = _value;
        emit DelegateForToken(msg.sender, _delegate, _role, _collection, _tokenId, _value);
    }

    //////////
    // READ //
    //////////

    /// @notice Returns the address delegated to act on your behalf for all NFTs
    function checkDelegateForAll(address _delegate, bytes32 _role, address _vault) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_delegate, _role, _vault));
        return delegations[delegateHash];
    }

    /// @notice Returns the address delegated to act on your behalf for an NFT collection
    function checkDelegateForCollection(address _delegate, bytes32 _role, address _vault, address _collection) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, _vault, _collection));
        return delegations[delegateHash] ? true : checkDelegateForAll(_delegate, _role, _vault);
    }
    
    /// @notice Returns the address delegated to act on your behalf for an specific NFT
    function checkDelegateForToken(address _delegate, bytes32 _role, address _vault, address _collection, uint256 _tokenId) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, _vault, _collection, _tokenId));
        return delegations[delegateHash] ? true : checkDelegateForCollection(_delegate, _role, _vault, _collection);
    }
}
