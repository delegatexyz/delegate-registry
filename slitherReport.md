**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [assembly](#assembly) (9 results) (Informational)
 - [solc-version](#solc-version) (7 results) (Informational)
 - [low-level-calls](#low-level-calls) (1 results) (Informational)
## assembly
Impact: Informational
Confidence: High
 - [ ] ID-0
[DelegateRegistry.readSlot(bytes32)](src/DelegateRegistry.sol#L254-L258) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L255-L257)

src/DelegateRegistry.sol#L254-L258


 - [ ] ID-1
[DelegateRegistry._loadDelegationAddresses(bytes32,IDelegateRegistry.StoragePositions,IDelegateRegistry.StoragePositions)](src/DelegateRegistry.sol#L383-L396) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L388-L395)

src/DelegateRegistry.sol#L383-L396


 - [ ] ID-2
[DelegateRegistry._loadDelegationUint(bytes32,IDelegateRegistry.StoragePositions)](src/DelegateRegistry.sol#L369-L373) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L370-L372)

src/DelegateRegistry.sol#L369-L373


 - [ ] ID-3
[DelegateRegistry._writeDelegation(bytes32,IDelegateRegistry.StoragePositions,uint256)](src/DelegateRegistry.sol#L297-L301) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L298-L300)

src/DelegateRegistry.sol#L297-L301


 - [ ] ID-4
[DelegateRegistry._loadDelegationBytes32(bytes32,IDelegateRegistry.StoragePositions)](src/DelegateRegistry.sol#L362-L366) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L363-L365)

src/DelegateRegistry.sol#L362-L366


 - [ ] ID-5
[DelegateRegistry.readSlots(bytes32[])](src/DelegateRegistry.sol#L260-L266) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L263-L265)

src/DelegateRegistry.sol#L260-L266


 - [ ] ID-6
[DelegateRegistry._writeDelegation(bytes32,IDelegateRegistry.StoragePositions,bytes32)](src/DelegateRegistry.sol#L290-L294) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L291-L293)

src/DelegateRegistry.sol#L290-L294


 - [ ] ID-7
[DelegateRegistry._writeDelegationAddresses(bytes32,IDelegateRegistry.StoragePositions,IDelegateRegistry.StoragePositions,address,address,address)](src/DelegateRegistry.sol#L304-L311) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L307-L310)

src/DelegateRegistry.sol#L304-L311


 - [ ] ID-8
[DelegateRegistry._loadFrom(bytes32,IDelegateRegistry.StoragePositions)](src/DelegateRegistry.sol#L376-L380) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L377-L379)

src/DelegateRegistry.sol#L376-L380


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
solc-0.8.20 is not recommended for deployment

 - [ ] ID-12
Pragma version[^0.8.20](src/tools/RegistryHarness.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/tools/RegistryHarness.sol#L2


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
Low level call in [DelegateRegistry.multicall(bytes[])](src/DelegateRegistry.sol#L34-L45):
	- [(success,results[i]) = address(this).delegatecall(data[i])](src/DelegateRegistry.sol#L41)

src/DelegateRegistry.sol#L34-L45


