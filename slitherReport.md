**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [shadowing-local](#shadowing-local) (1 results) (Low)
 - [missing-zero-check](#missing-zero-check) (1 results) (Low)
 - [calls-loop](#calls-loop) (1 results) (Low)
 - [assembly](#assembly) (6 results) (Informational)
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
[DelegateRegistry.multicall(bytes[])](src/DelegateRegistry.sol#L42-L51) has external calls inside a loop: [(success,results[i]) = address(this).delegatecall(data[i])](src/DelegateRegistry.sol#L47)

src/DelegateRegistry.sol#L42-L51


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-3
[DelegateRegistry._loadDelegationUint(bytes32,DelegateRegistry.StoragePositions)](src/DelegateRegistry.sol#L416-L420) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L417-L419)

src/DelegateRegistry.sol#L416-L420


 - [ ] ID-4
[DelegateRegistry._writeDelegation(bytes32,DelegateRegistry.StoragePositions,address)](src/DelegateRegistry.sol#L353-L357) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L354-L356)

src/DelegateRegistry.sol#L353-L357


 - [ ] ID-5
[DelegateRegistry._loadDelegationAddress(bytes32,DelegateRegistry.StoragePositions)](src/DelegateRegistry.sol#L423-L427) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L424-L426)

src/DelegateRegistry.sol#L423-L427


 - [ ] ID-6
[DelegateRegistry._writeDelegation(bytes32,DelegateRegistry.StoragePositions,bytes32)](src/DelegateRegistry.sol#L339-L343) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L340-L342)

src/DelegateRegistry.sol#L339-L343


 - [ ] ID-7
[DelegateRegistry._writeDelegation(bytes32,DelegateRegistry.StoragePositions,uint256)](src/DelegateRegistry.sol#L346-L350) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L347-L349)

src/DelegateRegistry.sol#L346-L350


 - [ ] ID-8
[DelegateRegistry._loadDelegationBytes32(bytes32,DelegateRegistry.StoragePositions)](src/DelegateRegistry.sol#L409-L413) uses assembly
	- [INLINE ASM](src/DelegateRegistry.sol#L410-L412)

src/DelegateRegistry.sol#L409-L413


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
Low level call in [DelegateRegistry.multicall(bytes[])](src/DelegateRegistry.sol#L42-L51):
	- [(success,results[i]) = address(this).delegatecall(data[i])](src/DelegateRegistry.sol#L47)

src/DelegateRegistry.sol#L42-L51


