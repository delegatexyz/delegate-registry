// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DelegateRegistry as Registry} from "src/DelegateRegistry.sol";
import {IDelegateRegistry as IRegistry} from "src/IDelegateRegistry.sol";

/// @dev for testing gas of write and consumable functions
/// @dev "forge test --match-test testGas --gas-report"
contract GasBenchmark is Test {
    Registry registry;

    function setUp() public {}

    function _createDelegations(bytes32 seed) private pure returns (IRegistry.Delegation[] memory delegations) {
        delegations = new IRegistry.Delegation[](5);
        delegations[0] = IRegistry.Delegation({
            type_: IRegistry.DelegationType.ALL,
            delegate: address(bytes20(keccak256(abi.encode(seed, "ALL", "delegate")))),
            vault: address(0),
            rights: "",
            contract_: address(0),
            tokenId: 0,
            amount: 0
        });
        delegations[1] = IRegistry.Delegation({
            type_: IRegistry.DelegationType.CONTRACT,
            delegate: address(bytes20(keccak256(abi.encode(seed, "CONTRACT", "delegate")))),
            vault: address(0),
            rights: "",
            contract_: address(bytes20(keccak256(abi.encode(seed, "CONTRACT", "contract_")))),
            tokenId: 0,
            amount: 0
        });
        delegations[2] = IRegistry.Delegation({
            type_: IRegistry.DelegationType.ERC721,
            delegate: address(bytes20(keccak256(abi.encode(seed, "ERC721", "delegate")))),
            vault: address(0),
            rights: "",
            contract_: address(bytes20(keccak256(abi.encode(seed, "ERC721", "contract_")))),
            tokenId: uint256(keccak256(abi.encode(seed, "ERC721", "tokenId"))),
            amount: 0
        });
        delegations[3] = IRegistry.Delegation({
            type_: IRegistry.DelegationType.ERC20,
            delegate: address(bytes20(keccak256(abi.encode(seed, "ERC20", "delegate")))),
            vault: address(0),
            rights: "",
            contract_: address(bytes20(keccak256(abi.encode(seed, "ERC20", "contract_")))),
            tokenId: 0,
            amount: uint256(keccak256(abi.encode(seed, "ERC20", "amount")))
        });
        delegations[4] = IRegistry.Delegation({
            type_: IRegistry.DelegationType.ERC1155,
            delegate: address(bytes20(keccak256(abi.encode(seed, "ERC1155", "delegate")))),
            vault: address(0),
            rights: "",
            contract_: address(bytes20(keccak256(abi.encode(seed, "ERC1155", "contract_")))),
            tokenId: uint256(keccak256(abi.encode(seed, "ERC1155", "tokenId"))),
            amount: uint256(keccak256(abi.encode(seed, "ERC1155", "amount")))
        });
    }

    function testGas(address vault, bytes32 seed) public {
        vm.assume(vault > address(1));
        // Benchmark delegate all and check all
        registry = new Registry();
        IRegistry.Delegation[] memory delegations = _createDelegations(keccak256(abi.encode(seed, "delegations")));
        registry.delegateAll(delegations[0].delegate, delegations[0].rights, true);
        registry.checkDelegateForAll(delegations[0].delegate, vault, delegations[0].rights);
        // Benchmark delegate contract and check contract
        registry = new Registry();
        registry.delegateContract(delegations[1].delegate, delegations[1].contract_, delegations[1].rights, true);
        registry.checkDelegateForContract(delegations[1].delegate, vault, delegations[1].contract_, delegations[1].rights);
        // Benchmark delegate erc721 and check erc721
        registry = new Registry();
        registry.delegateERC721(delegations[2].delegate, delegations[2].contract_, delegations[2].tokenId, delegations[2].rights, true);
        registry.checkDelegateForERC721(delegations[2].delegate, vault, delegations[2].contract_, delegations[2].tokenId, delegations[2].rights);
        // Benchmark delegate erc20 and check erc20
        registry = new Registry();
        registry.delegateERC20(delegations[3].delegate, delegations[3].contract_, delegations[3].amount, delegations[3].rights, true);
        registry.checkDelegateForERC20(delegations[3].delegate, vault, delegations[3].contract_, delegations[3].rights);
        // Benchmark delegate erc1155 and check erc20
        registry = new Registry();
        registry.delegateERC1155(delegations[4].delegate, delegations[4].contract_, delegations[4].tokenId, delegations[4].amount, delegations[4].rights, true);
        registry.checkDelegateForERC1155(delegations[4].delegate, vault, delegations[4].contract_, delegations[4].tokenId, delegations[4].rights);
        // Benchmark multicall
        registry = new Registry();
        IRegistry.Delegation[] memory multicallDelegations = new IRegistry.Delegation[](5);
        multicallDelegations = _createDelegations(keccak256(abi.encode(seed, "multicall")));
        bytes[] memory data = new bytes[](5);
        data[0] = abi.encodeWithSelector(IRegistry.delegateAll.selector, multicallDelegations[0].delegate, multicallDelegations[0].rights, true);
        data[1] = abi.encodeWithSelector(
            IRegistry.delegateContract.selector, multicallDelegations[1].delegate, multicallDelegations[1].contract_, multicallDelegations[1].rights, true
        );
        data[2] = abi.encodeWithSelector(
            IRegistry.delegateERC721.selector,
            multicallDelegations[2].delegate,
            multicallDelegations[2].contract_,
            multicallDelegations[2].tokenId,
            multicallDelegations[2].rights,
            true
        );
        data[3] = abi.encodeWithSelector(
            IRegistry.delegateERC20.selector,
            multicallDelegations[3].delegate,
            multicallDelegations[3].contract_,
            multicallDelegations[3].amount,
            multicallDelegations[3].rights,
            true
        );
        data[4] = abi.encodeWithSelector(
            IRegistry.delegateERC1155.selector,
            multicallDelegations[4].delegate,
            multicallDelegations[4].contract_,
            multicallDelegations[4].tokenId,
            multicallDelegations[4].amount,
            multicallDelegations[4].rights,
            true
        );
        registry.multicall(data);
    }
}
