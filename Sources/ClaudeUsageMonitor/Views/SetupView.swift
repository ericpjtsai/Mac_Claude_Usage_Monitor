import SwiftUI

struct SetupView: View {
    @ObservedObject var authService: AuthService
    @State private var sessionKey = ""
    @State private var orgId = ""
    @State private var showCookieForm = false
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: DS.Space._4) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 32))
                .foregroundStyle(DS.Color.accent)

            Text(Constants.appName)
                .font(DS.Font.h1)

            Text("Monitor your Claude plan usage from the menu bar.")
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                isConnecting = true
                // Delay slightly so the UI updates before the synchronous keychain call
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    authService.connectClaudeCode()
                    isConnecting = false
                }
            }) {
                HStack(spacing: DS.Space._2) {
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "terminal")
                    }
                    Text(isConnecting ? "Connecting..." : "Connect via Claude Code")
                }
                .font(DS.Font.button)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isConnecting)

            Text("Requires Claude Code installed and signed in")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.muted)

            Divider()

            if showCookieForm {
                cookieForm
            } else {
                Button(action: { showCookieForm = true }) {
                    HStack(spacing: DS.Space._2) {
                        Image(systemName: "key")
                        Text("Use Session Cookie Instead")
                    }
                    .font(DS.Font.button)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if let error = authService.authError {
                ScrollView {
                    Text(error)
                        .font(DS.Font.error)
                        .foregroundStyle(DS.Color.destructive)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxHeight: 80)
            }

            Divider()

            Button(action: { NSApp.terminate(nil) }) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
            .font(DS.Font.button)
            .foregroundStyle(DS.Color.muted)
        }
        .padding(DS.Space._6)
    }

    private var cookieForm: some View {
        VStack(spacing: DS.Space._2) {
            Text("Paste from browser DevTools:")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.secondary)

            TextField("sessionKey (sk-ant-sid01-...)", text: $sessionKey)
                .textFieldStyle(.roundedBorder)
                .font(DS.Font.body)

            TextField("Organization ID", text: $orgId)
                .textFieldStyle(.roundedBorder)
                .font(DS.Font.body)

            Button(action: {
                authService.connectSessionCookie(sessionKey: sessionKey, orgId: orgId)
            }) {
                Text("Connect")
                    .font(DS.Font.button)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(sessionKey.isEmpty || orgId.isEmpty)

            Button("How to get these values?") {
                NSWorkspace.shared.open(URL(string: "https://claude.ai")!)
            }
            .buttonStyle(.borderless)
            .font(DS.Font.caption)
        }
    }
}
