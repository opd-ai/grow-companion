//
//  SecureEnvelopeTests.swift
//  Grow CompanionTests
//
//  Round-trip, addressing and tamper tests for the protected envelope. These
//  cover the cryptographic contract only; the transport is not implemented.
//

import CryptoKit
import Foundation
import Testing
@testable import Grow_Companion

struct SecureEnvelopeTests {
    private func identity() -> SecureEnvelope.Identity {
        SecureEnvelope.Identity(
            agreement: Curve25519.KeyAgreement.PrivateKey(),
            signing: Curve25519.Signing.PrivateKey()
        )
    }

    @Test func roundTripReturnsThePlaintext() throws {
        let sender = identity()
        let recipient = identity()
        let plaintext = Data("harvest weight 42 g".utf8)

        let envelope = try SecureEnvelope.seal(plaintext, to: recipient.agreementPublicKey, from: sender)
        let opened = try SecureEnvelope.open(envelope, recipient: recipient, sender: sender.signingPublicKey)

        #expect(opened == plaintext)
    }

    @Test func envelopeCarriesNoPlaintext() throws {
        let sender = identity()
        let recipient = identity()
        let marker = Data("harvest weight 42 g".utf8)

        let envelope = try SecureEnvelope.seal(marker, to: recipient.agreementPublicKey, from: sender)

        #expect(envelope.range(of: marker) == nil)
        #expect(envelope.count == SecureEnvelope.headerByteCount
            + marker.count
            + SecureEnvelope.tagByteCount
            + SecureEnvelope.signatureByteCount)
    }

    @Test func twoSealsOfTheSamePlaintextDiffer() throws {
        let sender = identity()
        let recipient = identity()
        let plaintext = Data("same".utf8)

        let first = try SecureEnvelope.seal(plaintext, to: recipient.agreementPublicKey, from: sender)
        let second = try SecureEnvelope.seal(plaintext, to: recipient.agreementPublicKey, from: sender)

        #expect(first != second)
    }

    @Test func envelopeForAnotherRecipientIsRejected() throws {
        let sender = identity()
        let intended = identity()
        let other = identity()

        let envelope = try SecureEnvelope.seal(Data("scoped".utf8), to: intended.agreementPublicKey, from: sender)

        #expect(throws: EnvelopeError.self) {
            try SecureEnvelope.open(envelope, recipient: other, sender: sender.signingPublicKey)
        }
    }

    @Test func envelopeSignedByAnotherSenderIsRejected() throws {
        let sender = identity()
        let impostor = identity()
        let recipient = identity()

        let envelope = try SecureEnvelope.seal(Data("scoped".utf8), to: recipient.agreementPublicKey, from: sender)

        #expect(throws: EnvelopeError.self) {
            try SecureEnvelope.open(envelope, recipient: recipient, sender: impostor.signingPublicKey)
        }
    }

    @Test func alteredCiphertextIsRejected() throws {
        let sender = identity()
        let recipient = identity()
        var envelope = try SecureEnvelope.seal(Data("scoped".utf8), to: recipient.agreementPublicKey, from: sender)

        let ciphertextStart = envelope.startIndex + SecureEnvelope.headerByteCount
        envelope[ciphertextStart] ^= 0x01

        #expect(throws: EnvelopeError.self) {
            try SecureEnvelope.open(envelope, recipient: recipient, sender: sender.signingPublicKey)
        }
    }

    @Test func alteredHeaderIsRejected() throws {
        let sender = identity()
        let recipient = identity()
        var envelope = try SecureEnvelope.seal(Data("scoped".utf8), to: recipient.agreementPublicKey, from: sender)

        let recipientIDStart = envelope.startIndex + SecureEnvelope.magic.count + 2
        envelope[recipientIDStart] ^= 0x01

        #expect(throws: EnvelopeError.self) {
            try SecureEnvelope.open(envelope, recipient: recipient, sender: sender.signingPublicKey)
        }
    }

    @Test func unknownVersionFailsClosed() throws {
        let sender = identity()
        let recipient = identity()
        var envelope = try SecureEnvelope.seal(Data("scoped".utf8), to: recipient.agreementPublicKey, from: sender)

        envelope[envelope.startIndex + SecureEnvelope.magic.count] = 9

        #expect(throws: EnvelopeError.self) {
            try SecureEnvelope.open(envelope, recipient: recipient, sender: sender.signingPublicKey)
        }
    }

    @Test func truncatedEnvelopeIsRejected() throws {
        let sender = identity()
        let recipient = identity()
        var envelope = try SecureEnvelope.seal(Data("scoped".utf8), to: recipient.agreementPublicKey, from: sender)

        envelope = envelope.prefix(SecureEnvelope.headerByteCount)

        #expect(throws: EnvelopeError.self) {
            try SecureEnvelope.open(envelope, recipient: recipient, sender: sender.signingPublicKey)
        }
    }

    @Test func keyIdentifiersAreStableAndShort() {
        let mine = identity()
        let first = SecureEnvelope.keyID(for: mine.agreementPublicKey)
        let second = SecureEnvelope.keyID(for: mine.agreementPublicKey)

        #expect(first == second)
        #expect(first.count == SecureEnvelope.keyIDByteCount)
        #expect(SecureEnvelope.keyIDText(first).count == SecureEnvelope.keyIDByteCount * 2)
        #expect(SecureEnvelope.keyID(for: mine.agreementPublicKey) != SecureEnvelope.keyID(for: mine.signingPublicKey))
    }
}
