// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/** 
* @title An immutable registry contract to be deployed as a standalone primitive
* @dev New project launches can read previous cold wallet -> hot wallet delegations from here and integrate those permissions into their flow
* contributors: foobar (0xfoobar), punk6529 (open metaverse), loopify (loopiverse), andy8052 (fractional), purplehat (artblocks), emiliano (nftrentals),
*               arran (proof), james (collabland), john (gnosis safe), wwhchung (manifoldxyz) tally labs and many more
*/

interface IDelegationRegistry {

    /// @notice Emitted when a user delegates their entire wallet
    event DelegateForAll(address vault, address delegate, uint256 expiry);
    
    /// @notice Emitted when a user delegates a specific contract
    event DelegateForContract(address vault, address delegate, address contract_, uint256 expiry);

    /// @notice Emitted when a user delegates a specific token
    event DelegateForToken(address vault, address delegate, address contract_, uint256 tokenId, uint256 expiry);

    /// @notice Emitted when a user revokes all delegations
    event RevokeAllDelegates(address vault);

    /// @notice Emitted when a user revoes all delegations for a given delegate
    event RevokeDelegate(address vault, address delegate);
    
    /// @notice Emitted when a user revokes a specific contract
    event RevokeForContract(address vault, address delegate, address contract_);

    /// @notice Emitted when a user revokes a specific token
    event RevokeForToken(address vault, address delegate, address contract_, uint256 tokenId);

    /** -----------  WRITE ----------- */

    /** 
    * @notice Allow the delegate to act on your behalf for all contracts
    * @param delegate The hotwallet to act on your behalf
    * @param expiry The expiration timestamp of this delegation
    */
    function delegateForAll(address delegate, uint256 expiry) external;

    /** 
    * @notice Allow the delegate to act on your behalf for a specific contract
    * @param delegate The hotwallet to act on your behalf
    * @param contract_ The address for the contract you're delegating
    * @param expiry The expiration timestamp of this delegation
    */
    function delegateForContract(address delegate, address contract_, uint256 expiry) external;
    /** 
    * @notice Allow the delegate to act on your behalf for a specific token, supports 721 and 1155
    * @param delegate The hotwallet to act on your behalf
    * @param contract_ The address for the contract you're delegating
    * @param tokenId The token id for the token you're delegating
    * @param expiry The expiration timestamp of this delegation
    */
    function delegateForToken(address delegate, address contract_, uint256 tokenId, uint256 expiry) external;

    /**
     * @notice Revoke all delegates
     */
    function revokeAllDelegates() external;

    /**
     * @notice Revoke a specific delegate for all their permissions.
     *         Opposite of delegateForAll(address delegate, uint256 expiry)
     */
    function revokeDelegate(address delegate) external;

    /**
     * @notice Revoke delegation for a specific vault, for all permissions
     */
    function revokeSelf(address vault) external;

    /** 
    * @notice Prevent the delegate to act on your behalf for a specific contract.
    *         Opposite of delegateForContract(address delegate, address contract_, uint256 expiry)
    * @param delegate The hotwallet that could act on your behalf
    * @param contract_ The address for the contract you're revoking
    */
    function revokeForContract(address delegate, address contract_) external;
    
    /** 
    * @notice Prevent the delegate to act on your behalf for a specific token, supports 721 and 1155
    *         Opposite of delegateForToken(address delegate, address contract_, uint256 tokenId, uint256 expiry)
    * @param delegate The hotwallet that could on your behalf
    * @param contract_ The address for the contract you're revoking
    * @param tokenId The token id for the token you're revoking
    */
    function revokeForToken(address delegate, address contract_, uint256 tokenId) external;

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
