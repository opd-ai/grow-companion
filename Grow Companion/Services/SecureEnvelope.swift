//
//  SecureEnvelope.swift
//  Grow Companion
//
//  Versioned, authenticated encryption envelope for protected sharing and sync.
//  This is the cryptographic half only: there is no transport, server, account
//  or recipient directory in this build. See docs/E2EE_DESIGN.md for the threat
//  model, the byte layout and the gates that must pass before it is used to send
//  anything to anyone.
//

import CryptoKit
import Foundation
import Security

enum EnvelopeError: LocalizedError {
    case malformed(String)
    case unsupportedVersion
    case wrongRecipient
    case signatureInvalid
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .malformed(let detail):
            return "The protected envelope could not be read: \(detail)"
        case .unsupportedVersion:
            return "The protected envelope was written by a newer version of Grow Companion."
        case .wrongRecipient:
            return "The protected envelope is addressed to a different device key."
        case .signatureInvalid:
            return "The protected envelope is not signed by the expected sender."
        case .authenticationFailed:
            return "The protected envelope could not be authenticated. It may have been altered."
        }
    }
}

enum SecureEnvelope {
    /// Envelope layout version. Anything other than 1 fails closed.
    static let version: UInt8 = 1

    /// 1 = X25519 key agreement, HKDF-SHA256, AES-256-GCM and Ed25519.
    static let algorithm: UInt8 = 1

    static let magic = Data("GCENV".utf8)

    static let keyIDByteCount = 8
    static let saltByteCount = 16
    static let nonceByteCount = 12
    static let tagByteCount = 16
    static let signatureByteCount = 64
    static let ephemeralPublicKeyByteCount = 32
    static let ciphertextLengthByteCount = 4
    static let derivedKeyByteCount = 32

    /// magic + version + algorithm + recipient id + sender id + ephemeral key
    /// + salt + nonce + ciphertext length.
    static let headerByteCount = 5 + 1 + 1 + keyIDByteCount + keyIDByteCount
        + ephemeralPublicKeyByteCount + saltByteCount + nonceByteCount
        + ciphertextLengthByteCount

    private static let keyInfo = Data("GrowCompanion/envelope/v1".utf8)

    struct Identity {
        let agreement: Curve25519.KeyAgreement.PrivateKey
        let signing: Curve25519.Signing.PrivateKey

        var agreementPublicKey: Curve25519.KeyAgreement.PublicKey { agreement.publicKey }
        var signingPublicKey: Curve25519.Signing.PublicKey { signing.publicKey }
    }

    // MARK: - Key identifiers

    /// The first 8 bytes of SHA-256 over the raw public key. Long enough to name
    /// a key, short enough to print in a status screen.
    static func keyID(for key: Curve25519.KeyAgreement.PublicKey) -> Data {
        keyID(rawRepresentation: key.rawRepresentation)
    }

    static func keyID(for key: Curve25519.Signing.PublicKey) -> Data {
        keyID(rawRepresentation: key.rawRepresentation)
    }

    static func keyIDText(_ identifier: Data) -> String {
        identifier.map { String(format: "%02x", $0) }.joined()
    }

    private static func keyID(rawRepresentation: Data) -> Data {
        Data(SHA256.hash(data: rawRepresentation).prefix(keyIDByteCount))
    }

    // MARK: - Seal and open

    /// Encrypts `plaintext` for `recipient` and signs it with `sender`.
    ///
    /// The header is the AES-GCM authenticated data, so the recipient and sender
    /// identifiers, the ephemeral key, the salt and the nonce are all bound to
    /// the ciphertext. The signature covers the header, the ciphertext and the
    /// tag, so nothing in the envelope can be altered without detection.
    static func seal(
        _ plaintext: Data,
        to recipient: Curve25519.KeyAgreement.PublicKey,
        from sender: Identity
    ) throws -> Data {
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: recipient)
        let salt = try randomBytes(count: saltByteCount)
        let nonceData = try randomBytes(count: nonceByteCount)
        let key = deriveKey(shared: shared, salt: salt)
        let nonce = try AES.GCM.Nonce(data: nonceData)

        var header = Data()
        header.append(magic)
        header.append(version)
        header.append(algorithm)
        header.append(keyID(for: recipient))
        header.append(keyID(for: sender.signingPublicKey))
        header.append(ephemeral.publicKey.rawRepresentation)
        header.append(salt)
        header.append(nonceData)
        header.appendBigEndian(UInt32(plaintext.count))

        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: header)

        var signed = header
        signed.append(sealed.ciphertext)
        signed.append(sealed.tag)

        let signature = try sender.signing.signature(for: signed)

        var envelope = signed
        envelope.append(signature)
        return envelope
    }

    /// Verifies and decrypts an envelope addressed to `recipient`.
    static func open(
        _ envelope: Data,
        recipient: Identity,
        sender signingKey: Curve25519.Signing.PublicKey
    ) throws -> Data {
        let data = Data(envelope)
        let minimum = headerByteCount + tagByteCount + signatureByteCount
        guard data.count >= minimum else {
            throw EnvelopeError.malformed("the envelope is too short")
        }

        func slice(_ offset: Int, _ length: Int) -> Data {
            let start = data.startIndex + offset
            return Data(data[start..<(start + length)])
        }

        guard slice(0, magic.count) == magic else {
            throw EnvelopeError.malformed("the header is missing")
        }
        guard data[data.startIndex + magic.count] == version,
              data[data.startIndex + magic.count + 1] == algorithm else {
            throw EnvelopeError.unsupportedVersion
        }

        var offset = magic.count + 2
        let recipientKeyID = slice(offset, keyIDByteCount)
        offset += keyIDByteCount
        let senderKeyID = slice(offset, keyIDByteCount)
        offset += keyIDByteCount
        let ephemeralData = slice(offset, ephemeralPublicKeyByteCount)
        offset += ephemeralPublicKeyByteCount
        let salt = slice(offset, saltByteCount)
        offset += saltByteCount
        let nonceData = slice(offset, nonceByteCount)
        offset += nonceByteCount
        let ciphertextLength = Int(readBigEndianUInt32(data, at: offset))
        offset += ciphertextLengthByteCount

        guard offset == headerByteCount else {
            throw EnvelopeError.malformed("the header is not the expected size")
        }
        guard recipientKeyID == keyID(for: recipient.agreementPublicKey) else {
            throw EnvelopeError.wrongRecipient
        }
        guard data.count == minimum + ciphertextLength else {
            throw EnvelopeError.malformed("the length does not match the contents")
        }

        let header = slice(0, headerByteCount)
        let ciphertext = slice(headerByteCount, ciphertextLength)
        let tag = slice(headerByteCount + ciphertextLength, tagByteCount)
        let signed = slice(0, headerByteCount + ciphertextLength + tagByteCount)
        let signature = slice(headerByteCount + ciphertextLength + tagByteCount, signatureByteCount)

        guard senderKeyID == keyID(for: signingKey),
              signingKey.isValidSignature(signature, for: signed) else {
            throw EnvelopeError.signatureInvalid
        }

        do {
            let ephemeral = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralData)
            let shared = try recipient.agreement.sharedSecretFromKeyAgreement(with: ephemeral)
            let key = deriveKey(shared: shared, salt: salt)
            let box = try AES.GCM.SealedBox(
                nonce: try AES.GCM.Nonce(data: nonceData),
                ciphertext: ciphertext,
                tag: tag
            )
            return try AES.GCM.open(box, using: key, authenticating: header)
        } catch let error as EnvelopeError {
            throw error
        } catch {
            throw EnvelopeError.authenticationFailed
        }
    }

    // MARK: - Primitives

    private static func deriveKey(shared: SharedSecret, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: shared),
            salt: salt,
            info: keyInfo,
            outputByteCount: derivedKeyByteCount
        )
    }

    private static func randomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw EnvelopeError.malformed("secure random data is unavailable")
        }
        return Data(bytes)
    }

    private static func readBigEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let start = data.startIndex + offset
        var value: UInt32 = 0
        for index in 0..<4 {
            value = (value << 8) | UInt32(data[start + index])
        }
        return value
    }
}
