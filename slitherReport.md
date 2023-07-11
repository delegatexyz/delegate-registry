**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [assembly](#assembly) (9 results) (Informational)
 - [solc-version](#solc-version) (8 results) (Informational)
 - [low-level-calls](#low-level-calls) (1 results) (Informational)
## assembly
Impact: Informational
Confidence: High
 - [ ] ID-0
[DelegateRegistry.readSlots(bytes32[])](src/DelegateRegistry.sol#L255-L261) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L258-L260)

src/DelegateRegistry.sol#L255-L261


 - [ ] ID-1
[DelegateRegistry._writeDelegation(bytes32,RegistryStorage.Positions,bytes32)](src/DelegateRegistry.sol#L285-L289) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L286-L288)

src/DelegateRegistry.sol#L285-L289


 - [ ] ID-2
[DelegateRegistry._loadDelegationAddresses(bytes32,RegistryStorage.Positions,RegistryStorage.Positions)](src/DelegateRegistry.sol#L387-L399) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L394-L397)

src/DelegateRegistry.sol#L387-L399


 - [ ] ID-3
[DelegateRegistry._writeDelegation(bytes32,RegistryStorage.Positions,uint256)](src/DelegateRegistry.sol#L292-L296) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L293-L295)

src/DelegateRegistry.sol#L292-L296


 - [ ] ID-4
[DelegateRegistry._loadDelegationUint(bytes32,RegistryStorage.Positions)](src/DelegateRegistry.sol#L371-L375) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L372-L374)

src/DelegateRegistry.sol#L371-L375


 - [ ] ID-5
[DelegateRegistry._loadFrom(bytes32,RegistryStorage.Positions)](src/DelegateRegistry.sol#L378-L384) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L380-L382)

src/DelegateRegistry.sol#L378-L384


 - [ ] ID-6
[DelegateRegistry._loadDelegationBytes32(bytes32,RegistryStorage.Positions)](src/DelegateRegistry.sol#L364-L368) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L365-L367)

src/DelegateRegistry.sol#L364-L368


 - [ ] ID-7
[DelegateRegistry._writeDelegationAddresses(bytes32,RegistryStorage.Positions,RegistryStorage.Positions,address,address,address)](src/DelegateRegistry.sol#L299-L312) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L308-L311)

src/DelegateRegistry.sol#L299-L312


 - [ ] ID-8
[DelegateRegistry.readSlot(bytes32)](src/DelegateRegistry.sol#L249-L253) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L250-L252)

src/DelegateRegistry.sol#L249-L253


## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-9
Pragma version[>=0.8.13](src/IDelegateRegistry.sol#L2) allows old versions

src/IDelegateRegistry.sol#L2


 - [ ] ID-10
Pragma version[^0.8.20](src/tools/HashHarness.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/tools/HashHarness.sol#L2


 - [ ] ID-11
Pragma version[^0.8.20](src/examples/Airdrop.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/examples/Airdrop.sol#L2


 - [ ] ID-12
solc-0.8.20 is not recommended for deployment

 - [ ] ID-13
Pragma version[^0.8.20](src/tools/RegistryHarness.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/tools/RegistryHarness.sol#L2


 - [ ] ID-14
Pragma version[^0.8.20](src/examples/IPLicenseCheck.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/examples/IPLicenseCheck.sol#L2


 - [ ] ID-15
Pragma version[^0.8.20](src/DelegateRegistry.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/DelegateRegistry.sol#L2


 - [ ] ID-16
Pragma version[^0.8.20](src/examples/DelegateClaim.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/examples/DelegateClaim.sol#L2


## low-level-calls
Impact: Informational
Confidence: High
 - [ ] ID-17
Low level call in [DelegateRegistry.multicall(bytes[])](src/DelegateRegistry.sol#L34-L44):
	- [(success,results[i]) = address(this).delegatecall(data[i])](src/DelegateRegistry.sol#L40)

src/DelegateRegistry.sol#L34-L44


