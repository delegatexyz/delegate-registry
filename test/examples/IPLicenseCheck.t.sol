// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";

import {IPLicenseCheck} from "src/examples/IPLicenseCheck.sol";
import {DelegateRegistry} from "src/DelegateRegistry.sol";
import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";

contract NFT is ERC721 {
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        _mint(msg.sender, 1);
    }
}

contract IPLicenseCheckTest is Test {
    DelegateRegistry public registry;
    IPLicenseCheck public ipLicenseCheck;
    ERC721 public nft;

    function setUp() public {
        registry = new DelegateRegistry();
        ipLicenseCheck = new IPLicenseCheck(address(registry));
    }

    function testCheckForIPLicense(address wallet, address vault, address fVault, bytes32 ipLicense, bytes32 fIpLicense) public {
        vm.assume(vault > address(1));
        vm.assume(wallet != vault && wallet != fVault && fVault != vault);
        vm.assume(ipLicense != fIpLicense);
        // Create nft
        vm.startPrank(vault);
        nft = new NFT("nft", "nft");
        vm.stopPrank();
        // Delegate IP license to wallet for vault and fVault
        vm.startPrank(vault);
        registry.delegateERC721(wallet, address(nft), 1, ipLicense, true);
        vm.stopPrank();
        // Check false if vault doesn't own NFT
        assertFalse(ipLicenseCheck.checkForIPLicense(wallet, fVault, address(nft), 1, ipLicense));
        // Check false if wallet has a different license
        if (ipLicense != "") assertFalse(ipLicenseCheck.checkForIPLicense(wallet, vault, address(nft), 1, fIpLicense));
        else assertTrue(ipLicenseCheck.checkForIPLicense(wallet, vault, address(nft), 1, fIpLicense));
        // Check true if vault has nft and wallet has license
        assertTrue(ipLicenseCheck.checkForIPLicense(wallet, vault, address(nft), 1, ipLicense));
    }

    function testCheckForIPLicenseFromLicensor(address wallet, address vault, address licensor, address fLicensor, address fVault, bytes32 ipLicense, bytes32 fIpLicense) public {
        vm.assume(vault > address(1) && licensor > address(1));
        vm.assume(wallet != vault && wallet != licensor && wallet != fVault && wallet != fLicensor);
        vm.assume(licensor != vault && licensor != fVault && licensor != fLicensor);
        vm.assume(fVault != vault && fVault != fLicensor);
        vm.assume(fLicensor != vault);
        vm.assume(ipLicense != fIpLicense && ipLicense != "ip licensor" && fIpLicense != "ip licensor");
        // Create nft
        vm.startPrank(vault);
        nft = new NFT("nft", "nft");
        vm.stopPrank();
        // Delegate licensor rights to licensor for vault and IP license to wallet for licensor
        vm.startPrank(vault);
        registry.delegateERC721(licensor, address(nft), 1, "ip licensor", true);
        vm.stopPrank();
        vm.startPrank(licensor);
        registry.delegateERC721(wallet, address(nft), 1, ipLicense, true);
        vm.stopPrank();
        // Check false if vault doesn't own NFT
        assertFalse(ipLicenseCheck.checkForIPLicenseFromLicensor(wallet, licensor, fVault, address(nft), 1, ipLicense));
        // Check false if licensor doesn't have licensor rights
        assertFalse(ipLicenseCheck.checkForIPLicenseFromLicensor(wallet, fLicensor, vault, address(nft), 1, ipLicense));
        // Check false if wallet has a different license
        if (ipLicense != "") assertFalse(ipLicenseCheck.checkForIPLicenseFromLicensor(wallet, licensor, vault, address(nft), 1, fIpLicense));
        else assertTrue(ipLicenseCheck.checkForIPLicenseFromLicensor(wallet, licensor, vault, address(nft), 1, fIpLicense));
        // Check true if vault has nft, licensor has licensor rights, and wallet has license
        assertTrue(ipLicenseCheck.checkForIPLicenseFromLicensor(wallet, licensor, vault, address(nft), 1, ipLicense));
    }
}
