// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

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
        TOKEN
    }

    /// @notice Info about a single delegation, used for onchain enumeration
    struct DelegationInfo {
        DelegationType type_;
        address vault;
        address delegate;
        address contract_;
        uint256 tokenId;
        bytes32 data;
    }

    /// @notice Emitted when a user delegates their entire wallet
    event DelegateForAll(address indexed vault, address indexed delegate, bool value);

    /// @notice Emitted when a user delegates a specific contract
    event DelegateForContract(address indexed vault, address indexed delegate, address indexed contract_, bool value);

    /// @notice Emitted when a user delegates a specific token
    event DelegateForToken(
        address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, bool value
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
    function delegateForToken(address delegate, address contract_, uint256 tokenId, bool value, bytes32 data)
        external;

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
    function checkDelegateForContract(address delegate, address vault, address contract_, bytes32 data)
        external
        view
        returns (bool);

    /**
     * @notice Returns true if the address is delegated to act on your behalf for a specific token, the token's contract or an entire vault
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param tokenId The token id for the token you're delegating
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForToken(address delegate, address vault, address contract_, uint256 tokenId, bytes32 data)
        external
        view
        returns (bool);
}
