import ApplicationServices
import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let permissionViewModel: PermissionViewModel
    let recordingViewModel: RecordingViewModel

    @Published var settings: RecordingSettings

    private var cancellables: Set<AnyCancellable> = []

    init(
        permissionViewModel: PermissionViewModel = PermissionViewModel(),
        recordingViewModel: RecordingViewModel = RecordingViewModel(),
        settings: RecordingSettings = RecordingSettings()
    ) {
        self.permissionViewModel = permissionViewModel
        self.recordingViewModel = recordingViewModel
        self.settings = settings

        bindObjectWillChange(from: permissionViewModel)
        bindObjectWillChange(from: recordingViewModel)
    }

    var requiredPermissionKinds: Set<PermissionKind> {
        [.screenRecording]
    }

    func refreshPermissions() async {
        permissionViewModel.refresh()
    }

    func openOutputDirectory() {
        let directory = settings.outputDirectoryURL
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    func copyLastRecordingPath() {
        guard let lastRecordingURL = recordingViewModel.lastRecordingURL else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lastRecordingURL.path, forType: .string)
    }

    private func bindObjectWillChange(from object: some ObservableObject) {
        object.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

extension AppState {
    protocol PermissionManaging: AnyObject {
        func permissionRequirements(
            requiredPermissions: Set<PermissionKind>
        ) async -> [PermissionRequirement]

        func requestPermission(_ kind: PermissionKind) async
    }
}

enum PermissionKind: String, CaseIterable, Identifiable, Sendable {
    case screenRecording
    case camera
    case microphone
    case accessibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenRecording:
            return "Screen Recording"
        case .camera:
            return "Camera"
        case .microphone:
            return "Microphone"
        case .accessibility:
            return "Accessibility"
        }
    }

    var summary: String {
        switch self {
        case .screenRecording:
            return "Required to capture the selected display."
        case .camera:
            return "Needed only when webcam PiP is enabled."
        case .microphone:
            return "Needed only when microphone narration is enabled."
        case .accessibility:
            return "Needed only for cursor highlight and click effects."
        }
    }

    var systemImage: String {
        switch self {
        case .screenRecording:
            return "display"
        case .camera:
            return "video"
        case .microphone:
            return "mic"
        case .accessibility:
            return "cursorarrow.click"
        }
    }

    var systemSettingsURLString: String {
        switch self {
        case .screenRecording:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .camera:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        case .microphone:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }
    }
}

struct PermissionRequirement: Identifiable, Equatable, Sendable {
    let kind: PermissionKind
    var state: PermissionAuthorizationState
    var isRequired: Bool

    var id: PermissionKind { kind }
    var isGranted: Bool { state == .granted }
}

enum PermissionAuthorizationState: Equatable, Sendable {
    case unknown
    case notDetermined
    case granted
    case denied
    case restricted

    var label: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .notDetermined:
            return "Not granted"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        }
    }
}

struct RecordingSettings: Equatable, Sendable {
    var captureSystemAudio = true
    var captureMicrophone = true
    var includeCamera = false
    var showCursorHighlight = true
    var frameRate = 30
    var resolution = "Native"
    var outputDirectoryURL = FileManager.default
        .urls(for: .moviesDirectory, in: .userDomainMask)
        .first?
        .appendingPathComponent("DemoLens", isDirectory: true)
        ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Movies/DemoLens", isDirectory: true)
}

enum DemoLensShellTheme {
    static let background = PromptableTheme.Colors.background
    static let card = PromptableTheme.Colors.card
    static let surfaceElevated = PromptableTheme.Colors.surfaceElevated
    static let foreground = PromptableTheme.Colors.foreground
    static let cardForeground = PromptableTheme.Colors.cardForeground
    static let mutedForeground = PromptableTheme.Colors.mutedForeground
    static let mutedSubtle = PromptableTheme.Colors.mutedSubtle
    static let primary = PromptableTheme.Colors.primary
    static let primaryButton = PromptableTheme.Colors.primaryButton
    static let primaryForeground = PromptableTheme.Colors.primaryForeground
    static let destructiveSolid = PromptableTheme.Colors.destructiveSolid
    static let destructive = PromptableTheme.Colors.destructive
    static let border = PromptableTheme.Colors.border
    static let hairline = PromptableTheme.Colors.hairline
    static let hairlineStrong = PromptableTheme.Colors.hairlineStrong

    static func sans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .manrope(size: size, weight: weight)
    }

    static func mono(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .jetbrainsMono(size: size, weight: weight)
    }
}
