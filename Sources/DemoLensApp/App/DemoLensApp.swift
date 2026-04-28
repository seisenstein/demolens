import AppKit
import SwiftUI

@main
@MainActor
struct DemoLensApp: App {
    @StateObject private var appState = AppState()

    init() {
        PromptableFonts.registerBundledFonts()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            DemoLensMenuBarLabel()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(minWidth: 560, idealWidth: 640, minHeight: 520, idealHeight: 620)
                .task {
                    await appState.refreshPermissions()
                }
        }
    }
}

private struct DemoLensMenuBarLabel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Label {
            Text(appState.recordingViewModel.isRecording ? "DemoLens recording" : "DemoLens")
        } icon: {
            Image(systemName: appState.recordingViewModel.isRecording ? "record.circle.fill" : "video.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(appState.recordingViewModel.isRecording ? DemoLensShellTheme.destructive : DemoLensShellTheme.primary)
        }
    }
}
