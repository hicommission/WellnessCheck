import SwiftUI
import AppKit

/// Pins WellnessCheck to menu-bar-only (`.accessory`) mode for the
/// entire lifetime of the process AND blocks the macOS default of
/// terminating the app when the last window (the Settings window)
/// closes. WellnessCheck is a life-safety app — silently exiting
/// because the user closed Settings is unacceptable; the timer must
/// keep running and the menu-bar status item must stay visible.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Re-assert .accessory on every activation cycle. If something
        // (a sheet, a panel, a system prompt) bumped us to .regular,
        // slam the policy back so the SwiftUI MenuBarExtra status
        // item doesn't get garbage-collected by the macOS 14+
        // policy-flip bug.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillResignActive(_ notification: Notification) {
        // Belt-and-suspenders: also re-pin on resign so we're never
        // briefly .regular at the moment the last window closes.
        NSApp.setActivationPolicy(.accessory)
    }

    /// CRITICAL — without this, macOS' default behavior is to call
    /// NSApp.terminate() the moment the last visible window (the
    /// Settings window, here) closes. The MenuBarExtra status item
    /// disappears with the process and the wellness timer stops. For
    /// a life-safety app this is unacceptable. Returning `false`
    /// keeps the menu-bar-only runtime alive forever after every
    /// window close.
    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }
}

@main
struct WellnessCheckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager = WellnessManager.shared

    var body: some Scene {
        // Menu bar
        MenuBarExtra {
            menuContent
        } label: {
            let countdown = manager.menuBarCountdown
            if countdown.isEmpty {
                Label("WellnessCheck", systemImage: manager.status.menuBarIcon)
            } else {
                HStack(spacing: 2) {
                    Image(systemName: manager.status.menuBarIcon)
                    Text(countdown)
                        .monospacedDigit()
                        .font(.system(size: 12, weight: .medium))
                }
            }
        }

        // Settings window
        Window("WellnessCheck Settings", id: "settings") {
            SettingsView(manager: manager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    @ViewBuilder
    private var menuContent: some View {
        // Status header
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                statusIcon
                Text(manager.status.label)
                    .font(.system(size: 13, weight: .semibold))
            }

            if manager.settings.isEnabled && manager.status != .paused {
                Text("Last activity: \(timeAgo(manager.lastActivityDate))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if manager.status == .active {
                    Text("Alert in: \(manager.timeUntilAlert.formattedDuration)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)

        Divider()

        // I'm Here button
        Button("💚 I'm Here (Reset Timer)") {
            manager.confirmPresence()
        }
        .keyboardShortcut("r")

        // Pause/Resume
        Button(manager.status == .paused ? "▶️ Resume Monitoring" : "⏸️ Pause Monitoring") {
            manager.togglePause()
        }
        .keyboardShortcut("p")

        Divider()

        // Contacts summary
        if manager.settings.contacts.isEmpty {
            Text("⚠️ No emergency contacts configured")
                .foregroundColor(.orange)
        } else {
            Text("📋 \(manager.settings.contacts.count) contact(s) configured")

            ForEach(manager.settings.contacts) { contact in
                HStack {
                    Text("  \(contact.name)")
                        .font(.system(size: 12))
                    Text("(\(contact.relationship))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }

        Divider()

        // Settings
        Button("⚙️ Settings...") {
            openSettingsWindow()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit WellnessCheck") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    // MARK: - Helpers

    @ViewBuilder
    private var statusIcon: some View {
        switch manager.status {
        case .active:
            Image(systemName: "heart.fill")
                .foregroundColor(.green)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
        case .alertSent:
            Image(systemName: "heart.slash.fill")
                .foregroundColor(.red)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundColor(.gray)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        }
        return interval.formattedDuration + " ago"
    }

    private func openSettingsWindow() {
        if let window = NSApp.windows.first(where: { $0.title == "WellnessCheck Settings" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            let view = SettingsView(manager: manager)
            let hostingController = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "WellnessCheck Settings"
            window.setContentSize(NSSize(width: 520, height: 600))
            window.styleMask = [.titled, .closable]
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
}
