// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.4;

/// @title The simplest possible 1-of-1 smart contract wallet for counterfactually receiving native tokens and ERC20s
/// @dev Does not include receiver callbacks for "safe" transfer methods of ERC721, ERC1155, etc
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

    // @dev Function to receive native tokens when `msg.data` is empty
    receive() external payable {}

    // @dev Fallback function is called when `msg.data` is not empty
    fallback() external payable {}

    /// @dev Throws if called by any account other than the owner
    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable2Step: caller is not the owner");
        _;
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

    /**
     * @notice Executes a call with provided parameters
     * @dev This method doesn't perform any sanity check of the transaction
     * @param to Destination address
     * @param value Native token value in wei
     * @param data Data payload
     * @return success Boolean flag indicating if the call succeeded
     */
    function execute(address to, uint256 value, bytes memory data) public onlyOwner returns (bool success) {
        (success,) = to.call{value: value}(data);
    }
}
