import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published private(set) var state: RecordingLifecycleState = .idle
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var selectedDisplayName: String = "Main display"
    @Published private(set) var lastRecordingURL: URL?
    @Published private(set) var lastErrorMessage: String?

    let coordinator: RecordingCoordinator
    private var stateTask: Task<Void, Never>?
    private var durationTask: Task<Void, Never>?
    private var recordingStartedAt: Date?

    var isRecording: Bool {
        state.isRecording
    }

    init(coordinator: RecordingCoordinator = RecordingCoordinator()) {
        self.coordinator = coordinator
        observeCoordinator()
    }

    deinit {
        stateTask?.cancel()
        durationTask?.cancel()
    }

    func start(displayID: CGDirectDisplayID? = nil, includeMicrophone: Bool = true) {
        Task {
            await coordinator.startRecording(displayID: displayID, includeMicrophone: includeMicrophone)
        }
    }

    func stop() {
        Task {
            let url = await coordinator.stopRecording()
            if let url {
                await MainActor.run {
                    self.lastRecordingURL = url
                    self.revealRecording(url)
                }
            }
        }
    }

    func revealLastRecording() {
        guard let lastRecordingURL else { return }
        revealRecording(lastRecordingURL)
    }

    private func observeCoordinator() {
        stateTask = Task { [weak self] in
            guard let self else { return }
            for await state in coordinator.updates.stream() {
                await MainActor.run {
                    self.apply(state)
                }
            }
        }
    }

    private func apply(_ newState: RecordingLifecycleState) {
        state = newState
        selectedDisplayName = "Main display"

        switch newState {
        case .recording:
            recordingStartedAt = Date()
            startDurationTimer()
        case .finished(let url):
            lastRecordingURL = url
            stopDurationTimer()
            duration = 0
        case .failed(let message):
            lastErrorMessage = message
            stopDurationTimer()
            duration = 0
        case .idle, .preparing, .countdown, .paused, .stopping:
            if !newState.isRecording {
                stopDurationTimer()
            }
        }
    }

    private func startDurationTimer() {
        durationTask?.cancel()
        durationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, let recordingStartedAt = self.recordingStartedAt else { return }
                    self.duration = Date().timeIntervalSince(recordingStartedAt)
                }
            }
        }
    }

    private func stopDurationTimer() {
        durationTask?.cancel()
        durationTask = nil
        recordingStartedAt = nil
    }

    private func revealRecording(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
