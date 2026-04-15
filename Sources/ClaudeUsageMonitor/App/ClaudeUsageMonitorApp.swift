import SwiftUI

@main
struct ClaudeUsageMonitorApp: App {
    @StateObject private var authService: AuthService
    @StateObject private var usageService: UsageService
    @StateObject private var pollingService: PollingService

    init() {
        let auth = AuthService()
        let usage = UsageService(authService: auth)
        let polling = PollingService(usageService: usage, authService: auth)
        _authService = StateObject(wrappedValue: auth)
        _usageService = StateObject(wrappedValue: usage)
        _pollingService = StateObject(wrappedValue: polling)
        // PollingService observes AuthService.$isAuthenticated and starts itself
        // when auth is active (initial value fires immediately on subscription).

        NotificationService.shared.requestPermission()
        NotificationService.shared.onAuthNotificationTapped = {
            AuthWindowController.shared.showSetupWindow(authService: auth)
        }

        // Show setup window on launch if not authenticated
        if !auth.isAuthenticated {
            DispatchQueue.main.async {
                AuthWindowController.shared.showSetupWindow(authService: auth)
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
