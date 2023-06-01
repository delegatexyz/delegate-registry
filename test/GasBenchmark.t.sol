// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {DelegationRegistry as Registry} from "src/DelegationRegistry.sol";
import {IDelegationRegistry as IRegistry} from "src/IDelegationRegistry.sol";

/// @dev for testing gas of write and consumable functions
/// @dev "forge test --match-test GasBenchmark --gas-report"
contract GasBenchmark is Test {
    Registry registry;

    function setUp() public {}

    function _createDelegations(bytes32 seed) private pure returns (IRegistry.DelegationInfo[] memory delegations) {
        delegations = new IRegistry.DelegationInfo[](3);
        delegations[0] = IRegistry.DelegationInfo({
            type_: IRegistry.DelegationType.ALL,
            delegate: address(bytes20(keccak256(abi.encode(seed, "ALL", "delegate")))),
            vault: address(0),
            contract_: address(0),
            tokenId: 0
        });
        delegations[1] = IRegistry.DelegationInfo({
            type_: IRegistry.DelegationType.CONTRACT,
            delegate: address(bytes20(keccak256(abi.encode(seed, "CONTRACT", "delegate")))),
            vault: address(0),
            contract_: address(bytes20(keccak256(abi.encode(seed, "CONTRACT", "contract_")))),
            tokenId: 0
        });
        delegations[2] = IRegistry.DelegationInfo({
            type_: IRegistry.DelegationType.TOKEN,
            delegate: address(bytes20(keccak256(abi.encode(seed, "ERC721", "delegate")))),
            vault: address(0),
            contract_: address(bytes20(keccak256(abi.encode(seed, "ERC721", "contract_")))),
            tokenId: uint256(keccak256(abi.encode(seed, "ERC721", "tokenId")))
        });
    }

    function testGas(address vault, bytes32 seed) public {
        vm.assume(vault > address(1));
        // Benchmark delegate all and check all
        registry = new Registry();
        IRegistry.DelegationInfo[] memory delegations = _createDelegations(keccak256(abi.encode(seed, "delegations")));
        registry.delegateForAll(delegations[0].delegate, true);
        registry.checkDelegateForAll(delegations[0].delegate, vault);
        // Benchmark delegate contract and check contract
        registry = new Registry();
        registry.delegateForContract(delegations[1].delegate, delegations[1].contract_, true);
        registry.checkDelegateForContract(delegations[1].delegate, vault, delegations[1].contract_);
        // Benchmark delegate erc721 and check erc721
        registry = new Registry();
        registry.delegateForToken(delegations[2].delegate, delegations[2].contract_, delegations[2].tokenId, true);
        registry.checkDelegateForToken(delegations[2].delegate, vault, delegations[2].contract_, delegations[2].tokenId);
    }
}
