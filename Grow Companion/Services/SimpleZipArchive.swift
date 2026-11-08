//
//  SimpleZipArchive.swift
//  Grow Companion
//
//  A minimal ZIP writer with stored (uncompressed) entries. That is a valid
//  ZIP that any archive tool opens, and it needs no third-party dependency.
//

import Foundation

struct SimpleZipArchive {
    private struct Entry {
        let name: String
        let data: Data
    }

    private var entries: [Entry] = []

    mutating func add(_ data: Data, as name: String) {
        entries.append(Entry(name: name, data: data))
    }

    func makeData() -> Data {
        var output = Data()
        var centralDirectory = Data()

        let flags: UInt16 = 0x0800 // File names are UTF-8.
        let dosDate: UInt16 = 33   // 1 January 1980, the earliest ZIP date.
        let dosTime: UInt16 = 0

        for entry in entries {
            let nameData = Data(entry.name.utf8)
            let checksum = SimpleZipArchive.crc32(entry.data)
            let size = UInt32(entry.data.count)
            let offset = UInt32(output.count)

            output.appendLittleEndian(UInt32(0x04034b50))
            output.appendLittleEndian(UInt16(20))
            output.appendLittleEndian(flags)
            output.appendLittleEndian(UInt16(0))
            output.appendLittleEndian(dosTime)
            output.appendLittleEndian(dosDate)
            output.appendLittleEndian(checksum)
            output.appendLittleEndian(size)
            output.appendLittleEndian(size)
            output.appendLittleEndian(UInt16(nameData.count))
            output.appendLittleEndian(UInt16(0))
            output.append(nameData)
            output.append(entry.data)

            centralDirectory.appendLittleEndian(UInt32(0x02014b50))
            centralDirectory.appendLittleEndian(UInt16(20))
            centralDirectory.appendLittleEndian(UInt16(20))
            centralDirectory.appendLittleEndian(flags)
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(dosTime)
            centralDirectory.appendLittleEndian(dosDate)
            centralDirectory.appendLittleEndian(checksum)
            centralDirectory.appendLittleEndian(size)
            centralDirectory.appendLittleEndian(size)
            centralDirectory.appendLittleEndian(UInt16(nameData.count))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt32(0))
            centralDirectory.appendLittleEndian(offset)
            centralDirectory.append(nameData)
        }

        let centralOffset = UInt32(output.count)
        output.append(centralDirectory)

        output.appendLittleEndian(UInt32(0x06054b50))
        output.appendLittleEndian(UInt16(0))
        output.appendLittleEndian(UInt16(0))
        output.appendLittleEndian(UInt16(entries.count))
        output.appendLittleEndian(UInt16(entries.count))
        output.appendLittleEndian(UInt32(centralDirectory.count))
        output.appendLittleEndian(centralOffset)
        output.appendLittleEndian(UInt16(0))

        return output
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) == 1 ? (0xEDB88320 ^ (value >> 1)) : (value >> 1)
        }
        return value
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crcTable[index]
        }
        return crc ^ 0xFFFFFFFF
    }
}

extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        let bytes = Swift.withUnsafeBytes(of: &little) { Array($0) }
        append(contentsOf: bytes)
    }
}
