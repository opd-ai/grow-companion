//
//  PrivacyBoundaryTests.swift
//  Grow CompanionTests
//
//  The product's privacy boundary is a fixed property, not a stage it passes
//  through: no account, no server, no network request and no location access.
//  These tests scan the app sources and the Info.plist so a later change cannot
//  add one without failing the suite.
//

import Foundation
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct PrivacyBoundaryTests {
    /// APIs that would open a connection or read the device's position.
    private static let forbiddenTokens = [
        "URLSession",
        "CloudKit",
        "CKContainer",
        "import CoreLocation",
        "CLLocationManager",
        "CLGeocoder"
    ]

    @Test func appSourcesOpenNoNetworkOrLocation() throws {
        let sources = try appSources()
        #expect(!sources.isEmpty, "No app sources were found to scan")

        var offenders: [String] = []
        for source in sources {
            for token in Self.forbiddenTokens where source.text.contains(token) {
                offenders.append("\(source.name) contains \(token)")
            }
        }

        #expect(offenders.isEmpty, "\(offenders.prefix(5))")
    }

    @Test func theInfoPlistAsksForNoLocation() throws {
        let plist = try String(contentsOf: infoPlistURL(), encoding: .utf8)

        #expect(!plist.contains("NSLocation"), "The app must not request location access")
        #expect(plist.contains("NSFaceIDUsageDescription"))
        #expect(plist.contains("NSCameraUsageDescription"))
    }

    @Test func thePrivacyCopyPromisesNoLookup() {
        let copy = LegalCopy.privacy.lowercased()

        #expect(copy.contains("no network request"))
        #expect(!copy.contains("location service"))
        #expect(!copy.contains("geocod"))
        #expect(!copy.contains("coordinate"))
    }

    @Test func theLocationResolverIsGone() throws {
        let resolver = repositoryRoot()
            .appendingPathComponent("Grow Companion")
            .appendingPathComponent("Services")
            .appendingPathComponent("LocationResolver.swift")

        #expect(!FileManager.default.fileExists(atPath: resolver.path))
    }

    // MARK: Files

    private struct Source {
        let name: String
        let text: String
    }

    private func appSources() throws -> [Source] {
        let root = repositoryRoot()
        let folders = [
            root.appendingPathComponent("Grow Companion"),
            root.appendingPathComponent("Grow CompanionWidgetExtension")
        ]

        var sources: [Source] = []
        for folder in folders {
            let enumerator = FileManager.default.enumerator(
                at: folder,
                includingPropertiesForKeys: nil
            )
            while let url = enumerator?.nextObject() as? URL {
                guard url.pathExtension == "swift" else { continue }
                let text = try String(contentsOf: url, encoding: .utf8)
                sources.append(Source(name: url.lastPathComponent, text: text))
            }
        }
        return sources
    }

    private func infoPlistURL() -> URL {
        repositoryRoot()
            .appendingPathComponent("Grow Companion")
            .appendingPathComponent("Info.plist")
    }

    /// The test bundle runs from DerivedData, so the project is found from this
    /// file's own path: Grow CompanionTests/<file> → repository root.
    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
