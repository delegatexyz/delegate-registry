// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/** 
* @title An immutable registry contract to be deployed as a standalone primitive
* @author foobar, wwhchung
* @dev New project launches can read previous cold wallet -> hot wallet delegations from here and integrate those permissions into their flow
*/

interface IDelegationRegistry {

    /// @notice Emitted when a user delegates their entire wallet
    event DelegateForAll(address vault, address delegate, bool value);
    
    /// @notice Emitted when a user delegates a specific contract
    event DelegateForContract(address vault, address delegate, address contract_, bool value);

    /// @notice Emitted when a user delegates a specific token
    event DelegateForToken(address vault, address delegate, address contract_, uint256 tokenId, bool value);

    /// @notice Emitted when a user revokes all delegations
    event RevokeAllDelegates(address vault);

    /// @notice Emitted when a user revoes all delegations for a given delegate
    event RevokeDelegate(address vault, address delegate);

    /** -----------  WRITE ----------- */

    /** 
    * @notice Allow the delegate to act on your behalf for all contracts
    * @param delegate The hotwallet to act on your behalf
    * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
    */
    function delegateForAll(address delegate, bool value) external;

    /** 
    * @notice Allow the delegate to act on your behalf for a specific contract
    * @param delegate The hotwallet to act on your behalf
    * @param contract_ The address for the contract you're delegating
    * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
    */
    function delegateForContract(address delegate, address contract_, bool value) external;
    /** 
    * @notice Allow the delegate to act on your behalf for a specific token, supports 721 and 1155
    * @param delegate The hotwallet to act on your behalf
    * @param contract_ The address for the contract you're delegating
    * @param tokenId The token id for the token you're delegating
    * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
    */
    function delegateForToken(address delegate, address contract_, uint256 tokenId, bool value) external;

    /**
     * @notice Revoke all delegates
     */
    function revokeAllDelegates() external;

    /**
     * @notice Revoke a specific delegate for all their permissions
     */
    function revokeDelegate(address delegate) external;

    /** -----------  READ ----------- */

    /**
    * @notice Returns an array of wallet-level delegations for a given vault
    * @param vault The cold wallet who issued the delegation
    * @return addresses Array of wallet-level delegations for a given vault
    */
    function getDelegationsForAll(address vault) external view returns (address[] memory);

    /**
    * @notice Returns an array of contract-level delegations for a given vault and contract
    * @param vault The cold wallet who issued the delegation
    * @param contract_ The address for the contract you're delegating
    * @return addresses Array of contract-level delegations for a given vault and contract
    */
    function getDelegationsForContract(address vault, address contract_) external view returns (address[] memory);

    /**
    * @notice Returns an array of contract-level delegations for a given vault's token
    * @param vault The cold wallet who issued the delegation
    * @param contract_ The address for the contract holding the token
    * @param tokenId The token id for the token you're delegating
    * @return addresses Array of contract-level delegations for a given vault's token
    */
    function getDelegationsForToken(address vault, address contract_, uint256 tokenId) external view returns (address[] memory);

    /** 
    * @notice Returns true if the address is delegated to act on your behalf for all NFTs
    * @param delegate The hotwallet to act on your behalf
    * @param vault The cold wallet who issued the delegation
    */
    function checkDelegateForAll(address delegate, address vault) external view returns (bool);

    /** 
    * @notice Returns true if the address is delegated to act on your behalf for an NFT contract
    * @param delegate The hotwallet to act on your behalf
    * @param contract_ The address for the contract you're delegating
    * @param vault The cold wallet who issued the delegation
    */ 
    function checkDelegateForContract(address delegate, address vault, address contract_) external view returns (bool);
    
    /** 
    * @notice Returns true if the address is delegated to act on your behalf for an specific NFT
    * @param delegate The hotwallet to act on your behalf
    * @param contract_ The address for the contract you're delegating
    * @param tokenId The token id for the token you're delegating
    * @param vault The cold wallet who issued the delegation
    */
    function checkDelegateForToken(address delegate, address vault, address contract_, uint256 tokenId) external view returns (bool);
}
