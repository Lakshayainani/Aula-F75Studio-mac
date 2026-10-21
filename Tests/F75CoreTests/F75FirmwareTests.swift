import Foundation

enum FirmwareSelfTest {
    static func rejects(_ text: String) {
        do { _ = try F75FirmwareImage.inspect(data: Data(text.utf8), filename: "test.hex"); fatalError("Accepted invalid HEX: \(text)") }
        catch { }
    }
    static func record(_ type: UInt8, _ address: UInt16 = 0, _ data: [UInt8] = []) -> String {
        let bytes = [UInt8(data.count), UInt8(address >> 8), UInt8(address & 255), type] + data
        return ":" + (bytes + [0 &- bytes.reduce(UInt8(0), &+)]).map { String(format: "%02X", $0) }.joined()
    }
    static func run() throws {
        let eof = record(1)
        let source = record(4, 0, [0,1]) + "\r\n" + record(0, 0x100, [1,2,3]) + "\n" + eof
        let image = try F75FirmwareImage.inspect(data: Data(source.utf8), filename: "sample.hex")
        precondition(image.firstAddress == 0x10100 && image.lastAddress == 0x10102)
        precondition(image.payloadByteCount == 3 && image.recordCount == 3 && image.segments.count == 1)
        precondition(image.segments[0].bytes == [1,2,3] && image.vendorID == nil)
        let moved = try F75FirmwareImage.inspect(data: Data((record(0, 0x101, [1,2,3]) + "\n" + eof).utf8), filename: "moved.hex")
        precondition(moved.payloadSHA256 != image.payloadSHA256)
        let boundary = try F75FirmwareImage.inspect(data: Data((record(4, 0, [255,255]) + "\n" + record(0, 65535, [42]) + "\n" + eof).utf8), filename: "last.hex")
        precondition(boundary.lastAddress == UInt32.max)
        rejects(":03000000010203F8\n" + eof)
        rejects(record(0, 0, [1]))
        rejects(eof)
        rejects(eof + "\n" + record(0, 0, [1]))
        rejects(record(0, 0, [1]) + "\n" + record(0, 0, [1]) + "\n" + eof)
        rejects(record(0, 65535, [1,2]) + "\n" + eof)
        rejects(record(4, 1, [0,1]) + "\n" + eof)
        rejects(record(6) + "\n" + eof)
        rejects(":GG00000000\n" + eof)
        rejects("MZtest")
        precondition(!F75FirmwarePolicy.flashingEnabled)
        do { try F75FirmwarePolicy.validateForFlashing(image); fatalError("Enabled unverified flashing") } catch { }
        if let updater = ProcessInfo.processInfo.environment["F75_TEST_UPDATER"] {
            let supplied = try F75FirmwareImage.inspect(url: URL(fileURLWithPath: updater))
            precondition(supplied.format == "Embedded SINO firmware" && supplied.payloadByteCount == 61440)
            precondition(supplied.vendorID == 0x258A && supplied.productID == 0x010C)
            precondition(supplied.payloadSHA256 == "6610d821357fa654fa69cd11b32a714e118a9a38e5667cf87958dedbb7d2b703")
            precondition(Array(supplied.segments[0].bytes.prefix(3)) == [2,0x9C,0x74])
            print("PASS: supplied SINO updater extraction and exact decrypted image hash.")
        }
        print("PASS: HEX checksums, addressing, boundaries, overlap/EOF rejection, firmware compatibility gate.")
    }
}

func testFirmwareCodec() throws { try FirmwareSelfTest.run() }
