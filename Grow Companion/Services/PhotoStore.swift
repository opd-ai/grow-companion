//
//  PhotoStore.swift
//  Grow Companion
//
//  Journal photos live in an app-private folder with complete file protection.
//  Images are re-encoded on import, which drops all metadata including GPS.
//

import Foundation
import UIKit

enum PhotoStore {
    private static let directoryName = "GrowPhotos"
    private static let cache = NSCache<NSString, UIImage>()

    static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
        }
        return dir
    }

    static func url(for fileName: String) -> URL {
        directory().appendingPathComponent(fileName)
    }

    static func thumbnailName(for fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        return base + "-thumb.jpg"
    }

    /// Re-encodes the image (dropping EXIF metadata), writes a display copy and
    /// a thumbnail, and returns the file name to store on the entry.
    static func save(imageData: Data) -> String? {
        guard let image = UIImage(data: imageData) else { return nil }
        let fileName = UUID().uuidString + ".jpg"

        let displayImage = downscaled(image, maxDimension: 2048)
        guard let displayData = displayImage.jpegData(compressionQuality: 0.85) else { return nil }

        let thumbImage = downscaled(image, maxDimension: 400)
        guard let thumbData = thumbImage.jpegData(compressionQuality: 0.7) else { return nil }

        do {
            try displayData.write(to: url(for: fileName), options: [.atomic, .completeFileProtection])
            try thumbData.write(
                to: url(for: thumbnailName(for: fileName)),
                options: [.atomic, .completeFileProtection]
            )
            return fileName
        } catch {
            return nil
        }
    }

    static func image(named fileName: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: fileName).path)
    }

    static func thumbnail(named fileName: String) -> UIImage? {
        let key = fileName as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let loaded = UIImage(contentsOfFile: url(for: thumbnailName(for: fileName)).path)
            ?? UIImage(contentsOfFile: url(for: fileName).path)
        if let loaded {
            cache.setObject(loaded, forKey: key)
        }
        return loaded
    }

    static func delete(named fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
        try? FileManager.default.removeItem(at: url(for: thumbnailName(for: fileName)))
        cache.removeObject(forKey: fileName as NSString)
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory())
        cache.removeAllObjects()
    }

    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
