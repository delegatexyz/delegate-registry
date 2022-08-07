// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

/**

Opinionated:
- fully onchain, no EIP712 signatures
- fully immutable, no admin powers
- fully standalone, no external dependencies
- fully identifiable, clear method names
- reusable global registry w/ same address across multiple EVM chains

Why?
Onchain is critical for smart contract composability that can't produce a signature.
Immutable is critical for any public good that will stand the test of time.
Standalone is critical for ensuring the guarantees will stay valid.
Identifiable is critical to avoid phishing scams when people are using vaults to interact with the registry.
Reusable is critical so new projects can bootstrap off existing network effects.

Use an ERC-165-esque hash list for specific permissions. Start out with claim permissions but can expand to more later.

TODO: can we get onchain enumeration?
TODO: can we get all-at-once revocation?
TODO: can we get timelocked delegation for selling off airdrop rights?
TODO: does the ens fuse wrapper match what we're doing here?

*/


contract DelegationRegistry {

    mapping(bytes32 => address) delegations;

    event DelegateForAll(address _vault, address _delegate, bytes32 _role);
    event DelegateForCollection(address _vault, address _delegate, bytes32 _role, address _collection);
    event DelegateForToken(address _vault, address _delegate, bytes32 _role, address _collection, uint256 _tokenId);
    event DelegateFor(address _vault, address _delegate, bytes32 _role, bytes32 _data);
    event DelegateRevoked(address _vault, address _delegate, bytes32 _role);

    ///////////
    // WRITE //
    ///////////

    /// @notice Allow the delegate to act on your behalf for all NFT collections
    function delegateForAll(address _delegate, bytes32 _role) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, msg.sender));
        delegations[delegateHash] = _delegate;
        emit DelegateForAll(msg.sender, _delegate, _role);
    }

    /// @notice Allow the delegate to act on your behalf for a specific NFT collection
    function delegateForCollection(address _delegate, bytes32 _role, address _collection) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, msg.sender, _collection));
        delegations[delegateHash] = _delegate;
        emit DelegateForCollection(msg.sender, _delegate, _role, _collection);
    }

    /// @notice Allow the delegate to act on your behalf for a specific token, supports 721 and 1155
    function delegateForToken(address _delegate, bytes32 _role, address _collection, uint256 _tokenId) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, msg.sender, _collection, _tokenId));
        delegations[delegateHash] = _delegate;
        emit DelegateForToken(msg.sender, _delegate, _role, _collection, _tokenId);
    }

    /// @notice A delegation generalization where the vault can pass arbitrary data to be interpreted
    function delegateFor(address _delegate, bytes32 _role, bytes32 _data) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, msg.sender, _data));
        delegations[delegateHash] = _delegate;
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
    function getDelegateForAll(bytes32 _role, address _vault) public view returns (address) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, _vault));
        return delegations[delegateHash];
    }

    /// @notice Returns the address delegated to act on your behalf for an NFT collection
    function getDelegateForCollection(bytes32 _role, address _vault, address _collection) public view returns (address) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, _vault, _collection));
        address delegate = delegations[delegateHash];
        return delegate != address(0x0) ? delegate : getDelegateForAll(_role, _vault);
    }
    
    /// @notice Returns the address delegated to act on your behalf for an specific NFT
    function getDelegateForToken(bytes32 _role, address _vault, address _collection, uint256 _tokenId) public view returns (address) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, _vault, _collection, _tokenId));
        address delegate = delegations[delegateHash];
        return delegate != address(0x0) ? delegate : getDelegateForCollection(_role, _vault, _collection);
    }

    /// @notice Returns the address delegated to act on your behalf for arbitrary data
    function getDelegateFor(bytes32 _role, address _vault, bytes32 _data) public view returns (address) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_role, _vault, _data));
        address delegate = delegations[delegateHash];
        return delegate;
    }
}
