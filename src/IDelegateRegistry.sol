// SPDX-License-Identifier: CC0-1.0
pragma solidity >=0.8.13;

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
        ERC721,
        ERC20,
        ERC1155
    }

    /// @notice Struct for returning arbitrary delegations
    struct Delegation {
        DelegationType type_;
        address delegate;
        address vault;
        bytes32 rights;
        address contract_;
        uint256 tokenId;
        uint256 amount;
    }

    /// @notice Emitted when an address delegates rights for their entire wallet
    event DelegateAll(address indexed from, address indexed to, bytes32 rights, bool enable);

    /// @notice Emitted when an address delegates rights for a specific contract
    event DelegateContract(address indexed from, address indexed to, address indexed contract_, bytes32 rights, bool enable);

    /// @notice Emitted when an address delegates rights for a specific ERC721 token
    event DelegateERC721(address indexed from, address indexed to, address indexed contract_, uint256 tokenId, bytes32 rights, bool enable);

    /// @notice Emitted when an address delegates rights for a specific amount of ERC20 tokens
    event DelegateERC20(address indexed from, address indexed to, address indexed contract_, uint256 amount, bytes32 rights, bool enable);

    /// @notice Emitted when an address delegates rights for a specific amount of ERC1155 tokens
    event DelegateERC1155(address indexed from, address indexed to, address indexed contract_, uint256 tokenId, uint256 amount, bytes32 rights, bool enable);

    /// @notice Thrown if multicall calldata is malformed
    error MulticallFailed();

    /**
     * -----------  WRITE -----------
     */

    /**
     * @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
     * @param data The encoded function data for each of the calls to make to this contract
     * @return results The results from each of the calls passed in via data
     */
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);

    /**
     * @notice Allow the delegate to act on behalf of `msg.sender` for all contracts
     * @param to The address to act as delegate
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     */
    function delegateAll(address to, bytes32 rights, bool enable) external;

    /**
     * @notice Allow the delegate to act on behalf of `msg.sender` for a specific contract
     * @param to The address to act as delegate
     * @param contract_ The contract whose rights are being delegated
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     */
    function delegateContract(address to, address contract_, bytes32 rights, bool enable) external;

    /**
     * @notice Allow the delegate to act on behalf of `msg.sender` for a specific ERC721 token
     * @param to The address to act as delegate
     * @param contract_ The contract whose rights are being delegated
     * @param tokenId The token id to delegate
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     */
    function delegateERC721(address to, address contract_, uint256 tokenId, bytes32 rights, bool enable) external;

    /**
     * @notice Allow the delegate to act on behalf of `msg.sender` for a specific amount of ERC20 tokens
     * @param to The address to act as delegate
     * @param contract_ The address for the fungible token contract
     * @param amount The amount to delegate
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     */
    function delegateERC20(address to, address contract_, uint256 amount, bytes32 rights, bool enable) external;

    /**
     * @notice Allow the delegate to act on behalf of `msg.sender` for a specific amount of ERC1155 tokens
     * @param to The address to act as delegate
     * @param contract_ The address of the contract that holds the token
     * @param tokenId The token id to delegate
     * @param amount The amount of that token id to delegate
     * @param rights The rights granted to the delegate, leave empty for full rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     */
    function delegateERC1155(address to, address contract_, uint256 tokenId, uint256 amount, bytes32 rights, bool enable) external;

    /**
     * ----------- CHECKS -----------
     */

    /**
     * @notice Check if a delegate can act on a vault's behalf for an entire wallet
     * @param delegate The potential delegate address
     * @param vault The potential address who delegated rights
     * @param rights Specific rights to check for, leave empty for full rights only
     * @return valid Whether delegate is granted to act on the vault's behalf
     */
    function checkDelegateForAll(address delegate, address vault, bytes32 rights) external view returns (bool);

    /**
     * @notice Check if a delegate can act on a vault's behalf for a specific contract
     * @param delegate The delegated address to check
     * @param contract_ The specific contract address being checked
     * @param vault The cold wallet who issued the delegation
     * @param rights Specific rights to check for, leave empty for full rights only
     * @return valid Whether delegate is granted to act on vault's behalf for entire wallet or that specific contract
     */
    function checkDelegateForContract(address delegate, address vault, address contract_, bytes32 rights) external view returns (bool);

    /**
     * @notice Check if a delegate can act on a vault's behalf for a specific token
     * @param delegate The delegated address to check
     * @param contract_ The specific contract address being checked
     * @param tokenId The token id for the token to delegating
     * @param vault The wallet that issued the delegation
     * @param rights Specific rights to check for, leave empty for full rights only
     * @return valid Whether delegate is granted to act on vault's behalf for entire wallet, that contract, or that specific tokenId
     */
    function checkDelegateForERC721(address delegate, address vault, address contract_, uint256 tokenId, bytes32 rights) external view returns (bool);

    /**
     * @notice Returns the amount of ERC20 tokens the delegate is granted rights to act on the behalf of
     * @param delegate The delegated address to check
     * @param contract_ The address of the token contract
     * @param vault The cold wallet who issued the delegation
     * @param rights Specific rights to check for, leave empty for full rights only
     * @return balance The delegated balance, which will be 0 if the delegation does not exist
     */
    function checkDelegateForERC20(address delegate, address vault, address contract_, bytes32 rights) external view returns (uint256);

    /**
     * @notice Returns the amount of a ERC1155 tokens the delegate is granted rights to act on the behalf of
     * @param delegate The delegated address to check
     * @param contract_ The address of the token contract
     * @param tokenId The token id to check the delegated amount of
     * @param vault The cold wallet who issued the delegation
     * @param rights Specific rights to check for, leave empty for full rights only
     * @return balance The delegated balance, which will be 0 if the delegation does not exist
     */
    function checkDelegateForERC1155(address delegate, address vault, address contract_, uint256 tokenId, bytes32 rights) external view returns (uint256);

    /**
     * ----------- ENUMERATIONS -----------
     */

    /**
     * @notice Returns all enabled delegations a given delegate has received
     * @param to The address to retrieve delegations for
     * @return delegations Array of Delegation structs
     */
    function getIncomingDelegations(address to) external view returns (Delegation[] memory delegations);

    /**
     * @notice Returns all enabled delegations an address has given out
     * @param from The address to retrieve delegations for
     * @return delegations Array of Delegation structs
     */
    function getOutgoingDelegations(address from) external view returns (Delegation[] memory delegations);

    /**
     * @notice Returns all hashes associated with enabled delegations an address has received
     * @param to The address to retrieve incoming delegation hashes for
     * @return delegationHashes Array of delegation hashes
     */
    function getIncomingDelegationHashes(address to) external view returns (bytes32[] memory delegationHashes);

    /**
     * @notice Returns all hashes associated with enabled delegations an address has given out
     * @param from The address to retrieve outgoing delegation hashes for
     * @return delegationHashes Array of delegation hashes
     */
    function getOutgoingDelegationHashes(address from) external view returns (bytes32[] memory delegationHashes);

    /**
     * @notice Returns the delegations for a given array of delegation hashes
     * @param delegationHashes is an array of hashes that correspond to delegations
     * @return delegations Array of Delegation structs, return empty structs for nonexistent or revoked delegations
     */
    function getDelegationsFromHashes(bytes32[] calldata delegationHashes) external view returns (Delegation[] memory delegations);
}
