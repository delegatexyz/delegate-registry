// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IDelegateRegistry} from "./IDelegateRegistry.sol";

/**
 * @title DelegateRegistry
 * @custom:version 2.0
 * @custom:author foobar (0xfoobar)
 * @notice A standalone immutable registry storing delegated permissions from one wallet to another
 */
contract DelegateRegistry is IDelegateRegistry {
    /// @dev Only this mapping should be used to verify delegations; the other mappings are for record keeping only
    mapping(bytes32 delegationHash => bytes32[6] delegationStorage) private _delegations;

    /// @dev Vault delegation outbox, for pushing new hashes only
    mapping(address vault => bytes32[] delegationHashes) private _vaultDelegationHashes;

    /// @dev Delegate delegation inbox, for pushing new hashes only
    mapping(address delegate => bytes32[] delegationHashes) private _delegateDelegationHashes;

    /// @dev Standardizes storage positions of delegation data
    enum StoragePositions {
        delegate,
        vault,
        rights,
        contract_,
        tokenId,
        amount
    }

    /**
     * ----------- WRITE -----------
     */

    /// @inheritdoc IDelegateRegistry
    function batchDelegate(BatchDelegation[] calldata delegations) external override {
        for (uint256 i = 0; i < delegations.length; ++i) {
            if (delegations[i].type_ == DelegationType.ALL) {
                delegateForAll(delegations[i].delegate, delegations[i].rights, delegations[i].enable);
            } else if (delegations[i].type_ == DelegationType.CONTRACT) {
                delegateForContract(delegations[i].delegate, delegations[i].contract_, delegations[i].rights, delegations[i].enable);
            } else if (delegations[i].type_ == DelegationType.ERC721) {
                delegateForERC721(delegations[i].delegate, delegations[i].contract_, delegations[i].tokenId, delegations[i].rights, delegations[i].enable);
            } else if (delegations[i].type_ == DelegationType.ERC20) {
                delegateForERC20(delegations[i].delegate, delegations[i].contract_, delegations[i].amount, delegations[i].rights, delegations[i].enable);
            } else if (delegations[i].type_ == DelegationType.ERC1155) {
                delegateForERC1155(
                    delegations[i].delegate,
                    delegations[i].contract_,
                    delegations[i].tokenId,
                    delegations[i].amount,
                    delegations[i].rights,
                    delegations[i].enable
                );
            }
        }
    }

    /// @inheritdoc IDelegateRegistry
    function delegateForAll(address delegate, bytes32 rights, bool enable) public override {
        bytes32 hash = _computeDelegationHashForAll(delegate, rights, msg.sender);
        bytes32 location = _computeDelegationLocation(hash);
        emit AllDelegated(msg.sender, delegate, rights, enable);
        if (enable) {
            if (_loadDelegationBytes32(location, StoragePositions.vault) == "") _pushDelegationHashes(msg.sender, delegate, hash);
            _writeDelegation(location, StoragePositions.delegate, delegate);
            _writeDelegation(location, StoragePositions.vault, msg.sender);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.delegate, "");
            _writeDelegation(location, StoragePositions.vault, 1);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
    }

    /// @inheritdoc IDelegateRegistry
    function delegateForContract(address delegate, address contract_, bytes32 rights, bool enable) public override {
        bytes32 hash = _computeDelegationHashForContract(contract_, delegate, rights, msg.sender);
        bytes32 location = _computeDelegationLocation(hash);
        emit ContractDelegated(msg.sender, delegate, contract_, rights, enable);
        if (enable) {
            if (_loadDelegationBytes32(location, StoragePositions.vault) == "") _pushDelegationHashes(msg.sender, delegate, hash);
            _writeDelegation(location, StoragePositions.contract_, contract_);
            _writeDelegation(location, StoragePositions.delegate, delegate);
            _writeDelegation(location, StoragePositions.vault, msg.sender);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.contract_, "");
            _writeDelegation(location, StoragePositions.delegate, "");
            _writeDelegation(location, StoragePositions.vault, 1);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
    }

    /// @inheritdoc IDelegateRegistry
    function delegateForERC721(address delegate, address contract_, uint256 tokenId, bytes32 rights, bool enable) public override {
        bytes32 hash = _computeDelegationHashForERC721(contract_, delegate, rights, tokenId, msg.sender);
        bytes32 location = _computeDelegationLocation(hash);
        emit ERC721Delegated(msg.sender, delegate, contract_, tokenId, rights, enable);
        if (enable) {
            if (_loadDelegationBytes32(location, StoragePositions.vault) == "") _pushDelegationHashes(msg.sender, delegate, hash);
            _writeDelegation(location, StoragePositions.contract_, contract_);
            _writeDelegation(location, StoragePositions.delegate, delegate);
            _writeDelegation(location, StoragePositions.vault, msg.sender);
            _writeDelegation(location, StoragePositions.tokenId, tokenId);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.contract_, "");
            _writeDelegation(location, StoragePositions.delegate, "");
            _writeDelegation(location, StoragePositions.vault, 1);
            _writeDelegation(location, StoragePositions.tokenId, "");
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
    }

    /**
     * @inheritdoc IDelegateRegistry
     * @dev The actual amount is not encoded in the hash, just the existence of a amount (since it is an upper bound)
     */
    function delegateForERC20(address delegate, address contract_, uint256 amount, bytes32 rights, bool enable) public override {
        bytes32 hash = _computeDelegationHashForERC20(contract_, delegate, rights, msg.sender);
        bytes32 location = _computeDelegationLocation(hash);
        emit ERC20Delegated(msg.sender, delegate, contract_, amount, rights, enable);
        if (enable) {
            if (_loadDelegationBytes32(location, StoragePositions.vault) == "") _pushDelegationHashes(msg.sender, delegate, hash);
            _writeDelegation(location, StoragePositions.contract_, contract_);
            _writeDelegation(location, StoragePositions.delegate, delegate);
            _writeDelegation(location, StoragePositions.vault, msg.sender);
            _writeDelegation(location, StoragePositions.amount, amount);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.contract_, "");
            _writeDelegation(location, StoragePositions.delegate, "");
            _writeDelegation(location, StoragePositions.vault, 1);
            _writeDelegation(location, StoragePositions.amount, "");
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
    }

    /**
     * @inheritdoc IDelegateRegistry
     * @dev The actual amount is not encoded in the hash, just the existence of a amount (since it is an upper bound)
     */
    function delegateForERC1155(address delegate, address contract_, uint256 tokenId, uint256 amount, bytes32 rights, bool enable) public override {
        bytes32 hash = _computeDelegationHashForERC1155(contract_, delegate, rights, tokenId, msg.sender);
        bytes32 location = _computeDelegationLocation(hash);
        emit ERC1155Delegated(msg.sender, delegate, contract_, tokenId, amount, rights, enable);
        if (enable) {
            if (_loadDelegationBytes32(location, StoragePositions.vault) == "") _pushDelegationHashes(msg.sender, delegate, hash);
            _writeDelegation(location, StoragePositions.contract_, contract_);
            _writeDelegation(location, StoragePositions.delegate, delegate);
            _writeDelegation(location, StoragePositions.vault, msg.sender);
            _writeDelegation(location, StoragePositions.amount, amount);
            _writeDelegation(location, StoragePositions.tokenId, tokenId);
            if (rights != "") _writeDelegation(location, StoragePositions.rights, rights);
        } else {
            _writeDelegation(location, StoragePositions.contract_, "");
            _writeDelegation(location, StoragePositions.delegate, "");
            _writeDelegation(location, StoragePositions.vault, 1);
            _writeDelegation(location, StoragePositions.amount, "");
            _writeDelegation(location, StoragePositions.tokenId, "");
            if (rights != "") _writeDelegation(location, StoragePositions.rights, "");
        }
    }

    /**
     * ----------- Consumable -----------
     */

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForAll(address delegate, address vault, bytes32 rights) public view override returns (bool valid) {
        bytes32 location = _computeDelegationLocation(_computeDelegationHashForAll(delegate, "", vault));
        valid = _loadDelegationAddress(location, StoragePositions.vault) == vault;
        if (rights != "" && !valid) {
            location = _computeDelegationLocation(_computeDelegationHashForAll(delegate, rights, vault));
            valid = _loadDelegationAddress(location, StoragePositions.vault) == vault;
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForContract(address delegate, address vault, address contract_, bytes32 rights) public view override returns (bool valid) {
        bytes32 location = _computeDelegationLocation(_computeDelegationHashForContract(contract_, delegate, "", vault));
        valid = checkDelegateForAll(delegate, vault, "") || _loadDelegationAddress(location, StoragePositions.vault) == vault;
        if (rights != "" && !valid) {
            location = _computeDelegationLocation(_computeDelegationHashForContract(contract_, delegate, rights, vault));
            valid = checkDelegateForAll(delegate, vault, rights) || _loadDelegationAddress(location, StoragePositions.vault) == vault;
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC721(address delegate, address vault, address contract_, uint256 tokenId, bytes32 rights)
        external
        view
        override
        returns (bool valid)
    {
        bytes32 location = _computeDelegationLocation(_computeDelegationHashForERC721(contract_, delegate, "", tokenId, vault));
        valid = checkDelegateForContract(delegate, vault, contract_, "") || _loadDelegationAddress(location, StoragePositions.vault) == vault;
        if (rights != "" && !valid) {
            location = _computeDelegationLocation(_computeDelegationHashForERC721(contract_, delegate, rights, tokenId, vault));
            valid = checkDelegateForContract(delegate, vault, contract_, rights) || _loadDelegationAddress(location, StoragePositions.vault) == vault;
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC20(address delegate, address vault, address contract_, bytes32 rights) external view override returns (uint256 amount) {
        bytes32 location = _computeDelegationLocation(_computeDelegationHashForERC20(contract_, delegate, "", vault));
        amount = checkDelegateForContract(delegate, vault, contract_, "")
            ? type(uint256).max
            : (_loadDelegationAddress(location, StoragePositions.vault) == vault ? _loadDelegationUint(location, StoragePositions.amount) : 0);
        if (rights != "" && amount != type(uint256).max) {
            location = _computeDelegationLocation(_computeDelegationHashForERC20(contract_, delegate, rights, vault));
            uint256 rightsBalance = checkDelegateForContract(delegate, vault, contract_, rights)
                ? type(uint256).max
                : (_loadDelegationAddress(location, StoragePositions.vault) == vault ? _loadDelegationUint(location, StoragePositions.amount) : 0);
            amount = rightsBalance > amount ? rightsBalance : amount;
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC1155(address delegate, address vault, address contract_, uint256 tokenId, bytes32 rights)
        external
        view
        override
        returns (uint256 amount)
    {
        bytes32 location = _computeDelegationLocation(_computeDelegationHashForERC1155(contract_, delegate, "", tokenId, vault));
        amount = checkDelegateForContract(delegate, vault, contract_, "")
            ? type(uint256).max
            : (_loadDelegationAddress(location, StoragePositions.vault) == vault ? _loadDelegationUint(location, StoragePositions.amount) : 0);
        if (rights != "" && amount != type(uint256).max) {
            location = _computeDelegationLocation(_computeDelegationHashForERC1155(contract_, delegate, rights, tokenId, vault));
            uint256 rightsBalance = checkDelegateForContract(delegate, vault, contract_, rights)
                ? type(uint256).max
                : (_loadDelegationAddress(location, StoragePositions.vault) == vault ? _loadDelegationUint(location, StoragePositions.amount) : 0);
            amount = rightsBalance > amount ? rightsBalance : amount;
        }
    }

    /**
     * ----------- READ -----------
     */

    /// @inheritdoc IDelegateRegistry
    function getDelegationsForDelegate(address delegate) external view override returns (Delegation[] memory delegations) {
        delegations = _getValidDelegationsFromHashes(_delegateDelegationHashes[delegate]);
    }

    /// @inheritdoc IDelegateRegistry
    function getDelegationsForVault(address vault) external view returns (Delegation[] memory delegations) {
        delegations = _getValidDelegationsFromHashes(_vaultDelegationHashes[vault]);
    }

    /// @inheritdoc IDelegateRegistry
    function getDelegationsFromHashes(bytes32[] calldata hashes) external view returns (Delegation[] memory delegations) {
        delegations = new Delegation[](hashes.length);
        bytes32 location;
        address vault;
        for (uint256 i = 0; i < hashes.length; i++) {
            location = _computeDelegationLocation(hashes[i]);
            vault = _loadDelegationAddress(location, StoragePositions.vault);
            if (vault == address(1) || vault == address(0)) {
                delegations[i] = Delegation({
                    type_: _decodeLastByteToType(hashes[i]),
                    delegate: address(0),
                    vault: address(0),
                    rights: "",
                    amount: 0,
                    contract_: address(0),
                    tokenId: 0
                });
            } else {
                delegations[i] = Delegation({
                    type_: _decodeLastByteToType(hashes[i]),
                    delegate: _loadDelegationAddress(location, StoragePositions.delegate),
                    vault: vault,
                    rights: _loadDelegationBytes32(location, StoragePositions.rights),
                    amount: _loadDelegationUint(location, StoragePositions.amount),
                    contract_: _loadDelegationAddress(location, StoragePositions.contract_),
                    tokenId: _loadDelegationUint(location, StoragePositions.tokenId)
                });
            }
        }
    }

    /// @inheritdoc IDelegateRegistry
    function getDelegationHashesForDelegate(address delegate) external view returns (bytes32[] memory delegationHashes) {
        delegationHashes = _getValidDelegationHashesFromHashes(_delegateDelegationHashes[delegate]);
    }

    /// @inheritdoc IDelegateRegistry
    function getDelegationHashesForVault(address vault) external view returns (bytes32[] memory delegationHashes) {
        delegationHashes = _getValidDelegationHashesFromHashes(_vaultDelegationHashes[vault]);
    }

    /**
     * ----------- ERC165 -----------
     */

    /// @notice Query if a contract implements an ERC-165 interface
    /// @param interfaceId The interface identifier
    /// @return bool Whether the queried interface is supported
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IDelegateRegistry).interfaceId || interfaceId == 0x01ffc9a7;
    }

    /**
     * ----------- PRIVATE -----------
     */

    /// @dev Helper function that takes an array of delegation hashes and returns an array of Delegation structs with their on chain information
    function _getValidDelegationsFromHashes(bytes32[] storage hashes) private view returns (Delegation[] memory delegations) {
        uint256 count = 0;
        uint256 vaultCheck;
        uint256 hashesLength = hashes.length;
        bytes32 storedHash;
        bytes32[] memory filteredHashes = new bytes32[](hashesLength);

        for (uint256 i = 0; i < hashesLength; i++) {
            storedHash = hashes[i];
            vaultCheck = uint256(_delegations[storedHash][uint256(StoragePositions.vault)]);
            if (vaultCheck != 0 && vaultCheck != 1) {
                filteredHashes[count] = storedHash;
                count++;
            }
        }
        delegations = new Delegation[](count);
        bytes32 location;
        bytes32 hash;
        address vault;
        for (uint256 i = 0; i < count; i++) {
            hash = filteredHashes[i];
            location = _computeDelegationLocation(hash);
            vault = _loadDelegationAddress(location, StoragePositions.vault);
            delegations[i] = Delegation({
                type_: _decodeLastByteToType(hash),
                delegate: _loadDelegationAddress(location, StoragePositions.delegate),
                vault: vault,
                rights: _loadDelegationBytes32(location, StoragePositions.rights),
                amount: _loadDelegationUint(location, StoragePositions.amount),
                contract_: _loadDelegationAddress(location, StoragePositions.contract_),
                tokenId: _loadDelegationUint(location, StoragePositions.tokenId)
            });
        }
    }

    /// @dev Helper function that takes an array of delegation hashes and returns an array of valid delegation hashes
    function _getValidDelegationHashesFromHashes(bytes32[] storage hashes) private view returns (bytes32[] memory validHashes) {
        uint256 count = 0;
        uint256 vault;
        uint256 hashesLength = hashes.length;
        bytes32 storedHash;
        bytes32[] memory filteredHashes = new bytes32[](hashesLength);
        for (uint256 i = 0; i < hashesLength; i++) {
            storedHash = hashes[i];
            vault = uint256(_delegations[storedHash][uint256(StoragePositions.vault)]);
            if (vault != 0 && vault != 1) {
                filteredHashes[count] = storedHash;
                count++;
            }
        }
        validHashes = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            validHashes[i] = filteredHashes[i];
        }
    }

    /// @dev Helper function to push new delegation hashes to the delegate and vault hashes mappings
    function _pushDelegationHashes(address vault, address delegate, bytes32 delegationHash) private {
        _vaultDelegationHashes[vault].push(delegationHash);
        _delegateDelegationHashes[delegate].push(delegationHash);
    }

    /// @dev Helper function to compute delegation hash for all delegation
    function _computeDelegationHashForAll(address delegate, bytes32 rights, address vault) private pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(delegate, vault, rights)), DelegationType.ALL);
    }

    /// @dev Helper function to compute delegation hash for contract delegation
    function _computeDelegationHashForContract(address contract_, address delegate, bytes32 rights, address vault) private pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, delegate, rights, vault)), DelegationType.CONTRACT);
    }

    /// @dev Helper function to compute delegation hash for ERC20 delegation
    function _computeDelegationHashForERC20(address contract_, address delegate, bytes32 rights, address vault) private pure returns (bytes32) {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, delegate, rights, vault)), DelegationType.ERC20);
    }

    /// @dev Helper function to compute delegation hash for ERC721 delegation
    function _computeDelegationHashForERC721(address contract_, address delegate, bytes32 rights, uint256 tokenId, address vault)
        private
        pure
        returns (bytes32)
    {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, delegate, rights, tokenId, vault)), DelegationType.ERC721);
    }

    /// @dev Helper function to compute delegation hash for ERC1155 delegation
    function _computeDelegationHashForERC1155(address contract_, address delegate, bytes32 rights, uint256 tokenId, address vault)
        private
        pure
        returns (bytes32)
    {
        return _encodeLastByteWithType(keccak256(abi.encode(contract_, delegate, rights, tokenId, vault)), DelegationType.ERC1155);
    }

    /// @dev Helper function that writes bytes32 data to delegation data location at array position
    function _writeDelegation(bytes32 location, StoragePositions position, bytes32 data) private {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that writes uint256 data to delegation data location at array position
    function _writeDelegation(bytes32 location, StoragePositions position, uint256 data) private {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that writes address data to delegation data location at array position
    function _writeDelegation(bytes32 location, StoragePositions position, address data) private {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function to encode the last byte of a delegation hash to its type
    function _encodeLastByteWithType(bytes32 _input, DelegationType _type) private pure returns (bytes32) {
        return (_input & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00) | bytes32(uint256(_type));
    }

    /// @dev Helper function to decode last byte of a delegation hash to obtain its type
    function _decodeLastByteToType(bytes32 _input) private pure returns (DelegationType) {
        return DelegationType(uint8(uint256(_input) & 0xFF));
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as bytes32
    function _loadDelegationBytes32(bytes32 location, StoragePositions position) private view returns (bytes32 data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as uint256
    function _loadDelegationUint(bytes32 location, StoragePositions position) private view returns (uint256 data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as address
    function _loadDelegationAddress(bytes32 location, StoragePositions position) private view returns (address data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    /// @dev Helper function that computes the data location of a particular delegation hash
    function _computeDelegationLocation(bytes32 hash) private pure returns (bytes32 location) {
        location = keccak256(abi.encode(hash, 0)); // _delegations mapping is at slot 0
    }
}
