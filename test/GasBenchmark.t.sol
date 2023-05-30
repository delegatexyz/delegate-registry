// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DelegateRegistry as Registry} from "src/DelegateRegistry.sol";
import {IDelegateRegistry as IRegistry} from "src/IDelegateRegistry.sol";

/// @dev for testing gas of write and consumable functions
/// @dev "forge test --match-test testGas --gas-report"
contract GasBenchmark is Test {
    Registry registry;

    function setUp() public {
        registry = new Registry();
    }

    function _createDelegations(bytes32 seed) private pure returns (IRegistry.BatchDelegation[] memory delegations) {
        delegations = new IRegistry.BatchDelegation[](5);
        delegations[0] = IRegistry.BatchDelegation({
            type_: IRegistry.DelegationType.ALL,
            enable: true,
            delegate: address(bytes20(keccak256(abi.encode(seed, "ALL", "delegate")))),
            rights: "",
            contract_: address(0),
            tokenId: 0,
            amount: 0
        });
        delegations[1] = IRegistry.BatchDelegation({
            type_: IRegistry.DelegationType.CONTRACT,
            enable: true,
            delegate: address(bytes20(keccak256(abi.encode(seed, "CONTRACT", "delegate")))),
            rights: "",
            contract_: address(bytes20(keccak256(abi.encode(seed, "CONTRACT", "contract_")))),
            tokenId: 0,
            amount: 0
        });
        delegations[2] = IRegistry.BatchDelegation({
            type_: IRegistry.DelegationType.ERC721,
            enable: true,
            delegate: address(bytes20(keccak256(abi.encode(seed, "ERC721", "delegate")))),
            rights: "",
            contract_: address(bytes20(keccak256(abi.encode(seed, "ERC721", "contract_")))),
            tokenId: uint256(keccak256(abi.encode(seed, "ERC721", "tokenId"))),
            amount: 0
        });
        delegations[3] = IRegistry.BatchDelegation({
            type_: IRegistry.DelegationType.ERC20,
            enable: true,
            delegate: address(bytes20(keccak256(abi.encode(seed, "ERC20", "delegate")))),
            rights: "",
            contract_: address(bytes20(keccak256(abi.encode(seed, "ERC20", "contract_")))),
            tokenId: 0,
            amount: uint256(keccak256(abi.encode(seed, "ERC20", "amount")))
        });
        delegations[4] = IRegistry.BatchDelegation({
            type_: IRegistry.DelegationType.ERC1155,
            enable: true,
            delegate: address(bytes20(keccak256(abi.encode(seed, "ERC1155", "delegate")))),
            rights: "",
            contract_: address(bytes20(keccak256(abi.encode(seed, "ERC1155", "contract_")))),
            tokenId: uint256(keccak256(abi.encode(seed, "ERC1155", "tokenId"))),
            amount: uint256(keccak256(abi.encode(seed, "ERC1155", "amount")))
        });
    }

    function testGas(address vault, bytes32 seed) public {
        vm.assume(vault > address(1));
        // Benchmark batch delegate
        registry.batchDelegate(_createDelegations(keccak256(abi.encode(seed, "batch"))));
        // Benchmark delegate all
        IRegistry.BatchDelegation[] memory delegations = _createDelegations(keccak256(abi.encode(seed, "delegations")));
        registry.delegateAll(delegations[0].delegate, delegations[0].rights, delegations[0].enable);
        // Benchmark delegate contract
        registry.delegateContract(delegations[1].delegate, delegations[1].contract_, delegations[1].rights, delegations[1].enable);
        // Benchmark delegate erc721
        registry.delegateERC721(delegations[2].delegate, delegations[2].contract_, delegations[2].tokenId, delegations[2].rights, delegations[2].enable);
        // Benchmark delegate erc20
        registry.delegateERC20(delegations[3].delegate, delegations[3].contract_, delegations[3].amount, delegations[3].rights, delegations[3].enable);
        // Benchmark delegate erc1155
        registry.delegateERC1155(
            delegations[4].delegate, delegations[4].contract_, delegations[4].tokenId, delegations[4].amount, delegations[4].rights, delegations[4].enable
        );
        // Benchmark check delegate all
        registry.checkDelegateForAll(delegations[0].delegate, vault, delegations[0].rights);
        // Benchmark check delegate contract
        registry.checkDelegateForContract(delegations[1].delegate, vault, delegations[1].contract_, delegations[1].rights);
        // Benchmark check delegate erc721
        registry.checkDelegateForERC721(delegations[2].delegate, vault, delegations[2].contract_, delegations[2].tokenId, delegations[2].rights);
        // Benchmark check delegate for erc20
        registry.checkDelegateForERC20(delegations[3].delegate, vault, delegations[3].contract_, delegations[3].rights);
        // Benchmark check delegate for erc1155
        registry.checkDelegateForERC1155(delegations[4].delegate, vault, delegations[4].contract_, delegations[4].tokenId, delegations[4].rights);
    }
}
