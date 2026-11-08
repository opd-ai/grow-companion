# E2EE sharing and sync — design and current status

**Status: foundation only.** The protected envelope and the device key storage are
implemented and unit-tested in this build. There is **no transport, no account,
no server and no recipient directory**, and no screen in the app offers sharing
or sync. Nothing described here may be claimed as a shipped feature until the
gates in section 9 are met.

This document is the design of record for the shared/sync track. It is not a
claim of end-to-end encryption in the product.

## 1. Goal and non-goals

**Goal.** A grower can give a chosen person a scoped, read-only view of selected
records, and later keep two of their own devices in step, without the service
operator being able to read record contents.

**Non-goals for this track.** No sale, transfer, transport or distribution
pathway; no public posting; no discovery of other growers; no analytics of
shared content; no health advice; no collection of a personal effect journal.

## 2. Assets and adversaries

**Assets.** Record contents (plants, rooms, feeds, readings, treatments, harvest
weights, journal text and photos), room and plant names, the compliance inputs,
identifiers linking records to a person, and the access structure itself.

**Adversaries considered.**

| Adversary | Capability | Mitigation |
| --- | --- | --- |
| Service operator | Stores ciphertext, sees ciphertext sizes and timing | Record contents encrypted on device; metadata minimised and padded |
| Network attacker | Reads or alters traffic | Authenticated encryption with a signature over the whole envelope |
| Recipient beyond the grant | Holds a decrypted copy after access ends | Scoped grants, expiry, documented that a recipient can copy what they see |
| Another app user | Guesses an envelope is theirs | Recipient key identifier checked before decryption |
| Stolen unlocked device | Reads the Keychain while unlocked | Keys are `WhenUnlockedThisDeviceOnly`; app lock covers the UI |
| Malicious update or replay | Resends or downgrades an envelope | Version and algorithm fixed to a single supported value, fail closed |

**Out of scope.** A compromised recipient device, coercion of the grower, traffic
analysis beyond padding, and any guarantee about content after a recipient
screenshots or copies it.

## 3. Key hierarchy

- **Device identity (implemented).** An X25519 agreement key and an Ed25519
  signing key, generated on device, stored in the Keychain with
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. The key identifier is the first
  8 bytes of SHA-256 over the raw public key, printed as 16 hex characters.
- **Sync key (not implemented).** One symmetric key per grow, generated on the
  first device and wrapped to each authorised device's agreement key. Rotated on
  any membership change; rotation is a new key version plus re-wrapping.
- **Recovery key (not implemented).** 32 random bytes shown once at setup, never
  uploaded. It wraps the sync key so a lost device can be replaced without the
  operator ever holding a key. The UI must force the grower to confirm it is
  stored outside the app before sync is enabled.

## 4. Envelope format, version 1 (implemented)

Binary, big-endian, versioned. Layout:

| Offset | Size | Field |
| --- | --- | --- |
| 0 | 5 | magic `GCENV` |
| 5 | 1 | version (1) |
| 6 | 1 | algorithm (1 = X25519, HKDF-SHA256, AES-256-GCM, Ed25519) |
| 7 | 8 | recipient key identifier |
| 15 | 8 | sender key identifier |
| 23 | 32 | ephemeral X25519 public key |
| 55 | 16 | HKDF salt |
| 71 | 12 | AES-GCM nonce |
| 83 | 4 | ciphertext length |
| 87 | n | ciphertext |
| 87 + n | 16 | AES-GCM tag |
| 103 + n | 64 | Ed25519 signature |

Construction:

1. Generate an ephemeral X25519 key and derive the shared secret with the
   recipient's agreement key.
2. Derive a 32-byte key with HKDF-SHA256, salt = the envelope salt, info =
   `GrowCompanion/envelope/v1`.
3. Encrypt with AES-256-GCM, using bytes 0 to 86 as authenticated data.
4. Sign bytes 0 to (102 + n) — header, ciphertext and tag — with the sender's
   Ed25519 key.

Verification on open: magic, version and algorithm must be exactly the supported
values; the recipient identifier must equal the local agreement key's identifier;
the declared length must match the file exactly; the sender identifier must match
the supplied signing key and its signature must verify; only then is the GCM box
opened. Every failure is a distinct typed error, and there is no fallback path.

`salt`, `nonce` and the ephemeral key are fresh for every envelope, so sealing the
same plaintext twice never produces the same bytes.

## 5. Future sharing flow (not implemented)

1. Recipient sends their agreement public key to the grower out of band (a
   QR code or a text message; the key is public and not sensitive).
2. The grower chooses scope (rooms, plants, categories) and an expiry, exactly as
   the current placeholder screen describes.
3. The app builds a canonical, versioned payload of only the selected records —
   no journal, no location, no unrelated rooms — and seals one envelope per
   recipient key.
4. Delivery is out of band or through the operator, which only ever stores the
   envelope.
5. The recipient imports the envelope, checks the sender's key identifier against
   the one they were given, and reads it.

Revocation ends future delivery. It cannot un-send an envelope the recipient
already holds, and the UI must say so.

## 6. Future sync flow (not implemented)

- Each record is encrypted as an opaque blob keyed by a random per-record
  identifier; names, room associations and record types are inside the ciphertext.
- Blob sizes are padded into buckets before upload.
- Uploads are batched and delayed to blunt timing correlation.
- Deletions are tombstones that carry only an opaque identifier and a version.
- Conflicts are append-only sets of record versions. Identical identifier with
  identical canonical payload is idempotent; identical identifier with different
  payload is surfaced to the grower, never resolved by last-writer-wins.
- Clock skew is bounded by storing both a device sequence number and a wall-clock
  time, and by refusing to move backwards on a per-device sequence.
- Replay is rejected by the record version and the device sequence.

## 7. Deletion and revocation

- Delete-all destroys the local store, photos and the device key. Any synced
  copy is deleted with a tombstone and, for a full purge, by destroying the sync
  key so remaining ciphertext is unreadable.
- The operator may retain ciphertext until retention expires; that must be stated
  in the policy, not hidden.
- Removing a device from a grow rotates the sync key and re-wraps it for the
  remaining devices.

## 8. Failure behaviour

- Unknown envelope version or algorithm: reject, no downgrade.
- Recipient identifier mismatch: reject without attempting decryption.
- Bad signature or bad tag: reject, report tampering.
- No key available (locked device): the operation fails and the UI explains it;
  nothing is written in the clear as a fallback.
- Storage full: the operation fails and the source is unchanged.

## 9. Gates before this can ship as a feature

1. Attorney and privacy review of sharing, recipient disclosure, retention and
   revocation. See `docs/LEGAL_REVIEW.md`.
2. A decision on transport: CloudKit, an owned backend, or a purely out-of-band
   file exchange — with a documented metadata and retention posture.
3. An account or exchange identity model, plus deletion, export and revocation
   semantics for a second party's data.
4. Independent cryptographic review of this envelope and of the sync key
   management, and test vectors checked outside this repository.
5. Device testing on a locked device, across reboot, while backgrounded, and with
   the app lock on.
6. App Store privacy labels and policy text that match the implementation.
7. A migration plan for any new stored types, covered by the data inventory and
   the delete-all verification.

Until all seven are met, the app keeps saying there is no cloud sync and no
sharing, and the device key is described as prepared but unused.

## 10. What is tested today, and what is not

Unit tests in `Grow CompanionTests/SecureEnvelopeTests.swift` cover: round trip,
absence of plaintext in the envelope, uniqueness of two seals, wrong recipient,
wrong sender, altered ciphertext, altered header, unknown version, truncation and
key-identifier stability.

Not covered, and therefore not claimed: the Keychain integration itself, the
future sync key hierarchy, out-of-band key exchange, anything over a network, and
any interoperability with another implementation. The tests compile in CI but
were not executed in this environment because no simulator is available.
