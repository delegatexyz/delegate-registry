// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

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
        reg.delegateForAll(delegate, role, true);
        assertTrue(reg.checkDelegateForAll(delegate, role, vault));
        // Revoke
        reg.delegateForAll(delegate, role, false);
        assertFalse(reg.checkDelegateForAll(delegate, role, vault));
    }
}
