import SwiftUI
import F75Core

private typealias LibraryState<Value> = SwiftUI.State<Value>

struct MacroLibraryView: View {
    @ObservedObject var model: StudioModel
    @LibraryState private var pendingSwitch: (() -> Void)?
    @LibraryState private var removing: F75MacroLibrary.Entry?
    @LibraryState private var confirmingUpdate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 20) {
                savedLibrary
                keyboardLibrary
            }
            if let entry = model.library.entries.first(where: { $0.id == model.selectedMacroID }) {
                Text("Editing saved macro: \(entry.macro.name)\(model.macroDraftDirty ? " · unsaved changes" : "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let index = model.editingKeyboardIndex {
                Text("Editing keyboard macro \(index + 1). Updating changes its playback wherever it is assigned, including other layers.")
                    .font(.caption).foregroundStyle(.orange)
            }
            MacroEditor(connected: model.connected, busy: model.busy, draft: $model.macroDraft,
                        canSave: model.libraryWritable, onSave: { model.saveMacro($0) },
                        onUpdate: model.editingKeyboardIndex == nil ? nil : { _ in confirmingUpdate = true },
                        onImported: { model.newMacro() }) { macro, target in
                model.applyMacro(macro, matrixIndex: target)
            }
        }
        .confirmationDialog("Discard unsaved macro changes?", isPresented: Binding(
            get: { pendingSwitch != nil }, set: { if !$0 { pendingSwitch = nil } }
        ), titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) {
                let action = pendingSwitch; pendingSwitch = nil; action?()
            }
            Button("Cancel", role: .cancel) { pendingSwitch = nil }
        }
        .confirmationDialog("Remove this saved macro from the library?", isPresented: Binding(
            get: { removing != nil }, set: { if !$0 { removing = nil } }
        ), titleVisibility: .visible) {
            Button("Remove from library", role: .destructive) {
                if let entry = removing { model.removeMacro(entry) }; removing = nil
            }
            Button("Cancel", role: .cancel) { removing = nil }
        } message: { Text("This leaves the keyboard's stored macros and key assignments unchanged.") }
        .confirmationDialog("Update this macro on the keyboard?", isPresented: $confirmingUpdate, titleVisibility: .visible) {
            Button("Update keyboard macro") { model.updateKeyboardMacro(model.macroDraft) }
        } message: { Text("Every key using this record will play the updated sequence. A full keyboard backup is saved first.") }
    }

    private var savedLibrary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved library").font(.headline)
                Spacer()
                Button("New") { switchDraft { model.newMacro() } }
            }
            if model.library.entries.isEmpty {
                Text("Save a sequence below to keep it between launches.").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(model.library.entries) { entry in
                        HStack {
                            Button {
                                switchDraft { model.loadMacro(entry) }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(entry.macro.name).fontWeight(model.selectedMacroID == entry.id ? .bold : .regular)
                                    Text("\(entry.macro.events.count) events").font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                            Menu {
                                Button("Duplicate") { switchDraft { model.duplicateMacro(entry) } }
                                Button("Remove from library…", role: .destructive) { removing = entry }
                            } label: { Image(systemName: "ellipsis") }
                            .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Actions for \(entry.macro.name)")
                        }
                        .padding(8).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }.frame(minHeight: 60, maxHeight: 155)
        }.padding(16).frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
            .disabled(model.busy || !model.libraryWritable)
    }

    private var keyboardLibrary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("On keyboard").font(.headline)
                Spacer()
                Button("Read macros") { model.readMacros() }.disabled(!model.connected || model.busy)
            }
            if !model.connected {
                Text("Connect to read and edit existing keyboard macros.").font(.caption).foregroundStyle(.secondary)
            } else if model.keyboardRecords.isEmpty {
                Text("No macro records found. Apply a sequence below to add one.").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(model.keyboardRecords.indices, id: \.self) { index in
                        let macro = try? F75MacroCodec.decode(model.keyboardRecords[index])
                        Button { switchDraft { model.loadKeyboardMacro(at: index) } } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(index + 1). \(macro?.name ?? "Unsupported macro · preserved")")
                                    .fontWeight(model.editingKeyboardIndex == index ? .bold : .regular)
                                Text(assignments(index)).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        }.buttonStyle(.plain).disabled(macro == nil || model.busy)
                    }
                }
            }.frame(minHeight: 60, maxHeight: 155)
        }.padding(16).frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
    }
    private func assignments(_ index: Int) -> String {
        let keys = F75Layout.keys.filter {
            let offset = $0.matrixIndex * 4
            return offset + 3 < model.keyboardMacroKeys.count && model.keyboardMacroKeys[offset] == 3 && model.keyboardMacroKeys[offset + 3] == UInt8(index)
        }.map(\.label)
        return keys.isEmpty ? "No assignment in the main layer" : "Main layer: " + keys.joined(separator: ", ")
    }
    private func switchDraft(_ action: @escaping () -> Void) {
        if model.macroDraftDirty { pendingSwitch = action } else { action() }
    }
}
