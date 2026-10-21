import Foundation
import F75Core

func run() throws {
    let args = Array(CommandLine.arguments.dropFirst())
    try FileManager.default.createDirectory(atPath: "evidence", withIntermediateDirectories: true)
    guard let command = args.first, ["list","read","read-macros","verify-write","verify-roundtrip","verify-macro"].contains(command) else {
        print("Usage: f75ctl list | read [output.json] | read-macros output.json | verify-write | verify-roundtrip | verify-macro\nverify-write re-sends the current settings unchanged and checks the readback.")
        return
    }
    let devices = try F75HIDTransport.enumerateDevices(vendorID: 0x258A, productID: 0x010C, usagePage: 1, usage: 128)
    if command == "list" {
        for d in devices { print("\(d.product) — USB 258A:010C, interface \(d.usage), feature size \(d.maxFeatureReportSize)") }
        if devices.isEmpty { print("No supported wired F75 interface connected.") }
        return
    }
    guard devices.count == 1, let device = devices.first else { throw F75Error.invalid("Connect exactly one F75 by USB.") }
    let session = try F75Session(device: device); defer { session.close() }
    if command == "read-macros" {
        let bytes = try session.readMacroData()
        let data = try JSONEncoder().encode(bytes)
        guard args.count == 2 else { throw F75Error.invalid("Usage: f75ctl read-macros output.json") }
        try data.write(to: URL(fileURLWithPath: args[1]), options: .atomic)
        print("Read \(bytes.count) macro bytes without changing keyboard configuration.")
        return
    }
    let snapshot = try session.readSnapshot(includeMacros: command == "read" || command == "verify-macro")
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(snapshot)
    if command == "read" {
        if args.count > 1 { try data.write(to: URL(fileURLWithPath: args[1]), options: .atomic); print("Saved verified F75 snapshot to \(args[1])") }
        else { print(String(decoding: data, as: UTF8.self)) }
    } else if command == "verify-macro" {
        try data.write(to: URL(fileURLWithPath: "evidence/before-macro-verification.json"), options: .atomic)
        let macro = F75Macro(name: "F75 verification", events: [F75MacroEvent(usage: 0x73, isPressed: true), F75MacroEvent(usage: 0x73, isPressed: false)])
        do {
            let applied = try session.applyMacro(macro, matrixIndex: 78)
            let restored = try session.restore(snapshot)
            guard restored.keyData == snapshot.keyData, restored.lightingData == snapshot.lightingData, restored.macroData == snapshot.macroData else {
                throw F75Error.invalid("Macro verification restoration differs from the complete baseline.")
            }
            try encoder.encode(applied).write(to: URL(fileURLWithPath: "evidence/macro-verification-applied.json"), options: .atomic)
            try encoder.encode(restored).write(to: URL(fileURLWithPath: "evidence/macro-verification-restored.json"), options: .atomic)
            print("PASS: macro uploaded and assigned to F12; record and mapping readbacks verified; original full macro bank, lighting, and mappings restored byte-for-byte. Playback was not triggered.")
        } catch {
            do { _ = try session.restore(snapshot) }
            catch { fputs("MACRO RESTORE FAILED: \(error.localizedDescription)\n", stderr) }
            throw error
        }
    } else if command == "verify-roundtrip" {
        try data.write(to: URL(fileURLWithPath: "evidence/before-roundtrip-verification.json"), options: .atomic)
        do {
            var lighting = snapshot.lighting
            lighting.brightness = lighting.brightness == 9 ? 8 : lighting.brightness + 1
            _ = try session.applyLighting(lighting)
            _ = try session.remapKey(matrixIndex: 78, to: 72)
            let restored = try session.restore(snapshot)
            guard restored.keyData == snapshot.keyData, restored.lightingData == snapshot.lightingData else {
                throw F75Error.invalid("Restored snapshot differs from its baseline.")
            }
            print("PASS: changed brightness and F12 mapping; verified both; restored original lighting and all mappings byte-for-byte.")
        } catch {
            do { _ = try session.restore(snapshot) }
            catch { fputs("RESTORE FAILED: \(error.localizedDescription)\n", stderr) }
            throw error
        }
    } else {
        let backupURL = URL(fileURLWithPath: "evidence/before-write-verification.json")
        try data.write(to: backupURL, options: .atomic)
        session.close()
        let transport = try F75HIDTransport(device: device)
        for (cmd, payload) in [(UInt8(4), snapshot.lightingData), (UInt8(3), snapshot.keyData)] {
            try transport.setFeatureReport(reportID: 6, bytes: F75Protocol.frame(command: cmd, length: payload.count, payload: payload))
            Thread.sleep(forTimeInterval: 0.15)
        }
        transport.close()
        let check = try F75Session(device: device); defer { check.close() }
        let after = try check.readSnapshot()
        guard after.lightingData == snapshot.lightingData, after.keyData == snapshot.keyData else { throw F75Error.invalid("Unchanged-settings write did not match the readback. Baseline saved to \(backupURL.path)") }
        print("PASS: F75 model CD identified; 128-byte lighting and 512-byte key map writes read back unchanged. Fn entry preserved.")
    }
}
do { try run() } catch { fputs("F75: \(error.localizedDescription)\n", stderr); exit(1) }
