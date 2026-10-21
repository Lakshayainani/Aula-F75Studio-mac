// Derived from the supplied F75 driver configuration (Dev/kb/1/KB.ini)
// SHA-256: bde7c62053f16ff57f01b486074a7106a72e293e359c57183e1c4aa534049fdd
// Geometry is the OEM rectangle in source pixels; key labels are the preceding comments.

public struct F75Key: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let matrixIndex: Int
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let windowsVirtualKey: Int
    public let defaultType: Int
    public let defaultCode: Int
}

public enum F75Layout {
    public static let allKeys: [F75Key] = [
        F75Key(id: "K1", label: "Esc", matrixIndex: 0, x: 30, y: 30, width: 25, height: 27, windowsVirtualKey: 27, defaultType: 2, defaultCode: 0),
        F75Key(id: "K2", label: "F1", matrixIndex: 12, x: 107, y: 30, width: 25, height: 27, windowsVirtualKey: 112, defaultType: 2, defaultCode: 0),
        F75Key(id: "K3", label: "F2", matrixIndex: 18, x: 144, y: 30, width: 25, height: 27, windowsVirtualKey: 113, defaultType: 2, defaultCode: 0),
        F75Key(id: "K4", label: "F3", matrixIndex: 24, x: 183, y: 30, width: 25, height: 27, windowsVirtualKey: 114, defaultType: 2, defaultCode: 0),
        F75Key(id: "K5", label: "F4", matrixIndex: 30, x: 222, y: 30, width: 25, height: 27, windowsVirtualKey: 115, defaultType: 2, defaultCode: 0),
        F75Key(id: "K6", label: "F5", matrixIndex: 36, x: 269, y: 30, width: 25, height: 27, windowsVirtualKey: 116, defaultType: 2, defaultCode: 0),
        F75Key(id: "K7", label: "F6", matrixIndex: 42, x: 305, y: 30, width: 25, height: 27, windowsVirtualKey: 117, defaultType: 2, defaultCode: 0),
        F75Key(id: "K8", label: "F7", matrixIndex: 48, x: 343, y: 30, width: 25, height: 27, windowsVirtualKey: 118, defaultType: 2, defaultCode: 0),
        F75Key(id: "K9", label: "F8", matrixIndex: 54, x: 388, y: 30, width: 25, height: 27, windowsVirtualKey: 119, defaultType: 2, defaultCode: 0),
        F75Key(id: "K10", label: "F9", matrixIndex: 60, x: 439, y: 30, width: 25, height: 27, windowsVirtualKey: 120, defaultType: 2, defaultCode: 0),
        F75Key(id: "K11", label: "F10", matrixIndex: 66, x: 477, y: 30, width: 25, height: 27, windowsVirtualKey: 121, defaultType: 2, defaultCode: 0),
        F75Key(id: "K12", label: "F11", matrixIndex: 72, x: 516, y: 30, width: 25, height: 27, windowsVirtualKey: 122, defaultType: 2, defaultCode: 0),
        F75Key(id: "K13", label: "F12", matrixIndex: 78, x: 555, y: 30, width: 25, height: 27, windowsVirtualKey: 123, defaultType: 2, defaultCode: 0),
        F75Key(id: "K14", label: "End", matrixIndex: 88, x: 605, y: 195, width: 25, height: 27, windowsVirtualKey: 35, defaultType: 2, defaultCode: 0),
        F75Key(id: "K15", label: "`", matrixIndex: 1, x: 31, y: 81, width: 25, height: 27, windowsVirtualKey: 192, defaultType: 2, defaultCode: 0),
        F75Key(id: "K16", label: "1", matrixIndex: 7, x: 70, y: 81, width: 25, height: 27, windowsVirtualKey: 49, defaultType: 2, defaultCode: 0),
        F75Key(id: "K17", label: "2", matrixIndex: 13, x: 108, y: 81, width: 25, height: 27, windowsVirtualKey: 50, defaultType: 2, defaultCode: 0),
        F75Key(id: "K18", label: "3", matrixIndex: 19, x: 147, y: 81, width: 25, height: 27, windowsVirtualKey: 51, defaultType: 2, defaultCode: 0),
        F75Key(id: "K19", label: "4", matrixIndex: 25, x: 184, y: 81, width: 25, height: 27, windowsVirtualKey: 52, defaultType: 2, defaultCode: 0),
        F75Key(id: "K20", label: "5", matrixIndex: 31, x: 223, y: 81, width: 25, height: 27, windowsVirtualKey: 53, defaultType: 2, defaultCode: 0),
        F75Key(id: "K21", label: "6", matrixIndex: 37, x: 262, y: 81, width: 25, height: 27, windowsVirtualKey: 54, defaultType: 2, defaultCode: 0),
        F75Key(id: "K22", label: "7", matrixIndex: 43, x: 300, y: 80, width: 25, height: 27, windowsVirtualKey: 55, defaultType: 2, defaultCode: 0),
        F75Key(id: "K23", label: "8", matrixIndex: 49, x: 338, y: 81, width: 25, height: 27, windowsVirtualKey: 56, defaultType: 2, defaultCode: 0),
        F75Key(id: "K24", label: "9", matrixIndex: 55, x: 377, y: 81, width: 25, height: 27, windowsVirtualKey: 57, defaultType: 2, defaultCode: 0),
        F75Key(id: "K25", label: "0", matrixIndex: 61, x: 416, y: 81, width: 25, height: 27, windowsVirtualKey: 48, defaultType: 2, defaultCode: 0),
        F75Key(id: "K26", label: "-", matrixIndex: 67, x: 453, y: 81, width: 25, height: 27, windowsVirtualKey: 189, defaultType: 2, defaultCode: 0),
        F75Key(id: "K27", label: "=", matrixIndex: 73, x: 491, y: 81, width: 25, height: 27, windowsVirtualKey: 187, defaultType: 2, defaultCode: 0),
        F75Key(id: "K28", label: "Backspace", matrixIndex: 79, x: 531, y: 81, width: 60, height: 27, windowsVirtualKey: 8, defaultType: 2, defaultCode: 0),
        F75Key(id: "K29", label: "Delete", matrixIndex: 85, x: 604, y: 81, width: 25, height: 27, windowsVirtualKey: 46, defaultType: 2, defaultCode: 0),
        F75Key(id: "K30", label: "Tab", matrixIndex: 2, x: 34, y: 120, width: 44, height: 27, windowsVirtualKey: 9, defaultType: 2, defaultCode: 0),
        F75Key(id: "K31", label: "Q", matrixIndex: 8, x: 89, y: 119, width: 25, height: 27, windowsVirtualKey: 81, defaultType: 2, defaultCode: 0),
        F75Key(id: "K32", label: "W", matrixIndex: 14, x: 127, y: 119, width: 25, height: 27, windowsVirtualKey: 87, defaultType: 2, defaultCode: 0),
        F75Key(id: "K33", label: "E", matrixIndex: 20, x: 165, y: 119, width: 25, height: 27, windowsVirtualKey: 69, defaultType: 2, defaultCode: 0),
        F75Key(id: "K34", label: "R", matrixIndex: 26, x: 204, y: 119, width: 25, height: 27, windowsVirtualKey: 82, defaultType: 2, defaultCode: 0),
        F75Key(id: "K35", label: "T", matrixIndex: 32, x: 242, y: 119, width: 25, height: 27, windowsVirtualKey: 84, defaultType: 2, defaultCode: 0),
        F75Key(id: "K36", label: "Y", matrixIndex: 38, x: 280, y: 119, width: 25, height: 27, windowsVirtualKey: 89, defaultType: 2, defaultCode: 0),
        F75Key(id: "K37", label: "U", matrixIndex: 44, x: 318, y: 119, width: 25, height: 27, windowsVirtualKey: 85, defaultType: 2, defaultCode: 0),
        F75Key(id: "K38", label: "I", matrixIndex: 50, x: 356, y: 119, width: 25, height: 27, windowsVirtualKey: 73, defaultType: 2, defaultCode: 0),
        F75Key(id: "K39", label: "O", matrixIndex: 56, x: 395, y: 119, width: 25, height: 27, windowsVirtualKey: 79, defaultType: 2, defaultCode: 0),
        F75Key(id: "K40", label: "P", matrixIndex: 62, x: 433, y: 119, width: 25, height: 27, windowsVirtualKey: 80, defaultType: 2, defaultCode: 0),
        F75Key(id: "K41", label: "[", matrixIndex: 68, x: 471, y: 120, width: 25, height: 27, windowsVirtualKey: 219, defaultType: 2, defaultCode: 0),
        F75Key(id: "K42", label: "]", matrixIndex: 74, x: 509, y: 119, width: 25, height: 27, windowsVirtualKey: 221, defaultType: 2, defaultCode: 0),
        F75Key(id: "K43", label: "\\", matrixIndex: 80, x: 549, y: 119, width: 44, height: 27, windowsVirtualKey: 220, defaultType: 2, defaultCode: 0),
        F75Key(id: "K44", label: "PgUp", matrixIndex: 86, x: 605, y: 120, width: 25, height: 27, windowsVirtualKey: 33, defaultType: 2, defaultCode: 0),
        F75Key(id: "K45", label: "CapsLock", matrixIndex: 3, x: 33, y: 158, width: 52, height: 27, windowsVirtualKey: 20, defaultType: 2, defaultCode: 0),
        F75Key(id: "K46", label: "A", matrixIndex: 9, x: 98, y: 158, width: 25, height: 27, windowsVirtualKey: 65, defaultType: 2, defaultCode: 0),
        F75Key(id: "K47", label: "S", matrixIndex: 15, x: 136, y: 158, width: 25, height: 27, windowsVirtualKey: 83, defaultType: 2, defaultCode: 0),
        F75Key(id: "K48", label: "D", matrixIndex: 21, x: 174, y: 158, width: 25, height: 27, windowsVirtualKey: 68, defaultType: 2, defaultCode: 0),
        F75Key(id: "K49", label: "F", matrixIndex: 27, x: 213, y: 158, width: 25, height: 27, windowsVirtualKey: 70, defaultType: 2, defaultCode: 0),
        F75Key(id: "K50", label: "G", matrixIndex: 33, x: 252, y: 158, width: 25, height: 27, windowsVirtualKey: 71, defaultType: 2, defaultCode: 0),
        F75Key(id: "K51", label: "H", matrixIndex: 39, x: 290, y: 158, width: 25, height: 27, windowsVirtualKey: 72, defaultType: 2, defaultCode: 0),
        F75Key(id: "K52", label: "J", matrixIndex: 45, x: 327, y: 158, width: 25, height: 27, windowsVirtualKey: 74, defaultType: 2, defaultCode: 0),
        F75Key(id: "K53", label: "K", matrixIndex: 51, x: 366, y: 158, width: 25, height: 27, windowsVirtualKey: 75, defaultType: 2, defaultCode: 0),
        F75Key(id: "K54", label: "L", matrixIndex: 57, x: 405, y: 158, width: 25, height: 27, windowsVirtualKey: 76, defaultType: 2, defaultCode: 0),
        F75Key(id: "K55", label: ";", matrixIndex: 63, x: 443, y: 158, width: 25, height: 27, windowsVirtualKey: 186, defaultType: 2, defaultCode: 0),
        F75Key(id: "K56", label: "'", matrixIndex: 69, x: 481, y: 158, width: 25, height: 27, windowsVirtualKey: 222, defaultType: 2, defaultCode: 0),
        F75Key(id: "K57", label: "Enter", matrixIndex: 81, x: 521, y: 158, width: 70, height: 27, windowsVirtualKey: 13, defaultType: 2, defaultCode: 0),
        F75Key(id: "K58", label: "LShift", matrixIndex: 4, x: 33, y: 195, width: 72, height: 27, windowsVirtualKey: 160, defaultType: 2, defaultCode: 0),
        F75Key(id: "K59", label: "Z", matrixIndex: 10, x: 116, y: 195, width: 25, height: 27, windowsVirtualKey: 90, defaultType: 2, defaultCode: 0),
        F75Key(id: "K60", label: "X", matrixIndex: 16, x: 155, y: 195, width: 25, height: 27, windowsVirtualKey: 88, defaultType: 2, defaultCode: 0),
        F75Key(id: "K61", label: "C", matrixIndex: 22, x: 193, y: 195, width: 25, height: 27, windowsVirtualKey: 67, defaultType: 2, defaultCode: 0),
        F75Key(id: "K62", label: "V", matrixIndex: 28, x: 232, y: 195, width: 25, height: 27, windowsVirtualKey: 86, defaultType: 2, defaultCode: 0),
        F75Key(id: "K63", label: "B", matrixIndex: 34, x: 270, y: 196, width: 25, height: 27, windowsVirtualKey: 66, defaultType: 2, defaultCode: 0),
        F75Key(id: "K64", label: "N", matrixIndex: 40, x: 309, y: 195, width: 25, height: 27, windowsVirtualKey: 78, defaultType: 2, defaultCode: 0),
        F75Key(id: "K65", label: "M", matrixIndex: 46, x: 347, y: 195, width: 25, height: 27, windowsVirtualKey: 77, defaultType: 2, defaultCode: 0),
        F75Key(id: "K66", label: ",", matrixIndex: 52, x: 384, y: 195, width: 25, height: 27, windowsVirtualKey: 188, defaultType: 2, defaultCode: 0),
        F75Key(id: "K67", label: ".", matrixIndex: 58, x: 424, y: 195, width: 25, height: 27, windowsVirtualKey: 190, defaultType: 2, defaultCode: 0),
        F75Key(id: "K68", label: "/", matrixIndex: 64, x: 463, y: 195, width: 25, height: 27, windowsVirtualKey: 191, defaultType: 2, defaultCode: 0),
        F75Key(id: "K69", label: "RShift", matrixIndex: 70, x: 502, y: 195, width: 56, height: 27, windowsVirtualKey: 161, defaultType: 2, defaultCode: 0),
        F75Key(id: "K70", label: "Up", matrixIndex: 82, x: 567, y: 195, width: 25, height: 27, windowsVirtualKey: 38, defaultType: 2, defaultCode: 0),
        F75Key(id: "K71", label: "LCtrl", matrixIndex: 5, x: 34, y: 234, width: 35, height: 27, windowsVirtualKey: 162, defaultType: 2, defaultCode: 0),
        F75Key(id: "K72", label: "LWin", matrixIndex: 11, x: 79, y: 234, width: 35, height: 27, windowsVirtualKey: 91, defaultType: 2, defaultCode: 0),
        F75Key(id: "K73", label: "LAlt", matrixIndex: 17, x: 122, y: 235, width: 35, height: 27, windowsVirtualKey: 164, defaultType: 2, defaultCode: 0),
        F75Key(id: "K74", label: "Space", matrixIndex: 35, x: 174, y: 235, width: 226, height: 27, windowsVirtualKey: 32, defaultType: 2, defaultCode: 0),
        F75Key(id: "K75", label: "RCtrl", matrixIndex: 59, x: 463, y: 236, width: 34, height: 27, windowsVirtualKey: 163, defaultType: 2, defaultCode: 0),
        F75Key(id: "K76", label: "FN", matrixIndex: 53, x: 414, y: 235, width: 35, height: 27, windowsVirtualKey: 250, defaultType: 2, defaultCode: 0),
        F75Key(id: "K77", label: "Left", matrixIndex: 77, x: 529, y: 234, width: 25, height: 27, windowsVirtualKey: 37, defaultType: 2, defaultCode: 0),
        F75Key(id: "K78", label: "Down", matrixIndex: 83, x: 568, y: 234, width: 25, height: 27, windowsVirtualKey: 40, defaultType: 2, defaultCode: 0),
        F75Key(id: "K79", label: "Right", matrixIndex: 89, x: 605, y: 234, width: 25, height: 27, windowsVirtualKey: 39, defaultType: 2, defaultCode: 0),
        F75Key(id: "K80", label: "PgDn", matrixIndex: 87, x: 604, y: 159, width: 25, height: 27, windowsVirtualKey: 34, defaultType: 2, defaultCode: 0),
        F75Key(id: "K81", label: "Wheel", matrixIndex: 84, x: 0, y: 0, width: 0, height: 0, windowsVirtualKey: 1, defaultType: 9, defaultCode: 117440541),
    ]

    // Wheel has no rectangle in the vendor layout.
    public static let keys = allKeys.filter { $0.width > 0 && $0.height > 0 }
}
