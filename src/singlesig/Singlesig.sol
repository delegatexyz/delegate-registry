// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev This does not include receiver callbacks for "safe" transfer methods of ERC721, ERC1155, etc
contract Singlesig {
    address public owner;
    address public pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @dev Initializes the contract setting the address provided by the deployer as the initial owner
    /// @dev Distinct constructor args will lead to distinct CREATE2 deployment bytecode, so no collision risk here
    constructor(address initialOwner) {
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    // @dev Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // @dev Fallback function is called when msg.data is not empty
    fallback() external payable {}

    /// @dev Throws if called by any account other than the owner
    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable2Step: caller is not the owner");
        _;
    }

    /// @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one
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
     * @notice Executes either a delegatecall or a call with provided parameters
     * @dev This method doesn't perform any sanity check of the transaction
     * @param to Destination address
     * @param value Ether value in wei
     * @param data Data payload
     * @param delegate Should delegatecall or not
     * @return success Boolean flag indicating if the call succeeded
     */
    function execute(address to, uint256 value, bytes memory data, bool delegate) public onlyOwner returns (bool success) {
        if (delegate) {
            (success,) = to.delegatecall(data);
        } else {
            (success,) = to.call{value: value}(data);
        }
    }
}
