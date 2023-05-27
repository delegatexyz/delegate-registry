// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/**
 * @title IDelegateRegistry
 * @custom:version 2.0
 * @custom:author foobar (0xfoobar)
 * @notice A standalone immutable registry storing delegated permissions from one wallet to another
 */
interface IDelegateRegistry {
    /// @notice Delegation type
    enum DelegationType {
        ALL,
        CONTRACT,
        ERC20,
        ERC721,
        ERC1155
    }

    /// @notice Standardizes storage positions of delegation data
    enum StoragePositions {
        delegate,
        vault,
        rights,
        contract_,
        tokenId,
        balance
    }

    /// @notice Struct for returning arbitrary delegations
    struct Delegation {
        DelegationType type_;
        bool enable;
        address delegate;
        address vault;
        bytes32 rights;
        address contract_;
        uint256 tokenId;
        uint256 balance;
    }

    /// @notice Struct for batch delegations
    struct BatchDelegation {
        DelegationType type_;
        bool enable;
        address delegate;
        bytes32 rights;
        address contract_;
        uint256 tokenId;
        uint256 balance;
    }

    /// @notice Emitted when a user delegates rights for their entire wallet
    event AllDelegated(address indexed vault, address indexed delegate, bytes32 rights, bool enable);

    /// @notice Emitted when a user delegates rights for a specific contract
    event ContractDelegated(address indexed vault, address indexed delegate, address indexed contract_, bytes32 rights, bool enable);

    /// @notice Emitted when a user delegates rights for a specific ERC721 token
    event ERC721Delegated(address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, bytes32 rights, bool enable);

    /// @notice Emitted when a user delegates rights for a specific balance of ERC20 tokens
    event ERC20Delegated(address indexed vault, address indexed delegate, address indexed contract_, uint256 balance, bytes32 rights, bool enable);

    /// @notice Emitted when a user delegates rights for a specific balance of ERC1155 tokens
    event ERC1155Delegated(
        address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, uint256 balance, bytes32 rights, bool enable
    );

    /**
     * -----------  WRITE -----------
     */

    /**
     * @notice Batch several delegations into a single transactions
     * @param delegations An array of SetDelegation structs
     */
    function batchDelegate(BatchDelegation[] calldata delegations) external;

    /**
     * @notice Allow the delegate to act on your behalf for all contracts
     * @param delegate The hotwallet to act on your behalf
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     */
    function delegateForAll(address delegate, bytes32 rights, bool enable) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific contract
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     */
    function delegateForContract(address delegate, address contract_, bytes32 rights, bool enable) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific ERC721 token
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param tokenId The token id for the token you're delegating
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     */
    function delegateForERC721(address delegate, address contract_, uint256 tokenId, bytes32 rights, bool enable) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific balance of ERC20 tokens
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the fungible token contract
     * @param balance The balance you want to delegate
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     */
    function delegateForERC20(address delegate, address contract_, uint256 balance, bytes32 rights, bool enable) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific balance of ERC1155 tokens
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address of the contract that holds the token
     * @param tokenId, the id of the token you are delegating the balance of
     * @param balance The balance you want to delegate
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     */
    function delegateForERC1155(address delegate, address contract_, uint256 tokenId, uint256 balance, bytes32 rights, bool enable) external;

    /**
     * -----------  READ -----------
     */

    /**
     * @notice Returns all enabled delegations a given delegate has been granted
     * @param delegate The delegate to retrieve delegations for
     * @return info Array of Delegation structs
     */
    function getDelegationsForDelegate(address delegate) external view returns (Delegation[] memory);

    /**
     * @notice Returns all enabled delegations a vault has granted
     * @param vault The vault to to retrieve delegations for
     * @return info Array of Delegation structs
     */
    function getDelegationsForVault(address vault) external view returns (Delegation[] memory);

    /**
     * @notice Returns true if the delegate is granted rights to act on your behalf for an entire vault
     * @param delegate The hotwallet to act on your behalf
     * @param vault The cold wallet who issued the delegation
     * @param rights Specific rights to check for, leave empty for full rights only
     */
    function checkDelegateForAll(address delegate, address vault, bytes32 rights) external view returns (bool);

    /**
     * @notice Returns true if the delegate is granted rights to act on your behalf for a specific contract
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param vault The cold wallet who issued the delegation
     * @param rights Specific rights to check for, leave empty for full rights only
     */
    function checkDelegateForContract(address delegate, address vault, address contract_, bytes32 rights) external view returns (bool);

    /**
     * @notice Returns true if the delegate is granted rights to act on your behalf for a specific ERC721 token
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param tokenId The token id for the token you're delegating
     * @param vault The cold wallet who issued the delegation
     * @param rights Specific rights to check for, leave empty for full rights only
     */
    function checkDelegateForERC721(address delegate, address vault, address contract_, uint256 tokenId, bytes32 rights) external view returns (bool);

    /**
     * @notice Returns the balance of ERC20 tokens the delegate is granted rights to act on the behalf of
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address of the token contract
     * @param vault The cold wallet who issued the delegation
     * @param rights Specific rights to check for, leave empty for full rights only
     */
    function checkDelegateForERC20(address delegate, address vault, address contract_, bytes32 rights) external view returns (uint256);

    /**
     * @notice Returns the balance of a ERC1155 tokens the delegate is granted rights to act on the behalf of
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address of the token contract
     * @param tokenId the token id for the token you're delegating the balance of
     * @param vault The cold wallet who issued the delegation
     * @param rights Specific rights to check for, leave empty for full rights only
     */
    function checkDelegateForERC1155(address delegate, address vault, address contract_, uint256 tokenId, bytes32 rights) external view returns (uint256);
}
