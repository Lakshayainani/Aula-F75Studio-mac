import Foundation

public enum F75Error: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
}

public struct F75Lighting: Codable, Equatable, Sendable {
    public var effect: Int
    public var brightness: Int
    public var speed: Int
    public var red: Int
    public var green: Int
    public var blue: Int
    public var rainbow: Bool
    public init(effect: Int = 1, brightness: Int = 5, speed: Int = 2, red: Int = 255, green: Int = 80, blue: Int = 140, rainbow: Bool = false) {
        self.effect = effect; self.brightness = brightness; self.speed = speed
        self.red = red; self.green = green; self.blue = blue; self.rainbow = rainbow
    }
}

public struct F75Snapshot: Codable, Sendable {
    public let identity: [UInt8]
    public let lightingData: [UInt8]
    public let keyData: [UInt8]
    public let macroData: [UInt8]?
    public let capturedAt: Date
    public init(identity: [UInt8], lightingData: [UInt8], keyData: [UInt8], macroData: [UInt8]? = nil, capturedAt: Date = Date()) throws {
        try F75Protocol.validate(identity: identity, lighting: lightingData, keys: keyData)
        if let macroData, macroData.count != F75MacroCodec.bankCapacity { throw F75Error.invalid("Invalid macro backup size.") }
        self.identity = identity; self.lightingData = lightingData; self.keyData = keyData; self.macroData = macroData; self.capturedAt = capturedAt
    }
    public var lighting: F75Lighting { F75Protocol.decodeLighting(lightingData) }
    public func validate() throws {
        try F75Protocol.validate(identity: identity, lighting: lightingData, keys: keyData)
        if let macroData, macroData.count != F75MacroCodec.bankCapacity { throw F75Error.invalid("Invalid macro backup size.") }
        if let macroData { try F75MacroCodec.validateReferences(keyData, bank: macroData) }
    }
    public func validateRestore(over currentKeys: [UInt8]) throws {
        try validate()
        guard currentKeys.count == 512 else { throw F75Error.invalid("Invalid current key mapping size.") }
        if macroData == nil {
            for offset in stride(from: 0, to: keyData.count, by: 4) where keyData[offset] == 3 {
                guard keyData[offset..<offset + 4] == currentKeys[offset..<offset + 4] else {
                    throw F75Error.invalid("This older backup contains a macro assignment without its macro data. Use a full macro backup to restore that assignment.")
                }
            }
        }
    }
}

public enum F75Protocol {
    public static let reportID: UInt8 = 6
    public static let reportLength = 520
    // Hardware IDs and names are from the supplied KB.ini / English text resources.
    public static let effects: [(id: Int, name: String)] = [
        (1,"Steady"), (2,"Rainbow"), (3,"Breathing"), (4,"Self-defined"), (5,"Rotating windmill"),
        (6,"Sine wave"), (7,"Lights off"), (8,"Colorful waterfall"), (9,"Rotating storm"),
        (10,"Raindrops"), (11,"Ripples"), (12,"Blossoming"), (13,"Reactive"), (14,"Twinkling stars"),
        (15,"Effect 15"), (16,"Effect 16"), (17,"Following scan"), (18,"Effect 18"), (0,"Off")
    ]
    public static let colors: [(name: String, red: Int, green: Int, blue: Int)] = [
        ("Red",255,0,0), ("Green",0,255,0), ("Blue",0,0,255), ("Yellow",255,255,0),
        ("Magenta",255,0,255), ("Cyan",0,255,255), ("White",255,255,255)
    ]
    public static func supportsIdentity(_ bytes: [UInt8]) -> Bool { bytes == [3,0,0,0,0,0xCD] }
    public static func frame(command: UInt8, subcommand: UInt8 = 0, length: Int, payload: [UInt8] = [], page: Int = 0, pageCount: Int = 1) throws -> [UInt8] {
        guard (1...255).contains(pageCount), (0..<pageCount).contains(page), (1...512).contains(length), payload.isEmpty || payload.count == length else { throw F75Error.invalid("Invalid packet length.") }
        var bytes = [UInt8](repeating: 0, count: reportLength)
        bytes[0] = reportID; bytes[1] = command; bytes[2] = subcommand
        bytes[4] = UInt8(pageCount); bytes[5] = UInt8(page); bytes[6] = UInt8(length & 255); bytes[7] = UInt8(length >> 8)
        if !payload.isEmpty { bytes.replaceSubrange(8..<8+length, with: payload) }
        return bytes
    }
    public static func responsePayload(_ response: [UInt8], command: UInt8, subcommand: UInt8 = 0, length: Int, page: Int = 0, pageCount: Int = 1) throws -> [UInt8] {
        guard (1...255).contains(pageCount), (0..<pageCount).contains(page), (1...512).contains(length), response.count == length + 8 || response.count == reportLength,
              response.count >= length + 8, response[0] == reportID, response[1] == command,
              response[2] == subcommand, response[3] == 0, response[4] == UInt8(pageCount), response[5] == UInt8(page),
              Int(response[6]) | (Int(response[7]) << 8) == length else {
            throw F75Error.invalid("The keyboard returned an unexpected or truncated response. Reconnect and read again.")
        }
        return Array(response[8..<8+length])
    }
    public static func validate(identity: [UInt8], lighting: [UInt8], keys: [UInt8]) throws {
        guard supportsIdentity(identity) else { throw F75Error.invalid("This device is not the F75 model identified by the supplied driver (model CD).") }
        guard lighting.count == 128, Array(lighting.suffix(2)) == [0x5A,0xA5],
              keys.count == 512, Array(keys.suffix(2)) == [0x5A,0xA5],
              Array(keys[212..<216]) == [13,0,0,0] else {
            throw F75Error.invalid("The keyboard's configuration layout is unsupported. No changes were sent.")
        }
    }
    public static func remapping(_ original: [UInt8], matrixIndex: Int, targetMatrixIndex: Int) throws -> [UInt8] {
        let allowed = Set(F75Layout.keys.map(\.matrixIndex))
        guard original.count == 512, Array(original.suffix(2)) == [0x5A,0xA5],
              allowed.contains(matrixIndex), allowed.contains(targetMatrixIndex),
              matrixIndex != 53, targetMatrixIndex != 53 else { throw F75Error.invalid("Choose two supported keys. The Fn key is protected.") }
        var result = original
        result.replaceSubrange(matrixIndex*4..<matrixIndex*4+4, with: original[targetMatrixIndex*4..<targetMatrixIndex*4+4])
        return result
    }
    // REA: FUN_0048d810, ev_06f4f1969332d71dad85912a4d12200b0b03863eaa9ac71faf07e0a037ed6cd9.
    public static func decodeLighting(_ data: [UInt8]) -> F75Lighting {
        guard data.count == 128 else { return F75Lighting() }
        let effect = Int(data[10])
        let index = effect == 0 ? 19 : (effect == 21 ? 18 : max(0, min(17, effect - 1)))
        let colorIndex = Int(data[59 + index * 2] & 15)
        let color = colors[min(colorIndex, 6)]
        return F75Lighting(effect: effect, brightness: Int(data[58 + index * 2]),
                           speed: Int(data[59 + index * 2] >> 4),
                           red: colorIndex == 7 ? 255 : color.red,
                           green: colorIndex == 7 ? 0 : color.green,
                           blue: colorIndex == 7 ? 0 : color.blue, rainbow: colorIndex == 7)
    }
    public static func changingLighting(_ data: [UInt8], to settings: F75Lighting) throws -> [UInt8] {
        guard data.count == 128, Array(data.suffix(2)) == [0x5A,0xA5],
              effects.contains(where: { $0.id == settings.effect }),
              (0...9).contains(settings.brightness), (0...4).contains(settings.speed) else {
            throw F75Error.invalid("Choose a supported effect, brightness 0–9, and speed 0–4.")
        }
        let colorIndex = settings.rainbow ? 7 : colors.firstIndex(where: {
            $0.red == settings.red && $0.green == settings.green && $0.blue == settings.blue
        })
        guard let colorIndex else { throw F75Error.invalid("Choose one of the seven keyboard colors or Rainbow.") }
        let index = settings.effect == 0 ? 19 : settings.effect - 1
        var changed = data
        changed[9] = 0
        changed[10] = UInt8(settings.effect)
        changed[58 + index * 2] = UInt8(settings.brightness)
        changed[59 + index * 2] = UInt8(settings.speed << 4 | colorIndex)
        return changed
    }

}

/// Serializes complete feature transactions; the keyboard remains available for normal typing.
public final class F75Session: @unchecked Sendable {
    private let transport: F75HIDTransport
    private let lock = NSLock()
    public let identity: [UInt8]
    public init(device: F75HIDDevice) throws {
        guard device.vendorID == 0x258A, device.productID == 0x010C,
              device.usagePage == 1, device.usage == 128, device.maxFeatureReportSize == 520,
              device.transport == "USB" else { throw F75Error.invalid("Connect the supported F75 with its USB cable.") }
        let transport = try F75HIDTransport(device: device)
        self.transport = transport
        do {
            let request = try F75Protocol.frame(command: 0x82, subcommand: 1, length: 6)
            try transport.setFeatureReport(reportID: 6, bytes: request)
            Thread.sleep(forTimeInterval: 0.04)
            identity = try F75Protocol.responsePayload(transport.getFeatureReport(reportID: 6, length: 520), command: 0x82, subcommand: 1, length: 6)
            guard F75Protocol.supportsIdentity(identity) else { throw F75Error.invalid("This keyboard has a different model identifier; configuration is disabled.") }
        } catch { transport.close(); throw error }
    }
    public func close() { lock.lock(); defer { lock.unlock() }; transport.close() }
    public func readSnapshot(includeMacros: Bool = false) throws -> F75Snapshot {
        lock.lock(); defer { lock.unlock() }; return try readUnlocked(includeMacros: includeMacros)
    }
    public func applyLighting(_ settings: F75Lighting) throws -> F75Snapshot {
        lock.lock(); defer { lock.unlock() }
        let before = try readUnlocked()
        let changed = try F75Protocol.changingLighting(before.lightingData, to: settings)
        if changed == before.lightingData { return before }
        try backup(before)
        try write(command: 4, payload: changed)
        let after = try readUnlocked()
        guard after.lighting == F75Protocol.decodeLighting(changed) else { throw F75Error.invalid("The keyboard did not confirm the lighting change. Read its current settings before retrying.") }
        return after
    }
    public func remapKey(matrixIndex: Int, to targetMatrixIndex: Int) throws -> F75Snapshot {
        lock.lock(); defer { lock.unlock() }
        let current = try readUnlocked()
        let hasMacros = stride(from: 0, to: current.keyData.count, by: 4).contains { current.keyData[$0] == 3 }
        let before = try hasMacros ? F75Snapshot(identity: identity, lightingData: current.lightingData, keyData: current.keyData,
                                               macroData: read(command: 0x85, length: F75MacroCodec.bankCapacity)) : current
        let changed = try F75Protocol.remapping(before.keyData, matrixIndex: matrixIndex, targetMatrixIndex: targetMatrixIndex)
        if changed == before.keyData { return before }
        try backup(before)
        try write(command: 3, payload: changed)
        let after = try readUnlocked()
        guard after.keyData == changed else { throw F75Error.invalid("The keyboard did not confirm the key mapping. A backup of the original mapping is saved.") }
        return after
    }
    public func applyMacro(_ macro: F75Macro, matrixIndex: Int) throws -> F75Snapshot {
        lock.lock(); defer { lock.unlock() }
        let before = try readUnlocked(includeMacros: true)
        try F75MacroCodec.validateReferences(before.keyData, bank: before.macroData!)
        let bank = try F75MacroCodec.appending(macro, to: before.macroData!)
        let keys = try F75MacroCodec.assigningMacro(before.keyData, matrixIndex: matrixIndex, macroIndex: bank.index)
        try backup(before)
        if Array(before.macroData!.prefix(bank.data.count)) != bank.data {
            try write(command: 5, payload: bank.data)
            let confirmed = try read(command: 0x85, length: 4096)
            guard Array(confirmed.prefix(bank.data.count)) == bank.data else {
                throw F75Error.invalid("Macro storage did not verify. The key assignment was not changed; a full backup is saved.")
            }
        }
        if keys != before.keyData { try write(command: 3, payload: keys) }
        let after = try readUnlocked(includeMacros: true)
        guard after.lightingData == before.lightingData, after.keyData == keys, Array(after.macroData!.prefix(bank.data.count)) == bank.data else {
            throw F75Error.invalid("Macro assignment did not verify. Read the keyboard before retrying; a full backup is saved.")
        }
        return after
    }
    public func updateMacro(_ macro: F75Macro, at index: Int, expectedRecord: [UInt8]) throws -> F75Snapshot {
        lock.lock(); defer { lock.unlock() }
        let before = try readUnlocked(includeMacros: true)
        try before.validate()
        let data = try F75MacroCodec.replacing(macro, at: index, expectedRecord: expectedRecord, in: before.macroData!)
        if Array(before.macroData!.prefix(data.count)) == data { return before }
        try backup(before)
        try write(command: 5, payload: data)
        let after = try readUnlocked(includeMacros: true)
        guard after.keyData == before.keyData, after.lightingData == before.lightingData,
              Array(after.macroData!.prefix(data.count)) == data else {
            throw F75Error.invalid("The macro update did not verify. A full backup is saved; read the keyboard before retrying.")
        }
        return after
    }

    public func restore(_ snapshot: F75Snapshot) throws -> F75Snapshot {
        try snapshot.validate()
        lock.lock(); defer { lock.unlock() }
        guard identity == snapshot.identity else { throw F75Error.invalid("The backup belongs to a different keyboard model.") }
        let current = try readUnlocked(includeMacros: snapshot.macroData != nil)
        try snapshot.validateRestore(over: current.keyData)
        let needsMacroBackup = current.macroData == nil && stride(from: 0, to: current.keyData.count, by: 4).contains { current.keyData[$0] == 3 }
        let before = try needsMacroBackup ? F75Snapshot(identity: identity, lightingData: current.lightingData, keyData: current.keyData,
                                                      macroData: read(command: 0x85, length: F75MacroCodec.bankCapacity)) : current
        try backup(before)
        if let macros = snapshot.macroData, macros != before.macroData {
            try write(command: 5, payload: macros)
            guard try read(command: 0x85, length: 4096) == macros else { throw F75Error.invalid("Macro restoration did not verify; key mappings were not changed.") }
        }
        if snapshot.lightingData != before.lightingData { try write(command: 4, payload: snapshot.lightingData) }
        if snapshot.keyData != before.keyData { try write(command: 3, payload: snapshot.keyData) }
        let after = try readUnlocked(includeMacros: snapshot.macroData != nil)
        guard after.macroData == snapshot.macroData, after.keyData == snapshot.keyData, after.lightingData == snapshot.lightingData else {
            throw F75Error.invalid("Restoration did not fully verify. Read the current settings; the previous state is backed up.")
        }
        return after
    }
    private func readUnlocked(includeMacros: Bool = false) throws -> F75Snapshot {
        try F75Snapshot(identity: identity, lightingData: read(command: 0x84, length: 128), keyData: read(command: 0x83, length: 512), macroData: includeMacros ? read(command: 0x85, length: 4096) : nil)
    }
    public func readMacroData() throws -> [UInt8] {
        lock.lock(); defer { lock.unlock() }
        return try read(command: 0x85, length: 4096)
    }
    private func read(command: UInt8, length: Int) throws -> [UInt8] {
        let pages = (length + 511) / 512
        var result: [UInt8] = []
        for page in 0..<pages {
            let count = min(512, length - page * 512)
            try transport.setFeatureReport(reportID: 6, bytes: F75Protocol.frame(command: command, length: count, page: page, pageCount: pages))
            Thread.sleep(forTimeInterval: 0.04)
            result += try F75Protocol.responsePayload(transport.getFeatureReport(reportID: 6, length: 520), command: command, length: count, page: page, pageCount: pages)
        }
        return result
    }
    private func write(command: UInt8, payload: [UInt8]) throws {
        guard [3,4,5].contains(command), !payload.isEmpty, payload.count <= (command == 5 ? 4096 : 512) else { throw F75Error.invalid("Unsupported configuration command or length.") }
        let pages = (payload.count + 511) / 512
        for page in 0..<pages {
            let fragment = Array(payload[page * 512..<min(payload.count, (page + 1) * 512)])
            try transport.setFeatureReport(reportID: 6, bytes: F75Protocol.frame(command: command, length: fragment.count, payload: fragment, page: page, pageCount: pages))
            Thread.sleep(forTimeInterval: 0.15)
        }
    }
    private func backup(_ snapshot: F75Snapshot) throws {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("F75Studio/Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: directory.appendingPathComponent("before-change-\(UUID().uuidString).json"), options: .atomic)
    }
}
