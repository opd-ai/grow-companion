# E2EE design: protected shares and future sync

**Status.** Protected, recipient-scoped **file sharing is implemented**: a share
code identifies a device, the chosen categories are sealed for one recipient,
signed by the sender, and handed over by the user through the system share sheet.
There is still no server, no account and no sync: a received file is read-only and
never merged into the recipient's own records.

The encryption has not been independently reviewed, and the app has not been
updated with App Store privacy labels for sharing. Both remain release-blocking
for a public launch of the feature; see section 9.

## 1. Scope

- **Implemented:** recipient-scoped share files, sender verification, expiry,
  read-only viewing, revocation recorded locally.
- **Not implemented:** cloud sync, conflict resolution, accounts, contact
  discovery, group sharing, revocation that reaches a file already handed over.
- **Never in scope:** commercial sale, transfer, delivery, possession trading,
  cultivation advice beyond the estimate, or sharing the journal and photos.

## 2. Assets and adversaries

**Assets.** Record contents (plants, rooms, feeds, readings, treatments, harvest
weights, journal text and photos), room and plant names, the compliance inputs,
identifiers linking records to a person, and the access structure itself.

**Adversaries considered.**

| Adversary | Capability | Mitigation |
| --- | --- | --- |
| Intermediary carrying the file | Stores or forwards the sealed file | Record contents encrypted on device |
| Network or message attacker | Reads or alters the file | Authenticated encryption plus a signature over the whole envelope |
| Recipient beyond the grant | Holds a decrypted copy after access ends | Scoped grants and expiry, with copy stating a file cannot be recalled |
| Another app user | Opens a file that is not theirs | Recipient key identifier checked before decryption |
| Stolen unlocked device | Reads the Keychain while unlocked | Keys are `WhenUnlockedThisDeviceOnly`; app lock covers the UI |
| Malicious update or replay | Resends or downgrades a share | One supported version and algorithm, fail closed |

**Out of scope.** A compromised recipient device, coercion of the grower, and any
guarantee about content after a recipient screenshots or copies it.

## 3. Key hierarchy

- **Device identity (implemented).** An X25519 agreement key and an Ed25519
  signing key, generated on device, stored in the Keychain with
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. The key identifier is the first
  8 bytes of SHA-256 over the raw public key, printed as 16 hex characters.
- **Share code (implemented).** The base64 of the agreement public key followed by
  the signing public key, 64 bytes in all. It is public: it addresses shares and
  verifies their sender. It is not a secret and is never used as a password.
- **Sync key (not implemented).** One symmetric key per grow, wrapped to each
  authorised device's agreement key, rotated on membership change.
- **Recovery key (not implemented).** 32 random bytes shown once at setup, never
  uploaded, wrapping the sync key so a lost device can be replaced.

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

## 5. Share flow (implemented, file based)

1. Each device shows a share code on the Sharing screen. It can be created on
   first use and removed at any time.
2. The grower sends their code to the other person, and receives that person's
   code, out of band (message, note, or in person).
3. The grower chooses scope — rooms, plants, categories — and an expiry, then
   prepares the share. Only the chosen categories are projected into the payload;
   the cultivation journal, photos, county and plant notes are never included.
4. The payload is sealed for the recipient's code and signed by the sender, then
   handed to the system share sheet as a file named `Grow-share-<date>`.
5. The recipient opens the file, pastes the sender's code, and sees a read-only
   view. A wrong recipient, wrong sender, tampered file, unknown format or expired
   share is refused with a specific message.
6. The sender's device records the share locally, with a revoke action that marks
   the record and states plainly that a file already handed over cannot be
   recalled.

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

- Delete-all destroys the local store, photos and the device key. Any synced copy
  is deleted with a tombstone and, for a full purge, by destroying the sync key so
  remaining ciphertext is unreadable.
- Revoking a share records the change on the sender's device. It does not reach a
  file the recipient already holds; the UI and help text must say so.
- Removing a device from a grow (future) rotates the sync key and re-wraps it for
  the remaining devices.

## 8. Failure behaviour

- Unknown envelope version or format: reject, no downgrade.
- Recipient identifier mismatch: reject without attempting decryption.
- Bad signature or bad tag: reject, report tampering.
- No key available (locked device): the operation fails and the UI explains it;
  nothing is written in the clear as a fallback.
- Storage full or file unreadable: the operation fails and the source is unchanged.

## 9. Invariants

1. The app makes no network request. A share file is the only thing the app
   produces for another device.
2. The grower creates and sends the file themselves; the app has no transport.
3. The recipient's copy is read-only and covers only the categories the grower
   chose.
4. The device key pair stays in the Keychain, available only while unlocked, and
   never leaves the device.
5. A malformed, tampered or unsupported envelope is rejected rather than read.

The remaining engineering work is two-device device testing and a downgrade story
for a future payload version.

## 10. What is tested today, and what is not

Unit tests cover:

- `SecureEnvelopeTests`: round trip, absence of plaintext in the envelope,
  uniqueness of two seals, wrong recipient, wrong sender, altered ciphertext,
  altered header, unknown version, truncation, key-identifier stability.
- `SharingTests`: scoping by room, plant and category; journal, county and plant
  notes absent from the encoded payload; harvest only when selected; compliance
  only when selected; expired scope pushed forward; share-code round trip; package
  round trip between two devices; wrong recipient; wrong sender; tampered file;
  expired package; empty scope; newer payload format refused.

Not covered, and therefore not claimed: the Keychain integration itself, the
future sync key hierarchy, and interoperability with another implementation. The
tests compile in CI but were not executed in this environment because no simulator
is available.
