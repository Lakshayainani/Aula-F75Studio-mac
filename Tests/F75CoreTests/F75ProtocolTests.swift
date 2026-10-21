import Foundation

@main enum ProtocolSelfTest {
    static func rejects(_ body: () throws -> Void) {
        do { try body(); fatalError("Expected invalid input to be rejected") } catch { }
    }
    static func main() throws {
        try testMacroCodec()
        try testMacroLibrary()
        try testFirmwareCodec()
        let packet = try F75Protocol.frame(command: 0x82, subcommand: 1, length: 6)
        precondition(packet.count == 520)
        precondition(Array(packet.prefix(8)) == [6,0x82,1,0,1,0,6,0])
        let response: [UInt8] = [6,0x82,1,0,1,0,6,0,3,0,0,0,0,0xCD]
        let identity = try F75Protocol.responsePayload(response, command: 0x82, subcommand: 1, length: 6)
        precondition(F75Protocol.supportsIdentity(identity))
        precondition(!F75Protocol.supportsIdentity([3,0,0,0,0,0xE1]))
        rejects { _ = try F75Protocol.frame(command: 3, length: 513) }
        rejects { _ = try F75Protocol.responsePayload(Array(response.dropLast()), command: 0x82, subcommand: 1, length: 6) }
        rejects { _ = try F75Protocol.responsePayload(response, command: 0x84, length: 6) }
        let paged = try F75Protocol.frame(command: 0x85, length: 7, page: 2, pageCount: 3)
        precondition(Array(paged.prefix(8)) == [6,0x85,0,0,3,2,7,0])
        let pagePayload = try F75Protocol.responsePayload(paged, command: 0x85, length: 7, page: 2, pageCount: 3)
        precondition(pagePayload == [UInt8](repeating: 0, count: 7))
        rejects { _ = try F75Protocol.frame(command: 5, length: 1, page: 3, pageCount: 3) }
        rejects { _ = try F75Protocol.frame(command: 5, length: 1, pageCount: 256) }
        rejects { _ = try F75Protocol.responsePayload(paged, command: 0x85, length: 7, page: 1, pageCount: 3) }
        let frames = try JSONDecoder().decode([[UInt8]].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        let config = try F75Protocol.responsePayload(frames[3], command: 0x84, length: 128)
        let keys = try F75Protocol.responsePayload(frames[5], command: 0x83, length: 512)
        let snapshot = try F75Snapshot(identity: identity, lightingData: config, keyData: keys)
        let changed = try F75Protocol.remapping(keys, matrixIndex: 9, targetMatrixIndex: 34)
        precondition(Array(changed[36..<40]) == Array(keys[136..<140]))
        for i in keys.indices where !(36..<40).contains(i) { precondition(changed[i] == keys[i]) }
        rejects { _ = try F75Protocol.remapping(keys, matrixIndex: 53, targetMatrixIndex: 9) }
        rejects { _ = try F75Protocol.remapping(keys, matrixIndex: 9, targetMatrixIndex: 53) }
        rejects { _ = try F75Protocol.remapping(keys, matrixIndex: 126, targetMatrixIndex: 9) }
        rejects { _ = try F75Snapshot(identity: identity, lightingData: [], keyData: keys) }
        let lighting = F75Lighting(effect: 3, brightness: 8, speed: 2, red: 0, green: 255, blue: 0)
        let edited = try F75Protocol.changingLighting(config, to: lighting)
        precondition(edited[9] == 0 && edited[10] == 3 && edited[62] == 8 && edited[63] == 0x21)
        for i in config.indices where ![9,10,62,63].contains(i) { precondition(edited[i] == config[i]) }
        precondition(F75Protocol.decodeLighting(edited) == lighting)
        rejects { _ = try F75Protocol.changingLighting(config, to: F75Lighting(effect: 21)) }
        rejects { _ = try F75Protocol.changingLighting(config, to: F75Lighting(brightness: 99)) }
        rejects { _ = try F75Protocol.changingLighting(config, to: F75Lighting(red: 200, green: 55, blue: 60)) }
        let decoded = try JSONDecoder().decode(F75Snapshot.self, from: JSONEncoder().encode(snapshot))
        try decoded.validate()
        precondition(decoded.keyData == keys && decoded.lightingData == config)
        precondition(decoded.macroData == nil)
        let bank = [UInt8](repeating: 255, count: F75MacroCodec.bankCapacity)
        let fullBackup = try F75Snapshot(identity: identity, lightingData: config, keyData: keys, macroData: bank)
        let fullDecoded = try JSONDecoder().decode(F75Snapshot.self, from: JSONEncoder().encode(fullBackup))
        try fullDecoded.validate()
        precondition(fullDecoded.macroData == bank)
        rejects { _ = try F75Snapshot(identity: identity, lightingData: config, keyData: keys, macroData: [0]) }
        let macroKeys = try F75MacroCodec.assigningMacro(keys, matrixIndex: 9, macroIndex: 0)
        let legacyMacro = try F75Snapshot(identity: identity, lightingData: config, keyData: macroKeys)
        try legacyMacro.validateRestore(over: macroKeys)
        rejects { try legacyMacro.validateRestore(over: keys) }
        let missingMacro = try F75Snapshot(identity: identity, lightingData: config, keyData: macroKeys, macroData: bank)
        rejects { try missingMacro.validate() }
        var malformedBank = bank; malformedBank[0] = 3
        let malformedBackup = try F75Snapshot(identity: identity, lightingData: config, keyData: keys, macroData: malformedBank)
        rejects { try malformedBackup.validate() }
        let evidence = URL(fileURLWithPath: CommandLine.arguments[1]).deletingLastPathComponent()
        let appliedMacro = try JSONDecoder().decode(F75Snapshot.self, from: Data(contentsOf: evidence.appendingPathComponent("macro-verification-applied.json")))
        try appliedMacro.validate()
        let records = try F75MacroCodec.decodeBank(appliedMacro.macroData!)
        let capturedMacro = try F75MacroCodec.decode(records[0])
        precondition(capturedMacro.name == "F75 verification")
        precondition(Array(appliedMacro.keyData[312..<316]) == [3,1,1,0])
        let beforeMacro = try JSONDecoder().decode(F75Snapshot.self, from: Data(contentsOf: evidence.appendingPathComponent("before-macro-verification.json")))
        let restoredMacro = try JSONDecoder().decode(F75Snapshot.self, from: Data(contentsOf: evidence.appendingPathComponent("macro-verification-restored.json")))
        precondition(beforeMacro.macroData == restoredMacro.macroData && beforeMacro.keyData == restoredMacro.keyData && beforeMacro.lightingData == restoredMacro.lightingData)
        precondition(F75Layout.keys.count == 80 && Set(F75Layout.keys.map(\.matrixIndex)).count == 80)
        print("PASS: synthetic protocol packet vectors; malformed response rejection; protected Fn; key and lighting byte preservation; preset color validation; backup round trip; 80-key layout.")
    }
}
