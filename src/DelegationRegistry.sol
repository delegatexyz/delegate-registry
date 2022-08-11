// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/** 
* @title An immutable registry contract to be deployed as a standalone primitive
* @author foobar
* @dev New project launches can read previous cold wallet -> hot wallet delegations from here and integrate those permissions into their flow
*/

contract DelegationRegistry {

    /** 
    * @notice The global mapping and single source of truth for delegations
    */
    mapping(bytes32 => bool) delegations;    

    /** 
    * @notice Emitted when a user delegates their entire wallet
    */
    event DelegateForAll(address vault, address delegate, bytes32 role, bool value);
    
    /** 
    * @notice Emitted when a user delegates a specific contract address
    */ 
    event DelegateForContract(address vault, address delegate, bytes32 role, address contract, bool value);

    /** 
    * @notice Emitted when a user delegates a specific token
    */
    event DelegateForToken(address vault, address delegate, bytes32 role, address contract, uint256 tokenId, bool value);

    /** -----------  WRITE ----------- */

    /** 
    * @notice Allow the delegate to act on your behalf for all NFT collections
    * @param delegate The hotwallet to act on your behalf
    * @param role The role for delegations, default is 0x0000000000000000000000000000000000000000000000000000000000000000
    * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
    */
        
    function delegateForAll(address delegate, bytes32 role, bool value) external {
        bytes32 delegateHash = keccak256(abi.encode(delegate, role, msg.sender));
        delegations[delegateHash] = value;
        emit DelegateForAll(msg.sender, delegate, role, value);
    }

    /** 
    * @notice Allow the delegate to act on your behalf for a specific NFT contract
    * @param delegate The hotwallet to act on your behalf
    * @param role The role for delegations, default is 0x0000000000000000000000000000000000000000000000000000000000000000
    * @param contract The address for the contract you're delegating
    * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
    */

    function delegateForContract(address delegate, bytes32 role, address contract, bool value) external {
        bytes32 delegateHash = keccak256(abi.encode(delegate, role, msg.sender, contract));
        delegations[delegateHash] = value;
        emit DelegateForContract(msg.sender, delegate, role, contract, value);
    }

    /** 
    * @notice Allow the delegate to act on your behalf for a specific token, supports 721 and 1155
    * @param delegate The hotwallet to act on your behalf
    * @param role The role for delegations, default is 0x0000000000000000000000000000000000000000000000000000000000000000
    * @param contract The contract address that the token you're delegating belongs to
    * @param tokenId The token id for the token you're delegating
    * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
    */    

    function delegateForToken(address delegate, bytes32 role, address contract, uint256 tokenId, bool value) external {
        bytes32 delegateHash = keccak256(abi.encode(delegate, role, msg.sender, contract, tokenId));
        delegations[delegateHash] = value;
        emit DelegateForToken(msg.sender, delegate, role, contract, tokenId, value);
    }

    /** -----------  READ ----------- */

    /** 
    * @notice Returns true if the address is delegated to act on your behalf for all NFTs
    * @param delegate The hotwallet to act on your behalf
    * @param role The role for delegations, default is 0x0000000000000000000000000000000000000000000000000000000000000000
    * @param vault The cold wallet who issued the delegation
    */

    function checkDelegateForAll(address delegate, bytes32 role, address vault) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encode(delegate, role, vault));
        return delegations[delegateHash];
    }

    /** 
    * @notice Returns true if the address is delegated to act on your behalf for an NFT contract
    * @param delegate The hotwallet to act on your behalf
    * @param role The role for delegations, default is 0x0000000000000000000000000000000000000000000000000000000000000000
    * @param contract The address for the contract you're delegating
    * @param vault The cold wallet who issued the delegation
    */
        
    function checkDelegateForContract(address delegate, bytes32 role, address vault, address contract) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encode(delegate, role, vault, contract));
        return delegations[delegateHash] ? true : checkDelegateForAll(delegate, role, vault);
    }
    
    /** 
    * @notice Returns true if the address is delegated to act on your behalf for an specific NFT
    * @param delegate The hotwallet to act on your behalf
    * @param role The role for delegations, default is 0x0000000000000000000000000000000000000000000000000000000000000000
    * @param contract The contract address that the token you're delegating belongs to
    * @param tokenId The token id for the token you're delegating
    * @param vault The cold wallet who issued the delegation
    */

    function checkDelegateForToken(address delegate, bytes32 role, address vault, address contract, uint256 tokenId) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encode(delegate, role, vault, contract, tokenId));
        return delegations[delegateHash] ? true : checkDelegateForContract(delegate, role, vault, contract);
    }
}
