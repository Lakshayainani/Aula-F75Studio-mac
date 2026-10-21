import SwiftUI
import AppKit
import UniformTypeIdentifiers
import F75Core

private typealias MacroViewState<Value> = SwiftUI.State<Value>

@MainActor
struct MacroEditor: View {
    let connected: Bool
    let busy: Bool
    let canSave: Bool
    let onSave: (F75Macro) -> Void
    let onUpdate: ((F75Macro) -> Void)?
    let onImported: () -> Void
    let onApply: (F75Macro, Int) -> Void
    @Binding private var draft: F75Macro
    @MacroViewState private var target = 78
    @MacroViewState private var newUsage: UInt8 = 4
    @MacroViewState private var message: String?
    @MacroViewState private var fileError: String?

    init(connected: Bool, busy: Bool, draft: Binding<F75Macro>, canSave: Bool,
         onSave: @escaping (F75Macro) -> Void, onUpdate: ((F75Macro) -> Void)? = nil,
         onImported: @escaping () -> Void, onApply: @escaping (F75Macro, Int) -> Void) {
        self.connected = connected
        self.busy = busy
        self.canSave = canSave; self.onSave = onSave; self.onUpdate = onUpdate; self.onImported = onImported
        self.onApply = onApply
        _draft = draft
    }

    private var validationError: String? {
        do { _ = try F75MacroCodec.encode(draft); return nil }
        catch { return error.localizedDescription }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Macro sequence").font(.headline)
                    Text("Add key presses, releases, and delays in playback order.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Import JSON…", action: importJSON)
                Button("Export JSON…", action: exportJSON).disabled(validationError != nil)
            }
            HStack {
                TextField("Macro name", text: $draft.name).textFieldStyle(.roundedBorder)
                Text("\(draft.name.utf16.count)/30")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack {
                Button("Save to library") { onSave(draft) }.disabled(!canSave || validationError != nil)
                if let onUpdate {
                    Button("Update keyboard macro") { onUpdate(draft) }
                        .disabled(!connected || validationError != nil)
                }
                Spacer()
            }
            HStack(spacing: 12) {
                Picker("Key", selection: $newUsage) {
                    ForEach(Self.usages, id: \.self) { usage in Text(Self.keyName(usage)).tag(usage) }
                }
                .frame(maxWidth: 230)
                Button("Add press + release") {
                    draft.events += [F75MacroEvent(usage: newUsage, isPressed: true),
                                     F75MacroEvent(usage: newUsage, isPressed: false)]
                }
                Menu("Add event") {
                    Button("Key down") { draft.events.append(F75MacroEvent(usage: newUsage, isPressed: true)) }
                    Button("Key up") { draft.events.append(F75MacroEvent(usage: newUsage, isPressed: false)) }
                }.fixedSize()
                Spacer(minLength: 0)
            }
            if draft.events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle").font(.system(size: 28)).foregroundStyle(.secondary)
                    Text("Your sequence starts here").font(.callout.weight(.medium))
                    Text("Choose a key above, then add its press and release.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                HStack {
                    Text("EVENTS · \(draft.events.count)").font(.system(size: 10, weight: .bold)).tracking(1)
                    Spacer()
                    Text("Delays in milliseconds").font(.caption).foregroundStyle(.secondary)
                }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(draft.events.indices, id: \.self) { index in eventRow(index) }
                    }
                    .padding(2)
                }
                .frame(minHeight: 130, maxHeight: 260)
            }
            Divider()
            if let validationError {
                Label(validationError, systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
            HStack(spacing: 16) {
                Picker("Assign to", selection: $target) {
                    ForEach(F75Layout.keys.filter { $0.matrixIndex != 53 }) { key in
                        Text(key.label).tag(key.matrixIndex)
                    }
                }
                .frame(maxWidth: 250)
                Spacer()
                Button("Apply macro to key") { apply() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!connected || validationError != nil)
            }
            Text("Applying replaces the selected key's current mapping. A full backup is saved automatically; the Fn key is protected. Playback runs once per press.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
        .disabled(busy)
        .alert("Couldn't open or save the macro", isPresented: Binding(
            get: { fileError != nil }, set: { if !$0 { fileError = nil } }
        )) {
            Button("OK", role: .cancel) { fileError = nil }
        } message: { Text(fileError ?? "") }
    }

    private func eventRow(_ index: Int) -> some View {
        // Indexed rows can outlive deletion during a SwiftUI update.
        let event = Binding<F75MacroEvent>(
            get: { draft.events.indices.contains(index) ? draft.events[index] : F75MacroEvent(usage: 4, isPressed: true) },
            set: { if draft.events.indices.contains(index) { draft.events[index] = $0 } }
        )
        return HStack(spacing: 10) {
            Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 24)
            Picker("Event \(index + 1) key", selection: event.usage) {
                ForEach(Self.usages, id: \.self) { usage in Text(Self.keyName(usage)).tag(usage) }
            }.labelsHidden().frame(maxWidth: .infinity)
            Picker("Event \(index + 1) action", selection: event.isPressed) {
                Text("Key down").tag(true)
                Text("Key up").tag(false)
            }.labelsHidden().frame(width: 105)
            TextField("Delay", value: event.delayMS, format: .number)
                .textFieldStyle(.roundedBorder).frame(width: 75)
                .accessibilityLabel("Event \(index + 1) delay in milliseconds")
            VStack(spacing: 2) {
                Button { move(index, by: -1) } label: { Image(systemName: "chevron.up") }
                    .disabled(index == 0).accessibilityLabel("Move event \(index + 1) up")
                Button { move(index, by: 1) } label: { Image(systemName: "chevron.down") }
                    .disabled(index + 1 >= draft.events.count).accessibilityLabel("Move event \(index + 1) down")
            }.buttonStyle(.plain).font(.system(size: 9)).frame(width: 18)
            Button(role: .destructive) {
                if draft.events.indices.contains(index) { draft.events.remove(at: index) }
            } label: { Image(systemName: "trash") }
            .buttonStyle(.borderless).accessibilityLabel("Delete event \(index + 1)")
        }
        .padding(10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
    }

    private func move(_ index: Int, by delta: Int) {
        let destination = index + delta
        guard draft.events.indices.contains(index), draft.events.indices.contains(destination) else { return }
        draft.events.swapAt(index, destination)
    }

    private func apply() {
        do {
            _ = try F75MacroCodec.encode(draft)
            guard connected, !busy, target != 53,
                  F75Layout.keys.contains(where: { $0.matrixIndex == target }) else { return }
            onApply(draft, target)
        } catch { fileError = error.localizedDescription }
    }

    private func importJSON() {
        let panel = NSOpenPanel()
        panel.title = "Import macro"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0, size <= 1_048_576 else { throw CocoaError(.fileReadTooLarge) }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            let imported = try Self.decodeJSON(file.read(upToCount: 1_048_577) ?? Data())
            onImported()
            draft = imported
            message = "Loaded \(url.lastPathComponent). Review the sequence before applying."
        } catch { fileError = error.localizedDescription }
    }

    private func exportJSON() {
        do {
            _ = try F75MacroCodec.encode(draft)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(draft)
            let panel = NSSavePanel()
            panel.title = "Export macro"
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "F75-macro.json"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
            message = "Saved \(url.lastPathComponent)."
        } catch { fileError = error.localizedDescription }
    }

    private static let usages = (4...0xA4).map(UInt8.init) + (0xE0...0xE7).map(UInt8.init)

    nonisolated static func decodeJSON(_ data: Data) throws -> F75Macro {
        guard !data.isEmpty, data.count <= 1_048_576 else { throw CocoaError(.fileReadTooLarge) }
        let macro = try JSONDecoder().decode(F75Macro.self, from: data)
        _ = try F75MacroCodec.encode(macro)
        return macro
    }

    private static func keyName(_ usage: UInt8) -> String {
        if (4...29).contains(usage) { return String(UnicodeScalar(Int(usage) - 4 + 65)!) }
        if (30...38).contains(usage) { return String(Int(usage) - 29) }
        if usage == 39 { return "0" }
        if (58...69).contains(usage) { return "F\(Int(usage) - 57)" }
        if (104...115).contains(usage) { return "F\(Int(usage) - 91)" }
        return keyLabels[usage] ?? String(format: "HID key 0x%02X", usage)
    }

    private static let keyLabels: [UInt8: String] = [
            40: "Enter", 41: "Esc", 42: "Backspace", 43: "Tab", 44: "Space", 45: "-", 46: "=",
            47: "[", 48: "]", 49: "\\", 50: "Non-US #", 51: ";", 52: "'", 53: "`", 54: ",", 55: ".", 56: "/",
            57: "Caps Lock", 70: "Print Screen", 71: "Scroll Lock", 72: "Pause", 73: "Insert", 74: "Home",
            75: "Page Up", 76: "Delete", 77: "End", 78: "Page Down", 79: "Right", 80: "Left", 81: "Down", 82: "Up",
            83: "Num Lock", 84: "Keypad /", 85: "Keypad *", 86: "Keypad -", 87: "Keypad +", 88: "Keypad Enter",
            89: "Keypad 1", 90: "Keypad 2", 91: "Keypad 3", 92: "Keypad 4", 93: "Keypad 5", 94: "Keypad 6",
            95: "Keypad 7", 96: "Keypad 8", 97: "Keypad 9", 98: "Keypad 0", 99: "Keypad .",
            100: "Non-US backslash", 101: "Application", 102: "Power", 103: "Keypad =",
            224: "Left Control", 225: "Left Shift", 226: "Left Option / Alt", 227: "Left Command / GUI",
            228: "Right Control", 229: "Right Shift", 230: "Right Option / Alt", 231: "Right Command / GUI"
    ]
}
