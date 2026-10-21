import Foundation

public struct F75MacroEvent: Codable, Equatable, Sendable {
    public var usage: UInt8
    public var isPressed: Bool
    public var delayMS: Int
    public init(usage: UInt8, isPressed: Bool, delayMS: Int = 20) {
        self.usage = usage; self.isPressed = isPressed; self.delayMS = delayMS
    }
}

public struct F75Macro: Codable, Equatable, Sendable {
    public var name: String
    public var events: [F75MacroEvent]
    public init(name: String, events: [F75MacroEvent]) { self.name = name; self.events = events }
}

public enum F75MacroCodec {
    public static let maximumDelayMS = 0xFFFFF
    public static let maximumRecordLength = 4096
    public static let bankCapacity = 4096
    public static let maximumRecords = 100

    /// Keeps existing records opaque so macros with mouse actions survive an append unchanged.
    public static func decodeBank(_ bytes: [UInt8]) throws -> [[UInt8]] {
        guard !bytes.isEmpty, bytes.count <= bankCapacity else { throw F75Error.invalid("Invalid macro bank size.") }
        if bytes.allSatisfy({ $0 == 0 }) || bytes.allSatisfy({ $0 == 255 }) { return [] }
        guard bytes.count >= 4 else { throw F75Error.invalid("Truncated macro table.") }
        let firstOffset = Int(bytes[0]) | Int(bytes[1]) << 8
        guard firstOffset >= 4, firstOffset % 4 == 0, firstOffset / 4 <= maximumRecords,
              firstOffset <= bytes.count else { throw F75Error.invalid("The keyboard's macro table is unsupported. No macros were changed.") }
        var records: [[UInt8]] = []
        var expectedOffset = firstOffset
        for index in 0..<(firstOffset / 4) {
            let p = index * 4
            let offset = Int(bytes[p]) | Int(bytes[p + 1]) << 8
            let length = Int(bytes[p + 2]) | Int(bytes[p + 3]) << 8
            guard offset == expectedOffset, length > 0, length <= bytes.count - offset else {
                throw F75Error.invalid("The macro table contains an invalid or overlapping record.")
            }
            let record = Array(bytes[offset..<offset + length])
            try validateRecord(record)
            records.append(record)
            expectedOffset = offset + length
        }
        return records
    }

    public static func encodeBank(_ records: [[UInt8]]) throws -> [UInt8] {
        guard !records.isEmpty, records.count <= maximumRecords else { throw F75Error.invalid("A macro bank must contain 1–100 records.") }
        var offset = records.count * 4
        var table: [UInt8] = []
        var content: [UInt8] = []
        for record in records {
            try validateRecord(record)
            guard record.count <= bankCapacity - offset else { throw F75Error.invalid("The keyboard's 4 KB macro memory is full.") }
            table += [UInt8(offset & 255), UInt8(offset >> 8), UInt8(record.count & 255), UInt8(record.count >> 8)]
            content += record
            offset += record.count
        }
        return table + content
    }

    public static func appending(_ macro: F75Macro, to bank: [UInt8]) throws -> (data: [UInt8], index: Int) {
        var records = try decodeBank(bank)
        let record = try encode(macro)
        if let existing = records.firstIndex(of: record) { return (try encodeBank(records), existing) }
        let index = records.count
        records.append(record)
        return (try encodeBank(records), index)
    }

    public static func replacing(_ macro: F75Macro, at index: Int, expectedRecord: [UInt8], in bank: [UInt8]) throws -> [UInt8] {
        var records = try decodeBank(bank)
        guard records.indices.contains(index), records[index] == expectedRecord else {
            throw F75Error.invalid("The keyboard macro changed since it was loaded. Read its macros again before updating.")
        }
        records[index] = try encode(macro)
        return try encodeBank(records)
    }

    public static func assigningMacro(_ keys: [UInt8], matrixIndex: Int, macroIndex: Int, repeatCount: Int = 1) throws -> [UInt8] {
        guard keys.count == 512, Array(keys.suffix(2)) == [0x5A, 0xA5],
              Array(keys[212..<216]) == [13, 0, 0, 0],
              matrixIndex != 53, F75Layout.keys.contains(where: { $0.matrixIndex == matrixIndex }),
              (0..<maximumRecords).contains(macroIndex), (1...255).contains(repeatCount) else {
            throw F75Error.invalid("Choose a supported macro key and repeat count of 1–255. The Fn key is protected.")
        }
        var changed = keys
        changed.replaceSubrange(matrixIndex * 4..<matrixIndex * 4 + 4, with: [3, 1, UInt8(repeatCount), UInt8(macroIndex)])
        return changed
    }

    public static func validateReferences(_ keys: [UInt8], bank: [UInt8]) throws {
        guard keys.count == 512 else { throw F75Error.invalid("Invalid key mapping size.") }
        let records = try decodeBank(bank)
        for offset in stride(from: 0, to: keys.count, by: 4) where keys[offset] == 3 {
            guard Int(keys[offset + 3]) < records.count,
                  [UInt8(1), 2, 4].contains(keys[offset + 1]), keys[offset + 2] > 0 else {
                throw F75Error.invalid("A key refers to a missing macro or an unsupported macro playback mode.")
            }
        }
    }

    private static func validateRecord(_ bytes: [UInt8]) throws {
        guard let nameLength = bytes.first, nameLength <= 60, nameLength % 2 == 0,
              bytes.count <= maximumRecordLength, bytes.count >= Int(nameLength) + 1,
              (bytes.count - Int(nameLength) - 1) % 4 == 0 else {
            throw F75Error.invalid("Invalid macro record in the keyboard's memory.")
        }
    }

    // REA StMacro_To_HdMacro, OemDrv.exe 0x48cf00: UTF-16LE name then four-byte events.
    public static func encode(_ macro: F75Macro) throws -> [UInt8] {
        let name = Array(macro.name.utf16)
        guard !name.isEmpty, name.count <= 30, !name.contains(0),
              !macro.events.isEmpty, macro.events.count <= (maximumRecordLength - 1 - name.count * 2) / 4 else {
            throw F75Error.invalid("Use a macro name of 1–30 UTF-16 characters and a sequence that fits the keyboard's memory.")
        }
        var held = Set<UInt8>()
        var bytes: [UInt8] = [UInt8(name.count * 2)]
        for unit in name { bytes += [UInt8(unit & 255), UInt8(unit >> 8)] }
        for event in macro.events {
            guard (4...0xA4).contains(Int(event.usage)) || (0xE0...0xE7).contains(Int(event.usage)),
                  (0...maximumDelayMS).contains(event.delayMS) else {
                throw F75Error.invalid("Macro keys must be keyboard HID usages; delays must be 0–1,048,575 ms.")
            }
            if event.isPressed {
                guard held.insert(event.usage).inserted else { throw F75Error.invalid("A macro key is pressed twice without a release.") }
            } else {
                guard held.remove(event.usage) != nil else { throw F75Error.invalid("A macro key is released before it is pressed.") }
            }
            let kind = event.usage >= 0xE0 ? 0x10 : 0
            bytes += [UInt8(event.delayMS >> 16) | UInt8(kind) | (event.isPressed ? 0 : 0x80),
                      UInt8((event.delayMS >> 8) & 255), UInt8(event.delayMS & 255), event.usage]
        }
        guard held.isEmpty else { throw F75Error.invalid("Release every macro key before the sequence ends.") }
        return bytes
    }

    public static func decode(_ bytes: [UInt8]) throws -> F75Macro {
        guard let nameLength = bytes.first, nameLength > 0, nameLength <= 60, nameLength % 2 == 0,
              bytes.count <= maximumRecordLength, bytes.count > Int(nameLength) + 1,
              (bytes.count - Int(nameLength) - 1) % 4 == 0 else { throw F75Error.invalid("Invalid macro record length.") }
        let nameData = Data(bytes[1...Int(nameLength)])
        guard let name = String(data: nameData, encoding: .utf16LittleEndian), !name.utf16.contains(0) else {
            throw F75Error.invalid("The macro name is not valid UTF-16.")
        }
        var events: [F75MacroEvent] = []
        for offset in stride(from: Int(nameLength) + 1, to: bytes.count, by: 4) {
            let flags = bytes[offset], usage = bytes[offset + 3]
            guard (flags & 0x70) == (usage >= 0xE0 && usage <= 0xE7 ? 0x10 : 0) else {
                throw F75Error.invalid("This macro contains unsupported mouse or movement events.")
            }
            events.append(F75MacroEvent(usage: usage, isPressed: flags & 0x80 == 0,
                                       delayMS: Int(flags & 15) << 16 | Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2])))
        }
        let macro = F75Macro(name: name, events: events)
        guard try encode(macro) == bytes else { throw F75Error.invalid("The macro record is not supported.") }
        return macro
    }
}
