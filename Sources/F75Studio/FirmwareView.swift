import SwiftUI
import AppKit
import UniformTypeIdentifiers
import F75Core

private typealias FirmwareState<Value> = SwiftUI.State<Value>

struct FirmwareView: View {
    @FirmwareState private var image: F75FirmwareImage?
    @FirmwareState private var error: String?
    @FirmwareState private var inspecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Firmware image", systemImage: "cpu").font(.headline)
            Text("Choose an Intel HEX image or the supplied F75 firmware.exe updater. Its embedded image is inspected without running Windows code.")
                .foregroundStyle(.secondary)
            Button(inspecting ? "Inspecting…" : "Choose firmware image…", action: chooseImage).disabled(inspecting)
            if let image {
                Text(image.filename).font(.title3)
                Text(image.format).foregroundStyle(.secondary)
                if let vendor = image.vendorID, let product = image.productID {
                    Text(String(format: "Embedded target: USB %04X:%04X · hardware revision unknown", vendor, product)).font(.caption)
                }
                Text("\(image.payloadByteCount) bytes · \(image.recordCount) records · \(image.segments.count) address regions")
                Text(String(format: "Address range: 0x%08X–0x%08X", image.firstAddress, image.lastAddress))
                    .font(.system(.caption, design: .monospaced))
                Text("SHA-256: \(image.sha256)").font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                Text("Payload SHA-256: \(image.payloadSHA256)").font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                Label(image.format == "Embedded SINO firmware" ? "Known updater and decrypted payload hashes verified" : "HEX checksums and addresses validated", systemImage: "checkmark.circle").foregroundStyle(.green)
                Text("File integrity does not establish compatibility with your keyboard.").font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.orange).textSelection(.enabled) }
            Divider()
            Label("Flashing is not yet available", systemImage: "lock.shield").font(.headline)
            Text("The updater uses a different bootloader interface. Hardware revision checks, verification, and recovery must be established before enabling firmware writes.")
                .foregroundStyle(.secondary)
            Text("You can inspect an image here without changing the keyboard.").font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.title = "Choose F75 firmware or the supplied updater"
        panel.allowedContentTypes = [UTType(filenameExtension: "hex") ?? .data, UTType(filenameExtension: "exe") ?? .data]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        inspecting = true; image = nil; error = nil
        Task {
            let result = await Task.detached { Result { try F75FirmwareImage.inspect(url: url) } }.value
            inspecting = false
            switch result {
            case .success(let value): image = value
            case .failure(let failure): error = failure.localizedDescription
            }
        }
    }
}
