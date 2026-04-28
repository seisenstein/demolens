import AppKit
@preconcurrency import ApplicationServices
@preconcurrency import AVFoundation
import CoreGraphics
import Foundation

struct PermissionSnapshot: Equatable {
    var screenRecording: PermissionAuthorizationState
    var camera: PermissionAuthorizationState
    var microphone: PermissionAuthorizationState
    var accessibility: PermissionAuthorizationState

    static let unknown = PermissionSnapshot(
        screenRecording: .unknown,
        camera: .unknown,
        microphone: .unknown,
        accessibility: .unknown
    )
}

final class PermissionManager: AppState.PermissionManaging, @unchecked Sendable {
    init() {}

    func currentPermissions() -> PermissionSnapshot {
        PermissionSnapshot(
            screenRecording: screenRecordingPermission(),
            camera: cameraPermission(),
            microphone: microphonePermission(),
            accessibility: accessibilityPermission(prompt: false)
        )
    }

    func permission(for kind: PermissionKind) -> PermissionAuthorizationState {
        switch kind {
        case .screenRecording:
            screenRecordingPermission()
        case .camera:
            cameraPermission()
        case .microphone:
            microphonePermission()
        case .accessibility:
            accessibilityPermission(prompt: false)
        }
    }

    func request(_ kind: PermissionKind) async -> PermissionAuthorizationState {
        switch kind {
        case .screenRecording:
            requestScreenRecordingPermission()
        case .camera:
            await requestAVPermission(for: .video)
        case .microphone:
            await requestAVPermission(for: .audio)
        case .accessibility:
            requestAccessibilityPermission()
        }
    }

    func requestAll() async -> PermissionSnapshot {
        let screenRecording = await request(.screenRecording)
        let camera = await request(.camera)
        let microphone = await request(.microphone)
        let accessibility = await request(.accessibility)

        return PermissionSnapshot(
            screenRecording: screenRecording,
            camera: camera,
            microphone: microphone,
            accessibility: accessibility
        )
    }

    func permissionRequirements(
        requiredPermissions: Set<PermissionKind>
    ) async -> [PermissionRequirement] {
        PermissionKind.allCases.map { kind in
            PermissionRequirement(
                kind: kind,
                state: permission(for: kind),
                isRequired: requiredPermissions.contains(kind)
            )
        }
    }

    func requestPermission(_ kind: PermissionKind) async {
        _ = await request(kind)
    }

    @MainActor
    func openSystemSettings(for kind: PermissionKind) {
        guard let url = URL(string: kind.systemSettingsURLString) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func screenRecordingPermission() -> PermissionAuthorizationState {
        CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
    }

    private func requestScreenRecordingPermission() -> PermissionAuthorizationState {
        if CGPreflightScreenCaptureAccess() {
            return .granted
        }

        return CGRequestScreenCaptureAccess() ? .granted : .denied
    }

    private func cameraPermission() -> PermissionAuthorizationState {
        avPermission(for: .video)
    }

    private func microphonePermission() -> PermissionAuthorizationState {
        avPermission(for: .audio)
    }

    private func requestAVPermission(for mediaType: AVMediaType) async -> PermissionAuthorizationState {
        let existingStatus = avPermission(for: mediaType)
        guard existingStatus == .notDetermined else {
            return existingStatus
        }

        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                continuation.resume(returning: granted)
            }
        }

        guard granted else {
            return avPermission(for: mediaType)
        }

        return .granted
    }

    private func avPermission(for mediaType: AVMediaType) -> PermissionAuthorizationState {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            .granted
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .restricted:
            .restricted
        @unknown default:
            .unknown
        }
    }

    private func accessibilityPermission(prompt: Bool) -> PermissionAuthorizationState {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .granted : .notDetermined
    }

    private func requestAccessibilityPermission() -> PermissionAuthorizationState {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .granted : .denied
    }
}
