import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var pollingService: PollingService

    @AppStorage("refreshInterval") private var refreshInterval: Double = Constants.defaultRefreshInterval
    @AppStorage("showPercentageInMenuBar") private var showPercentage = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            accountTab
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
        }
        .frame(width: 360, height: 220)
    }

    private var generalTab: some View {
        Form {
            Picker("Refresh interval", selection: $refreshInterval) {
                Text("2 minutes").tag(120.0)
                Text("5 minutes").tag(300.0)
                Text("15 minutes").tag(900.0)
                Text("30 minutes").tag(1800.0)
            }
            .font(DS.Font.body)
            .onChange(of: refreshInterval) { _, newValue in
                pollingService.refreshInterval = newValue
            }

            Toggle("Show percentage in menu bar", isOn: $showPercentage)
                .font(DS.Font.body)

            Toggle("Launch at login", isOn: $launchAtLogin)
                .font(DS.Font.body)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {}
                }
        }
        .padding()
    }

    private var accountTab: some View {
        VStack(spacing: DS.Space._4) {
            if authService.isAuthenticated {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(DS.Color.usage(0))

                Text("Signed in")
                    .font(DS.Font.h2)

                if let method = authService.authMethod {
                    Text("via \(method == .claudeCode ? "Claude Code" : "Session Cookie")")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondary)
                }

                Button("Sign Out", role: .destructive) {
                    authService.logout()
                }
                .font(DS.Font.button)
            } else {
                Image(systemName: "person.crop.circle.badge.xmark")
                    .font(.system(size: 24))
                    .foregroundStyle(DS.Color.secondary)

                Text("Not signed in")
                    .font(DS.Font.h2)

                Button("Sign In") {
                    authService.connectClaudeCode()
                }
                .font(DS.Font.button)
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
