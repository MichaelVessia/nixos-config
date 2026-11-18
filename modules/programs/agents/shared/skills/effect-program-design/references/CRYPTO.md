# Select crypto services at the runtime boundary

This guidance uses the Effect 4.1 APIs. Check them against the installed declarations.

For crypto operations in Effect 4.1, use the required family from `effect/crypto/*`:
`SecureRandom` for randomness and UUIDs, `Digest` for hashes, `Mac` for message
authentication, `Aead` for authenticated encryption, and `Signature` for signatures.
Other families include `Cipher`, `Kdf`, `KeyAgreement`, and `KeyWrap`.
Check the installed declarations for supported algorithms and key formats.

Keep these service requirements in the adapter. At the composition root, provide
layers for the consumer's existing runtime, such as `NodeCrypto`, `BunCrypto`,
`DenoCrypto`, or `BrowserCrypto`. Each has family layers and a combined `layer`.
Crypto is no longer part of the runtime `*Services` bundles.
Core families also expose `layerWebCrypto`. Check their remaining requirements,
including `SecureRandom`, before composition.
Do not change the application's runtime to obtain a crypto implementation.

This adapter computes a SHA-256 checksum. Only the composition root selects Node:

```ts
import * as Effect from 'effect/Effect'
import * as Digest from 'effect/crypto/Digest'

interface ChecksumInput {
	readonly bytes: Uint8Array
}
export const checksum = Effect.fn('assets.checksum')(function* (input: ChecksumInput) {
	const digest = yield* Digest.Digest
	return yield* digest.digestHex(Digest.sha256, input.bytes)
})
```

In the Node composition root:

```ts
// main.ts
import * as NodeCrypto from '@effect/platform-node/NodeCrypto'
import * as NodeRuntime from '@effect/platform-node/NodeRuntime'
import * as Effect from 'effect/Effect'
import { checksum } from './checksum.js'

checksum({ bytes: new TextEncoder().encode('abc') }).pipe(
	Effect.tap((hex) => Effect.log(hex)),
	Effect.provide(NodeCrypto.layerDigest),
	NodeRuntime.runMain,
)
```

The `digestHex` method of the `Digest` service returns lowercase hex. This example logs
`ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`.
Digest operations have no typed failure in these declarations. Fallible key,
encryption, and signing operations expose `CryptoError`. Keep those failures
typed, then map them to caller-actionable errors at the adapter boundary.
Record only safe details before narrowing. Never record keys or raw crypto causes.
Do not add `orDie` to remove an operational crypto failure.

## Preserve bytes and algorithms during migration

Effect 4.1 removes `effect/Crypto` and `effect/testing/TestCrypto`.
Use `Layer.mock` for the required family in tests.
Before replacing an existing implementation, compare known vectors against the
current output. Preserve input encoding, algorithm parameters, key format,
output length, hex case, Base64 variant and padding, nonce, and authentication
tag layout. A hash with the same length is not necessarily the same algorithm.
If the required algorithm or format is unavailable, retain the existing adapter
and document the reason. Do not substitute an algorithm or truncate its output.

Keep keys opaque where the API supports them. Secret and private key schemas
require `{ allowEncode: true }` for byte or format encoding. Enable that option
only at the boundary that must export the key. Test compatibility with stored
values and external verifiers before replacing an implementation.
