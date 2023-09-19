// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.4;

/// @title 1-of-1 smart contract wallet with rotatable ownership for counterfactually receiving tokens at the same address across many EVM chains
contract Singlesig {
    address public owner;
    address public pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @dev Initializes the contract setting the address provided by the deployer as the initial owner
    /// @dev Distinct constructor args will lead to distinct CREATE2 initialization bytecode, so no collision risk here
    constructor(address initialOwner) {
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    /// @dev Throws if called by any account other than the owner
    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable2Step: caller is not the owner");
        _;
    }

    /// @notice Executes a call with provided parameters
    /// @dev This method doesn't perform any sanity check of the transaction
    /// @param to Destination address
    /// @param value Native token value in wei
    /// @param data Data payload
    /// @return success Boolean flag indicating if the call succeeded
    function execute(address to, uint256 value, bytes memory data) public onlyOwner returns (bool success) {
        (success,) = to.call{value: value}(data);
    }

    /// @dev Offers to transfer ownership permissions to a new account
    function transferOwnership(address newOwner) external onlyOwner {
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /// @dev The new owner accepts the ownership transfer
    function acceptOwnership() external {
        require(pendingOwner == msg.sender, "Ownable2Step: caller is not the new owner");
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
    }

    /// @dev Function to receive native tokens when `msg.data` is empty
    receive() external payable {}

    /// @dev Fallback function is called when `msg.data` is not empty
    fallback() external payable {}

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0x150b7a02 // ERC165 Interface ID for ERC721TokenReceiver
            || interfaceId == 0x4e2312e0; // ERC165 Interface ID for ERC1155TokenReceiver
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0x150b7a02; //bytes4(keccak256("onERC721Received(address,uint256,bytes)"));
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return 0xf23a6e61; // bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure returns (bytes4) {
        return 0xbc197c81; // bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
    }
}
