import Combine
import Foundation

@MainActor
final class PermissionViewModel: ObservableObject {
    @Published private(set) var screenRecording: PermissionAuthorizationState = .unknown
    @Published private(set) var camera: PermissionAuthorizationState = .unknown
    @Published private(set) var microphone: PermissionAuthorizationState = .unknown
    @Published private(set) var accessibility: PermissionAuthorizationState = .unknown

    @Published private(set) var noPiP = true
    @Published private(set) var noCursorHighlight = true
    @Published private(set) var systemAudioOnly = true

    @Published private(set) var isRequesting = false
    @Published private(set) var requestingPermission: PermissionKind?
    @Published private(set) var isRefreshing = false
    @Published private(set) var permissions: [PermissionRequirement] = PermissionKind.allCases.map {
        PermissionRequirement(kind: $0, state: .unknown, isRequired: $0 == .screenRecording)
    }

    private let permissionManager: PermissionManager

    var canRecord: Bool {
        screenRecording.isGranted
    }

    var hasMissingRequiredPermissions: Bool {
        !missingRequiredPermissions.isEmpty
    }

    var missingRequiredPermissions: [PermissionRequirement] {
        permissions.filter { $0.isRequired && !$0.isGranted }
    }

    var hasOptionalDegradations: Bool {
        noPiP || noCursorHighlight || systemAudioOnly
    }

    init(permissionManager: PermissionManager = PermissionManager()) {
        self.permissionManager = permissionManager
        refresh()
    }

    func refresh() {
        isRefreshing = true
        defer { isRefreshing = false }
        apply(permissionManager.currentPermissions())
    }

    func request(_ permission: PermissionKind) async {
        guard !isRequesting else {
            return
        }

        isRequesting = true
        requestingPermission = permission
        defer {
            requestingPermission = nil
            isRequesting = false
        }

        let status = await permissionManager.request(permission)
        set(status, for: permission)
        updateDegradations()
        updateRequirements()
    }

    func requestAll() async {
        guard !isRequesting else {
            return
        }

        isRequesting = true
        defer {
            requestingPermission = nil
            isRequesting = false
        }

        for permission in PermissionKind.allCases {
            requestingPermission = permission
            let status = await permissionManager.request(permission)
            set(status, for: permission)
            updateDegradations()
            updateRequirements()
        }
    }

    func openSystemSettings(for permission: PermissionKind) {
        permissionManager.openSystemSettings(for: permission)
    }

    func status(for permission: PermissionKind) -> PermissionAuthorizationState {
        switch permission {
        case .screenRecording:
            screenRecording
        case .camera:
            camera
        case .microphone:
            microphone
        case .accessibility:
            accessibility
        }
    }

    private func apply(_ snapshot: PermissionSnapshot) {
        screenRecording = snapshot.screenRecording
        camera = snapshot.camera
        microphone = snapshot.microphone
        accessibility = snapshot.accessibility
        updateDegradations()
        updateRequirements()
    }

    private func set(_ status: PermissionAuthorizationState, for permission: PermissionKind) {
        switch permission {
        case .screenRecording:
            screenRecording = status
        case .camera:
            camera = status
        case .microphone:
            microphone = status
        case .accessibility:
            accessibility = status
        }
    }

    private func updateDegradations() {
        noPiP = !camera.isGranted
        noCursorHighlight = !accessibility.isGranted
        systemAudioOnly = !microphone.isGranted
    }

    private func updateRequirements() {
        permissions = PermissionKind.allCases.map { permission in
            PermissionRequirement(
                kind: permission,
                state: status(for: permission),
                isRequired: permission == .screenRecording
            )
        }
    }
}

extension PermissionAuthorizationState {
    var isGranted: Bool {
        self == .granted
    }

    var needsSettingsFallback: Bool {
        switch self {
        case .denied, .restricted:
            true
        case .unknown, .notDetermined, .granted:
            false
        }
    }
}
