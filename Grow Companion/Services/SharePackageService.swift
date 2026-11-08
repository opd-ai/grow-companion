//
//  SharePackageService.swift
//  Grow Companion
//
//  Builds and opens protected grow shares. A share is a scoped payload sealed
//  with the device's key pair for one recipient's share code and signed by the
//  sender, then handed over as a file. There is no server in this flow.
//

import CryptoKit
import Foundation
import os

enum SharePackageError: LocalizedError {
    case noDeviceKey
    case invalidCode(String)
    case expired(Date)
    case unsupportedFormat(Int)
    case notAddressedToThisDevice
    case tampered
    case emptyScope

    var errorDescription: String? {
        switch self {
        case .noDeviceKey:
            return String(localized: "Create your share code first, then try again.")
        case .invalidCode(let reason):
            return String(localized: "That share code could not be read: \(reason).")
        case .expired(let date):
            return String(localized: "This share expired on \(Format.shortDate(date)).")
        case .unsupportedFormat(let version):
            return String(localized: "This share was created by a newer version of Grow Companion (format \(version)).")
        case .notAddressedToThisDevice:
            return String(localized: "This share is addressed to a different device, so it cannot be opened here.")
        case .tampered:
            return String(localized: "This share could not be verified. It may be damaged or altered.")
        case .emptyScope:
            return String(localized: "Choose at least one room or plant to share.")
        }
    }
}

/// A device's share code: its agreement public key and signing public key,
/// base64 encoded. It is public information, meant to be handed to the other
/// person, and it addresses shares and verifies who created them.
enum ShareCode {
    static let byteCount = 64
    private static let keyByteCount = 32

    static func encode(_ identity: SecureEnvelope.Identity) -> String {
        var data = Data()
        data.append(identity.agreementPublicKey.rawRepresentation)
        data.append(identity.signingPublicKey.rawRepresentation)
        return data.base64EncodedString()
    }

    static func decode(_ text: String) throws -> (agreement: Curve25519.KeyAgreement.PublicKey, signing: Curve25519.Signing.PublicKey) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed), data.count == byteCount else {
            throw SharePackageError.invalidCode("it is not a 64-byte share code")
        }

        do {
            let agreement = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: Data(data.prefix(keyByteCount)))
            let signing = try Curve25519.Signing.PublicKey(rawRepresentation: Data(data.suffix(keyByteCount)))
            return (agreement, signing)
        } catch {
            throw SharePackageError.invalidCode("the key is not valid")
        }
    }

    static func isValid(_ text: String) -> Bool {
        (try? decode(text)) != nil
    }
}

struct SharePackageService {
    typealias IdentityProvider = () throws -> SecureEnvelope.Identity

    struct PreparedShare {
        let payload: GrowSharePayload
        let data: Data
        let fileName: String
    }

    private let identityProvider: IdentityProvider
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GrowCompanion",
        category: "Sharing"
    )

    init(identityProvider: @escaping IdentityProvider = { try DeviceKeyStore.identity() }) {
        self.identityProvider = identityProvider
    }

    /// Projects the chosen categories, seals them for the recipient and names
    /// the file without any person, plant or room in it.
    func prepareShare(
        source: SharePayloadBuilder.Source,
        scope: ShareScope,
        recipientCode: String,
        now: Date = Date()
    ) throws -> PreparedShare {
        guard !scope.rooms.isEmpty || !scope.plants.isEmpty else {
            throw SharePackageError.emptyScope
        }

        let payload = SharePayloadBuilder.build(source: source, scope: scope, now: now)
        let data = try makePackage(for: payload, recipientCode: recipientCode)
        let fileName = "Grow-share-\(Self.stamp(now))"

        logger.notice("Prepared share with \(payload.totalRecords, privacy: .private) records")
        return PreparedShare(payload: payload, data: data, fileName: fileName)
    }

    func makePackage(for payload: GrowSharePayload, recipientCode: String) throws -> Data {
        let recipient = try ShareCode.decode(recipientCode)
        let identity = try currentIdentity()
        let plaintext = try Self.encode(payload)

        do {
            return try SecureEnvelope.seal(plaintext, to: recipient.agreement, from: identity)
        } catch {
            logger.error("Sealing a share failed")
            throw SharePackageError.tampered
        }
    }

    func openPackage(_ data: Data, senderCode: String, now: Date = Date()) throws -> GrowSharePayload {
        let sender = try ShareCode.decode(senderCode)
        let identity = try currentIdentity()

        let plaintext: Data
        do {
            plaintext = try SecureEnvelope.open(data, recipient: identity, sender: sender.signing)
        } catch let error as EnvelopeError {
            switch error {
            case .wrongRecipient:
                throw SharePackageError.notAddressedToThisDevice
            default:
                logger.error("Opening a share failed: \(String(describing: error), privacy: .private)")
                throw SharePackageError.tampered
            }
        } catch {
            logger.error("Opening a share failed")
            throw SharePackageError.tampered
        }

        let payload = try Self.decode(plaintext)
        guard !payload.isExpired(now: now) else {
            throw SharePackageError.expired(payload.expiresAt)
        }
        return payload
    }

    /// Canonical payload encoding, so identical payloads produce identical bytes.
    static func encode(_ payload: GrowSharePayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(payload)
    }

    static func decode(_ data: Data) throws -> GrowSharePayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let payload: GrowSharePayload
        do {
            payload = try decoder.decode(GrowSharePayload.self, from: data)
        } catch {
            throw SharePackageError.tampered
        }

        guard payload.formatVersion <= GrowSharePayload.currentFormatVersion else {
            throw SharePackageError.unsupportedFormat(payload.formatVersion)
        }
        return payload
    }

    private func currentIdentity() throws -> SecureEnvelope.Identity {
        do {
            return try identityProvider()
        } catch {
            logger.error("The device key is unavailable")
            throw SharePackageError.noDeviceKey
        }
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }
}

extension GrowSharePayload: Identifiable {
    var id: UUID { shareID }
}
