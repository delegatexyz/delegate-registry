// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/**
 * @title An immutable registry contract to be deployed as a standalone primitive
 * @dev See EIP-5639, new project launches can read previous cold wallet -> hot wallet delegations
 * from here and integrate those permissions into their flow
 */
interface IDelegationRegistry {
    /// @notice Delegation type
    enum DelegationType {
        NONE,
        ALL,
        CONTRACT,
        ERC721,
        ERC20,
        ERC1155
    }
    // ERC20,
    // ERC721,
    // ERC1155

    /// @notice Info about a single delegation, used for onchain enumeration
    struct DelegationInfo {
        DelegationType type_;
        address vault;
        address delegate;
        address contract_;
        uint256 tokenId;
        uint256 balance;
        bytes32 data;
    }

    /// @notice Emitted when a user delegates their entire wallet
    event DelegateForAll(address indexed vault, address indexed delegate, bool value, bytes32 data);

    /// @notice Emitted when a user delegates a specific contract
    event DelegateForContract(address indexed vault, address indexed delegate, address indexed contract_, bool value, bytes32 data);

    /// @notice Emitted when a user delegates a specific token
    event DelegateForERC721(address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, bool value, bytes32 data);

    /// @notice Emitted when a user delegates a fungible balance
    event DelegateForERC20(address indexed vault, address indexed delegate, address indexed contract_, uint256 balance, bool value, bytes32 data);

    /// @notice Emitted when a user delegates a specific token with a specific balance
    event DelegateForERC1155(
        address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, uint256 balance, bool value, bytes32 data
    );

    /**
     * -----------  WRITE -----------
     */

    /**
     * @notice Batch several delegations into a single transactions
     * @param delegations An array of DelegationInfo structs
     * @param values A parallel array of booleans for whether to enable or disable the delegation
     */
    function batchDelegate(DelegationInfo[] memory delegations, bool[] memory values) external;

    /**
     * @notice Allow the delegate to act on your behalf for all contracts
     * @param delegate The hotwallet to act on your behalf
     * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForAll(address delegate, bool value, bytes32 data) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific contract
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForContract(address delegate, address contract_, bool value, bytes32 data) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific token
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param tokenId The token id for the token you're delegating
     * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForERC721(address delegate, address contract_, uint256 tokenId, bool value, bytes32 data) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific fungible balance
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the fungible token contract
     * @param balance The balance you want to delegate
     * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForERC20(address delegate, address contract_, uint256 balance, bool value, bytes32 data) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific balance for a specific token
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address of the contract that holds the token
     * @param tokenId, the id of the token you are delegating the balance of
     * @param balance The balance you want to delegate
     * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForERC1155(address delegate, address contract_, uint256 tokenId, uint256 balance, bool value, bytes32 data) external;

    /**
     * -----------  READ -----------
     */

    /**
     * @notice Returns all active delegations a given delegate is able to claim on behalf of
     * @param delegate The delegate to retrieve delegations for
     * @return info Array of DelegationInfo structs
     */
    function getDelegationsForDelegate(address delegate) external view returns (DelegationInfo[] memory);

    /**
     * @notice Returns all active delegations a vault has given out
     * @param vault The vault to to retrieve delegations for
     * @return info Array of DelegationInfo structs
     */
    function getDelegationsForVault(address vault) external view returns (DelegationInfo[] memory);

    /**
     * @notice Returns true if the address is delegated to act on the entire vault
     * @param delegate The hotwallet to act on your behalf
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForAll(address delegate, address vault, bytes32 data) external view returns (bool);

    /**
     * @notice Returns true if the address is delegated to act on your behalf for a token contract or an entire vault
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForContract(address delegate, address vault, address contract_, bytes32 data) external view returns (bool);

    /**
     * @notice Returns true if the address is delegated to act on your behalf for a specific token, the token's contract or an entire vault
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param tokenId The token id for the token you're delegating
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForERC721(address delegate, address vault, address contract_, uint256 tokenId, bytes32 data) external view returns (bool);

    /**
     * @notice Returns the balance of a fungible token that the address is delegated to act on the behalf, or max(uint256) if the the token's contract or entire vault has been delegated (and 0 otherwise)
     * @dev we may need to change this method or create another method since this isn't providing truth of a balance, just returning it
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address of the token contract
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForERC20(address delegate, address vault, address contract_, bytes32 data) external view returns (uint256);

    /**
     * @notice Returns the balance of a specific token that the address is delegated to act on the behalf, or max(uint256) if the the specific token, the token's contract or entire vault has been delegated (and 0 otherwise)
     * @dev we may need to change this method or create another method since this isn't providing truth of a balance, just returning it
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address of the token contract
     * @param tokenId the token id for the token you're delegating the balance of
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForERC1155(address delegate, address vault, address contract_, uint256 tokenId, bytes32 data) external view returns (uint256);
}
