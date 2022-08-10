// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @notice An immutable registry contract to be deployed as a standalone primitive
/// @dev New project launches can read previous cold wallet -> hot wallet delegations from here and integrate those permissions into their flow
contract DelegationRegistry {

    /// @notice The global mapping and single source of truth for delegations
    mapping(bytes32 => bool) delegations;

    event DelegateForAll(address _vault, address _delegate, bytes32 _role);
    event DelegateForCollection(address _vault, address _delegate, bytes32 _role, address _collection);
    event DelegateForToken(address _vault, address _delegate, bytes32 _role, address _collection, uint256 _tokenId);
    event DelegateFor(address _vault, address _delegate, bytes32 _role, bytes32 _data);
    event DelegateRevoked(address _vault, address _delegate, bytes32 _role);

    ///////////
    // WRITE //
    ///////////

    /// @notice Allow the delegate to act on your behalf for all NFT collections
    function delegateForAll(address _delegate, bytes32 _role, bool _value) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(_delegate, _role, msg.sender));
        delegations[delegateHash] = _value;
        emit DelegateForAll(msg.sender, _delegate, _role);
    }

    /// @notice Allow the delegate to act on your behalf for a specific NFT collection
    function delegateForCollection(address _delegate, bytes32 _role, address _collection, bool _value) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(_delegate, _role, msg.sender, _collection));
        delegations[delegateHash] = _value;
        emit DelegateForCollection(msg.sender, _delegate, _role, _collection);
    }

    /// @notice Allow the delegate to act on your behalf for a specific token, supports 721 and 1155
    function delegateForToken(address _delegate, bytes32 _role, address _collection, uint256 _tokenId, bool _value) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(_delegate, _role, msg.sender, _collection, _tokenId));
        delegations[delegateHash] = _value;
        emit DelegateForToken(msg.sender, _delegate, _role, _collection, _tokenId);
    }

    /// @notice A delegation generalization where the vault can pass arbitrary data to be interpreted
    function delegateFor(address _delegate, bytes32 _role, bytes32 _data, bool _value) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(_delegate, _role, msg.sender, _data));
        delegations[delegateHash] = _value;
        emit DelegateFor(msg.sender, _delegate, _role, _data);
    }

    /// @notice Revoke the delegate's authority to act on your behalf for all NFT collections
    function revokeDelegationForAll(bytes32 _role) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, msg.sender));
        address delegate = delegations[delegateHash];
        delegations[delegateHash] = address(0);
        emit DelegateRevoked(msg.sender, delegate, _role);
    }

    //////////
    // READ //
    //////////

    /// @notice Returns the address delegated to act on your behalf for all NFTs
    function getDelegateForAll(bytes32 _role, address _vault) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, _vault));
        return delegations[delegateHash];
    }

    /// @notice Returns the address delegated to act on your behalf for an NFT collection
    function getDelegateForCollection(bytes32 _role, address _vault, address _collection) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, _vault, _collection));
        address delegate = delegations[delegateHash];
        return delegate != address(0x0) ? delegate : getDelegateForAll(_role, _vault);
    }
    
    /// @notice Returns the address delegated to act on your behalf for an specific NFT
    function getDelegateForToken(bytes32 _role, address _vault, address _collection, uint256 _tokenId) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, _vault, _collection, _tokenId));
        address delegate = delegations[delegateHash];
        return delegate != address(0x0) ? delegate : getDelegateForCollection(_role, _vault, _collection);
    }

    /// @notice Returns the address delegated to act on your behalf for arbitrary data
    function getDelegateFor(bytes32 _role, address _vault, bytes32 _data) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, _vault, _data));
        address delegate = delegations[delegateHash];
        return delegate;
    }

    /// @notice Returns the address delegated to act on your behalf for all NFTs
    function checkDelegateForAll(address _delegate, bytes32 _role, address _vault) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_delegate, _role, _vault));
        return delegations[delegateHash];
    }
}
