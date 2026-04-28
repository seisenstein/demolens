import SwiftUI

enum PermissionsViewPresentation {
    case full
    case compact
}

struct PermissionsView: View {
    @StateObject private var viewModel: PermissionViewModel

    private let presentation: PermissionsViewPresentation
    private let onContinue: (() -> Void)?

    @MainActor
    init(presentation: PermissionsViewPresentation = .full, onContinue: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: PermissionViewModel(permissionManager: PermissionManager()))
        self.presentation = presentation
        self.onContinue = onContinue
    }

    @MainActor
    init(
        viewModel: PermissionViewModel,
        presentation: PermissionsViewPresentation = .full,
        onContinue: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.presentation = presentation
        self.onContinue = onContinue
    }

    var body: some View {
        switch presentation {
        case .full:
            fullBody
        case .compact:
            compactBody
        }
    }

    private var fullBody: some View {
        ZStack {
            PromptableTheme.Colors.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                header

                VStack(spacing: 12) {
                    ForEach(PermissionKind.allCases) { permission in
                        PermissionRow(
                            permission: permission,
                            status: viewModel.status(for: permission),
                            isRequesting: viewModel.requestingPermission == permission,
                            isDisabled: viewModel.isRequesting,
                            requestAction: {
                                Task {
                                    await viewModel.request(permission)
                                }
                            },
                            settingsAction: {
                                viewModel.openSystemSettings(for: permission)
                            }
                        )
                    }
                }

                if viewModel.hasOptionalDegradations {
                    DegradationSummary(
                        noPiP: viewModel.noPiP,
                        noCursorHighlight: viewModel.noCursorHighlight,
                        systemAudioOnly: viewModel.systemAudioOnly
                    )
                }

                footer
            }
            .padding(32)
            .frame(maxWidth: 760)
        }
        .frame(minWidth: 680, minHeight: 620)
        .task {
            viewModel.refresh()
        }
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Permissions required")
                    .font(.manrope(size: 14, weight: .semibold))
                    .foregroundStyle(PromptableTheme.Colors.cardForeground)

                Text("Grant Screen Recording before starting.")
                    .font(.manrope(size: 12))
                    .foregroundStyle(PromptableTheme.Colors.mutedForeground)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: PermissionKind.screenRecording.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PromptableTheme.Colors.primary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(PermissionKind.screenRecording.title)
                        .font(.manrope(size: 13, weight: .semibold))
                        .foregroundStyle(PromptableTheme.Colors.cardForeground)

                    Text(PermissionKind.screenRecording.summary)
                        .font(.manrope(size: 12))
                        .foregroundStyle(PromptableTheme.Colors.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                PTButton("Grant access", systemImage: "checkmark.shield", size: .lg) {
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
        .background {
            PTRoundedSurface(
                fill: PromptableTheme.Colors.card,
                cornerRadius: PromptableTheme.Radius.base,
                shadow: PromptableTheme.Shadows.sm
            )
        }
        .task {
            viewModel.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DemoLens permissions")
                .font(.manrope(size: 28, weight: .semibold))
                .foregroundStyle(PromptableTheme.Colors.cardForeground)

            Text("Screen Recording is required. Camera, microphone, and Accessibility unlock richer recordings when available.")
                .font(.manrope(size: 14))
                .foregroundStyle(PromptableTheme.Colors.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            PTButton("Refresh", systemImage: "arrow.clockwise", variant: .secondary) {
                viewModel.refresh()
            }
            .disabled(viewModel.isRequesting)

            Spacer()

            PTButton("Request All", systemImage: "checklist", variant: .secondary) {
                Task {
                    await viewModel.requestAll()
                }
            }
            .disabled(viewModel.isRequesting)

            PTButton(
                LocalizedStringKey(viewModel.canRecord ? "Continue" : "Continue Without Recording"),
                systemImage: "arrow.right"
            ) {
                onContinue?()
            }
            .disabled(viewModel.isRequesting || onContinue == nil)
        }
    }
}

private struct PermissionRow: View {
    let permission: PermissionKind
    let status: PermissionAuthorizationState
    let isRequesting: Bool
    let isDisabled: Bool
    let requestAction: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PromptableTheme.Colors.primary10)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(PromptableTheme.Colors.primary30, lineWidth: 1)
                    }

                Image(systemName: permission.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PromptableTheme.Colors.primary)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(permission.title)
                        .font(.manrope(size: 15, weight: .semibold))
                        .foregroundStyle(PromptableTheme.Colors.cardForeground)

                    Text(permission.requirementLabel)
                        .font(.manrope(size: 11, weight: .semibold))
                        .foregroundStyle(permission.isRequired ? PromptableTheme.Colors.primary : PromptableTheme.Colors.mutedForeground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(permission.isRequired ? PromptableTheme.Colors.primary10 : PromptableTheme.Colors.accent)
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(PromptableTheme.Colors.border.opacity(0.8), lineWidth: 1)
                        }
                }

                Text(permission.summary)
                    .font(.manrope(size: 13))
                    .foregroundStyle(PromptableTheme.Colors.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            StatusPill(status: status)

            PTButton(
                LocalizedStringKey(actionTitle),
                systemImage: status.needsSettingsFallback ? "gearshape" : "hand.raised",
                variant: .secondary,
                size: .sm
            ) {
                if status.needsSettingsFallback {
                    settingsAction()
                } else {
                    requestAction()
                }
            }
            .disabled(isDisabled || status.isGranted)
        }
        .padding(16)
        .background {
            PTRoundedSurface(
                fill: PromptableTheme.Colors.card,
                cornerRadius: PromptableTheme.Radius.lg,
                shadow: PromptableTheme.Shadows.sm
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var actionTitle: String {
        if isRequesting {
            return "Requesting"
        }

        if status.needsSettingsFallback {
            return "Open Settings"
        }

        return status.isGranted ? "Granted" : "Grant"
    }
}

private struct StatusPill: View {
    let status: PermissionAuthorizationState

    var body: some View {
        Label(status.title, systemImage: status.symbolName)
            .font(.manrope(size: 12, weight: .semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(status.color.opacity(0.1))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(status.color.opacity(0.35), lineWidth: 1)
            }
            .lineLimit(1)
    }
}

private struct DegradationSummary: View {
    let noPiP: Bool
    let noCursorHighlight: Bool
    let systemAudioOnly: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Graceful degradation")
                .font(.manrope(size: 13, weight: .semibold))
                .foregroundStyle(PromptableTheme.Colors.cardForeground)

            VStack(alignment: .leading, spacing: 6) {
                if noPiP {
                    Label("No camera access: webcam PiP will be disabled.", systemImage: "video.slash")
                }

                if noCursorHighlight {
                    Label("No Accessibility access: cursor highlight will be disabled.", systemImage: "cursorarrow.rays")
                }

                if systemAudioOnly {
                    Label("No microphone access: recordings will use system audio only.", systemImage: "mic.slash")
                }
            }
            .font(.manrope(size: 13))
            .foregroundStyle(PromptableTheme.Colors.mutedForeground)
        }
        .padding(14)
        .background {
            PTRoundedSurface(
                fill: PromptableTheme.Colors.surfaceElevated,
                cornerRadius: 10,
                shadow: PromptableTheme.Shadows.xs
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension PermissionKind {
    var isRequired: Bool {
        self == .screenRecording
    }

    var requirementLabel: String {
        isRequired ? "Required" : "Optional"
    }
}

private extension PermissionAuthorizationState {
    var title: String {
        switch self {
        case .unknown:
            "Unknown"
        case .notDetermined:
            "Needs Permission"
        case .granted:
            "Granted"
        case .denied:
            "Settings Needed"
        case .restricted:
            "Restricted"
        }
    }

    var symbolName: String {
        switch self {
        case .unknown:
            "questionmark.circle"
        case .notDetermined:
            "exclamationmark.circle"
        case .granted:
            "checkmark.circle.fill"
        case .denied:
            "gearshape.fill"
        case .restricted:
            "lock.fill"
        }
    }

    var color: Color {
        switch self {
        case .unknown, .notDetermined:
            PromptableTheme.Colors.mutedForeground
        case .granted:
            PromptableTheme.Colors.primary
        case .denied, .restricted:
            PromptableTheme.Colors.destructive
        }
    }
}
