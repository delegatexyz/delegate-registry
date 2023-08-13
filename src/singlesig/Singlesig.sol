// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract Singlesig {
    address public owner;

    /// @dev The caller account is not authorized to perform an operation
    error OwnableUnauthorizedAccount(address account);

    /// @dev The owner is not a valid owner account. (eg. `address(0)`)
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @dev Initializes the contract setting the address provided by the deployer as the initial owner
    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    /// @dev Throws if called by any account other than the owner
    modifier onlyOwner() {
        if (owner != msg.sender) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`)
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /// @dev Internal function with no access restriction
    function _transferOwnership(address newOwner) internal {
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
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
