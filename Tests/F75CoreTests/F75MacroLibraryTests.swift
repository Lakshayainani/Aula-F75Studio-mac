import Foundation

func testMacroLibrary() throws {
    func rejects(_ body: () throws -> Void) {
        do { try body(); fatalError("Accepted invalid library operation") } catch { }
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("f75-library-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("macros.json")
    var library = try F75MacroLibrary.load(from: url)
    precondition(library.entries.isEmpty)
    let macro = F75Macro(name: "Original", events: [.init(usage: 4, isPressed: true), .init(usage: 4, isPressed: false)])
    let id = try library.save(macro)
    try library.write(to: url)
    var edited = macro; edited.name = "Renamed"; edited.events[0].delayMS = 100
    try library.save(edited, id: id)
    let duplicateID = try library.save(edited)
    precondition(id != duplicateID && library.entries.count == 2)
    try library.write(to: url)
    let reloaded = try F75MacroLibrary.load(from: url)
    precondition(reloaded.entries == library.entries && reloaded.entries[0].id == id)
    let previous = try F75MacroLibrary.load(from: url.deletingPathExtension().appendingPathExtension("previous.json"))
    precondition(previous.entries.count == 1 && previous.entries[0].macro == macro)
    try library.remove(id: duplicateID)
    try library.write(to: url)
    let removed = try F75MacroLibrary.load(from: url)
    precondition(removed.entries.count == 1 && removed.entries[0].id == id)
    rejects { try library.remove(id: duplicateID) }
    rejects { try library.save(macro, id: duplicateID) }
    rejects { _ = try library.save(F75Macro(name: "Invalid", events: [])) }
    try Data("{invalid".utf8).write(to: url)
    rejects { _ = try F75MacroLibrary.load(from: url) }
    let entry = F75MacroLibrary.Entry(id: id, macro: macro)
    let duplicateData = try JSONEncoder().encode(["entries": [entry, entry]])
    try duplicateData.write(to: url)
    rejects { _ = try F75MacroLibrary.load(from: url) }
    let record = try F75MacroCodec.encode(macro)
    var opaque = record; opaque[1 + Int(opaque[0])] = 0x20
    let bank = try F75MacroCodec.encodeBank([record, opaque])
    let updated = try F75MacroCodec.replacing(edited, at: 0, expectedRecord: record, in: bank)
    let records = try F75MacroCodec.decodeBank(updated)
    precondition(records.count == 2 && records[1] == opaque)
    let decoded = try F75MacroCodec.decode(records[0])
    precondition(decoded == edited)
    rejects { _ = try F75MacroCodec.replacing(macro, at: 0, expectedRecord: record, in: updated) }
    rejects { _ = try F75MacroCodec.replacing(macro, at: 2, expectedRecord: record, in: bank) }
    print("PASS: macro library persistence, rename/duplicate/removal, previous-file backup, invalid input rejection, stable keyboard record indexes and stale-edit protection.")
}
