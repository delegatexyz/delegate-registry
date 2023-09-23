// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IDelegateRegistry} from "src/IDelegateRegistry.sol";

/**
 * @title IP License Checker
 * @notice A contract for checking whether a wallet has been granted IP licenses for an NFT. It supports both NFT vault -> IP license and NFT vault -> IP
 * licensor -> IP license workflows.
 */

contract IPLicenseCheck {
    IDelegateRegistry public immutable delegateRegistry;

    /// @param registry_ is the address of the v2 delegation registry contract.
    constructor(address registry_) {
        delegateRegistry = IDelegateRegistry(registry_);
    }

    /**
     * @notice Checks whether a wallet has been granted an IP license for an NFT
     * @param wallet to be checked for having the IP license
     * @param vault is the address that owns the NFT
     * @param nftContract is the contract address of the NFT
     * @param tokenId is the ID of the NFT
     * @param ipLicense is a bytes32 representation of the IP license to be check for
     * @return valid is returned true if the wallet has rights to the IP license for the NFT
     */
    function checkForIPLicense(address wallet, address vault, address nftContract, uint256 tokenId, bytes32 ipLicense) external view returns (bool valid) {
        // Return false if the vault does not own the NFT
        if (IERC721(nftContract).ownerOf(tokenId) != vault) return false;
        // Call the v2 registry, which will return true if the wallet has a valid delegation or sub-delegation with "<ipLicense>" rights
        return delegateRegistry.checkDelegateForERC721(wallet, vault, nftContract, tokenId, ipLicense);
    }

    /**
     * @notice Checks whether a wallet has been granted an IP license for an NFT
     * @param wallet to be checked for having the IP license
     * @param licensor is the address that has been granted the right to create IP licenses for the vault
     * @param vault is the address that owns the NFT
     * @param nftContract is the contract address of the NFT
     * @param tokenId is the ID of the NFT
     * @param ipLicense is a bytes32 representation of the IP license to be check for
     * @return valid is returned true if the wallet has rights to the IP license for the NFT
     */
    function checkForIPLicenseFromLicensor(address wallet, address licensor, address vault, address nftContract, uint256 tokenId, bytes32 ipLicense) external view returns (bool) {
        // Return false if the vault does not own the NFT
        if (IERC721(nftContract).ownerOf(tokenId) != vault) return false;
        // Call the v2 registry, and return false if vault has not granted "ip licensor" rights to the licensor for the nft
        if (!delegateRegistry.checkDelegateForERC721(licensor, vault, nftContract, tokenId, "ip licensor")) return false;
        // Call the v2 registry, which will return true if the wallet has a valid delegation or sub-delegation with "<ipLicense>" rights
        return delegateRegistry.checkDelegateForERC721(wallet, licensor, nftContract, tokenId, ipLicense);
    }
}
