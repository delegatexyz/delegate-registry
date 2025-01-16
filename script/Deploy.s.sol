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

interface ZksyncCreate2Factory {
    function create2(bytes32 salt, bytes32 bytecodeHash, bytes calldata constructorInput) external payable returns (address deploymentAddress);
    function getNewAddressCreate2(
        address _sender,
        bytes32 _bytecodeHash,
        bytes32 _salt,
        bytes calldata _input
    ) external view returns (address newAddress);
}

contract Deploy is Script {
    ZksyncCreate2Factory immutable zksyncCreateFactory = ZksyncCreate2Factory(0x0000000000000000000000000000000000010000);
    ZksyncCreate2Factory immutable zksyncContractDeployer = ZksyncCreate2Factory(0x0000000000000000000000000000000000008006);

    ImmutableCreate2Factory immutable factory = ImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);
    bytes initCode = type(DelegateRegistry).creationCode;
    // bytes32 singlesigSalt = 0x0000000000000000000000000000000000000000fbe49ecfc3decb1164228b89;
    bytes32 registrySalt = 0x10000000000000000000000000000000000000002bbc593dd77cb93fbb932d5f;

    // bytes initCode = abi.encodePacked(type(Singlesig).creationCode, abi.encode(address(0x6Ed7D526b020780f694f3c10Dfb25E1b134D3215)));
    // bytes32 salt = 0x000000000000000000000000000000000000000016c7768a8c7a2824b846321d;

    function run() external {
        vm.startBroadcast();

        // address singlesigAddress = factory.safeCreate2(singlesigSalt, initCode);
        // Singlesig singlesig = Singlesig(payable(singlesigAddress));
        // console2.log(address(singlesig));

        // DelegateRegistry existing = DelegateRegistry(0x6b176c958fb89Ddca0fc8214150DA4c4D0a32fbe);
        // bytes32[] memory hashes = existing.getOutgoingDelegationHashes(0x86362a4C99d900D72d787Ef1BddA38Fd318aa5E9);
        // console2.logBytes32(hashes[0]);

        DelegateRegistry predeploy = new DelegateRegistry();
        console2.log(address(predeploy));
        console2.log(msg.sender);
        console2.logBytes32(keccak256(initCode));
        console2.logBytes32(registrySalt);
        address registryAddress = zksyncContractDeployer.getNewAddressCreate2(address(zksyncCreateFactory), keccak256(initCode), registrySalt, "");
        console2.log(registryAddress);
        bytes memory constructorInput = "";
        zksyncCreateFactory.create2(registrySalt, keccak256(initCode), constructorInput);

        // address registryAddress = factory.safeCreate2(registrySalt, initCode);
        // DelegateRegistry registry = DelegateRegistry(registryAddress);
        // console2.log(address(registry));

        // address registryAddress = factory.safeCreate2(salt, initCode);
        // DelegateRegistry registry = DelegateRegistry(registryAddress);
        // console2.log(address(registry));

        vm.stopBroadcast();
    }
}
