import SwiftUI

@main
struct ClaudeUsageMonitorApp: App {
    @StateObject private var authService: AuthService
    @StateObject private var usageService: UsageService
    @StateObject private var pollingService: PollingService

    init() {
        let auth = AuthService()
        let usage = UsageService(authService: auth)
        let polling = PollingService(usageService: usage)
        _authService = StateObject(wrappedValue: auth)
        _usageService = StateObject(wrappedValue: usage)
        _pollingService = StateObject(wrappedValue: polling)

        // Schedule polling start after app is fully initialized
        // DispatchQueue.main.async runs after init() completes and the run loop starts
        if auth.isAuthenticated {
            DispatchQueue.main.async {
                polling.start()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(
                authService: authService,
                usageService: usageService,
                pollingService: pollingService
            )
            .frame(width: 320)
            .onChange(of: authService.isAuthenticated) { _, isAuth in
                if isAuth {
                    pollingService.start()
                } else {
                    pollingService.stop()
                    // Clear stale data so the menu bar icon resets to "--%"
                    usageService.usage = nil
                    usageService.userInfo = nil
                    usageService.lastUpdated = nil
                    usageService.error = nil
                }
            }
        } label: {
            Image(nsImage: MenuBarIconRenderer.render(
                percentage: usageService.usage?.primaryBucket?.utilization
            ))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                authService: authService,
                pollingService: pollingService
            )
        }
    }
}
