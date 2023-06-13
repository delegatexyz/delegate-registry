// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IDelegateRegistry as IRegistry} from "src/IDelegateRegistry.sol";
import {DelegateRegistry as Registry} from "src/DelegateRegistry.sol";
import {RegistryHarness as Harness} from "src/tools/RegistryHarness.sol";

contract RegistryUnitTests is Test {
    Harness public harness;
    Registry public registry;

    enum StoragePositions {
        delegate,
        vault,
        rights,
        contract_,
        tokenId,
        amount
    }

    function setUp() public {
        harness = new Harness();
        registry = new Registry();
    }

    /**
     * ----------- multicall -----------
     */

    function testMulticall(
        address vault,
        address delegate,
        bytes32 rights,
        bool enable,
        address contract_,
        uint256 tokenId,
        uint256 amount,
        bytes32 hash,
        bytes4 interfaceId,
        uint8 position
    ) public {
        registry = new Registry();
        bytes[] memory cases;
        bytes[] memory results;
        // Positive cases first
        bytes[] memory positiveCases = _multicallPositiveCases(vault, delegate, rights, enable, contract_, tokenId, amount, hash, interfaceId);
        // Single cases
        for (uint256 i = 0; i < positiveCases.length; i++) {
            cases = new bytes[](1);
            cases[0] = positiveCases[i];
            results = registry.multicall(cases);
            assertEq(results.length, 1);
        }
        // Positive multiple case
        cases = _randomizeAndReduce(positiveCases, positiveCases);
        results = registry.multicall(cases);
        assertEq(results.length, cases.length);
        // Negative cases next
        bytes[] memory negativeCases = _multicallNegativeCases(vault, delegate, hash, position, tokenId);
        // Single cases
        for (uint256 i = 0; i < negativeCases.length; i++) {
            cases = new bytes[](1);
            cases[0] = negativeCases[i];
            vm.expectRevert(IRegistry.MulticallFailed.selector);
            registry.multicall(cases);
        }
        // Negative multiple case
        cases = _randomizeAndReduce(negativeCases, negativeCases);
        vm.expectRevert(IRegistry.MulticallFailed.selector);
        registry.multicall(cases);
        // Multiple negative or positive cases (at least one of both)
        cases = _randomizeAndReduce(positiveCases, negativeCases);
        vm.expectRevert(IRegistry.MulticallFailed.selector);
        registry.multicall(cases);
    }

    function _multicallPositiveCases(
        address vault,
        address delegate,
        bytes32 rights,
        bool enable,
        address contract_,
        uint256 tokenId,
        uint256 amount,
        bytes32 hash,
        bytes4 interfaceId
    ) internal view returns (bytes[] memory data) {
        data = new bytes[](16);
        data[0] = abi.encodeWithSelector(registry.delegateAll.selector, delegate, rights, enable);
        data[1] = abi.encodeWithSelector(registry.delegateContract.selector, delegate, contract_, rights, enable);
        data[2] = abi.encodeWithSelector(registry.delegateERC721.selector, delegate, contract_, tokenId, rights, enable);
        data[3] = abi.encodeWithSelector(registry.delegateERC20.selector, delegate, contract_, amount, rights, enable);
        data[4] = abi.encodeWithSelector(registry.delegateERC1155.selector, delegate, contract_, tokenId, amount, rights, enable);
        data[5] = abi.encodeWithSelector(registry.checkDelegateForAll.selector, delegate, vault, rights);
        data[6] = abi.encodeWithSelector(registry.checkDelegateForContract.selector, delegate, vault, contract_, rights);
        data[7] = abi.encodeWithSelector(registry.checkDelegateForERC721.selector, delegate, vault, contract_, tokenId, rights);
        data[8] = abi.encodeWithSelector(registry.checkDelegateForERC20.selector, delegate, vault, contract_, rights);
        data[9] = abi.encodeWithSelector(registry.checkDelegateForERC1155.selector, delegate, vault, contract_, tokenId, rights);
        data[10] = abi.encodeWithSelector(registry.getIncomingDelegations.selector, delegate);
        data[11] = abi.encodeWithSelector(registry.getOutgoingDelegations.selector, vault);
        data[12] = abi.encodeWithSelector(registry.getIncomingDelegationHashes.selector, delegate);
        data[13] = abi.encodeWithSelector(registry.getOutgoingDelegationHashes.selector, vault);
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = hash;
        data[14] = abi.encodeWithSelector(registry.getDelegationsFromHashes.selector, hashes);
        data[15] = abi.encodeWithSelector(registry.supportsInterface.selector, interfaceId);
    }

    function _multicallNegativeCases(address vault, address delegate, bytes32 hash, uint8 position, uint256 tokenId)
        internal
        pure
        returns (bytes[] memory data)
    {
        data = new bytes[](4);
        data[0] = abi.encodeWithSelector(bytes4(keccak256(bytes("_pushDelegationHashes(address,address,bytes32)"))), vault, delegate, hash);
        data[1] = abi.encodeWithSelector(bytes4(keccak256(bytes("_writeDelegation(bytes32,uint8,bytes32)"))), hash, position, hash);
        data[2] = abi.encodeWithSelector(bytes4(keccak256(bytes("_writeDelegation(bytes32,uint8,uint256)"))), hash, position, tokenId);
        data[3] = abi.encodeWithSelector(bytes4(keccak256(bytes("_writeDelegation(bytes32,uint8,address)"))), hash, position, vault);
    }

    function _randomizeAndReduce(bytes[] memory array1, bytes[] memory array2) internal pure returns (bytes[] memory) {
        require(array1.length > 0 && array2.length > 0, "Both arrays should be non-empty");

        // Shuffle array1 and array2
        array1 = _shuffleArray(array1);
        array2 = _shuffleArray(array2);

        // Randomly reduce sizes
        uint256 newSize1 = 1 + uint256(keccak256(abi.encode(array1, array2))) % array1.length;
        uint256 newSize2 = 1 + uint256(keccak256(abi.encode(array2, array1))) % array2.length;

        bytes[] memory reduced1 = new bytes[](newSize1);
        bytes[] memory reduced2 = new bytes[](newSize2);

        for (uint256 i = 0; i < newSize1; i++) {
            reduced1[i] = array1[i];
        }
        for (uint256 i = 0; i < newSize2; i++) {
            reduced2[i] = array2[i];
        }

        bytes[] memory combined = new bytes[](reduced1.length + reduced2.length);

        // Combine arrays
        for (uint256 i = 0; i < reduced1.length; i++) {
            combined[i] = reduced1[i];
        }
        for (uint256 i = 0; i < reduced2.length; i++) {
            combined[i + reduced1.length] = reduced2[i];
        }

        // Shuffle again and return
        return _shuffleArray(combined);
    }

    function _shuffleArray(bytes[] memory array) internal pure returns (bytes[] memory) {
        for (uint256 i = 0; i < array.length; i++) {
            uint256 randomIndex = uint256(keccak256(abi.encode(i, array))) % array.length;
            bytes memory temp = array[i];
            array[i] = array[randomIndex];
            array[randomIndex] = temp;
        }
        return array;
    }

    /**
     * ----------- delegate methods -----------
     */

    event DelegateAll(address indexed vault, address indexed delegate, bytes32 rights, bool enable);

    function testDelegateAll(address vault, address delegate, bytes32 rights, bool enable, uint256 n) public {
        vm.assume(vault > address(1) && n > 0 && n < 10);
        // Create new harness
        harness = new Harness();
        // Calculate hash
        bytes32 hash = harness.exposed_computeDelegationHashForAll(delegate, rights, vault);
        // Hashes should not exist yet
        _checkHashes(vault, delegate, hash, false);
        // Storage should not exist yet
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        // Loop over this test
        for (uint256 i = 0; i < n; i++) {
            // Test correct event emitted
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit DelegateAll(vault, delegate, rights, enable);
            harness.delegateAll(delegate, rights, enable);
            vm.stopPrank();
            // Hashes should now exist regardless of true or false
            _checkHashes(vault, delegate, hash, true);
            // Check enable case
            if (enable) {
                // Check storage slots are written correctly
                _checkStorage(0, address(0), delegate, hash, rights, 0, vault);
                // Disable again
                vm.startPrank(vault);
                vm.expectEmit(true, true, true, true, address(harness));
                emit DelegateAll(vault, delegate, rights, false);
                harness.delegateAll(delegate, rights, false);
                vm.stopPrank();
                // There should be no change to the hash mappings
                _checkHashes(vault, delegate, hash, true);
            }
            // Check storage slots are written correctly for disable
            _checkStorage(0, address(0), address(0), hash, 0, 0, address(1));
            // Randomize enable for next loop
            enable = uint256(keccak256(abi.encode(i, vault, delegate))) % 2 == 0;
        }
    }

    event DelegateContract(address indexed vault, address indexed delegate, address indexed contract_, bytes32 rights, bool enable);

    function testDelegateContract(address vault, address delegate, address contract_, bytes32 rights, bool enable, uint256 n) public {
        vm.assume(vault > address(1) && n > 0 && n < 10);
        harness = new Harness();
        bytes32 hash = harness.exposed_computeDelegationHashForContract(contract_, delegate, rights, vault);
        _checkHashes(vault, delegate, hash, false);
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        for (uint256 i = 0; i < n; i++) {
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit DelegateContract(vault, delegate, contract_, rights, enable);
            harness.delegateContract(delegate, contract_, rights, enable);
            vm.stopPrank();
            _checkHashes(vault, delegate, hash, true);
            if (enable) {
                _checkStorage(0, contract_, delegate, hash, rights, 0, vault);
                vm.startPrank(vault);
                vm.expectEmit(true, true, true, true, address(harness));
                emit DelegateContract(vault, delegate, contract_, rights, false);
                harness.delegateContract(delegate, contract_, rights, false);
                vm.stopPrank();
                _checkHashes(vault, delegate, hash, true);
            }
            _checkStorage(0, address(0), address(0), hash, 0, 0, address(1));
            enable = uint256(keccak256(abi.encode(i, vault, delegate))) % 2 == 0;
        }
    }

    event DelegateERC721(address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, bytes32 rights, bool enable);

    function testDelegateERC721(address vault, address delegate, address contract_, uint256 tokenId, bytes32 rights, bool enable, uint256 n) public {
        vm.assume(vault > address(1) && n > 0 && n < 10);
        harness = new Harness();
        bytes32 hash = harness.exposed_computeDelegationHashForERC721(contract_, delegate, rights, tokenId, vault);
        _checkHashes(vault, delegate, hash, false);
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        for (uint256 i = 0; i < n; i++) {
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit DelegateERC721(vault, delegate, contract_, tokenId, rights, enable);
            harness.delegateERC721(delegate, contract_, tokenId, rights, enable);
            vm.stopPrank();
            _checkHashes(vault, delegate, hash, true);
            if (enable) {
                _checkStorage(0, contract_, delegate, hash, rights, tokenId, vault);
                vm.startPrank(vault);
                vm.expectEmit(true, true, true, true, address(harness));
                emit DelegateERC721(vault, delegate, contract_, tokenId, rights, false);
                harness.delegateERC721(delegate, contract_, tokenId, rights, false);
                vm.stopPrank();
                _checkHashes(vault, delegate, hash, true);
            }
            _checkStorage(0, address(0), address(0), hash, 0, 0, address(1));
            enable = uint256(keccak256(abi.encode(i, vault, delegate))) % 2 == 0;
        }
    }

    event DelegateERC20(address indexed vault, address indexed delegate, address indexed contract_, uint256 amount, bytes32 rights, bool enable);

    function testDelegateERC20(address vault, address delegate, address contract_, uint256 amount, bytes32 rights, bool enable, uint256 n) public {
        vm.assume(vault > address(1) && n > 0 && n < 10);
        harness = new Harness();
        bytes32 hash = harness.exposed_computeDelegationHashForERC20(contract_, delegate, rights, vault);
        _checkHashes(vault, delegate, hash, false);
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        for (uint256 i = 0; i < n; i++) {
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit DelegateERC20(vault, delegate, contract_, amount, rights, enable);
            harness.delegateERC20(delegate, contract_, amount, rights, enable);
            vm.stopPrank();
            _checkHashes(vault, delegate, hash, true);
            if (enable) {
                _checkStorage(amount, contract_, delegate, hash, rights, 0, vault);
                vm.startPrank(vault);
                emit DelegateERC20(vault, delegate, contract_, amount, rights, false);
                harness.delegateERC20(delegate, contract_, amount, rights, false);
                vm.stopPrank();
                _checkHashes(vault, delegate, hash, true);
            }
            _checkStorage(0, address(0), address(0), hash, 0, 0, address(1));
            enable = uint256(keccak256(abi.encode(i, vault, delegate))) % 2 == 0;
            amount = uint256(keccak256(abi.encode(i, enable, amount)));
        }
    }

    event DelegateERC1155(
        address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, uint256 amount, bytes32 rights, bool enable
    );

    function testDelegateERC1155(address vault, address delegate, address contract_, uint256 tokenId, uint256 amount, bytes32 rights, bool enable) public {
        vm.assume(vault > address(1));
        harness = new Harness();
        bytes32 hash = harness.exposed_computeDelegationHashForERC1155(contract_, delegate, rights, tokenId, vault);
        _checkHashes(vault, delegate, hash, false);
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        for (uint256 i = 0; i < (1 + amount % 10); i++) {
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit DelegateERC1155(vault, delegate, contract_, tokenId, amount, rights, enable);
            harness.delegateERC1155(delegate, contract_, tokenId, amount, rights, enable);
            vm.stopPrank();
            _checkHashes(vault, delegate, hash, true);
            if (enable) {
                _checkStorage(amount, contract_, delegate, hash, rights, tokenId, vault);
                vm.startPrank(vault);
                emit DelegateERC1155(vault, delegate, contract_, tokenId, amount, rights, false);
                harness.delegateERC1155(delegate, contract_, tokenId, amount, rights, false);
                vm.stopPrank();
                _checkHashes(vault, delegate, hash, true);
            }
            _checkStorage(0, address(0), address(0), hash, 0, 0, address(1));
            enable = uint256(keccak256(abi.encode(i, vault, delegate))) % 2 == 0;
            amount = uint256(keccak256(abi.encode(i, enable, amount)));
        }
    }

    function _checkHashes(address vault, address delegate, bytes32 hash, bool on) internal {
        if (on) {
            assertEq(harness.exposed_outgoingDelegationHashes(vault).length, 1);
            assertEq(harness.exposed_outgoingDelegationHashes(vault)[0], hash);
            assertEq(harness.exposed_incomingDelegationHashes(delegate).length, 1);
            assertEq(harness.exposed_incomingDelegationHashes(delegate)[0], hash);
        } else {
            assertEq(harness.exposed_outgoingDelegationHashes(vault).length, 0);
            assertEq(harness.exposed_incomingDelegationHashes(delegate).length, 0);
        }
    }

    function _checkStorage(uint256 amount, address contract_, address delegate, bytes32 hash, bytes32 rights, uint256 tokenId, address vault) internal {
        assertEq(harness.exposed_delegations(hash).length, uint256(type(StoragePositions).max) + 1);
        assertEq(address(uint160(uint256(harness.exposed_delegations(hash)[uint256(StoragePositions.delegate)]))), delegate);
        assertEq(address(uint160(uint256(harness.exposed_delegations(hash)[uint256(StoragePositions.vault)]))), vault);
        assertEq(harness.exposed_delegations(hash)[uint256(StoragePositions.rights)], rights);
        assertEq(address(uint160(uint256(harness.exposed_delegations(hash)[uint256(StoragePositions.contract_)]))), contract_);
        assertEq(uint256(harness.exposed_delegations(hash)[uint256(StoragePositions.tokenId)]), tokenId);
        assertEq(uint256(harness.exposed_delegations(hash)[uint256(StoragePositions.amount)]), amount);
    }

    /**
     * ----------- consumables -----------
     */

    function testCheckDelegateForAll(
        address vault,
        bytes32 rights,
        bool enable,
        address delegate,
        address contract_,
        uint256 tokenId,
        uint256 amount,
        bytes32 fRights
    ) public {
        vm.assume(vault > address(1));
        if (amount % 2 == 0) vm.assume(rights == "");
        // new registry
        registry = new Registry();
        // Should return false for any input
        assertFalse(registry.checkDelegateForAll(delegate, vault, rights));
        // Should return false if delegations are made for all other types
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, enable);
        registry.delegateERC721(delegate, contract_, tokenId, rights, enable);
        registry.delegateERC20(delegate, contract_, amount, rights, enable);
        registry.delegateERC1155(delegate, contract_, tokenId, amount, rights, enable);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForAll(delegate, vault, rights));
        // delegateAll and test
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, enable);
        vm.stopPrank();
        if (enable) assertTrue(registry.checkDelegateForAll(delegate, vault, rights));
        else assertFalse(registry.checkDelegateForAll(delegate, vault, rights));
        if (rights == "") assertTrue(registry.checkDelegateForAll(delegate, vault, fRights));
        else if (rights != fRights) assertFalse(registry.checkDelegateForAll(delegate, vault, fRights));
        // revoke and assert false
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForAll(delegate, vault, fRights));
    }

    function testCheckDelegateForContract(
        address vault,
        bytes32 rights,
        bool enable,
        address delegate,
        address contract_,
        uint256 tokenId,
        uint256 amount,
        bytes32 fRights
    ) public {
        vm.assume(vault > address(1));
        if (amount % 2 == 0) vm.assume(rights == "");
        registry = new Registry();
        assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, rights));
        vm.startPrank(vault);
        registry.delegateERC721(delegate, contract_, tokenId, rights, enable);
        registry.delegateERC20(delegate, contract_, amount, rights, enable);
        registry.delegateERC1155(delegate, contract_, tokenId, amount, rights, enable);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, rights));
        // check all case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, enable);
        vm.stopPrank();
        if (enable) assertTrue(registry.checkDelegateForContract(delegate, vault, contract_, rights));
        else assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, rights));
        if (rights == "") assertTrue(registry.checkDelegateForContract(delegate, vault, contract_, fRights));
        else if (rights != fRights) assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, fRights));
        // revoke all case, assert false, then check contract_ case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, rights));
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, enable);
        vm.stopPrank();
        if (enable) assertTrue(registry.checkDelegateForContract(delegate, vault, contract_, rights));
        else assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, rights));
        if (rights == "") assertTrue(registry.checkDelegateForContract(delegate, vault, contract_, fRights));
        else if (rights != fRights) assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, fRights));
        // revoke and check false
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, false);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, rights));
    }

    function testCheckDelegateForERC721(
        address vault,
        bytes32 rights,
        bool enable,
        address delegate,
        address contract_,
        uint256 tokenId,
        uint256 amount,
        bytes32 fRights
    ) public {
        vm.assume(vault > address(1));
        if (amount % 2 == 0) vm.assume(rights == "");
        registry = new Registry();
        assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        vm.startPrank(vault);
        registry.delegateERC20(delegate, contract_, amount, rights, enable);
        registry.delegateERC1155(delegate, contract_, tokenId, amount, rights, enable);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        // check all case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, enable);
        vm.stopPrank();
        if (enable) assertTrue(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        else assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        if (rights == "") assertTrue(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, fRights));
        else if (rights != fRights) assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, fRights));
        // Revoke all then check contract case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, enable);
        vm.stopPrank();
        if (enable) assertTrue(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        else assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        if (rights == "") assertTrue(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, fRights));
        else if (rights != fRights) assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, fRights));
        // Revoke contract then check 721 case
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, false);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        vm.startPrank(vault);
        registry.delegateERC721(delegate, contract_, tokenId, rights, enable);
        vm.stopPrank();
        if (enable) assertTrue(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        else assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        if (rights == "") assertTrue(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, fRights));
        else if (rights != fRights) assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, fRights));
        // revoke and check false
        vm.startPrank(vault);
        registry.delegateERC721(delegate, contract_, tokenId, rights, false);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
    }

    function testCheckDelegateForERC20(
        address vault,
        bytes32 rights,
        bool enable,
        address delegate,
        address contract_,
        uint256 tokenId,
        uint256 amount,
        bytes32 fRights
    ) public {
        vm.assume(vault > address(1));
        if (amount % 2 == 0) vm.assume(rights == "");
        registry = new Registry();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        vm.startPrank(vault);
        registry.delegateERC721(delegate, contract_, tokenId, rights, enable);
        registry.delegateERC1155(delegate, contract_, tokenId, amount, rights, enable);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        // Check all case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, enable);
        vm.stopPrank();
        if (enable) assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), type(uint256).max);
        else assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        if (rights == "") assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, fRights), type(uint256).max);
        else if (rights != fRights) assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, fRights), 0);
        // Revoke all case then check contract case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, enable);
        vm.stopPrank();
        if (enable) assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), type(uint256).max);
        else assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        if (rights == "") assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, fRights), type(uint256).max);
        else if (rights != fRights) assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, fRights), 0);
        // Revoke contract case then check for ERC20 case
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        vm.startPrank(vault);
        registry.delegateERC20(delegate, contract_, amount, rights, enable);
        vm.stopPrank();
        if (enable) assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), amount);
        else assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        if (rights == "") assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, fRights), amount);
        else if (rights != fRights) assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, fRights), 0);
        // Revoke and check false
        vm.startPrank(vault);
        registry.delegateERC20(delegate, contract_, amount, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        // Check bubble up for all and erc20
        vm.assume(amount < type(uint256).max);
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, true);
        registry.delegateERC20(delegate, contract_, amount, rights, true);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), type(uint256).max);
        // Revoke all then check bubble up for contract
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), amount);
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, true);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), type(uint256).max);
        // Revoke and check false
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, false);
        registry.delegateERC20(delegate, contract_, amount, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
    }

    function testCheckDelegateForERC1155(
        address vault,
        bytes32 rights,
        bool enable,
        address delegate,
        address contract_,
        uint256 tokenId,
        uint256 amount,
        bytes32 fRights
    ) public {
        vm.assume(vault > address(1));
        if (amount % 2 == 0) vm.assume(rights == "");
        registry = new Registry();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        vm.startPrank(vault);
        registry.delegateERC721(delegate, contract_, tokenId, rights, enable);
        registry.delegateERC20(delegate, contract_, amount, rights, enable);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        // Check all case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, enable);
        vm.stopPrank();
        if (enable) assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), type(uint256).max);
        else assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        if (rights == "") assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, fRights), type(uint256).max);
        else if (rights != fRights) assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, fRights), 0);
        // Revoke all then check contract case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, enable);
        vm.stopPrank();
        if (enable) assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), type(uint256).max);
        else assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        if (rights == "") assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, fRights), type(uint256).max);
        else if (rights != fRights) assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, fRights), 0);
        // Revoke contract then check for ERC1155 case
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        vm.startPrank(vault);
        registry.delegateERC1155(delegate, contract_, tokenId, amount, rights, enable);
        vm.stopPrank();
        if (enable) assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), amount);
        else assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        if (rights == "") assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, fRights), amount);
        else if (rights != fRights) assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, fRights), 0);
        // Revoke and check false
        vm.startPrank(vault);
        registry.delegateERC1155(delegate, contract_, tokenId, amount, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        // Check bubble up for all and erc1155
        vm.assume(amount < type(uint256).max);
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, true);
        registry.delegateERC1155(delegate, contract_, tokenId, amount, rights, true);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), type(uint256).max);
        // Revoke all then check bubble up for contract
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), amount);
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, true);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), type(uint256).max);
        // Revoke and check false
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, false);
        registry.delegateERC1155(delegate, contract_, tokenId, amount, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
    }
}
