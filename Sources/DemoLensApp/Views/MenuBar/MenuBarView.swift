import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MenuHeader(recordingViewModel: appState.recordingViewModel)

            if !appState.permissionViewModel.canRecord {
                PermissionsView(
                    viewModel: appState.permissionViewModel,
                    presentation: .compact
                )
            } else {
                CompactRecordingView(
                    viewModel: appState.recordingViewModel,
                    includeMicrophone: appState.settings.captureMicrophone
                )
            }

            Divider()
                .overlay(DemoLensShellTheme.border.opacity(0.7))

            HStack(spacing: 8) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ShellSecondaryButtonStyle())

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .frame(width: 36, height: 34)
                }
                .buttonStyle(ShellIconButtonStyle())
                .help("Quit DemoLens")
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(DemoLensShellTheme.surfaceElevated)
        .foregroundStyle(DemoLensShellTheme.foreground)
        .task {
            await appState.refreshPermissions()
        }
    }
}

private struct MenuHeader: View {
    @ObservedObject var recordingViewModel: RecordingViewModel

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.16))
                    .frame(width: 28, height: 28)

                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("DemoLens")
                    .font(DemoLensShellTheme.sans(size: 14, weight: .semibold))
                    .foregroundStyle(DemoLensShellTheme.cardForeground)

                Text(recordingViewModel.state.statusText)
                    .font(DemoLensShellTheme.sans(size: 12, weight: .medium))
                    .foregroundStyle(DemoLensShellTheme.mutedForeground)
            }

            Spacer()

            if recordingViewModel.isRecording {
                Text(recordingViewModel.durationText)
                    .font(DemoLensShellTheme.mono(size: 13, weight: .medium))
                    .foregroundStyle(DemoLensShellTheme.cardForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(DemoLensShellTheme.card, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DemoLensShellTheme.border.opacity(0.6), lineWidth: 1)
                    )
            }
        }
    }

    private var statusColor: Color {
        switch recordingViewModel.state {
        case .failed:
            return DemoLensShellTheme.destructive
        case .preparing, .countdown, .recording, .paused, .stopping:
            return DemoLensShellTheme.destructiveSolid
        case .idle, .finished:
            return DemoLensShellTheme.primary
        }
    }
}

private struct ShellPermissionsView: View {
    @ObservedObject var viewModel: PermissionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Permissions required")
                    .font(DemoLensShellTheme.sans(size: 14, weight: .semibold))
                    .foregroundStyle(DemoLensShellTheme.cardForeground)

                Text("Grant access before starting a recording.")
                    .font(DemoLensShellTheme.sans(size: 12, weight: .regular))
                    .foregroundStyle(DemoLensShellTheme.mutedForeground)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: PermissionKind.screenRecording.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DemoLensShellTheme.primary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(PermissionKind.screenRecording.title)
                        .font(DemoLensShellTheme.sans(size: 13, weight: .semibold))
                        .foregroundStyle(DemoLensShellTheme.cardForeground)

                    Text(PermissionKind.screenRecording.summary)
                        .font(DemoLensShellTheme.sans(size: 12, weight: .regular))
                        .foregroundStyle(DemoLensShellTheme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                PTButton(
                    "Grant access",
                    systemImage: "checkmark.shield",
                    variant: .default,
                    size: .lg
                ) {
                    Task {
                        await viewModel.request(.screenRecording)
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(viewModel.isRequesting)

                PTButton(variant: .secondary, size: .icon) {
                    viewModel.refresh()
                } label: {
                    Image(systemName: viewModel.isRequesting ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                }
                .disabled(viewModel.isRequesting)
                .help("Refresh permissions")
            }

            PTButton(
                "Open System Settings",
                systemImage: "arrow.up.forward.app",
                variant: .link,
                size: .sm
            ) {
                viewModel.openSystemSettings(for: .screenRecording)
            }
        }
        .padding(12)
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

private struct CompactRecordingView: View {
    @ObservedObject var viewModel: RecordingViewModel
    let includeMicrophone: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PTButton(
                variant: viewModel.isRecording ? .destructive : .default,
                size: .lg
            ) {
                if viewModel.isRecording {
                    viewModel.stop()
                } else {
                    viewModel.start(includeMicrophone: includeMicrophone)
                }
            } label: {
                Label(viewModel.menuActionTitle, systemImage: viewModel.menuActionSystemImage)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .disabled(!viewModel.canToggleFromMenu)

            InfoRow(
                systemImage: "display",
                title: "Display",
                value: viewModel.selectedDisplayName
            )

            LastRecordingRow(viewModel: viewModel)

            if let errorMessage = viewModel.lastErrorMessage {
                Text(errorMessage)
                    .font(DemoLensShellTheme.sans(size: 12, weight: .regular))
                    .foregroundStyle(DemoLensShellTheme.destructive)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct InfoRow: View {
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DemoLensShellTheme.mutedForeground)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DemoLensShellTheme.sans(size: 11, weight: .medium))
                    .foregroundStyle(DemoLensShellTheme.mutedSubtle)

                Text(value)
                    .font(DemoLensShellTheme.sans(size: 13, weight: .medium))
                    .foregroundStyle(DemoLensShellTheme.cardForeground)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct LastRecordingRow: View {
    @ObservedObject var viewModel: RecordingViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "film")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DemoLensShellTheme.mutedForeground)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text("Last recording")
                    .font(DemoLensShellTheme.sans(size: 11, weight: .medium))
                    .foregroundStyle(DemoLensShellTheme.mutedSubtle)

                if let lastRecordingURL = viewModel.lastRecordingURL {
                    Button {
                        viewModel.revealLastRecording()
                    } label: {
                        Text(lastRecordingURL.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                    .font(DemoLensShellTheme.sans(size: 13, weight: .medium))
                    .foregroundStyle(DemoLensShellTheme.primary)
                    .help(lastRecordingURL.path)
                } else {
                    Text("None yet")
                        .font(DemoLensShellTheme.sans(size: 13, weight: .medium))
                        .foregroundStyle(DemoLensShellTheme.mutedForeground)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ShellSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DemoLensShellTheme.sans(size: 13, weight: .medium))
            .foregroundStyle(DemoLensShellTheme.foreground)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(DemoLensShellTheme.card, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DemoLensShellTheme.border.opacity(0.8), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private extension RecordingViewModel {
    var canToggleFromMenu: Bool {
        switch state {
        case .idle, .recording, .finished, .failed:
            return true
        case .preparing, .countdown, .paused, .stopping:
            return false
        }
    }

    var menuActionTitle: LocalizedStringKey {
        isRecording ? "Stop recording" : "Start recording"
    }

    var menuActionSystemImage: String {
        isRecording ? "stop.fill" : "record.circle"
    }

    var durationText: String {
        let totalSeconds = Int(duration.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct ShellIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(DemoLensShellTheme.foreground)
            .background(DemoLensShellTheme.card, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DemoLensShellTheme.border.opacity(0.8), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
