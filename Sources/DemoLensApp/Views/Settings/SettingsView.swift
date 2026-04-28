import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(DemoLensShellTheme.sans(size: 22, weight: .semibold))
                        .foregroundStyle(DemoLensShellTheme.cardForeground)

                    Text("Recording defaults and local permission status.")
                        .font(DemoLensShellTheme.sans(size: 13, weight: .regular))
                        .foregroundStyle(DemoLensShellTheme.mutedForeground)
                }

                SettingsSection(title: "Recording", systemImage: "record.circle") {
                    Toggle("Capture system audio", isOn: $appState.settings.captureSystemAudio)
                    Toggle("Capture microphone narration", isOn: $appState.settings.captureMicrophone)
                    Toggle("Include webcam PiP", isOn: $appState.settings.includeCamera)
                    Toggle("Show cursor highlight", isOn: $appState.settings.showCursorHighlight)

                    Picker("Frame rate", selection: $appState.settings.frameRate) {
                        Text("30 fps").tag(30)
                        Text("60 fps").tag(60)
                    }
                    .pickerStyle(.segmented)

                    Picker("Resolution", selection: $appState.settings.resolution) {
                        Text("Native").tag("Native")
                        Text("1080p").tag("1080p")
                        Text("720p").tag("720p")
                    }
                    .pickerStyle(.segmented)
                }

                SettingsSection(title: "Display", systemImage: "display") {
                    HStack {
                        SettingsValueLabel(title: "Selected display", value: appState.recordingViewModel.selectedDisplayName)
                        Spacer()
                    }
                }

                SettingsSection(title: "Output", systemImage: "folder") {
                    HStack(alignment: .center, spacing: 12) {
                        SettingsValueLabel(
                            title: "Save location",
                            value: appState.settings.outputDirectoryURL.path
                        )

                        Spacer(minLength: 12)

                        Button {
                            appState.openOutputDirectory()
                        } label: {
                            Label("Open", systemImage: "folder")
                        }
                        .buttonStyle(SettingsSecondaryButtonStyle())
                    }

                    if let lastRecordingURL = appState.recordingViewModel.lastRecordingURL {
                        HStack(alignment: .center, spacing: 12) {
                            SettingsValueLabel(
                                title: "Last recording",
                                value: lastRecordingURL.lastPathComponent
                            )

                            Spacer(minLength: 12)

                            Button {
                                appState.recordingViewModel.revealLastRecording()
                            } label: {
                                Label("Reveal", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(SettingsSecondaryButtonStyle())

                            Button {
                                appState.copyLastRecordingPath()
                            } label: {
                                Label("Copy path", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(SettingsSecondaryButtonStyle())
                        }
                    }
                }

                SettingsSection(title: "Permissions", systemImage: "checkmark.shield") {
                    VStack(spacing: 10) {
                        ForEach(appState.permissionViewModel.permissions) { permission in
                            PermissionSettingsRow(
                                permission: permission,
                                viewModel: appState.permissionViewModel
                            )
                        }
                    }

                    HStack {
                        Button {
                            Task {
                                await appState.refreshPermissions()
                            }
                        } label: {
                            Label(
                                appState.permissionViewModel.isRefreshing ? "Refreshing" : "Refresh",
                                systemImage: "arrow.clockwise"
                            )
                        }
                        .buttonStyle(SettingsSecondaryButtonStyle())
                        .disabled(appState.permissionViewModel.isRefreshing)

                        Spacer()
                    }
                }
            }
            .padding(24)
        }
        .background(DemoLensShellTheme.background)
        .foregroundStyle(DemoLensShellTheme.foreground)
        .task {
            await appState.refreshPermissions()
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DemoLensShellTheme.primary)

                Text(title)
                    .font(DemoLensShellTheme.sans(size: 15, weight: .semibold))
                    .foregroundStyle(DemoLensShellTheme.cardForeground)
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DemoLensShellTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DemoLensShellTheme.hairline)
                .frame(height: 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DemoLensShellTheme.border.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct SettingsValueLabel: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(DemoLensShellTheme.sans(size: 12, weight: .medium))
                .foregroundStyle(DemoLensShellTheme.mutedSubtle)

            Text(value)
                .font(DemoLensShellTheme.sans(size: 13, weight: .medium))
                .foregroundStyle(DemoLensShellTheme.cardForeground)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct PermissionSettingsRow: View {
    let permission: PermissionRequirement
    @ObservedObject var viewModel: PermissionViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: permission.kind.systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(permission.isGranted ? DemoLensShellTheme.primary : DemoLensShellTheme.mutedForeground)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(permission.kind.title)
                        .font(DemoLensShellTheme.sans(size: 13, weight: .semibold))
                        .foregroundStyle(DemoLensShellTheme.cardForeground)

                    if permission.isRequired {
                        Text("Required")
                            .font(DemoLensShellTheme.sans(size: 11, weight: .medium))
                            .foregroundStyle(DemoLensShellTheme.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DemoLensShellTheme.primary.opacity(0.1), in: Capsule())
                    }
                }

                Text(permission.kind.summary)
                    .font(DemoLensShellTheme.sans(size: 12, weight: .regular))
                    .foregroundStyle(DemoLensShellTheme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text(permission.state.label)
                .font(DemoLensShellTheme.sans(size: 12, weight: .medium))
                .foregroundStyle(permission.isGranted ? DemoLensShellTheme.primary : DemoLensShellTheme.mutedForeground)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(DemoLensShellTheme.surfaceElevated, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(DemoLensShellTheme.border.opacity(0.7), lineWidth: 1)
                )

            if !permission.isGranted {
                Button {
                    Task {
                        await viewModel.request(permission.kind)
                    }
                } label: {
                    Text("Request")
                }
                .buttonStyle(SettingsSecondaryButtonStyle())

                Button {
                    viewModel.openSystemSettings(for: permission.kind)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(SettingsIconButtonStyle())
                .help("Open System Settings")
            }
        }
    }
}

private struct SettingsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DemoLensShellTheme.sans(size: 12, weight: .medium))
            .foregroundStyle(DemoLensShellTheme.foreground)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(DemoLensShellTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DemoLensShellTheme.border.opacity(0.8), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct SettingsIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(DemoLensShellTheme.foreground)
            .background(DemoLensShellTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DemoLensShellTheme.border.opacity(0.8), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
