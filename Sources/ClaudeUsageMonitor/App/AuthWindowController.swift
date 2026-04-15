import AppKit
import SwiftUI
import Combine

@MainActor
final class AuthWindowController {
    static let shared = AuthWindowController()

    private var window: NSWindow?
    private var authCancellable: AnyCancellable?

    private init() {}

    func showSetupWindow(authService: AuthService) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let setupView = SetupView(authService: authService)
            .frame(width: 320)
            .padding()

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Claude Usage Monitor"
        win.contentView = NSHostingView(rootView: setupView)
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = win

        // Auto-close when authentication succeeds
        authCancellable = authService.$isAuthenticated
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                self?.close()
            }
    }

    func close() {
        window?.close()
        window = nil
        authCancellable = nil
    }
}
