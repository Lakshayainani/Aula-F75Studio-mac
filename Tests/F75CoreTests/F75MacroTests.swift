import Foundation

func testMacroCodec() throws {
    func rejects(_ body: () throws -> Void) {
        do { try body(); fatalError("Expected invalid macro to be rejected") } catch { }
    }
    let sequence = F75Macro(name: "A", events: [
        F75MacroEvent(usage: 0xE3, isPressed: true, delayMS: 0),
        F75MacroEvent(usage: 4, isPressed: true, delayMS: 0x12345),
        F75MacroEvent(usage: 4, isPressed: false, delayMS: 20),
        F75MacroEvent(usage: 0xE3, isPressed: false, delayMS: 0xFFFFF)
    ])
    let encoded = try F75MacroCodec.encode(sequence)
    precondition(encoded == [2,65,0, 0x10,0,0,0xE3, 1,0x23,0x45,4, 0x80,0,20,4, 0x9F,0xFF,0xFF,0xE3])
    let decoded = try F75MacroCodec.decode(encoded)
    precondition(decoded == sequence)
    rejects { _ = try F75MacroCodec.decode(Array(encoded.dropLast())) }
    rejects { _ = try F75MacroCodec.encode(F75Macro(name: String(repeating: "x", count: 31), events: sequence.events)) }
    rejects { _ = try F75MacroCodec.encode(F75Macro(name: "x", events: [sequence.events[1]])) }
    rejects { _ = try F75MacroCodec.encode(F75Macro(name: "x", events: [sequence.events[2]])) }
    var excessive = sequence; excessive.events[0].delayMS = 0x100000
    rejects { _ = try F75MacroCodec.encode(excessive) }
    var mouse = encoded; mouse[3] = 0x20
    rejects { _ = try F75MacroCodec.decode(mouse) }
    var invalidName = encoded; invalidName[1] = 0; invalidName[2] = 0xD8
    rejects { _ = try F75MacroCodec.decode(invalidName) }
    let empty = try F75MacroCodec.decodeBank([UInt8](repeating: 255, count: 4096))
    precondition(empty.isEmpty)
    let bank = try F75MacroCodec.encodeBank([encoded, mouse])
    precondition(Array(bank.prefix(8)) == [8,0,19,0,27,0,19,0])
    let records = try F75MacroCodec.decodeBank(bank + [1,2,3])
    precondition(records == [encoded, mouse])
    var overlapping = bank; overlapping[4] = 8
    rejects { _ = try F75MacroCodec.decodeBank(overlapping) }
    rejects { _ = try F75MacroCodec.decodeBank([4,0,255,255]) }
    rejects { _ = try F75MacroCodec.decodeBank([3,0,0,0]) }
    rejects { _ = try F75MacroCodec.encodeBank(Array(repeating: encoded, count: 101)) }
    let fullRecord = [UInt8]([0] + Array(repeating: 0, count: 4092))
    rejects { _ = try F75MacroCodec.encodeBank([fullRecord]) }
    let appended = try F75MacroCodec.appending(sequence, to: [UInt8](repeating: 0, count: 4096))
    precondition(appended.index == 0 && appended.data.count == 23)
    let duplicate = try F75MacroCodec.appending(sequence, to: appended.data)
    precondition(duplicate.index == 0 && duplicate.data == appended.data)
    var keys = [UInt8](repeating: 0, count: 512)
    keys[212] = 13; keys[510] = 0x5A; keys[511] = 0xA5
    let mapping = try F75MacroCodec.assigningMacro(keys, matrixIndex: 9, macroIndex: 1, repeatCount: 3)
    precondition(Array(mapping[36..<40]) == [3,1,3,1])
    for i in keys.indices where !(36..<40).contains(i) { precondition(keys[i] == mapping[i]) }
    rejects { _ = try F75MacroCodec.assigningMacro(keys, matrixIndex: 53, macroIndex: 0) }
    rejects { _ = try F75MacroCodec.assigningMacro(keys, matrixIndex: 9, macroIndex: 100) }
    rejects { _ = try F75MacroCodec.assigningMacro(keys, matrixIndex: 9, macroIndex: 0, repeatCount: 0) }
    try F75MacroCodec.validateReferences(mapping, bank: bank)
    rejects { _ = try F75MacroCodec.validateReferences(mapping, bank: appended.data) }
    var badMode = mapping; badMode[37] = 255
    rejects { _ = try F75MacroCodec.validateReferences(badMode, bank: bank) }
}
