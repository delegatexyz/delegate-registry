// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {DelegateRegistry as Registry} from "src/DelegateRegistry.sol";
import {RegistryHashes as Hashes} from "src/libraries/RegistryHashes.sol";
import {IDelegateRegistry as IRegistry} from "src/IDelegateRegistry.sol";
import {RegistryHarness as Harness} from "./tools/RegistryHarness.sol";

contract DelegateSingularIntegrations is Test {
    Registry public registry;
    Harness public harness;

    function setUp() public {
        harness = new Harness();
        registry = new Registry();
    }

    address _vault;
    address _fVault;
    address _delegate;
    address _fDelegate;
    address _contract;
    address _fContract;
    uint256 _tokenId;
    uint256 _fTokenId;
    bytes32 _rights;
    bytes32 _fRights;
    uint256 _amount;
    IRegistry.DelegationType _type;
    bool _enable;
    bool _multicall;

    function _setParameters(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        uint256 tokenId,
        uint256 fTokenId,
        bytes32 rights,
        bytes32 fRights,
        uint256 amount,
        IRegistry.DelegationType type_
    ) internal {
        vm.assume(vault > address(1) && fVault > address(1));
        vm.assume(vault != fVault && vault != delegate && vault != fDelegate && vault != contract_ && vault != fContract);
        vm.assume(fVault != delegate && fVault != fDelegate && fVault != contract_ && fVault != fContract);
        vm.assume(delegate != fDelegate && delegate != contract_ && delegate != fContract);
        vm.assume(fDelegate != contract_ && fDelegate != fContract);
        vm.assume(contract_ != fContract);
        vm.assume(rights != fRights);
        vm.assume(tokenId != fTokenId);
        _vault = vault;
        _fVault = fVault;
        _delegate = delegate;
        _fDelegate = fDelegate;
        _contract = contract_;
        _fContract = fContract;
        _tokenId = tokenId;
        _fTokenId = fTokenId;
        _rights = rights;
        _fRights = fRights;
        _amount = amount;
        _type = type_;
        uint256 randomize = uint256(keccak256(abi.encode(vault, fVault, delegate, fDelegate, contract_, fContract, tokenId, fTokenId, rights, fRights, amount, type_)));
        _enable = randomize % 2 == 1;
        _multicall = uint256(keccak256(abi.encode(randomize))) % 2 == 1;
    }

    // Tests delegateAll case with non-default rights
    function testDelegateAllSpecificRights(address vault, address fVault, address delegate, address fDelegate, bytes32 rights, bytes32 fRights, address fContract, uint256 fTokenId)
        public
    {
        vm.assume(rights != "");
        _setParameters(vault, fVault, delegate, fDelegate, address(0), fContract, 0, fTokenId, rights, fRights, 0, IRegistry.DelegationType.ALL);
        _testDelegateAll();
    }

    // Tests delegateAll case with default rights
    function testDelegateAllDefault(address vault, address fVault, address delegate, address fDelegate, bytes32 fRights, address fContract, uint256 fTokenId) public {
        bytes32 rights = "";
        _setParameters(vault, fVault, delegate, fDelegate, address(0), fContract, 0, fTokenId, rights, fRights, 0, IRegistry.DelegationType.ALL);
        _testDelegateAll();
    }

    function _testDelegateAll() internal {
        registry = new Registry();
        // Create delegation
        vm.startPrank(_vault);
        bytes[] memory batchData = new bytes[](1);
        batchData[0] = abi.encodeWithSelector(Registry.delegateAll.selector, _delegate, _rights, _enable);
        if (_multicall) registry.multicall(batchData);
        else registry.delegateAll(_delegate, _rights, _enable);
        vm.stopPrank();
        // Check consumables and read
        _checkConsumableAll();
        _checkFalseConsumableCases();
        _checkReadAll();
        _checkReadCases();
        // Revoke and check logic again
        vm.startPrank(_vault);
        batchData[0] = abi.encodeWithSelector(Registry.delegateAll.selector, _delegate, _rights, false);
        if (_multicall) registry.multicall(batchData);
        else registry.delegateAll(_delegate, _rights, false);
        vm.stopPrank();
        _enable = false;
        _checkConsumableAll();
        _checkFalseConsumableCases();
        _checkReadAll();
        _checkReadCases();
    }

    function _checkConsumableAll() internal {
        // Check logic outcomes of checkDelegateForAll
        assertTrue(registry.checkDelegateForAll(_delegate, _vault, _rights) == _enable);
        if (_rights == "") assertTrue(registry.checkDelegateForAll(_delegate, _vault, _fRights) == _enable);
        else assertFalse(registry.checkDelegateForAll(_delegate, _vault, _fRights));
        // Check logic outcomes of checkDelegateForContract
        assertTrue(registry.checkDelegateForContract(_delegate, _vault, _fContract, _rights) == _enable);
        if (_rights == "") assertTrue(registry.checkDelegateForContract(_delegate, _vault, _fContract, _fRights) == _enable);
        else assertFalse(registry.checkDelegateForContract(_delegate, _vault, _fContract, _fRights));
        // Check logic outcomes of checkDelegateForERC721
        assertTrue(registry.checkDelegateForERC721(_delegate, _vault, _fContract, _fTokenId, _rights) == _enable);
        if (_rights == "") {
            assertTrue(registry.checkDelegateForERC721(_delegate, _vault, _fContract, _fTokenId, _fRights) == _enable);
        } else {
            assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _fContract, _fTokenId, _fRights));
        }
        // Check logic outcomes of checkDelegateForERC20
        assertTrue((registry.checkDelegateForERC20(_delegate, _vault, _fContract, _rights) == type(uint256).max) == _enable);
        if (_rights == "") {
            assertTrue((registry.checkDelegateForERC20(_delegate, _vault, _fContract, _fRights) == type(uint256).max) == _enable);
        } else {
            assertEq(registry.checkDelegateForERC20(_delegate, _vault, _fContract, _fRights), 0);
        }
        // Check logic outcomes of checkDelegateForERC1155
        assertTrue((registry.checkDelegateForERC1155(_delegate, _vault, _fContract, _fTokenId, _rights) == type(uint256).max) == _enable);
        if (_rights == "") {
            assertTrue((registry.checkDelegateForERC1155(_delegate, _vault, _fContract, _fTokenId, _fRights) == type(uint256).max) == _enable);
        } else {
            assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _fContract, _fTokenId, _fRights), 0);
        }
    }

    function _checkReadAll() internal {
        bytes32 checkHash = Hashes.allHash(_vault, _rights, _delegate);
        // Check outcomes of getIncomingDelegationHashes
        assertEq(registry.getIncomingDelegationHashes(_delegate).length == 1, _enable);
        if (_enable) {
            assertEq(registry.getIncomingDelegationHashes(_delegate)[0], checkHash);
        }
        // Check outcomes of getOutgoingDelegationHashes
        assertEq(registry.getOutgoingDelegationHashes(_vault).length == 1, _enable);
        if (_enable) {
            assertEq(registry.getOutgoingDelegationHashes(_vault)[0], checkHash);
        }
        // Check outcomes of getDelegationsFromHashes
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = checkHash;
        assertEq(registry.getDelegationsFromHashes(hashes).length, 1);
        _checkDelegation(registry.getDelegationsFromHashes(hashes)[0]);
    }

    // Tests delegateContract case with non-default rights
    function testDelegateContractSpecificRights(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        bytes32 rights,
        bytes32 fRights,
        uint256 fTokenId
    ) public {
        vm.assume(rights != "");
        _setParameters(vault, fVault, delegate, fDelegate, contract_, fContract, 0, fTokenId, rights, fRights, 0, IRegistry.DelegationType.CONTRACT);
        _testDelegateContract();
    }

    // Tests delegateContract case with default rights
    function testDelegateContractDefault(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        bytes32 fRights,
        uint256 fTokenId
    ) public {
        bytes32 rights = "";
        _setParameters(vault, fVault, delegate, fDelegate, contract_, fContract, 0, fTokenId, rights, fRights, 0, IRegistry.DelegationType.CONTRACT);
        _testDelegateContract();
    }

    function _testDelegateContract() internal {
        registry = new Registry();
        // Create delegation
        vm.startPrank(_vault);
        bytes[] memory batchData = new bytes[](1);
        batchData[0] = abi.encodeWithSelector(Registry.delegateContract.selector, _delegate, _contract, _rights, _enable);
        if (_multicall) registry.multicall(batchData);
        else registry.delegateContract(_delegate, _contract, _rights, _enable);
        vm.stopPrank();
        // Check consumables and read
        _checkConsumableContract();
        _checkFalseConsumableCases();
        _checkFalseConsumableCasesBelowAll();
        _checkReadContract();
        _checkReadCases();
        // Revoke and check logic again
        vm.startPrank(_vault);
        batchData[0] = abi.encodeWithSelector(Registry.delegateContract.selector, _delegate, _contract, _rights, false);
        if (_multicall) registry.multicall(batchData);
        else registry.delegateContract(_delegate, _contract, _rights, false);
        vm.stopPrank();
        _enable = false;
        _checkConsumableContract();
        _checkFalseConsumableCases();
        _checkFalseConsumableCasesBelowAll();
        _checkReadContract();
        _checkReadCases();
    }

    function _checkConsumableContract() internal {
        // Check logic outcomes of checkDelegateForContract
        assertTrue(registry.checkDelegateForContract(_delegate, _vault, _contract, _rights) == _enable);
        if (_rights == "") {
            assertTrue(registry.checkDelegateForContract(_delegate, _vault, _contract, _fRights) == _enable);
        } else {
            assertFalse(registry.checkDelegateForContract(_delegate, _vault, _contract, _fRights));
        }
        // Check logic outcomes of checkDelegateForERC721
        assertTrue(registry.checkDelegateForERC721(_delegate, _vault, _contract, _fTokenId, _rights) == _enable);
        if (_rights == "") {
            assertTrue(registry.checkDelegateForERC721(_delegate, _vault, _contract, _fTokenId, _fRights) == _enable);
        } else {
            assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _contract, _fTokenId, _fRights));
        }
        // Check logic outcomes of checkDelegateForERC20
        assertTrue((registry.checkDelegateForERC20(_delegate, _vault, _contract, _rights) == type(uint256).max) == _enable);
        if (_rights == "") {
            assertTrue((registry.checkDelegateForERC20(_delegate, _vault, _contract, _fRights) == type(uint256).max) == _enable);
        } else {
            assertEq(registry.checkDelegateForERC20(_delegate, _vault, _contract, _fRights), 0);
        }
        // Check logic outcomes of checkDelegateForERC1155
        assertTrue((registry.checkDelegateForERC1155(_delegate, _vault, _contract, _fTokenId, _rights) == type(uint256).max) == _enable);
        if (_rights == "") {
            assertTrue((registry.checkDelegateForERC1155(_delegate, _vault, _contract, _fTokenId, _fRights) == type(uint256).max) == _enable);
        } else {
            assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _contract, _fTokenId, _fRights), 0);
        }
    }

    function _checkReadContract() internal {
        bytes32 checkHash = Hashes.contractHash(_vault, _rights, _delegate, _contract);
        // Check outcomes of getIncomingDelegationHashes
        assertEq(registry.getIncomingDelegationHashes(_delegate).length == 1, _enable);
        if (_enable) {
            assertEq(registry.getIncomingDelegationHashes(_delegate)[0], checkHash);
        }
        // Check outcomes of getOutgoingDelegationHashes
        assertEq(registry.getOutgoingDelegationHashes(_vault).length == 1, _enable);
        if (_enable) {
            assertEq(registry.getOutgoingDelegationHashes(_vault)[0], checkHash);
        }
        // Check outcomes of getDelegationsFromHashes
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = checkHash;
        assertEq(registry.getDelegationsFromHashes(hashes).length, 1);
        _checkDelegation(registry.getDelegationsFromHashes(hashes)[0]);
    }

    // Tests delegateERC721 case with non-default rights
    function testDelegateERC721SpecificRights(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        uint256 tokenId,
        uint256 fTokenId,
        bytes32 rights,
        bytes32 fRights
    ) public {
        vm.assume(rights != "");
        _setParameters(vault, fVault, delegate, fDelegate, contract_, fContract, tokenId, fTokenId, rights, fRights, 0, IRegistry.DelegationType.ERC721);
        _testDelegateERC721();
    }

    // Tests delegateERC721 case with default rights
    function testDelegateERC721Default(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        uint256 tokenId,
        uint256 fTokenId,
        bytes32 fRights
    ) public {
        bytes32 rights = "";
        _setParameters(vault, fVault, delegate, fDelegate, contract_, fContract, tokenId, fTokenId, rights, fRights, 0, IRegistry.DelegationType.ERC721);
        _testDelegateERC721();
    }

    function _testDelegateERC721() internal {
        registry = new Registry();
        // Create delegation
        vm.startPrank(_vault);
        bytes[] memory batchData = new bytes[](1);
        batchData[0] = abi.encodeWithSelector(Registry.delegateERC721.selector, _delegate, _contract, _tokenId, _rights, _enable);
        if (_multicall) registry.multicall(batchData);
        else registry.delegateERC721(_delegate, _contract, _tokenId, _rights, _enable);
        vm.stopPrank();
        // Check consumables and read
        _checkConsumableERC721();
        _checkFalseConsumableCases();
        _checkFalseConsumableCasesBelowAll();
        _checkFalseConsumableCasesBelowContract();
        _checkReadERC721();
        _checkReadCases();
        // Revoke and check logic again
        vm.startPrank(_vault);
        batchData[0] = abi.encodeWithSelector(Registry.delegateERC721.selector, _delegate, _contract, _tokenId, _rights, false);
        if (_multicall) registry.multicall(batchData);
        else registry.delegateERC721(_delegate, _contract, _tokenId, _rights, false);
        vm.stopPrank();
        _enable = false;
        _checkConsumableERC721();
        _checkFalseConsumableCases();
        _checkFalseConsumableCasesBelowAll();
        _checkFalseConsumableCasesBelowContract();
        _checkReadERC721();
        _checkReadCases();
    }

    function _checkConsumableERC721() internal {
        // Check logic outcomes of checkDelegateForERC721
        assertTrue(registry.checkDelegateForERC721(_delegate, _vault, _contract, _tokenId, _rights) == _enable);
        if (_rights == "") {
            assertTrue(registry.checkDelegateForERC721(_delegate, _vault, _contract, _tokenId, _fRights) == _enable);
        } else {
            assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _contract, _tokenId, _fRights));
        }
        // Check logic outcomes of checkDelegateForERC20
        assertEq(registry.checkDelegateForERC20(_delegate, _vault, _contract, _rights), 0);
        assertEq(registry.checkDelegateForERC20(_delegate, _vault, _contract, _fRights), 0);
        // Check logic outcomes of checkDelegateForERC1155
        assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _contract, _tokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _contract, _tokenId, _fRights), 0);
    }

    function _checkReadERC721() internal {
        bytes32 checkHash = Hashes.erc721Hash(_vault, _rights, _delegate, _tokenId, _contract);
        // Check outcomes of getIncomingDelegationHashes
        assertEq(registry.getIncomingDelegationHashes(_delegate).length == 1, _enable);
        if (_enable) {
            assertEq(registry.getIncomingDelegationHashes(_delegate)[0], checkHash);
        }
        // Check outcomes of getOutgoingDelegationHashes
        assertEq(registry.getOutgoingDelegationHashes(_vault).length == 1, _enable);
        if (_enable) {
            assertEq(registry.getOutgoingDelegationHashes(_vault)[0], checkHash);
        }
        // Check outcomes of getDelegationsFromHashes
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = checkHash;
        assertEq(registry.getDelegationsFromHashes(hashes).length, 1);
        _checkDelegation(registry.getDelegationsFromHashes(hashes)[0]);
    }

    // Tests delegateContract case with non-default rights
    function testDelegateERC20SpecificRights(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        uint256 fTokenId,
        bytes32 rights,
        bytes32 fRights,
        uint256 amount
    ) public {
        vm.assume(rights != "");
        vm.assume(amount != 0);
        _setParameters(vault, fVault, delegate, fDelegate, contract_, fContract, 0, fTokenId, rights, fRights, amount, IRegistry.DelegationType.ERC20);
        _testDelegateERC20();
    }

    // Tests delegateContract case with default rights
    function testDelegateERC20Default(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        uint256 fTokenId,
        bytes32 fRights,
        uint256 amount
    ) public {
        bytes32 rights = "";
        vm.assume(amount != 0);
        _setParameters(vault, fVault, delegate, fDelegate, contract_, fContract, 0, fTokenId, rights, fRights, amount, IRegistry.DelegationType.ERC20);
        _testDelegateERC20();
    }

    function _testDelegateERC20() internal {
        registry = new Registry();
        // Create delegation
        vm.startPrank(_vault);
        bytes[] memory batchData = new bytes[](1);
        batchData[0] = abi.encodeWithSelector(Registry.delegateERC20.selector, _delegate, _contract, _rights, _amount);
        if (_multicall) registry.multicall(batchData);
        else registry.delegateERC20(_delegate, _contract, _rights, _amount);
        vm.stopPrank();
        // Check consumables and read
        _enable = true;
        _checkConsumableERC20();
        _checkFalseConsumableCases();
        _checkFalseConsumableCasesBelowAll();
        _checkFalseConsumableCasesBelowContract();
        _checkReadERC20();
        _checkReadCases();
        // Revoke and check logic again
        vm.startPrank(_vault);
        batchData[0] = abi.encodeWithSelector(Registry.delegateERC20.selector, _delegate, _contract, _rights, 0);
        if (_multicall) registry.multicall(batchData);
        else registry.delegateERC20(_delegate, _contract, _rights, 0);
        vm.stopPrank();
        _enable = false;
        _checkConsumableERC20();
        _checkFalseConsumableCases();
        _checkFalseConsumableCasesBelowAll();
        _checkFalseConsumableCasesBelowContract();
        _checkReadERC20();
        _checkReadCases();
    }

    function _checkConsumableERC20() internal {
        // Check logic outcomes of checkDelegateForERC721
        assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _contract, _tokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _contract, _tokenId, _fRights));
        // Check logic outcomes of checkDelegateForERC20
        assertTrue((registry.checkDelegateForERC20(_delegate, _vault, _contract, _rights) == _amount) == _enable);
        if (_rights == "") {
            assertTrue((registry.checkDelegateForERC20(_delegate, _vault, _contract, _fRights) == _amount) == _enable);
        } else {
            assertEq(registry.checkDelegateForERC20(_delegate, _vault, _contract, _fRights), 0);
        }
        // Check logic outcomes of checkDelegateForERC1155
        assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _contract, _tokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _contract, _tokenId, _fRights), 0);
    }

    function _checkReadERC20() internal {
        bytes32 checkHash = Hashes.erc20Hash(_vault, _rights, _delegate, _contract);
        // Check outcomes of getIncomingDelegationHashes
        assertEq(registry.getIncomingDelegationHashes(_delegate).length == 1, _enable);
        if (_enable) {
            assertEq(registry.getIncomingDelegationHashes(_delegate)[0], checkHash);
        }
        // Check outcomes of getOutgoingDelegationHashes
        assertEq(registry.getOutgoingDelegationHashes(_vault).length == 1, _enable);
        if (_enable) {
            assertEq(registry.getOutgoingDelegationHashes(_vault)[0], checkHash);
        }
        // Check outcomes of getDelegationsFromHashes
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = checkHash;
        assertEq(registry.getDelegationsFromHashes(hashes).length, 1);
        _checkDelegation(registry.getDelegationsFromHashes(hashes)[0]);
    }

    // Tests delegateERC1155 case with non-default rights
    function testDelegateERC1155SpecificRights(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        uint256 tokenId,
        uint256 fTokenId,
        bytes32 rights,
        bytes32 fRights,
        uint256 amount
    ) public {
        vm.assume(rights != "");
        vm.assume(amount != 0);
        _setParameters(vault, fVault, delegate, fDelegate, contract_, fContract, tokenId, fTokenId, rights, fRights, amount, IRegistry.DelegationType.ERC1155);
        _testDelegateERC1155();
    }

    // Tests delegateERC1155 case with default rights
    function testDelegateERC1155Default(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        uint256 tokenId,
        uint256 fTokenId,
        bytes32 fRights,
        uint256 amount
    ) public {
        bytes32 rights = "";
        vm.assume(amount != 0);
        _setParameters(vault, fVault, delegate, fDelegate, contract_, fContract, tokenId, fTokenId, rights, fRights, amount, IRegistry.DelegationType.ERC1155);
        _testDelegateERC1155();
    }

    function _testDelegateERC1155() internal {
        registry = new Registry();
        // Create delegation
        vm.startPrank(_vault);
        bytes[] memory batchData = new bytes[](1);
        batchData[0] = abi.encodeWithSelector(Registry.delegateERC1155.selector, _delegate, _contract, _tokenId, _rights, _amount);
        if (_multicall) registry.multicall(batchData);
        else registry.delegateERC1155(_delegate, _contract, _tokenId, _rights, _amount);
        vm.stopPrank();
        _enable = true;
        // Check consumables and read
        _checkConsumableERC1155();
        _checkFalseConsumableCases();
        _checkFalseConsumableCasesBelowAll();
        _checkFalseConsumableCasesBelowContract();
        _checkReadERC1155();
        _checkReadCases();
        // Revoke and check logic again
        vm.startPrank(_vault);
        batchData[0] = abi.encodeWithSelector(Registry.delegateERC1155.selector, _delegate, _contract, _tokenId, _rights, 0);
        if (_multicall) registry.multicall(batchData);
        else registry.delegateERC1155(_delegate, _contract, _tokenId, _rights, 0);
        vm.stopPrank();
        _enable = false;
        _checkConsumableERC1155();
        _checkFalseConsumableCases();
        _checkFalseConsumableCasesBelowAll();
        _checkFalseConsumableCasesBelowContract();
        _checkReadERC1155();
        _checkReadCases();
    }

    function _checkConsumableERC1155() internal {
        // Check logic outcomes of checkDelegateForERC721
        assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _contract, _tokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _contract, _tokenId, _fRights));
        // Check logic outcomes of checkDelegateForERC20
        assertEq(registry.checkDelegateForERC20(_delegate, _vault, _contract, _rights), 0);
        assertEq(registry.checkDelegateForERC20(_delegate, _vault, _contract, _fRights), 0);
        // Check logic outcomes of checkDelegateForERC1155
        assertTrue((registry.checkDelegateForERC1155(_delegate, _vault, _contract, _tokenId, _rights) == _amount) == _enable);
        if (_rights == "") {
            assertTrue((registry.checkDelegateForERC1155(_delegate, _vault, _contract, _tokenId, _fRights) == _amount) == _enable);
        } else {
            assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _contract, _tokenId, _fRights), 0);
        }
    }

    function _checkReadERC1155() internal {
        bytes32 checkHash = Hashes.erc1155Hash(_vault, _rights, _delegate, _tokenId, _contract);
        // Check outcomes of getIncomingDelegationHashes
        assertEq(registry.getIncomingDelegationHashes(_delegate).length == 1, _enable);
        if (_enable) {
            assertEq(registry.getIncomingDelegationHashes(_delegate)[0], checkHash);
        }
        // Check outcomes of getOutgoingDelegationHashes
        assertEq(registry.getOutgoingDelegationHashes(_vault).length == 1, _enable);
        if (_enable) {
            assertEq(registry.getOutgoingDelegationHashes(_vault)[0], checkHash);
        }
        // Check outcomes of getDelegationsFromHashes
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = checkHash;
        assertEq(registry.getDelegationsFromHashes(hashes).length, 1);
        _checkDelegation(registry.getDelegationsFromHashes(hashes)[0]);
    }

    function _checkDelegation(IRegistry.Delegation memory delegation) internal {
        if (_enable) {
            assertEq(uint256(delegation.type_), uint256(_type));
            assertEq(delegation.to, _delegate);
            assertEq(delegation.from, _vault);
            assertEq(delegation.rights, _rights);
            assertEq(delegation.contract_, _contract);
            assertEq(delegation.tokenId, _tokenId);
            assertEq(delegation.amount, _amount);
        } else {
            assertEq(uint256(delegation.type_), uint256(IRegistry.DelegationType.NONE));
            assertEq(delegation.to, address(0));
            assertEq(uint160(delegation.from), uint160(0));
            assertEq(delegation.rights, "");
            assertEq(delegation.contract_, address(0));
            assertEq(delegation.tokenId, 0);
            assertEq(delegation.amount, 0);
        }
    }

    function _checkFalseConsumableCasesBelowContract() internal {
        // checkDelegateForAll cases
        assertFalse(registry.checkDelegateForAll(_delegate, _vault, _rights));
        assertFalse(registry.checkDelegateForAll(_delegate, _vault, _fRights));
        // checkDelegateForContract cases
        assertFalse(registry.checkDelegateForContract(_delegate, _vault, _contract, _rights));
        assertFalse(registry.checkDelegateForContract(_delegate, _vault, _contract, _fRights));
        // erc721 cases
        assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _contract, _fTokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _contract, _fTokenId, _fRights));
        // erc1155 cases
        assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _contract, _fTokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _contract, _fTokenId, _fRights), 0);
    }

    function _checkFalseConsumableCasesBelowAll() internal {
        // contract cases
        assertFalse(registry.checkDelegateForContract(_delegate, _vault, _fContract, _rights));
        assertFalse(registry.checkDelegateForContract(_delegate, _vault, _fContract, _fRights));
        // erc721 cases
        assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _fContract, _tokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _fContract, _tokenId, _fRights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _fContract, _fTokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _vault, _fContract, _fTokenId, _fRights));
        // erc20 cases
        assertEq(registry.checkDelegateForERC20(_delegate, _vault, _fContract, _rights), 0);
        assertEq(registry.checkDelegateForERC20(_delegate, _vault, _fContract, _fRights), 0);
        // erc1155 cases
        assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _fContract, _tokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _fContract, _tokenId, _fRights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _fContract, _fTokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _vault, _fContract, _fTokenId, _fRights), 0);
    }

    function _checkFalseConsumableCases() internal {
        // all false cases
        assertFalse(registry.checkDelegateForAll(_delegate, _fVault, _fRights));
        assertFalse(registry.checkDelegateForAll(_delegate, _fVault, _rights));
        assertFalse(registry.checkDelegateForAll(_fDelegate, _vault, _rights));
        assertFalse(registry.checkDelegateForAll(_fDelegate, _fVault, _rights));
        assertFalse(registry.checkDelegateForAll(_fDelegate, _vault, _fRights));
        assertFalse(registry.checkDelegateForAll(_fDelegate, _fVault, _fRights));
        // contract cases
        assertFalse(registry.checkDelegateForContract(_delegate, _fVault, _contract, _rights));
        assertFalse(registry.checkDelegateForContract(_delegate, _fVault, _fContract, _rights));
        assertFalse(registry.checkDelegateForContract(_delegate, _fVault, _contract, _fRights));
        assertFalse(registry.checkDelegateForContract(_delegate, _fVault, _fContract, _fRights));
        assertFalse(registry.checkDelegateForContract(_fDelegate, _vault, _contract, _rights));
        assertFalse(registry.checkDelegateForContract(_fDelegate, _vault, _contract, _fRights));
        assertFalse(registry.checkDelegateForContract(_fDelegate, _vault, _fContract, _rights));
        assertFalse(registry.checkDelegateForContract(_fDelegate, _fVault, _contract, _rights));
        assertFalse(registry.checkDelegateForContract(_fDelegate, _vault, _fContract, _fRights));
        assertFalse(registry.checkDelegateForContract(_fDelegate, _fVault, _fContract, _rights));
        assertFalse(registry.checkDelegateForContract(_fDelegate, _fVault, _contract, _fRights));
        assertFalse(registry.checkDelegateForContract(_fDelegate, _fVault, _fContract, _fRights));
        // erc721 cases
        assertFalse(registry.checkDelegateForERC721(_delegate, _fVault, _contract, _tokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _fVault, _contract, _tokenId, _fRights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _fVault, _contract, _fTokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _fVault, _contract, _fTokenId, _fRights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _fVault, _fContract, _tokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _fVault, _fContract, _tokenId, _fRights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _fVault, _fContract, _fTokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_delegate, _fVault, _fContract, _fTokenId, _fRights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _vault, _contract, _tokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _vault, _contract, _tokenId, _fRights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _vault, _contract, _fTokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _vault, _contract, _fTokenId, _fRights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _vault, _fContract, _tokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _vault, _fContract, _tokenId, _fRights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _vault, _fContract, _fTokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _vault, _fContract, _fTokenId, _fRights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _fVault, _contract, _tokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _fVault, _contract, _tokenId, _fRights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _fVault, _contract, _fTokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _fVault, _contract, _fTokenId, _fRights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _fVault, _fContract, _tokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _fVault, _fContract, _tokenId, _fRights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _fVault, _fContract, _fTokenId, _rights));
        assertFalse(registry.checkDelegateForERC721(_fDelegate, _fVault, _fContract, _fTokenId, _fRights));
        // erc20 cases
        assertEq(registry.checkDelegateForERC20(_delegate, _fVault, _contract, _rights), 0);
        assertEq(registry.checkDelegateForERC20(_delegate, _fVault, _fContract, _rights), 0);
        assertEq(registry.checkDelegateForERC20(_delegate, _fVault, _contract, _fRights), 0);
        assertEq(registry.checkDelegateForERC20(_delegate, _fVault, _fContract, _fRights), 0);
        assertEq(registry.checkDelegateForERC20(_fDelegate, _vault, _contract, _rights), 0);
        assertEq(registry.checkDelegateForERC20(_fDelegate, _fVault, _contract, _rights), 0);
        assertEq(registry.checkDelegateForERC20(_fDelegate, _vault, _fContract, _rights), 0);
        assertEq(registry.checkDelegateForERC20(_fDelegate, _fVault, _fContract, _rights), 0);
        assertEq(registry.checkDelegateForERC20(_fDelegate, _vault, _contract, _fRights), 0);
        assertEq(registry.checkDelegateForERC20(_fDelegate, _fVault, _contract, _fRights), 0);
        assertEq(registry.checkDelegateForERC20(_fDelegate, _vault, _fContract, _fRights), 0);
        assertEq(registry.checkDelegateForERC20(_fDelegate, _fVault, _fContract, _fRights), 0);
        // erc1155 cases
        assertEq(registry.checkDelegateForERC1155(_delegate, _fVault, _contract, _tokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _fVault, _contract, _tokenId, _fRights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _fVault, _contract, _fTokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _fVault, _contract, _fTokenId, _fRights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _fVault, _fContract, _tokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _fVault, _fContract, _tokenId, _fRights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _fVault, _fContract, _fTokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_delegate, _fVault, _fContract, _fTokenId, _fRights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _vault, _contract, _tokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _vault, _contract, _tokenId, _fRights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _vault, _contract, _fTokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _vault, _contract, _fTokenId, _fRights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _vault, _fContract, _tokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _vault, _fContract, _tokenId, _fRights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _vault, _fContract, _fTokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _vault, _fContract, _fTokenId, _fRights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _fVault, _contract, _tokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _fVault, _contract, _tokenId, _fRights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _fVault, _contract, _fTokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _fVault, _contract, _fTokenId, _fRights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _fVault, _fContract, _tokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _fVault, _fContract, _tokenId, _fRights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _fVault, _fContract, _fTokenId, _rights), 0);
        assertEq(registry.checkDelegateForERC1155(_fDelegate, _fVault, _fContract, _fTokenId, _fRights), 0);
    }

    function _checkReadCases() internal {
        // getIncomingDelegations
        assertEq(registry.getIncomingDelegations(_delegate).length == 1, _enable);
        if (_enable) _checkDelegation(registry.getIncomingDelegations(_delegate)[0]);
        assertEq(registry.getIncomingDelegations(_vault).length, 0);
        assertEq(registry.getIncomingDelegations(_fVault).length, 0);
        assertEq(registry.getIncomingDelegations(_fDelegate).length, 0);
        // getOutgoingDelegations
        assertEq(registry.getOutgoingDelegations(_vault).length == 1, _enable);
        if (_enable) _checkDelegation(registry.getIncomingDelegations(_delegate)[0]);
        assertEq(registry.getOutgoingDelegations(_fVault).length, 0);
        assertEq(registry.getOutgoingDelegations(_delegate).length, 0);
        assertEq(registry.getOutgoingDelegations(_fDelegate).length, 0);
        // getIncomingDelegationHashes
        assertEq(registry.getIncomingDelegationHashes(_vault).length, 0);
        assertEq(registry.getIncomingDelegationHashes(_fVault).length, 0);
        assertEq(registry.getIncomingDelegationHashes(_fDelegate).length, 0);
        // getOutgoingDelegationHashes
        assertEq(registry.getOutgoingDelegationHashes(_fVault).length, 0);
        assertEq(registry.getOutgoingDelegationHashes(_delegate).length, 0);
        assertEq(registry.getOutgoingDelegationHashes(_fDelegate).length, 0);
    }
}
