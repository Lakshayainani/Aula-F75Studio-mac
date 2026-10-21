import SwiftUI
import ServiceManagement

struct StudioSettings: View {
    @ObservedObject var model: StudioModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Show F75 Studio in the menu bar", isOn: $model.showMenuBar)
            Text("Open the app, access your macro library, and connect or refresh your keyboard from the menu bar. Closing the window keeps the app running; choose Quit to exit.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Toggle("Launch F75 Studio at login", isOn: Binding(get: { model.loginRequested }, set: model.setLaunchAtLogin))
            if model.loginStatus == .requiresApproval {
                Label("Approval needed in macOS Login Items", systemImage: "exclamationmark.circle").foregroundStyle(.orange)
            } else {
                Text(model.loginStatus == .enabled ? "Enabled in macOS Login Items." : "Launch at login is off.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Open macOS Login Items") { SMAppService.openSystemSettingsLoginItems() }
            Text("Keyboard macros run on the keyboard even when this app is closed.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
        .onAppear { model.refreshLoginStatus() }
    }
}
