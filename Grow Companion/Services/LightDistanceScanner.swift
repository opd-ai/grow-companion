//
//  LightDistanceScanner.swift
//  Grow Companion
//
//  Reads a temporary center depth sample from LiDAR. No depth frame is saved.
//

import ARKit
import Combine
import Foundation

@MainActor
final class LightDistanceScanner: NSObject, ObservableObject, ARSessionDelegate {
    let session = ARSession()
    @Published private(set) var distanceMeters: Double?
    let isSupported: Bool

    override init() {
        isSupported = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        super.init()
        session.delegate = self
    }

    func start() {
        guard isSupported else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
        configuration.isLightEstimationEnabled = true
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        session.pause()
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthMap = frame.sceneDepth?.depthMap else { return }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0 else { return }

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let centerX = width / 2
        let centerY = height / 2
        let row = baseAddress.advanced(by: centerY * bytesPerRow)
        let value = row.assumingMemoryBound(to: Float32.self)[centerX]
        guard value.isFinite, value > 0.05, value < 5 else { return }

        Task { @MainActor [weak self] in
            self?.distanceMeters = Double(value)
        }
    }
}
