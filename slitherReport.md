**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [assembly](#assembly) (9 results) (Informational)
 - [solc-version](#solc-version) (7 results) (Informational)
 - [low-level-calls](#low-level-calls) (1 results) (Informational)
## assembly
Impact: Informational
Confidence: High
 - [ ] ID-0
[DelegateRegistry._writeDelegationAddresses(bytes32,RegistryStorage.Positions,RegistryStorage.Positions,address,address,address)](src/DelegateRegistry.sol#L295-L303) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L299-L302)

src/DelegateRegistry.sol#L295-L303


 - [ ] ID-1
[DelegateRegistry._writeDelegation(bytes32,RegistryStorage.Positions,bytes32)](src/DelegateRegistry.sol#L281-L285) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L282-L284)

src/DelegateRegistry.sol#L281-L285


 - [ ] ID-2
[DelegateRegistry.readSlots(bytes32[])](src/DelegateRegistry.sol#L251-L257) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L254-L256)

src/DelegateRegistry.sol#L251-L257


 - [ ] ID-3
[DelegateRegistry._loadDelegationUint(bytes32,RegistryStorage.Positions)](src/DelegateRegistry.sol#L361-L365) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L362-L364)

src/DelegateRegistry.sol#L361-L365


 - [ ] ID-4
[DelegateRegistry._writeDelegation(bytes32,RegistryStorage.Positions,uint256)](src/DelegateRegistry.sol#L288-L292) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L289-L291)

src/DelegateRegistry.sol#L288-L292


 - [ ] ID-5
[DelegateRegistry._loadDelegationBytes32(bytes32,RegistryStorage.Positions)](src/DelegateRegistry.sol#L354-L358) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L355-L357)

src/DelegateRegistry.sol#L354-L358


 - [ ] ID-6
[DelegateRegistry._loadFrom(bytes32,RegistryStorage.Positions)](src/DelegateRegistry.sol#L368-L374) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L370-L372)

src/DelegateRegistry.sol#L368-L374


 - [ ] ID-7
[DelegateRegistry._loadDelegationAddresses(bytes32,RegistryStorage.Positions,RegistryStorage.Positions)](src/DelegateRegistry.sol#L377-L389) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L384-L387)

src/DelegateRegistry.sol#L377-L389


 - [ ] ID-8
[DelegateRegistry.readSlot(bytes32)](src/DelegateRegistry.sol#L245-L249) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L246-L248)

src/DelegateRegistry.sol#L245-L249


## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-9
Pragma version[>=0.8.13](src/IDelegateRegistry.sol#L2) allows old versions

src/IDelegateRegistry.sol#L2


 - [ ] ID-10
Pragma version[^0.8.20](src/examples/Airdrop.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/examples/Airdrop.sol#L2


 - [ ] ID-11
Pragma version[^0.8.20](test/tools/RegistryHarness.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

test/tools/RegistryHarness.sol#L2


 - [ ] ID-12
solc-0.8.20 is not recommended for deployment

 - [ ] ID-13
Pragma version[^0.8.20](src/examples/IPLicenseCheck.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/examples/IPLicenseCheck.sol#L2


 - [ ] ID-14
Pragma version[^0.8.20](src/DelegateRegistry.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/DelegateRegistry.sol#L2


 - [ ] ID-15
Pragma version[^0.8.20](src/examples/DelegateClaim.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/examples/DelegateClaim.sol#L2


## low-level-calls
Impact: Informational
Confidence: High
 - [ ] ID-16
Low level call in [DelegateRegistry.multicall(bytes[])](src/DelegateRegistry.sol#L34-L44):
	- [(success,results[i]) = address(this).delegatecall(data[i])](src/DelegateRegistry.sol#L40)

src/DelegateRegistry.sol#L34-L44


