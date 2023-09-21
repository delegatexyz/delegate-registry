// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {DelegateRegistry} from "../src/DelegateRegistry.sol";
import {Singlesig} from "../src/singlesig/Singlesig.sol";

interface ImmutableCreate2Factory {
    function safeCreate2(bytes32 salt, bytes calldata initCode) external payable returns (address deploymentAddress);
    function findCreate2Address(bytes32 salt, bytes calldata initCode) external view returns (address deploymentAddress);
    function findCreate2AddressViaHash(bytes32 salt, bytes32 initCodeHash) external view returns (address deploymentAddress);
}

contract Deploy is Script {
    ImmutableCreate2Factory immutable factory = ImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);
    bytes initCode = type(DelegateRegistry).creationCode;
    // bytes32 salt = 0x0000000000000000000000000000000000000000fbe49ecfc3decb1164228b89;
    bytes32 salt = 0x00000000000000000000000000000000000000002bbc593dd77cb93fbb932d5f;

    // bytes initCode = abi.encodePacked(type(Singlesig).creationCode, abi.encode(address(0x6Ed7D526b020780f694f3c10Dfb25E1b134D3215)));
    // bytes32 salt = 0x000000000000000000000000000000000000000016c7768a8c7a2824b846321d;

    function run() external {
        vm.startBroadcast();

        // address singlesigAddress = factory.safeCreate2(salt, initCode);
        // Singlesig singlesig = Singlesig(payable(singlesigAddress));
        // console2.log(address(singlesig));

        address registryAddress = factory.safeCreate2(salt, initCode);
        DelegateRegistry registry = DelegateRegistry(registryAddress);
        console2.log(address(registry));

        // address registryAddress = factory.safeCreate2(salt, initCode);
        // DelegateRegistry registry = DelegateRegistry(registryAddress);
        // console2.log(address(registry));

        vm.stopBroadcast();
    }
}
