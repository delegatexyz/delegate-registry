// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { DelegationRegistry } from "src/DelegationRegistry.sol";

contract DelegationRegistryTest is Test {
    DelegationRegistry reg;
    function setUp() public {
        reg = new DelegationRegistry();
    }

    function testApproveAndRevokeForAll(address vault, address delegate, bytes32 role ) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForAll(delegate, role);
        assertEq(reg.getDelegateForAll(role, vault), delegate);
        // Revoke
        reg.revokeDelegationForAll(role);
        assertEq(reg.getDelegateForAll(role, vault), address(0));
    }
}
