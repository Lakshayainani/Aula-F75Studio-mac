import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers
import F75Core

// The SDK also exports a State macro; naming its storage type avoids macro-plugin dependence.
private typealias ViewState<Value> = SwiftUI.State<Value>

private final class StudioAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct F75StudioApp: App {
    @NSApplicationDelegateAdaptor(StudioAppDelegate.self) private var delegate
    @StateObject private var model = StudioModel()
    init() { NSApplication.shared.setActivationPolicy(.regular) }

    var body: some Scene {
        WindowGroup("F75 Studio", id: "studio") {
            StudioView().environmentObject(model)
                .frame(minWidth: 940, minHeight: 680)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1050, height: 740)
        MenuBarExtra("F75 Studio", systemImage: "keyboard", isInserted: Binding(get: { model.showMenuBar }, set: { if model.showMenuBar != $0 { model.showMenuBar = $0 } })) {
            StudioMenu(model: model)
        }
    }
}

private struct StudioMenu: View {
    @ObservedObject var model: StudioModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(model.connected ? "F75 connected" : "F75 offline")
        Button("Open F75 Studio") { show(.lighting) }
        Button("Macro library") { show(.macros) }
        Button("Settings") { show(.settings) }
        Divider()
        if model.connected {
            Button("Refresh keyboard settings") { model.refresh() }.disabled(model.busy)
            Button("Disconnect keyboard") { model.disconnect() }.disabled(model.busy)
        } else {
            Button("Connect keyboard") { model.connect() }.disabled(model.busy || model.devices.isEmpty)
            Button("Find keyboard") { model.discover() }.disabled(model.busy)
        }
        Divider()
        Button("Quit F75 Studio") { NSApplication.shared.terminate(nil) }.disabled(model.busy)
    }
    private func show(_ page: StudioPage) {
        model.page = page
        if let window = NSApplication.shared.windows.first(where: { $0.title == "F75 Studio" }) {
            window.makeKeyAndOrderFront(nil)
        } else { openWindow(id: "studio") }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@MainActor
final class StudioModel: ObservableObject {
    @Published var devices: [F75HIDDevice] = []
    @Published var selectedDevice: UInt64 = 0
    @Published var session: F75Session?
    @Published var snapshot: F75Snapshot?
    @Published var imported: F75Snapshot?
    @Published var lighting = F75Lighting(red: 255, green: 0, blue: 0)
    @Published var busy = false
    @Published var status = "Connect your F75 by USB to get started."
    @Published var error: String?

    @Published var page = StudioPage.lighting
    @Published var showMenuBar = UserDefaults.standard.object(forKey: "showMenuBar") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showMenuBar, forKey: "showMenuBar") }
    }
    @Published var loginStatus = SMAppService.mainApp.status
    @Published var library = F75MacroLibrary()
    @Published var libraryWritable = true
    @Published var macroDraft = F75Macro(name: "My macro", events: [])
    @Published var selectedMacroID: UUID?
    @Published var editingKeyboardIndex: Int?
    @Published var editingKeyboardRecord: [UInt8]?
    @Published var keyboardRecords: [[UInt8]] = []
    @Published var keyboardMacroKeys: [UInt8] = []
    private let libraryURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("F75Studio/macros.json")

    init() {
        do { library = try F75MacroLibrary.load(from: libraryURL) }
        catch { libraryWritable = false; self.error = "Could not load the macro library. Its file was preserved. " + error.localizedDescription }
    }
    var macroDraftDirty: Bool {
        if let entry = library.entries.first(where: { $0.id == selectedMacroID }) { return entry.macro != macroDraft }
        if let record = editingKeyboardRecord { return (try? F75MacroCodec.encode(macroDraft)) != record }
        return macroDraft != F75Macro(name: "My macro", events: [])
    }
    var loginRequested: Bool { loginStatus == .enabled || loginStatus == .requiresApproval }
    func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        if loginStatus != status { loginStatus = status }
    }
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            let service = SMAppService.mainApp
            if enabled, service.status != .enabled, service.status != .requiresApproval { try service.register() }
            if !enabled, service.status == .enabled || service.status == .requiresApproval { try service.unregister() }
        } catch { self.error = "Could not change launch at login: " + error.localizedDescription }
        refreshLoginStatus()
    }
    func newMacro() {
        selectedMacroID = nil; editingKeyboardIndex = nil; editingKeyboardRecord = nil
        macroDraft = F75Macro(name: "My macro", events: [])
    }
    func loadMacro(_ entry: F75MacroLibrary.Entry) {
        selectedMacroID = entry.id; editingKeyboardIndex = nil; editingKeyboardRecord = nil
        macroDraft = entry.macro
    }
    func loadKeyboardMacro(at index: Int) {
        guard keyboardRecords.indices.contains(index) else { return }
        do {
            macroDraft = try F75MacroCodec.decode(keyboardRecords[index])
            selectedMacroID = nil; editingKeyboardIndex = index; editingKeyboardRecord = keyboardRecords[index]
        } catch { self.error = error.localizedDescription }
    }
    func saveMacro(_ macro: F75Macro, asCopy: Bool = false) {
        guard libraryWritable else { return }
        do {
            var next = library
            let id = try next.save(macro, id: asCopy ? nil : selectedMacroID)
            try next.write(to: libraryURL)
            library = next; selectedMacroID = id; macroDraft = macro
            status = "Macro saved in your library. Keyboard changes apply separately."
        } catch { self.error = error.localizedDescription }
    }
    func duplicateMacro(_ entry: F75MacroLibrary.Entry) {
        var copy = entry.macro
        while copy.name.utf16.count > 25 { copy.name.removeLast() }
        copy.name += " copy"
        editingKeyboardIndex = nil; editingKeyboardRecord = nil
        saveMacro(copy, asCopy: true)
    }
    func removeMacro(_ entry: F75MacroLibrary.Entry) {
        guard libraryWritable else { return }
        do {
            var next = library; try next.remove(id: entry.id); try next.write(to: libraryURL)
            library = next
            if selectedMacroID == entry.id { newMacro() }
            status = "Removed from the library. On-keyboard macros were left unchanged."
        } catch { self.error = error.localizedDescription }
    }
    func readMacros() {
        guard let session else { return }
        perform({ try session.readSnapshot(includeMacros: true) }) { snapshot in
            self.accept(snapshot)
            self.status = "On-keyboard macro records refreshed."
        }
    }
    func updateKeyboardMacro(_ macro: F75Macro) {
        guard let session, let index = editingKeyboardIndex, let record = editingKeyboardRecord else { return }
        perform({ try session.updateMacro(macro, at: index, expectedRecord: record) }) { snapshot in
            self.accept(snapshot)
            self.editingKeyboardRecord = try? F75MacroCodec.encode(macro)
            self.status = "Keyboard macro updated and verified. Existing assignments were preserved."
        }
    }

    var connected: Bool { session != nil && snapshot != nil }
    var canRestore: Bool {
        guard let snapshot, let imported else { return false }
        return snapshot.identity == imported.identity && F75Protocol.supportsIdentity(imported.identity)
    }

    func discover() {
        perform({
            try F75HIDTransport.enumerateDevices(vendorID: 0x258A, productID: 0x010C,
                                                usagePage: 1, usage: 128)
        }) { devices in
            self.devices = devices
            if !devices.contains(where: { $0.registryID == self.selectedDevice }) {
                self.selectedDevice = devices.first?.registryID ?? 0
            }
            self.status = devices.isEmpty
                ? "No supported F75 interface found. Use USB wired mode, then refresh."
                : "F75 interface found. Connect to read its settings."
        }
    }

    func connect() {
        guard let device = devices.first(where: { $0.registryID == selectedDevice }) else { return }
        perform({
            let session = try F75Session(device: device)
            do { return (session, try session.readSnapshot(includeMacros: true)) }
            catch { session.close(); throw error }
        }) { session, snapshot in
            self.session = session
            self.accept(snapshot)
            self.status = "Connected · settings read from your keyboard."
        }
    }

    func refresh() {
        guard let session else { discover(); return }
        perform({ try session.readSnapshot() }) { snapshot in
            self.accept(snapshot)
            self.status = "Settings refreshed from your keyboard."
        }
    }

    func disconnect() {
        guard let session else { return }
        perform({ session.close() }) { _ in
            self.session = nil
            self.snapshot = nil
            self.keyboardRecords = []; self.keyboardMacroKeys = []
            self.editingKeyboardIndex = nil; self.editingKeyboardRecord = nil
            self.status = "Disconnected."
        }
    }

    func applyLighting() {
        var settings = lighting
        if settings.rainbow { settings.red = 255; settings.green = 0; settings.blue = 0 }
        let confirmedSettings = settings
        write("Lighting saved and read back from your keyboard.") { try $0.applyLighting(confirmedSettings) }
    }

    func remap(source: Int, target: Int) {
        write("Key mapping saved and read back from your keyboard.") {
            try $0.remapKey(matrixIndex: source, to: target)
        }
    }

    func applyMacro(_ macro: F75Macro, matrixIndex: Int) {
        write("Macro saved, assigned, and read back from your keyboard.") {
            try $0.applyMacro(macro, matrixIndex: matrixIndex)
        }
    }

    func restore() {
        guard canRestore, let imported else { return }
        write("Backup restored and read back from your keyboard.") { try $0.restore(imported) }
    }

    private func write(_ message: String, action: @escaping @Sendable (F75Session) throws -> F75Snapshot) {
        guard let session, snapshot != nil else { return }
        perform({ try action(session) }) { snapshot in
            self.accept(snapshot)
            self.status = message
        }
    }

    func exportBackup() {
        guard let session else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "F75-backup.json"
        panel.title = "Export keyboard backup"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        perform({ try Self.encode(session.readSnapshot(includeMacros: true)).write(to: url, options: .atomic) }) { _ in
            self.status = "Backup exported to \(url.lastPathComponent)."
        }
    }

    func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Choose a keyboard backup"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        perform({
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0, size <= 1_048_576 else {
                throw CocoaError(.fileReadTooLarge)
            }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            let data = try file.read(upToCount: 1_048_577) ?? Data()
            guard data.count <= 1_048_576 else { throw CocoaError(.fileReadTooLarge) }
            let snapshot = try JSONDecoder().decode(F75Snapshot.self, from: data)
            try snapshot.validate()
            return snapshot
        }) { imported in
            self.imported = imported
            self.status = "Backup loaded for review. Choose Restore to apply it."
        }
    }

    func revealBackups() {
        do { NSWorkspace.shared.open(try Self.backupDirectory()) }
        catch { self.error = error.localizedDescription }
    }

    func openPermissions() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func accept(_ snapshot: F75Snapshot) {
        self.snapshot = snapshot
        lighting = snapshot.lighting
        if let bank = snapshot.macroData {
            do {
                keyboardRecords = try F75MacroCodec.decodeBank(bank)
                keyboardMacroKeys = snapshot.keyData
            } catch { self.error = error.localizedDescription }
        }
    }

    private func perform<T: Sendable>(_ action: @escaping @Sendable () throws -> T,
                                      completion: @escaping (T) -> Void) {
        guard !busy else { return }
        busy = true
        Task {
            let result = await Task.detached(priority: .userInitiated) { Result { try action() } }.value
            busy = false
            switch result {
            case .success(let value): completion(value)
            case .failure(let failure):
                error = failure.localizedDescription
                status = "Operation failed. Review the error before trying again."
            }
        }
    }

    private nonisolated static func backupDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("F75Studio/Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private nonisolated static func encode(_ snapshot: F75Snapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }
}

enum StudioPage: String, CaseIterable {
    case lighting = "Lighting", mapping = "Key mapping", backups = "Backups", macros = "Macros", firmware = "Firmware", settings = "Settings"
    var symbol: String {
        switch self { case .lighting: "lightbulb"; case .mapping: "keyboard"; case .backups: "externaldrive"; case .firmware: "cpu"; case .macros: "list.bullet.rectangle"; case .settings: "gearshape" }
    }
    var subtitle: String {
        switch self {
        case .lighting: "Make your keyboard feel like yours."
        case .mapping: "Choose a key and give it a new role."
        case .backups: "Keep a copy of your keyboard settings."
        case .firmware: "Inspect firmware before updating your keyboard."
        case .macros: "Manage saved macros and edit your keyboard sequences."
        case .settings: "Keep F75 Studio close at hand."
        }
    }
}

private struct StudioView: View {
    @EnvironmentObject private var model: StudioModel
    private var page: StudioPage { model.page }
    @ViewState private var source = 0
    @ViewState private var target = 12
    @ViewState private var confirmingRestore = false
    private let accent = Color(red: 0.66, green: 0.52, blue: 1)
    private let background = Color(red: 0.055, green: 0.065, blue: 0.105)

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 20) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if page == .lighting || page == .mapping { keyboard }
                        switch page {
                        case .lighting: lightingControls
                        case .mapping: mappingControls
                        case .backups: backupControls
                        case .firmware: FirmwareView()
                        case .macros: MacroLibraryView(model: model)
                        case .settings: StudioSettings(model: model)
                        }
                    }
                    .padding(2)
                }
                Spacer(minLength: 0)
                footer
            }
            .padding(28)
        }
        .background(background)
        .tint(accent)
        .task { if model.devices.isEmpty { model.discover() } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refreshLoginStatus() }
        .alert("Couldn't complete the operation", isPresented: Binding(
            get: { model.error != nil }, set: { if !$0 { model.error = nil } }
        )) {
            Button("Open Input Monitoring") { model.openPermissions() }
            Button("OK", role: .cancel) { model.error = nil }
        } message: {
            Text((model.error ?? "") + "\n\nIf macOS denied HID access, enable F75 Studio in System Settings → Privacy & Security → Input Monitoring, then quit and reopen the app.")
        }
        .confirmationDialog("Restore the imported backup to this keyboard?", isPresented: $confirmingRestore,
                            titleVisibility: .visible) {
            Button("Restore keyboard settings", role: .destructive) { model.restore() }
        } message: { Text("This replaces its lighting, key mappings, and any macro data included in the backup. A local backup is saved before applying changes.") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 30) {
            VStack(alignment: .leading, spacing: 6) {
                Text("F75").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("STUDIO").font(.system(size: 10, weight: .bold)).tracking(4).foregroundStyle(accent)
            }
            VStack(spacing: 6) {
                ForEach(StudioPage.allCases, id: \.self) { item in
                    Button { model.page = item } label: {
                        Label(item.rawValue, systemImage: item.symbol)
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(page == item ? accent.opacity(0.17) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(page == item ? accent : .secondary)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Label("USB wired mode", systemImage: "cable.connector")
                Text("AULA F75\nIndependent macOS companion")
                    .font(.caption).foregroundStyle(.secondary).lineSpacing(4)
            }.font(.caption)
        }
        .padding(24)
        .frame(width: 188)
        .frame(maxHeight: .infinity)
        .background(Color.white.opacity(0.025))
        .overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(page.rawValue).font(.system(size: 27, weight: .semibold))
                    Text(page.subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Label(model.connected ? "Connected" : "Offline", systemImage: "circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(model.connected ? Color.green : Color.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.white.opacity(0.04), in: Capsule())
            }
            HStack(spacing: 10) {
                Picker("Device", selection: $model.selectedDevice) {
                    if model.devices.isEmpty { Text("No F75 connected").tag(UInt64(0)) }
                    ForEach(model.devices) { device in
                        Text("\(device.product.isEmpty ? "AULA F75" : device.product) · \(device.transport)")
                            .tag(device.registryID)
                    }
                }
                .labelsHidden().frame(maxWidth: 350)
                .disabled(model.busy || model.connected)
                if model.connected {
                    Button("Disconnect") { model.disconnect() }.disabled(model.busy)
                } else {
                    Button("Connect") { model.connect() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.busy || model.devices.isEmpty)
                }
                Button { model.refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.busy)
                Spacer(minLength: 0)
            }
        }
    }

    private var keyboard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(page == .mapping ? "SELECT A KEY" : "AULA F75").font(.system(size: 10, weight: .bold)).tracking(2)
                Spacer()
                Text(page == .mapping ? "Click to select" : "Layout preview · changes apply below")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 18).padding(.top, 16)
            GeometryReader { geometry in
                let scale = geometry.size.width / 660
                ZStack(alignment: .topLeading) {
                    ForEach(F75Layout.keys) { key in
                        Button { if page == .mapping { source = key.matrixIndex } } label: {
                            Text(key.label)
                                .font(.system(size: key.label.count > 4 ? 6.5 * scale : 9 * scale, weight: .medium))
                                .lineLimit(1).minimumScaleFactor(0.6)
                                .frame(width: key.width * scale, height: key.height * scale)
                                .background(keyColor(key), in: RoundedRectangle(cornerRadius: 4 * scale))
                                .overlay(RoundedRectangle(cornerRadius: 4 * scale)
                                    .stroke(Color.white.opacity(0.09), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .position(x: (key.x + key.width / 2) * scale, y: (key.y + key.height / 2) * scale)
                        .accessibilityLabel("\(key.label) key")
                        .accessibilityAddTraits(page == .mapping && source == key.matrixIndex ? .isSelected : [])
                        .help("\(key.label) · matrix \(key.matrixIndex)")
                    }
                    Circle().fill(Color.white.opacity(0.1))
                        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 3))
                        .frame(width: 32 * scale, height: 32 * scale)
                        .position(x: 616 * scale, y: 42 * scale)
                        .accessibilityLabel("Volume dial")
                }
            }
            .aspectRatio(660 / 285, contentMode: .fit)
        }
        .background(Color(red: 0.085, green: 0.10, blue: 0.15), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06)))
    }

    private func keyColor(_ key: F75Key) -> Color {
        if page == .mapping { return source == key.matrixIndex ? accent.opacity(0.8) : Color.white.opacity(0.075) }
        return Color(red: Double(model.lighting.red) / 255, green: Double(model.lighting.green) / 255,
                     blue: Double(model.lighting.blue) / 255).opacity(0.18)
    }

    private var lightingControls: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Lighting settings").font(.headline)
                Spacer()
                Text("Stored on your keyboard").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Effect", selection: $model.lighting.effect) {
                        if !F75Protocol.effects.contains(where: { $0.id == model.lighting.effect }) {
                            Text("Current effect (\(model.lighting.effect)) · read only").tag(model.lighting.effect)
                        }
                        ForEach(F75Protocol.effects, id: \.id) { effect in Text(effect.name).tag(effect.id) }
                    }
                    Picker("Color", selection: paletteIndex) {
                        ForEach(F75Protocol.colors.indices, id: \.self) { index in
                            Text(F75Protocol.colors[index].name).tag(index)
                        }
                    }
                        .disabled(model.lighting.rainbow)
                    Toggle("Rainbow colors", isOn: $model.lighting.rainbow)
                }.frame(maxWidth: .infinity)
                VStack(spacing: 16) {
                    slider("Brightness", value: $model.lighting.brightness, range: 0...9)
                    slider("Speed", value: $model.lighting.speed, range: 0...4)
                }.frame(maxWidth: .infinity)
            }
            HStack {
                Text("Preview color is illustrative; effects run on the keyboard.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Apply lighting") { model.applyLighting() }.buttonStyle(.borderedProminent)
                    .disabled(!model.connected || !F75Protocol.effects.contains(where: { $0.id == model.lighting.effect }))
            }
        }
        .padding(20).background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
        .disabled(model.busy)
    }

    private var paletteIndex: Binding<Int> {
        Binding(get: {
            F75Protocol.colors.firstIndex {
                $0.red == model.lighting.red && $0.green == model.lighting.green && $0.blue == model.lighting.blue
            } ?? 0
        }, set: { index in
            guard F75Protocol.colors.indices.contains(index) else { return }
            let color = F75Protocol.colors[index]
            model.lighting.red = color.red
            model.lighting.green = color.green
            model.lighting.blue = color.blue
        })
    }

    private func slider(_ title: String, value: Binding<Int>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: 6) {
            HStack { Text(title); Spacer(); Text("\(value.wrappedValue)").foregroundStyle(.secondary).monospacedDigit() }
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0) }),
                   in: range, step: 1).accessibilityLabel(title)
        }
    }

    private var mappingControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Remap a key").font(.headline)
            HStack(spacing: 16) {
                Text(F75Layout.keys.first(where: { $0.matrixIndex == source })?.label ?? "Select a key")
                    .font(.title3.weight(.semibold)).frame(width: 110, height: 44)
                    .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                Picker("Use mapping from", selection: $target) {
                    ForEach(F75Layout.keys.filter { $0.matrixIndex != 53 }) { key in
                        Text(key.label).tag(key.matrixIndex)
                    }
                }
                Spacer()
                Button("Apply mapping") { model.remap(source: source, target: target) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.connected || source == 53 || source == target)
            }
            Text(source == 53 ? "The Fn key is protected and cannot be remapped."
                 : "Copies the target key's current on-device mapping to the selected key. The target stays unchanged.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20).background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
        .disabled(model.busy)
    }

    private var backupControls: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "externaldrive.badge.checkmark")
                .font(.system(size: 38, weight: .light)).foregroundStyle(accent)
            Text("A safe starting point").font(.title2.weight(.semibold))
            Text("Before changing settings, F75 Studio saves a local copy of the current settings. Macro changes include a copy of the complete macro bank. You can also export a backup to a location you choose.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Export current settings…") { model.exportBackup() }.disabled(!model.connected)
                Button("Import backup…") { model.importBackup() }
                Button("Reveal local backups") { model.revealBackups() }
            }
            Divider()
            if let imported = model.imported {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Backup ready for review", systemImage: "doc.text")
                        .font(.headline)
                    Text("Captured \(imported.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(!model.connected ? "Connect a keyboard to check compatibility."
                         : model.canRestore ? "Keyboard model identity matches. Ready to restore."
                         : "Keyboard model identity does not match. Restore is unavailable.")
                        .foregroundStyle(model.canRestore ? Color.green : Color.orange)
                    Button("Restore imported backup…") { confirmingRestore = true }
                        .buttonStyle(.borderedProminent).disabled(!model.canRestore)
                }
            } else {
                Text("Import a JSON backup to review it before restoring.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Text("Exported backups include lighting, key mappings, and the macro bank. Firmware inspection is available in the Firmware tab.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 16))
        .disabled(model.busy)
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 10) {
            if model.busy { ProgressView().controlSize(.small) }
            else { Image(systemName: "info.circle").foregroundStyle(.secondary) }
            Text(model.status).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Permissions") { model.openPermissions() }
                .buttonStyle(.link).font(.caption)
                .help("Open Input Monitoring settings. Enable F75 Studio if macOS denied device access.")
        }
        .padding(.top, 8)
    }
}
