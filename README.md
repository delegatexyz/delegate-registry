# token-delegation

<img src="vault.png" width="300" />

## Overview

Welcome! If you're a programmer, view [the specific registry code here](src/DelegationRegistry.sol). If you want to discuss specific open questions, click on the "Issues" tab to leave a comment. If you're interested in integrating this standard into your token project or marketplace, we're in the process of creating example templates - or reach out directly via a [Twitter DM](https://twitter.com/0xfoobar).

We have an exciting group of initial people circling around this standard, including foobar (hi!), punk6529 (open metaverse), loopify (loopiverse), andy8052 (fractional), purplehat (artblocks), arran (proof), james (collabland), john (gnosis safe), wwhchung (manifoldxyz), tally labs and many more. The dream is to move from a fragmented world where no individual deployment gets serious use to a global registry where users can register their vault once and use it safely for a variety of airdrops & other claims! Please reach out if interested in helping make this a reality on either the technical, social, or integration side.


## Why delegation?

Proving ownership of an asset to a third party application in the Ethereum ecosystem is common. Common examples include claiming airdrops, minting from collection whitelists, and verifying token ownership for a gated discord/telegram channel. Users frequently sign payloads of data to authenticate themselves before gaining access to perform some operation. However, this introduces the danger of accidentally signing a malicious transaction from a cold wallet vault.

While a technical solution that "just works" may appear easy to code up, there's a reason no existing approaches have delighted users and hit mass adoption yet.
- EIP712 signatures are not smart contract compatible. 
- ENS names are a dangerous & clunky dependency not suitable for an EIP standard.
- Some solutions are too specific or hardcoded for general reuse.

## What features does this include?

### Fully Onchain, No EIP 712 signatures
Why? This is critical for smart contract composability, which cannot produce a private key signature. And while we could have two separate paths for delegation setup, one with smart contract calls and one with signature calls, this fragments adoption and developer use. Not to mention that allowing offchain signatures encourages people to interact with their vault and hotwallet in rapid succession, and accidental signatures can float around offchain with no easy way to revoke as we saw with the OpenSea "old ape offer" attack vector. More thoughts in [this tweet](https://twitter.com/0xfoobar/status/1557035539752181762).

### Fully Immutable, No Admin Powers
Why? Because governance is an attack vector. There should be none of it in a neutral trustless delegation standard. The standard is designed to be as flexible as possible, but upgrades are always possible by deploying a new registry with different functionality.

### Fully Extensible, User-Defined Roles
Why? Because we can't anticipate all the future use cases for delegation today. The registry should accomodate novel and distinct roles, via an [EIP-165-esque hashlist](https://eips.ethereum.org/EIPS/eip-165) for specific permissions. We will hardcode token-specific methods to ease adoption as well.

### Fully Standalone, No External Dependencies
Why? Because external dependencies are an unnecessary attack vector. 

### Fully Identifiable, Clear Unique Method Names
Why? Delegation is distinct from token ownership. Delegation implies the ability to claim or act on behalf of a token owner, but it does not imply the ability to move the token. So method names such as `balanceOf()` and `ownerOf()` should be avoided at all costs, replaced with clear method names that make it clear the hotwallet has delegation powers but not token ownership powers.

### Reusable Global Registry w/ Same Address Across Multiple EVM Chains
Why? For ease of use and adoption. It should also be a vanity address that's clearly distinguishable from others via CREATE2, either leading zeros or some fun prefix/postfix.

## Why not existing solutions?

Sincere appreciation for everyone who's taken a crack at this problem in the past with different tradeoffs. Comparison is done not to denigrate, but with the goal of hitting the best unified standard for mass adoption.

ENS delegation via [EIP-5131](https://eips.ethereum.org/EIPS/eip-5131): ENS is an offshore foundation with a for-profit token that charges rent for every new domain registration. We applaud the widespread adoption it's gotten, however this is a dangerous dependency for what should be a timeless standard. Additionally, delegations for a fresh wallet should be free (only gas) rather than costing additional economic rents.

wenew's approach via [HotWalletProxy](https://github.com/wenewlabs/public/blob/main/HotWalletProxy/HotWalletProxy.sol): This is the right directional approach, with an onchain registry that can be set via either a vault transaction or a vault signature submitted from a hot wallet. However it doesn't provide enough generalizability of drilling down into specific collections or specific tokens, the `ownerOf()` method naming overlaps with existing standards, and doesn't generalize to other types of delegation such as governance-specific standards. Delegation should be explicit rather than overwriting existing ERC721 method names.

### Open Questions
Please open an issue or pull request if you have ideas or code for how to address these issues, or thoughts on how important they are compared to a simple interface.

Can we get onchain enumeration?  
Can we get multiple delegation?  
Can we get timelocked delegation?  
Does the ENS fuse wrapper match what we're doing here?  
