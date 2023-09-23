// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {IDelegateRegistry as IRegistry} from "src/IDelegateRegistry.sol";
import {DelegateRegistry as Registry} from "src/DelegateRegistry.sol";
import {RegistryStorage as Storage} from "src/libraries/RegistryStorage.sol";
import {RegistryHashes as Hashes} from "src/libraries/RegistryHashes.sol";
import {RegistryHarness as Harness} from "./tools/RegistryHarness.sol";

contract RegistryUnitTests is Test {
    Harness public harness;
    Registry public registry;
    bool everEnabled = false;

    function setUp() public {
        harness = new Harness();
        registry = new Registry();
        everEnabled = false;
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

    function _multicallNegativeCases(address vault, address delegate, bytes32 hash, uint8 position, uint256 tokenId) internal pure returns (bytes[] memory data) {
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
        bytes32 hash = Hashes.allHash(vault, rights, delegate);
        // Hashes should not exist yet
        _checkHashes(vault, delegate, hash, false);
        // Storage should not exist yet
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        // Loop over this test
        for (uint256 i = 0; i < n; i++) {
            if (enable) everEnabled = true;
            // Test correct event emitted
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit DelegateAll(vault, delegate, rights, enable);
            harness.delegateAll(delegate, rights, enable);
            vm.stopPrank();
            // Hashes should now exist regardless of true or false
            if (everEnabled) _checkHashes(vault, delegate, hash, true);
            else _checkHashes(vault, delegate, hash, false);
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
            if (everEnabled) {
                _checkStorage(0, address(0), delegate, hash, rights, 0, address(1));
            } else {
                _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
            }
            // Randomize enable for next loop
            enable = uint256(keccak256(abi.encode(i, vault, delegate))) % 2 == 0;
        }
    }

    event DelegateContract(address indexed vault, address indexed delegate, address indexed contract_, bytes32 rights, bool enable);

    function testDelegateContract(address vault, address delegate, address contract_, bytes32 rights, bool enable, uint256 n) public {
        vm.assume(vault > address(1) && n > 0 && n < 10);
        harness = new Harness();
        bytes32 hash = Hashes.contractHash(vault, rights, delegate, contract_);
        _checkHashes(vault, delegate, hash, false);
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        for (uint256 i = 0; i < n; i++) {
            if (enable) everEnabled = true;
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit DelegateContract(vault, delegate, contract_, rights, enable);
            harness.delegateContract(delegate, contract_, rights, enable);
            vm.stopPrank();
            if (everEnabled) _checkHashes(vault, delegate, hash, true);
            else _checkHashes(vault, delegate, hash, false);
            if (enable) {
                _checkStorage(0, contract_, delegate, hash, rights, 0, vault);
                vm.startPrank(vault);
                vm.expectEmit(true, true, true, true, address(harness));
                emit DelegateContract(vault, delegate, contract_, rights, false);
                harness.delegateContract(delegate, contract_, rights, false);
                vm.stopPrank();
                _checkHashes(vault, delegate, hash, true);
            }
            if (everEnabled) {
                _checkStorage(0, contract_, delegate, hash, rights, 0, address(1));
            } else {
                _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
            }
            enable = uint256(keccak256(abi.encode(i, vault, delegate))) % 2 == 0;
        }
    }

    event DelegateERC721(address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, bytes32 rights, bool enable);

    function testDelegateERC721(address vault, address delegate, address contract_, uint256 tokenId, bytes32 rights, bool enable, uint256 n) public {
        vm.assume(vault > address(1) && n > 0 && n < 10);
        harness = new Harness();
        bytes32 hash = Hashes.erc721Hash(vault, rights, delegate, tokenId, contract_);
        _checkHashes(vault, delegate, hash, false);
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        for (uint256 i = 0; i < n; i++) {
            if (enable) everEnabled = true;
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit DelegateERC721(vault, delegate, contract_, tokenId, rights, enable);
            harness.delegateERC721(delegate, contract_, tokenId, rights, enable);
            vm.stopPrank();
            if (everEnabled) _checkHashes(vault, delegate, hash, true);
            else _checkHashes(vault, delegate, hash, false);
            if (enable) {
                _checkStorage(0, contract_, delegate, hash, rights, tokenId, vault);
                vm.startPrank(vault);
                vm.expectEmit(true, true, true, true, address(harness));
                emit DelegateERC721(vault, delegate, contract_, tokenId, rights, false);
                harness.delegateERC721(delegate, contract_, tokenId, rights, false);
                vm.stopPrank();
                _checkHashes(vault, delegate, hash, true);
            }
            if (everEnabled) {
                _checkStorage(0, contract_, delegate, hash, rights, tokenId, address(1));
            } else {
                _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
            }
            enable = uint256(keccak256(abi.encode(i, vault, delegate))) % 2 == 0;
        }
    }

    event DelegateERC20(address indexed vault, address indexed delegate, address indexed contract_, bytes32 rights, uint256 amount);

    function testDelegateERC20(address vault, address delegate, address contract_, uint256 amount, bytes32 rights, uint256 n) public {
        vm.assume(vault > address(1) && n > 0 && n < 10);
        harness = new Harness();
        bytes32 hash = Hashes.erc20Hash(vault, rights, delegate, contract_);
        _checkHashes(vault, delegate, hash, false);
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        for (uint256 i = 0; i < n; i++) {
            if (amount != 0) everEnabled = true;
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit DelegateERC20(vault, delegate, contract_, rights, amount);
            harness.delegateERC20(delegate, contract_, rights, amount);
            vm.stopPrank();
            if (everEnabled) _checkHashes(vault, delegate, hash, true);
            else _checkHashes(vault, delegate, hash, false);
            if (amount != 0) {
                _checkStorage(amount, contract_, delegate, hash, rights, 0, vault);
                vm.startPrank(vault);
                emit DelegateERC20(vault, delegate, contract_, rights, 0);
                harness.delegateERC20(delegate, contract_, rights, 0);
                vm.stopPrank();
                _checkHashes(vault, delegate, hash, true);
            }
            if (everEnabled) _checkStorage(0, contract_, delegate, hash, rights, 0, address(1));
            else _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
            amount = uint256(keccak256(abi.encode(i, amount)));
        }
    }

    event DelegateERC1155(address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, bytes32 rights, uint256 amount);

    function testDelegateERC1155(address vault, address delegate, address contract_, uint256 tokenId, uint256 amount, bytes32 rights) public {
        vm.assume(vault > address(1));
        harness = new Harness();
        bytes32 hash = Hashes.erc1155Hash(vault, rights, delegate, tokenId, contract_);
        _checkHashes(vault, delegate, hash, false);
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        for (uint256 i = 0; i < (1 + amount % 10); i++) {
            if (amount != 0) everEnabled = true;
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit DelegateERC1155(vault, delegate, contract_, tokenId, rights, amount);
            harness.delegateERC1155(delegate, contract_, tokenId, rights, amount);
            vm.stopPrank();
            if (everEnabled) _checkHashes(vault, delegate, hash, true);
            else _checkHashes(vault, delegate, hash, false);
            if (amount != 0) {
                _checkStorage(amount, contract_, delegate, hash, rights, tokenId, vault);
                vm.startPrank(vault);
                emit DelegateERC1155(vault, delegate, contract_, tokenId, rights, 0);
                harness.delegateERC1155(delegate, contract_, tokenId, rights, 0);
                vm.stopPrank();
                _checkHashes(vault, delegate, hash, true);
            }
            if (everEnabled) {
                _checkStorage(0, contract_, delegate, hash, rights, tokenId, address(1));
            } else {
                _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
            }
            amount = uint256(keccak256(abi.encode(i, amount)));
        }
    }

    function _checkHashes(address vault, address delegate, bytes32 hash, bool on) internal {
        if (on) {
            assertEq(harness.exposedOutgoingDelegationHashes(vault).length, 1);
            assertEq(harness.exposedOutgoingDelegationHashes(vault)[0], hash);
            assertEq(harness.exposedIncomingDelegationHashes(delegate).length, 1);
            assertEq(harness.exposedIncomingDelegationHashes(delegate)[0], hash);
        } else {
            assertEq(harness.exposedOutgoingDelegationHashes(vault).length, 0);
            assertEq(harness.exposedIncomingDelegationHashes(delegate).length, 0);
        }
    }

    function _checkStorage(uint256 amount, address contract_, address delegate, bytes32 hash, bytes32 rights, uint256 tokenId, address vault) internal {
        assertEq(harness.exposedDelegations(hash).length, Storage.POSITIONS_AMOUNT + 1);
        assertEq(address(uint160(uint256(harness.exposedDelegations(hash)[Storage.POSITIONS_SECOND_PACKED]))), delegate);
        assertEq(address(uint160(uint256(harness.exposedDelegations(hash)[Storage.POSITIONS_FIRST_PACKED]))), vault);
        assertEq(harness.exposedDelegations(hash)[Storage.POSITIONS_RIGHTS], rights);
        assertEq(uint256(harness.exposedDelegations(hash)[Storage.POSITIONS_TOKEN_ID]), tokenId);
        assertEq(uint256(harness.exposedDelegations(hash)[Storage.POSITIONS_AMOUNT]), amount);
        // Check token contract
        uint256 contractFirst8Bytes = ((uint256(harness.exposedDelegations(hash)[Storage.POSITIONS_FIRST_PACKED]) >> 160) << 96);
        uint256 contractLast12Bytes = (uint256(harness.exposedDelegations(hash)[Storage.POSITIONS_SECOND_PACKED]) >> 160);
        address decodedContract = address(uint160(contractFirst8Bytes | contractLast12Bytes));
        assertEq(decodedContract, contract_);
    }

    /**
     * ----------- consumables -----------
     */

    function testCheckDelegateForAll(address vault, bytes32 rights, bool enable, address delegate, address contract_, uint256 tokenId, uint256 amount, bytes32 fRights) public {
        vm.assume(vault > address(1));
        // new registry
        registry = new Registry();
        // Should return false for any input
        assertFalse(registry.checkDelegateForAll(delegate, vault, rights));
        // Should return false if delegations are made for all other types
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, enable);
        registry.delegateERC721(delegate, contract_, tokenId, rights, enable);
        registry.delegateERC20(delegate, contract_, rights, amount);
        registry.delegateERC1155(delegate, contract_, tokenId, rights, amount);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForAll(delegate, vault, rights));
        // delegateAll and test
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, enable);
        vm.stopPrank();
        if (enable) {
            assertTrue(registry.checkDelegateForAll(delegate, vault, rights));
        } else {
            assertFalse(registry.checkDelegateForAll(delegate, vault, rights));
            assertFalse(registry.checkDelegateForAll(delegate, vault, fRights));
        }
        if (enable && (rights == "" || rights == fRights)) assertTrue(registry.checkDelegateForAll(delegate, vault, fRights));
        else assertFalse(registry.checkDelegateForAll(delegate, vault, fRights));
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForAll(delegate, vault, fRights));
    }

    function testCheckDelegateForContract(address vault, bytes32 rights, bool enable, address delegate, address contract_, uint256 tokenId, uint256 amount, bytes32 fRights)
        public
    {
        vm.assume(vault > address(1));
        registry = new Registry();
        assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, rights));
        vm.startPrank(vault);
        registry.delegateERC721(delegate, contract_, tokenId, rights, enable);
        registry.delegateERC20(delegate, contract_, rights, amount);
        registry.delegateERC1155(delegate, contract_, tokenId, rights, amount);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, rights));
        // check all case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, enable);
        vm.stopPrank();
        _checkDelegateForContractLogic(enable, delegate, vault, contract_, rights, fRights);
        // revoke all case, assert false, then check contract_ case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, rights));
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, enable);
        vm.stopPrank();
        _checkDelegateForContractLogic(enable, delegate, vault, contract_, rights, fRights);
        // revoke and check false
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, false);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, rights));
    }

    function _checkDelegateForContractLogic(bool enable, address delegate, address vault, address contract_, bytes32 rights, bytes32 fRights) internal {
        if (enable) {
            assertTrue(registry.checkDelegateForContract(delegate, vault, contract_, rights));
        } else {
            assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, rights));
            assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, fRights));
        }
        if (enable && (rights == "" || rights == fRights)) assertTrue(registry.checkDelegateForContract(delegate, vault, contract_, fRights));
        else assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, fRights));
    }

    function testCheckDelegateForERC721(address vault, bytes32 rights, bool enable, address delegate, address contract_, uint256 tokenId, uint256 amount, bytes32 fRights) public {
        vm.assume(vault > address(1));
        registry = new Registry();
        assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        vm.startPrank(vault);
        registry.delegateERC20(delegate, contract_, rights, amount);
        registry.delegateERC1155(delegate, contract_, tokenId, rights, amount);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        // check all case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, enable);
        vm.stopPrank();
        _checkDelegateForERC721Logic(enable, delegate, vault, contract_, tokenId, rights, fRights);
        // Revoke all then check contract case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, enable);
        vm.stopPrank();
        _checkDelegateForERC721Logic(enable, delegate, vault, contract_, tokenId, rights, fRights);
        // Revoke contract then check 721 case
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, false);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        vm.startPrank(vault);
        registry.delegateERC721(delegate, contract_, tokenId, rights, enable);
        vm.stopPrank();
        _checkDelegateForERC721Logic(enable, delegate, vault, contract_, tokenId, rights, fRights);
        // revoke and check false
        vm.startPrank(vault);
        registry.delegateERC721(delegate, contract_, tokenId, rights, false);
        vm.stopPrank();
        assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
    }

    function _checkDelegateForERC721Logic(bool enable, address delegate, address vault, address contract_, uint256 tokenId, bytes32 rights, bytes32 fRights) internal {
        if (enable) {
            assertTrue(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        } else {
            assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
            assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, fRights));
        }
        if (enable && (rights == "" || rights == fRights)) assertTrue(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, fRights));
        else assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, tokenId, fRights));
    }

    function testCheckDelegateForERC20(address vault, bytes32 rights, bool enable, address delegate, address contract_, uint256 tokenId, uint256 amount, bytes32 fRights) public {
        vm.assume(vault > address(1));
        registry = new Registry();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        vm.startPrank(vault);
        registry.delegateERC721(delegate, contract_, tokenId, rights, enable);
        registry.delegateERC1155(delegate, contract_, tokenId, rights, amount);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        // Check all case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, enable);
        vm.stopPrank();
        _checkDelegateForERC20Logic(delegate, vault, contract_, rights, fRights, enable ? type(uint256).max : 0);
        // Revoke all case then check contract case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, enable);
        vm.stopPrank();
        _checkDelegateForERC20Logic(delegate, vault, contract_, rights, fRights, enable ? type(uint256).max : 0);
        // Revoke contract case then check for ERC20 case
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        vm.startPrank(vault);
        registry.delegateERC20(delegate, contract_, rights, amount);
        vm.stopPrank();
        _checkDelegateForERC20Logic(delegate, vault, contract_, rights, fRights, amount);
        // Revoke and check false
        vm.startPrank(vault);
        registry.delegateERC20(delegate, contract_, rights, 0);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
        // Check bubble up for all and erc20
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, true);
        registry.delegateERC20(delegate, contract_, rights, amount);
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
        registry.delegateERC20(delegate, contract_, rights, 0);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
    }

    function _checkDelegateForERC20Logic(address delegate, address vault, address contract_, bytes32 rights, bytes32 fRights, uint256 amount) internal {
        if (amount != 0) {
            assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), amount);
        } else {
            assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
            assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, fRights), 0);
        }
        if (amount != 0 && (rights == "" || rights == fRights)) assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, fRights), amount);
        else assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, fRights), 0);
    }

    function testCheckDelegateForERC1155(address vault, bytes32 rights, bool enable, address delegate, address contract_, uint256 tokenId, uint256 amount, bytes32 fRights)
        public
    {
        vm.assume(vault > address(1));
        registry = new Registry();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        vm.startPrank(vault);
        registry.delegateERC721(delegate, contract_, tokenId, rights, enable);
        registry.delegateERC20(delegate, contract_, rights, amount);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        // Check all case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, enable);
        vm.stopPrank();
        _checkDelegateForERC1155Logic(delegate, vault, contract_, tokenId, rights, fRights, enable ? type(uint256).max : 0);
        // Revoke all then check contract case
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, enable);
        vm.stopPrank();
        _checkDelegateForERC1155Logic(delegate, vault, contract_, tokenId, rights, fRights, enable ? type(uint256).max : 0);
        // Revoke contract then check for ERC1155 case
        vm.startPrank(vault);
        registry.delegateContract(delegate, contract_, rights, false);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        vm.startPrank(vault);
        registry.delegateERC1155(delegate, contract_, tokenId, rights, amount);
        vm.stopPrank();
        _checkDelegateForERC1155Logic(delegate, vault, contract_, tokenId, rights, fRights, amount);
        // Revoke and check false
        vm.startPrank(vault);
        registry.delegateERC1155(delegate, contract_, tokenId, rights, 0);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
        // Check bubble up for all and erc1155
        vm.startPrank(vault);
        registry.delegateAll(delegate, rights, true);
        registry.delegateERC1155(delegate, contract_, tokenId, rights, amount);
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
        registry.delegateERC1155(delegate, contract_, tokenId, rights, 0);
        vm.stopPrank();
        assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
    }

    function _checkDelegateForERC1155Logic(address delegate, address vault, address contract_, uint256 tokenId, bytes32 rights, bytes32 fRights, uint256 amount) internal {
        if (amount != 0) {
            assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), amount);
        } else {
            assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
            assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, fRights), 0);
        }
        if (amount != 0 && (rights == "" || rights == fRights)) assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, fRights), amount);
        else assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, tokenId, fRights), 0);
    }

    /**
     * ----------- TODO: Enumerations -----------
     */

    function testGetValidDelegationsFromHashesEquivalence(address from, bytes32 rights, address to, uint256 amount, uint256 tokenId, address contract_, bool[5] calldata enables)
        public
    {
        vm.assume(from > address(1) && amount > 0);
        bytes32[] memory delegationHashes = new bytes32[](5);
        vm.startPrank(from);
        delegationHashes[0] = harness.delegateAll(to, rights, enables[0]);
        delegationHashes[1] = harness.delegateContract(to, contract_, rights, enables[1]);
        delegationHashes[2] = harness.delegateERC721(to, contract_, tokenId, rights, enables[2]);
        delegationHashes[3] = harness.delegateERC20(to, contract_, rights, enables[3] ? amount : 0);
        delegationHashes[4] = harness.delegateERC1155(to, contract_, tokenId, rights, enables[4] ? amount : 0);
        vm.stopPrank();
        uint256 numberOfEnables;
        for (uint256 i = 0; i < 5; i++) {
            if (enables[i]) {
                numberOfEnables++;
            }
        }
        IRegistry.Delegation[] memory validDelegations = harness.exposedGetValidDelegationsFromHashes(delegationHashes);
        IRegistry.Delegation[] memory incomingDelegations = harness.getIncomingDelegations(to);
        IRegistry.Delegation[] memory outgoingDelegations = harness.getOutgoingDelegations(from);
        assertEq(validDelegations.length, numberOfEnables);
        assertEq(incomingDelegations.length, numberOfEnables);
        assertEq(outgoingDelegations.length, numberOfEnables);
        assertEq(keccak256(abi.encode(validDelegations)), keccak256(abi.encode(incomingDelegations)));
        assertEq(keccak256(abi.encode(validDelegations)), keccak256(abi.encode(outgoingDelegations)));
        assertEq(keccak256(abi.encode(incomingDelegations)), keccak256(abi.encode(outgoingDelegations)));
    }

    function testGetValidDelegationHashesFromHashes(address from, bytes32 rights, address to, uint256 amount, uint256 tokenId, address contract_, bool[5] calldata enables)
        public
    {
        vm.assume(amount > 0);
        bytes32[] memory delegationHashes = new bytes32[](5);
        vm.startPrank(from);
        delegationHashes[0] = harness.delegateAll(to, rights, enables[0]);
        delegationHashes[1] = harness.delegateContract(to, contract_, rights, enables[1]);
        delegationHashes[2] = harness.delegateERC721(to, contract_, tokenId, rights, enables[2]);
        delegationHashes[3] = harness.delegateERC20(to, contract_, rights, enables[3] == true ? amount : 0);
        delegationHashes[4] = harness.delegateERC1155(to, contract_, tokenId, rights, enables[4] == true ? amount : 0);
        vm.stopPrank();
        if (from == Storage.DELEGATION_EMPTY || from == Storage.DELEGATION_REVOKED) {
            assertEq(harness.exposedGetValidDelegationHashesFromHashes(delegationHashes).length, 0);
        } else {
            bytes32[] memory hashesFromHashes = harness.exposedGetValidDelegationHashesFromHashes(delegationHashes);
            uint256 numberOfEnables;
            for (uint256 i = 0; i < 5; i++) {
                if (enables[i]) {
                    assertEq(hashesFromHashes[numberOfEnables], delegationHashes[i]);
                    numberOfEnables++;
                }
            }
            assertEq(harness.exposedGetValidDelegationHashesFromHashes(delegationHashes).length, numberOfEnables);
        }
    }

    function testGetDelegationsFromHashesSpecialFrom(address from, bytes32 rights, address to, uint256 amount, uint256 tokenId, address contract_) public {
        vm.assume(amount > 0);
        bytes32[] memory delegationHashes = new bytes32[](5);
        vm.startPrank(from);
        delegationHashes[0] = registry.delegateAll(to, rights, true);
        harness.delegateAll(to, rights, true);
        delegationHashes[1] = registry.delegateContract(to, contract_, rights, true);
        harness.delegateContract(to, contract_, rights, true);
        delegationHashes[2] = registry.delegateERC721(to, contract_, tokenId, rights, true);
        harness.delegateERC721(to, contract_, tokenId, rights, true);
        delegationHashes[3] = registry.delegateERC20(to, contract_, rights, amount);
        harness.delegateERC20(to, contract_, rights, amount);
        delegationHashes[4] = registry.delegateERC1155(to, contract_, tokenId, rights, amount);
        harness.delegateERC1155(to, contract_, tokenId, rights, amount);
        vm.stopPrank();
        IRegistry.Delegation[] memory emptyDelegations = new IRegistry.Delegation[](5);
        IRegistry.Delegation[] memory getDelegations = registry.getDelegationsFromHashes(delegationHashes);
        IRegistry.Delegation[] memory getHarnessDelegations = harness.exposedGetValidDelegationsFromHashes(delegationHashes);

        assertEq(emptyDelegations.length, getDelegations.length);
        if (from == Storage.DELEGATION_EMPTY || from == Storage.DELEGATION_REVOKED) {
            assertEq(keccak256(abi.encode(emptyDelegations)), keccak256(abi.encode(getDelegations)));
            assertEq(getHarnessDelegations.length, 0);
        } else {
            assertFalse(keccak256(abi.encode(emptyDelegations)) == keccak256(abi.encode(getDelegations)));
            assertFalse(keccak256(abi.encode(emptyDelegations)) == keccak256(abi.encode(getHarnessDelegations)));
            assertEq(emptyDelegations.length, getHarnessDelegations.length);
        }
    }

    /**
     * ----------- storage access -----------
     */

    function testReadSlot(bytes32 slot, bytes32 data) public {
        registry = new Registry();
        vm.store(address(registry), slot, data);
        assertEq(data, registry.readSlot(slot));
    }

    function testReadSlots(uint256 slotSeed, bytes32[] calldata data) public {
        registry = new Registry();
        bytes32[] memory slots = new bytes32[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            slots[i] = keccak256(abi.encode(slotSeed, i));
            vm.store(address(registry), slots[i], data[i]);
        }
        bytes32[] memory receivedData = registry.readSlots(slots);
        assertEq(receivedData.length, data.length);
        for (uint256 i = 0; i < data.length; i++) {
            assertEq(receivedData[i], data[i]);
        }
    }

    /**
     * ----------- ERC165 -----------
     */

    function testSupportsInterface(bytes32 notInterface) public {
        bytes4 formattedNotInterface = bytes4(notInterface);
        vm.assume(formattedNotInterface != type(IRegistry).interfaceId);
        vm.assume(formattedNotInterface != 0x01ffc9a7);
        assertFalse(registry.supportsInterface(formattedNotInterface));
        assertTrue(registry.supportsInterface(type(IRegistry).interfaceId));
        assertTrue(registry.supportsInterface(0x01ffc9a7));
    }

    /**
     * ----------- Internal helper functions -----------
     */

    function testPushDelegationHashes(uint256 seed, uint256 n) public {
        vm.assume(n < 100);
        address[] memory fromAddresses = new address[](n);
        address[] memory toAddresses = new address[](n);
        bytes32[] memory delegationHashes = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            fromAddresses[i] = address(uint160(uint256(keccak256(abi.encode("from", i)))));
            toAddresses[i] = address(uint160(uint256(keccak256(abi.encode("to", i)))));
            delegationHashes[i] = keccak256(abi.encode("delegationHash", i));
            harness.exposedPushDelegationHashes(fromAddresses[i], toAddresses[i], delegationHashes[i]);
            assertEq(harness.exposedIncomingDelegationHashes(toAddresses[i])[0], delegationHashes[i]);
            assertEq(harness.exposedOutgoingDelegationHashes(fromAddresses[i])[0], delegationHashes[i]);
            assertEq(harness.exposedIncomingDelegationHashes(toAddresses[i]).length, 1);
            assertEq(harness.exposedOutgoingDelegationHashes(fromAddresses[i]).length, 1);
            if (i != 0) {
                uint256 spotCheck = seed % i;
                assertEq(harness.exposedIncomingDelegationHashes(toAddresses[spotCheck])[0], delegationHashes[spotCheck]);
                assertEq(harness.exposedOutgoingDelegationHashes(fromAddresses[spotCheck])[0], delegationHashes[spotCheck]);
                assertEq(harness.exposedIncomingDelegationHashes(toAddresses[spotCheck]).length, 1);
                assertEq(harness.exposedOutgoingDelegationHashes(fromAddresses[spotCheck]).length, 1);
            }
        }
    }

    function testWriteDelegationBytes32(bytes32 location, bytes32 notLocation, bytes32 data) public {
        harness.exposedWriteDelegation(location, Storage.POSITIONS_FIRST_PACKED, data);
        bytes32 formattedLocation = bytes32(uint256(location) + Storage.POSITIONS_FIRST_PACKED);
        bytes32 slotContains = harness.readSlot(formattedLocation);
        assertEq(slotContains, data);
        bytes32 notSlotContains = harness.readSlot(notLocation);
        if (notLocation == formattedLocation) assertEq(notSlotContains, data);
        else assertEq(notSlotContains, "");
    }

    function testWriteDelegationUint256(bytes32 location, bytes32 notLocation, uint256 data) public {
        harness.exposedWriteDelegation(location, Storage.POSITIONS_FIRST_PACKED, data);
        bytes32 formattedLocation = bytes32(uint256(location) + Storage.POSITIONS_FIRST_PACKED);
        uint256 slotContains = uint256(harness.readSlot(formattedLocation));
        assertEq(slotContains, data);
        uint256 notSlotContains = uint256(harness.readSlot(notLocation));
        if (notLocation == formattedLocation) assertEq(notSlotContains, data);
        else assertEq(notSlotContains, 0);
    }

    // @dev see IDelegateRegistry for packed layout
    function testWriteDelegationAddresses(bytes32 location, address from, address to, address contract_) public {
        vm.assume(uint256(location) < type(uint256).max - 10); // Prevents overflow
        harness.exposedWriteDelegationAddresses(location, from, to, contract_);
        uint256 contractUint256 = uint256(uint160(contract_));
        uint256 first8BytesContract = (contractUint256 >> 96);
        uint256 last12BytesContract = ((contractUint256 << 160) >> 160);
        bytes32 formattedLocation1 = bytes32(uint256(location) + Storage.POSITIONS_FIRST_PACKED);
        bytes32 formattedLocation2 = bytes32(uint256(location) + Storage.POSITIONS_SECOND_PACKED);
        bytes32 slot1 = harness.readSlot(formattedLocation1);
        bytes32 slot2 = harness.readSlot(formattedLocation2);
        // Checking from, to, contract_ here
        assertEq(from, address(uint160(uint256(slot1))));
        assertEq(to, address(uint160(uint256(slot2))));
        assertEq(first8BytesContract, (uint256(slot1) >> 160));
        assertEq(last12BytesContract, (uint256(slot2) >> 160));
    }

    /// TODO: enumeration helper functions

    function testLoadDelegationBytes32(bytes32 location, bytes32 data) public {
        bytes32 formattedLocation = bytes32(uint256(location) + Storage.POSITIONS_FIRST_PACKED);
        vm.store(address(harness), formattedLocation, data);
        assertEq(data, harness.exposedLoadDelegationBytes32(location, Storage.POSITIONS_FIRST_PACKED));
    }

    function testLoadDelegationUint256(bytes32 location, uint256 data) public {
        bytes32 formattedLocation = bytes32(uint256(location) + Storage.POSITIONS_FIRST_PACKED);
        vm.store(address(harness), formattedLocation, bytes32(data));
        assertEq(data, harness.exposedLoadDelegationUint(location, Storage.POSITIONS_FIRST_PACKED));
    }

    function testLoadFrom(bytes32 location, uint256 from) public {
        bytes32 formattedLocation = bytes32(uint256(location) + Storage.POSITIONS_FIRST_PACKED);
        vm.store(address(harness), formattedLocation, bytes32(from));
        assertEq(address(uint160(((from << 96) >> 96))), harness.exposedLoadFrom(location));
    }

    function testLoadDelegationAddresses(bytes32 location, address from, address to, address contract_) public {
        harness.exposedWriteDelegationAddresses(location, from, to, contract_);
        (address checkFrom, address checkTo, address checkContract) = harness.exposedLoadDelegationAddresses(location);
        assertEq(from, checkFrom);
        assertEq(to, checkTo);
        assertEq(contract_, checkContract);
    }

    function testValidateFrom(bytes32 location, address from, bytes32 notLocation, address notFrom) public {
        bytes32 formattedLocation = bytes32(uint256(location) + Storage.POSITIONS_FIRST_PACKED);
        vm.store(address(harness), formattedLocation, bytes32(uint256(uint160(from))));
        vm.assume(formattedLocation != notLocation);
        vm.assume(from != notFrom && notFrom != address(0) && from != address(0));
        assertTrue(harness.exposedValidateFrom(formattedLocation, from));
        assertFalse(harness.exposedValidateFrom(formattedLocation, notFrom));
        assertFalse(harness.exposedValidateFrom(notLocation, from));
        assertFalse(harness.exposedValidateFrom(notLocation, notFrom));
    }
}
