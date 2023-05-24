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
        NONE,
        ALL,
        CONTRACT,
        ERC20,
        ERC721,
        ERC1155
    }

    struct AllStorage {
        bytes32 rights;
        address delegate;
        address vault;
    }

    struct ContractStorage {
        bytes32 rights;
        address contract_;
        address delegate;
        address vault;
    }

    struct ERC20Storage {
        uint256 balance;
        bytes32 rights;
        address contract_;
        address delegate;
        address vault;
    }

    struct ERC721Storage {
        bytes32 rights;
        address contract_;
        address delegate;
        uint256 tokenId;
        address vault;
    }

    struct ERC1155Storage {
        uint256 balance;
        bytes32 rights;
        address contract_;
        address delegate;
        uint256 tokenId;
        address vault;
    }

    /// @notice Struct used for batch delegations and returning arbitrary delegations
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

    /// @notice Emitted when a user delegates their entire wallet
    event AllDelegated(address indexed vault, address indexed delegate, bytes32 rights, bool enable);

    /// @notice Emitted when a user delegates a specific contract
    event ContractDelegated(address indexed vault, address indexed delegate, address indexed contract_, bytes32 rights, bool enable);

    /// @notice Emitted when a user delegates a specific token
    event ERC721Delegated(address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, bytes32 rights, bool enable);

    /// @notice Emitted when a user delegates a fungible balance
    event ERC20Delegated(address indexed vault, address indexed delegate, address indexed contract_, uint256 balance, bytes32 rights, bool enable);

    /// @notice Emitted when a user delegates a specific token with a specific balance
    event ERC1155Delegated(
        address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, uint256 balance, bytes32 rights, bool enable
    );

    /**
     * -----------  WRITE -----------
     */

    /**
     * @notice Batch several delegations into a single transactions
     * @param delegationSet An array of SetDelegation structs
     */
    function batchDelegate(Delegation[] calldata delegationSet) external;

    /**
     * @notice Allow the delegate to act on your behalf for all contracts
     * @param delegate The hotwallet to act on your behalf
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForAll(address delegate, bytes32 rights, bool enable) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific contract
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForContract(address delegate, address contract_, bytes32 rights, bool enable) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific token
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param tokenId The token id for the token you're delegating
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForERC721(address delegate, address contract_, uint256 tokenId, bytes32 rights, bool enable) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific fungible balance
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the fungible token contract
     * @param balance The balance you want to delegate
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForERC20(address delegate, address contract_, uint256 balance, bytes32 rights, bool enable) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific balance for a specific token
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address of the contract that holds the token
     * @param tokenId, the id of the token you are delegating the balance of
     * @param balance The balance you want to delegate
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForERC1155(address delegate, address contract_, uint256 tokenId, uint256 balance, bytes32 rights, bool enable) external;

    /**
     * -----------  READ -----------
     */

    /**
     * @notice Returns all enable delegations a given delegate is able to claim on behalf of
     * @param delegate The delegate to retrieve delegations for
     * @return info Array of DelegationInfo structs
     */
    function getDelegationsForDelegate(address delegate) external view returns (Delegation[] memory);

    /**
     * @notice Returns all enable delegations a vault has given out
     * @param vault The vault to to retrieve delegations for
     * @return info Array of DelegationInfo structs
     */
    function getDelegationsForVault(address vault) external view returns (Delegation[] memory);

    /**
     * @notice Returns true if the address is delegated to act on the entire vault
     * @param delegate The hotwallet to act on your behalf
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForAll(address delegate, address vault, bytes32 rights) external view returns (bool);

    /**
     * @notice Returns true if the address is delegated to act on your behalf for a token contract or an entire vault
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForContract(address delegate, address vault, address contract_, bytes32 rights) external view returns (bool);

    /**
     * @notice Returns true if the address is delegated to act on your behalf for a specific token, the token's contract or an entire vault
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param tokenId The token id for the token you're delegating
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForERC721(address delegate, address vault, address contract_, uint256 tokenId, bytes32 rights) external view returns (bool);

    /**
     * @notice Returns the balance of a fungible token that the address is delegated to act on the behalf, or max(uint256) if the the token's contract or entire vault has been delegated (and 0 otherwise)
     * @dev we may need to change this method or create another method since this isn't providing truth of a balance, just returning it
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address of the token contract
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForERC20(address delegate, address vault, address contract_, bytes32 rights) external view returns (uint256);

    /**
     * @notice Returns the balance of a specific token that the address is delegated to act on the behalf, or max(uint256) if the the specific token, the token's contract or entire vault has been delegated (and 0 otherwise)
     * @dev we may need to change this method or create another method since this isn't providing truth of a balance, just returning it
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address of the token contract
     * @param tokenId the token id for the token you're delegating the balance of
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForERC1155(address delegate, address vault, address contract_, uint256 tokenId, bytes32 rights) external view returns (uint256);
}
