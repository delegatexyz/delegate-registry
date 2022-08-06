# nft-delegation

### Why NFT delegation?

Proving ownership of an asset to a third party application in the Ethereum ecosystem is common. Users frequently sign payloads of data to authenticate themselves before gaining access to perform some operation. However, this method–akin to giving the third party root access to one’s main wallet–is both insecure and inconvenient.

### Why not existing solutions?

EIP712 signatures are not smart contract compatible. 
ENS names are a dangerous & clunky dependency not suitable for an EIP standard.
Some solutions are too specific or hardcoded for general reuse.

Opinionated:
- fully onchain, no EIP712 signatures
- fully immutable, no admin powers
- fully standalone, no external dependencies
- fully identifiable, clear method names
- reusable global registry w/ same address across multiple EVM chains

Why?
Onchain is critical for smart contract composability that can't produce a signature.
Immutable is critical for any public good that will stand the test of time.
Standalone is critical for ensuring the guarantees will stay valid.
Identifiable is critical to avoid phishing scams when people are using vaults to interact with the registry.
Reusable is critical so new projects can bootstrap off existing network effects.

Use an ERC-165-esque hash list for specific permissions. Start out with claim permissions but can expand to more later.

TODO: can we get onchain enumeration?
TODO: can we get all-at-once revocation?
TODO: can we get timelocked delegation for selling off airdrop rights?
TODO: does the ens fuse wrapper match what we're doing here?
