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

*/


contract DelegationRegistry {

    mapping(address => address) internal delegationsForAll;
    mapping(bytes32 => address) internal delegationsForCollection;
    mapping(bytes32 => address) internal delegationsForToken;

    function delegateForAll(address _delegate) external {
        delegationsForAll[msg.sender] = _delegate;
    }

    function delegateForCollection(address _delegate, address _collection) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(msg.sender, _collection));
        delegationsForCollection[delegateHash] = _delegate;
    }

    function delegateForToken(address _delegate, address _collection, uint256 _tokenId) external {
        bytes32 delegateHash = keccak256(abi.encodePacked(msg.sender, _collection, _tokenId));
        delegationsForToken[delegateHash] = _delegate;
    }

    function getDelegateForAll(address _vault) public view returns (address) {
        return delegationsForAll[_vault];
    }

    function getDelegateForCollection(address _vault, address _collection) public view returns (address) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_vault, _collection));
        address delegate = delegationsForCollection[delegateHash];
        return delegate != address(0x0) ? delegate : getDelegateForAll(_vault);
    }
    
    function getDelegateForToken(address _vault, address _collection, uint256 _tokenId) public view returns (address) {
        bytes32 delegateHash = keccak256(abi.encodePacked(_vault, _collection, _tokenId));
        address delegate = delegationsForToken[delegateHash];
        return delegate != address(0x0) ? delegate : getDelegateForCollection(_vault, _collection);
    }
}
