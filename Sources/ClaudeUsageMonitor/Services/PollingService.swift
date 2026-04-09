import Foundation
import AppKit
import Combine

@MainActor
final class PollingService: ObservableObject {
    @Published var refreshInterval: TimeInterval = Constants.defaultRefreshInterval

    private let usageService: UsageService
    private var timerTask: Task<Void, Never>?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var isPaused = false

    init(usageService: UsageService) {
        self.usageService = usageService
        observeSleepWake()
    }

    deinit {
        timerTask?.cancel()
        if let obs = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        if let obs = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    // MARK: - Start/Stop

    private var isRunning = false

    func start() {
        guard !isRunning else { NSLog("[Polling] Already running, skipping start"); return }
        isRunning = true
        NSLog("[Polling] Starting with interval \(refreshInterval)s")
        timerTask?.cancel()
        timerTask = Task.detached { [weak self] in
            NSLog("[Polling] Task started, fetching initial data...")
            await self?.usageService.fetchUsage()
            await self?.usageService.fetchUserInfo()
            NSLog("[Polling] Initial fetch complete")

            while !Task.isCancelled {
                let paused = await self?.isPaused ?? false
                guard !paused else {
                    try? await Task.sleep(for: .seconds(1))
                    continue
                }

                let interval = await self?.refreshInterval ?? Constants.defaultRefreshInterval
                try? await Task.sleep(for: .seconds(interval))

                if !Task.isCancelled {
                    await self?.usageService.fetchUsage()
                }
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
    }

    func refreshNow() {
        Task.detached { [weak self] in
            await self?.usageService.fetchUsage()
        }
    }

    // MARK: - Sleep/Wake

    private func observeSleepWake() {
        let center = NSWorkspace.shared.notificationCenter

        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPaused = true
            }
        }

        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPaused = false
                NSLog("[Polling] Wake detected, waiting 3s for network/keychain to stabilize...")
                try? await Task.sleep(for: .seconds(3))
                NSLog("[Polling] Refreshing after wake")
                self?.refreshNow()
            }
        }
    }
}
