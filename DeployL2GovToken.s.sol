// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {L2GovToken} from "src/L2GovToken.sol";

contract DeployL2GovToken is Script {
  address deployer;
  address proxyAdmin;
  address tokenAdmin;
  L2GovToken proxy;

  function setUp() public virtual {
    console.log("Deployer address:\t", msg.sender);
    proxyAdmin = vm.envAddress("PROXY_ADMIN_ADDRESS");
    console.log("Proxy admin address:\t", proxyAdmin);
    tokenAdmin = vm.envAddress("TOKEN_ADMIN_ADDRESS");
    console.log("Token admin address:\t", tokenAdmin);
    if (proxyAdmin == tokenAdmin) {
      revert("Proxy admin and token admin must be different");
    }
  }

  function run() public virtual {
    vm.startBroadcast(deployer);
    L2GovToken token = new L2GovToken();
    console.log("L2GovToken impl:\t", address(token));
    proxy = L2GovToken(
      address(
        new TransparentUpgradeableProxy(
          address(token),
          proxyAdmin,
          abi.encodeWithSelector(token.initialize.selector, tokenAdmin, "L2 Governance Token", "gL2")
        )
      )
    );
    console.log("L2GovToken proxy:\t", address(proxy));
    vm.stopBroadcast();
  }
}
