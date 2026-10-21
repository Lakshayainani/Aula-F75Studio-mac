import Foundation
import CryptoKit

/// A parsed image is structurally valid; it is not proof of compatibility with a keyboard.
public struct F75FirmwareImage: Sendable {
    public struct Segment: Sendable {
        public let address: UInt32
        public let bytes: [UInt8]
    }
    public let filename: String
    public let format: String
    public let sha256: String
    public let payloadSHA256: String
    public let vendorID: Int?
    public let productID: Int?
    public let sourceByteCount: Int
    public let recordCount: Int
    public let segments: [Segment]
    public var payloadByteCount: Int { segments.reduce(0) { $0 + $1.bytes.count } }
    public var firstAddress: UInt32 { segments[0].address }
    public var lastAddress: UInt32 { segments.last!.address + UInt32(segments.last!.bytes.count - 1) }

    public static func inspect(url: URL) throws -> F75FirmwareImage {
        let size = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard size.isRegularFile == true, let bytes = size.fileSize, bytes > 0, bytes <= 16 * 1024 * 1024 else {
            throw F75Error.invalid("Choose a firmware image or the supplied F75 updater, no larger than 16 MB.")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        let maximum = 16 * 1024 * 1024
        while data.count <= maximum {
            guard let part = try handle.read(upToCount: min(65536, maximum + 1 - data.count)), !part.isEmpty else { break }
            data.append(part)
        }
        return try inspect(data: data, filename: url.lastPathComponent)
    }

    public static func inspect(data: Data, filename: String) throws -> F75FirmwareImage {
        guard !data.isEmpty, data.count <= 16 * 1024 * 1024 else {
            throw F75Error.invalid("The firmware file is empty or larger than 16 MB.")
        }
        let sourceDigest = digest(data)
        if data.starts(with: [0x4D, 0x5A]) {
            return try inspectUpdater(data: data, filename: filename, sha256: sourceDigest)
        }
        guard let text = String(data: data, encoding: .ascii) else {
            throw F75Error.invalid("Choose an Intel HEX (.hex) image. Raw binaries have no established address or F75 identity.")
        }
        var memory: [UInt32: UInt8] = [:]
        var base: UInt32 = 0
        var finished = false
        var records = 0
        // Intel HEX record lengths, checksums, and address records follow the Intel format.
        for (lineIndex, rawLine) in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            func invalid(_ reason: String) -> F75Error { .invalid("HEX line \(lineIndex + 1): \(reason)") }
            guard !finished else { throw invalid("data appears after the end-of-file record.") }
            let characters = Array(line.utf8)
            guard characters.first == 0x3A, characters.count >= 11, characters.count <= 521,
                  characters.count % 2 == 1 else { throw invalid("invalid record framing.") }
            func nibble(_ c: UInt8) -> UInt8? {
                switch c {
                case 48...57: c - 48
                case 65...70: c - 55
                case 97...102: c - 87
                default: nil
                }
            }
            var record: [UInt8] = []
            for index in stride(from: 1, to: characters.count, by: 2) {
                guard let high = nibble(characters[index]), let low = nibble(characters[index + 1]) else {
                    throw invalid("a record contains non-hexadecimal characters.")
                }
                record.append(high << 4 | low)
            }
            let count = Int(record[0])
            guard record.count == count + 5 else { throw invalid("the byte count does not match the record.") }
            guard record.reduce(UInt8(0), &+) == 0 else { throw invalid("checksum mismatch; the image may be damaged.") }
            let offset = UInt32(record[1]) << 8 | UInt32(record[2])
            let payload = Array(record[4..<4 + count])
            records += 1
            switch record[3] {
            case 0:
                guard count > 0, offset + UInt32(count) <= 0x10000 else {
                    throw invalid("a data record is empty or crosses its 64 KB address window.")
                }
                let start = UInt64(base) + UInt64(offset)
                guard start + UInt64(count) <= UInt64(UInt32.max) + 1 else { throw invalid("address overflow.") }
                guard memory.count + count <= 1024 * 1024 else { throw invalid("payload exceeds the 1 MB inspection limit.") }
                for (index, byte) in payload.enumerated() {
                    let address = UInt32(start + UInt64(index))
                    guard memory.updateValue(byte, forKey: address) == nil else {
                        throw invalid("overlapping data records are not accepted.")
                    }
                }
            case 1:
                guard count == 0, offset == 0 else { throw invalid("malformed end-of-file record.") }
                finished = true
            case 2, 4:
                guard count == 2, offset == 0 else { throw invalid("malformed extended-address record.") }
                let value = UInt32(payload[0]) << 8 | UInt32(payload[1])
                base = record[3] == 2 ? value << 4 : value << 16
            case 3, 5:
                guard count == 4, offset == 0 else { throw invalid("malformed start-address record.") }
                // Start addresses are metadata, never a permission to reset or execute a device.
            default:
                throw invalid("unsupported record type \(record[3]).")
            }
        }
        guard finished, !memory.isEmpty else { throw F75Error.invalid("The HEX image must contain data and a final end-of-file record.") }
        var segments: [Segment] = []
        var start: UInt32 = 0
        var bytes: [UInt8] = []
        for address in memory.keys.sorted() {
            if !bytes.isEmpty, UInt64(start) + UInt64(bytes.count) != UInt64(address) {
                segments.append(Segment(address: start, bytes: bytes)); bytes = []
            }
            if bytes.isEmpty { start = address }
            bytes.append(memory[address]!)
        }
        segments.append(Segment(address: start, bytes: bytes))
        // Include addresses in the canonical payload digest so moving data changes its identity.
        var canonical = Data()
        for segment in segments {
            for value in [segment.address, UInt32(segment.bytes.count)] {
                canonical.append(contentsOf: [UInt8(value >> 24), UInt8((value >> 16) & 255), UInt8((value >> 8) & 255), UInt8(value & 255)])
            }
            canonical.append(contentsOf: segment.bytes)
        }
        return F75FirmwareImage(filename: filename, format: "Intel HEX", sha256: sourceDigest, payloadSHA256: digest(canonical),
                                vendorID: nil, productID: nil, sourceByteCount: data.count, recordCount: records, segments: segments)
    }

    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    private static func inspectUpdater(data: Data, filename: String, sha256: String) throws -> F75FirmwareImage {
        guard sha256 == "f694dab8d1937bcf52be81132095114a81da39d5e8130b166f2d7a27999ab9ce", data.count == 2_146_304 else {
            throw F75Error.invalid("This Windows updater is not the exact F75 updater analyzed for this app. Its image layout is unsupported.")
        }
        let offset = 0x18CD58
        let header: [UInt8] = [0x5A,0xA5,0x53,0x49,0x4E,0x4F,0x25,0x8A,0x01,0x0C,0xF0,0]
        guard Array(data[offset..<offset + 12]) == header else { throw F75Error.invalid("The updater's SINO image header is invalid.") }
        let encrypted = Array(data[offset + 12..<offset + 12 + 0xF000])
        let key = Array(data[offset + 12 + 0xF000..<offset + 16 + 0xF000]).map(UInt32.init)
        var decoded: [UInt8] = []
        // Updater 0x403970/0x4038e0: BE words, four byte-sized keys, 32 rounds, vendor delta.
        for index in stride(from: 0, to: encrypted.count, by: 8) {
            func word(_ start: Int) -> UInt32 { encrypted[start..<start + 4].reduce(0) { $0 << 8 | UInt32($1) } }
            var first = word(index), second = word(index + 4), sum: UInt32 = 0xC6ED3720
            for _ in 0..<32 {
                second = second &- (((first >> 5) &+ key[3]) ^ ((first << 4) &+ key[2]) ^ (sum &+ first))
                first = first &- (((second >> 5) &+ key[1]) ^ ((second << 4) &+ key[0]) ^ (sum &+ second))
                sum = sum &+ 0x61C89647
            }
            for value in [first, second] {
                decoded.append(contentsOf: [UInt8(value >> 24), UInt8((value >> 16) & 255), UInt8((value >> 8) & 255), UInt8(value & 255)])
            }
        }
        let payloadDigest = digest(Data(decoded))
        guard payloadDigest == "6610d821357fa654fa69cd11b32a714e118a9a38e5667cf87958dedbb7d2b703" else {
            throw F75Error.invalid("The extracted firmware does not match the analyzed image.")
        }
        return F75FirmwareImage(filename: filename, format: "Embedded SINO firmware", sha256: sha256, payloadSHA256: payloadDigest,
                                vendorID: 0x258A, productID: 0x010C, sourceByteCount: data.count, recordCount: 1,
                                segments: [Segment(address: 0, bytes: decoded)])
    }
}

public enum F75FirmwarePolicy {
    // shortcut: no authenticated F75 image or validated bootloader protocol; enable only with both.
    public static let flashingEnabled = false
    public static let blockingReasons = [
        "The supplied updater contains an image for USB 258A:010C, but its F75 hardware revision and version are not established.",
        "Its updater uses a different HID interface and bootloader from the 520-byte configuration interface.",
        "Bootloader entry, device matching, flash verification, and recovery have not been validated on this keyboard."
    ]
    public static func validateForFlashing(_ image: F75FirmwareImage) throws {
        throw F75Error.invalid("Firmware flashing is unavailable. " + blockingReasons.joined(separator: " "))
    }
}
