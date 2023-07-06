**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [shadowing-local](#shadowing-local) (1 results) (Low)
 - [missing-zero-check](#missing-zero-check) (1 results) (Low)
 - [calls-loop](#calls-loop) (1 results) (Low)
 - [assembly](#assembly) (8 results) (Informational)
 - [solc-version](#solc-version) (7 results) (Informational)
 - [low-level-calls](#low-level-calls) (1 results) (Informational)
## shadowing-local
Impact: Low
Confidence: High
 - [ ] ID-0
[Airdrop.constructor(address,address,bytes32,uint256,bytes32,address).acceptedRight](src/examples/Airdrop.sol#L27) shadows:
	- [DelegateClaim.acceptedRight](src/examples/DelegateClaim.sol#L14) (state variable)

src/examples/Airdrop.sol#L27


## missing-zero-check
Impact: Low
Confidence: Medium
 - [ ] ID-1
[DelegateClaim.constructor(address,address,bytes32).referenceToken_](src/examples/DelegateClaim.sol#L24) lacks a zero-check on :
		- [referenceToken = referenceToken_](src/examples/DelegateClaim.sol#L26)

src/examples/DelegateClaim.sol#L24


## calls-loop
Impact: Low
Confidence: Medium
 - [ ] ID-2
[DelegateRegistry.multicall(bytes[])](src/DelegateRegistry.sol#L34-L43) has external calls inside a loop: [(success,results[i]) = address(this).delegatecall(data[i])](src/DelegateRegistry.sol#L39)

src/DelegateRegistry.sol#L34-L43


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-3
[DelegateRegistry._writeDelegation(bytes32,IDelegateRegistry.StoragePositions,uint256)](src/DelegateRegistry.sol#L314-L318) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L315-L317)

src/DelegateRegistry.sol#L314-L318


 - [ ] ID-4
[DelegateRegistry._loadDelegationUint(bytes32,IDelegateRegistry.StoragePositions)](src/DelegateRegistry.sol#L384-L388) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L385-L387)

src/DelegateRegistry.sol#L384-L388


 - [ ] ID-5
[DelegateRegistry.readSlots(bytes32[])](src/DelegateRegistry.sol#L277-L283) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L280-L282)

src/DelegateRegistry.sol#L277-L283


 - [ ] ID-6
[DelegateRegistry._loadDelegationBytes32(bytes32,IDelegateRegistry.StoragePositions)](src/DelegateRegistry.sol#L377-L381) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L378-L380)

src/DelegateRegistry.sol#L377-L381


 - [ ] ID-7
[DelegateRegistry._loadDelegationAddress(bytes32,IDelegateRegistry.StoragePositions)](src/DelegateRegistry.sol#L391-L395) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L392-L394)

src/DelegateRegistry.sol#L391-L395


 - [ ] ID-8
[DelegateRegistry._writeDelegation(bytes32,IDelegateRegistry.StoragePositions,bytes32)](src/DelegateRegistry.sol#L307-L311) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L308-L310)

src/DelegateRegistry.sol#L307-L311


 - [ ] ID-9
[DelegateRegistry._writeDelegation(bytes32,IDelegateRegistry.StoragePositions,address)](src/DelegateRegistry.sol#L321-L325) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L322-L324)

src/DelegateRegistry.sol#L321-L325


 - [ ] ID-10
[DelegateRegistry.readSlot(bytes32)](src/DelegateRegistry.sol#L271-L275) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L272-L274)

src/DelegateRegistry.sol#L271-L275


## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-11
Pragma version[>=0.8.13](src/IDelegateRegistry.sol#L2) allows old versions

src/IDelegateRegistry.sol#L2


 - [ ] ID-12
Pragma version[^0.8.20](src/examples/Airdrop.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/examples/Airdrop.sol#L2


 - [ ] ID-13
solc-0.8.20 is not recommended for deployment

 - [ ] ID-14
Pragma version[^0.8.20](src/tools/RegistryHarness.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/tools/RegistryHarness.sol#L2


 - [ ] ID-15
Pragma version[^0.8.20](src/examples/IPLicenseCheck.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/examples/IPLicenseCheck.sol#L2


 - [ ] ID-16
Pragma version[^0.8.20](src/DelegateRegistry.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/DelegateRegistry.sol#L2


 - [ ] ID-17
Pragma version[^0.8.20](src/examples/DelegateClaim.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/examples/DelegateClaim.sol#L2


## low-level-calls
Impact: Informational
Confidence: High
 - [ ] ID-18
Low level call in [DelegateRegistry.multicall(bytes[])](src/DelegateRegistry.sol#L34-L43):
	- [(success,results[i]) = address(this).delegatecall(data[i])](src/DelegateRegistry.sol#L39)

src/DelegateRegistry.sol#L34-L43


