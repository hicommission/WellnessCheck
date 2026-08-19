import Foundation
import AppKit
import UserNotifications
import Combine

final class WellnessManager: ObservableObject {
    static let shared = WellnessManager()

    @Published var settings: WellnessSettings
    @Published var status: MonitoringStatus = .active
    @Published var lastAlertDate: Date?

    private let monitor = ActivityMonitor.shared
    private var checkTimer: AnyCancellable?
    private var displayTimer: AnyCancellable?
    private var activitySubscription: AnyCancellable?
    private var previousActivityDate: Date

    private init() {
        settings = WellnessStore.loadSettings()
        lastAlertDate = WellnessStore.loadLastAlert()
        previousActivityDate = monitor.lastActivityDate
        requestNotificationPermission()
        startChecking()
        observeActivity()
        log("WellnessManager initialized — status: \(status.rawValue), threshold: \(settings.thresholdHours)h, contacts: \(settings.contacts.count), enabled: \(settings.isEnabled)")
    }

    // MARK: - Periodic Check (every 60 seconds)

    private func startChecking() {
        checkTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.evaluateStatus()
            }

        // 1-second display timer so the menu bar countdown updates live
        displayTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    // MARK: - Observe Activity Changes

    private func observeActivity() {
        activitySubscription = monitor.$lastActivityDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newDate in
                guard let self = self else { return }
                if newDate != self.previousActivityDate {
                    self.previousActivityDate = newDate
                    self.onActivityDetected()
                }
            }
    }

    private func onActivityDetected() {
        monitor.resetSleepAccumulation()
        if status == .warning || status == .alertSent {
            log("Activity detected — status reset from \(status.rawValue) to active")
            status = .active
            lastAlertDate = nil
            WellnessStore.saveLastAlert(nil)
        }
        objectWillChange.send()
    }

    // MARK: - Status Evaluation

    func evaluateStatus() {
        guard settings.isEnabled, status != .paused else { return }
        guard !monitor.isSleeping else { return }

        let inactivity = monitor.inactivityDuration
        let threshold = settings.thresholdSeconds
        let warningThreshold = settings.warningSeconds

        if inactivity >= threshold {
            // Should we send (or re-send) an alert?
            if status != .alertSent || shouldResendAlert() {
                let isResend = status == .alertSent
                log("Threshold reached — inactivity: \(inactivity.formattedDuration), threshold: \(threshold.formattedDuration)\(isResend ? " (resend)" : "")")
                sendAlertEmails()
                status = .alertSent
                lastAlertDate = Date()
                WellnessStore.saveLastAlert(lastAlertDate)
            }
        } else if settings.warningEnabled && inactivity >= warningThreshold {
            if status != .warning && status != .alertSent {
                log("Warning threshold reached — inactivity: \(inactivity.formattedDuration), warning at: \(warningThreshold.formattedDuration)")
                sendWarningNotification()
                status = .warning
            }
        } else {
            status = .active
        }

        objectWillChange.send()
    }

    private func shouldResendAlert() -> Bool {
        guard let lastAlert = lastAlertDate else { return true }
        return Date().timeIntervalSince(lastAlert) >= settings.repeatAlertSeconds
    }

    // MARK: - Alerts

    private func sendAlertEmails() {
        let names = settings.contacts.map(\.name).joined(separator: ", ")
        log("Sending alert to \(settings.contacts.count) contact(s): \(names)")

        // Separate contacts into those with valid emails and those without
        let contactsWithEmail = settings.contacts.filter { !$0.email.isEmpty }
        let contactsWithoutEmail = settings.contacts.filter { $0.email.isEmpty }

        if !contactsWithoutEmail.isEmpty {
            let skipped = contactsWithoutEmail.map(\.name).joined(separator: ", ")
            log("Skipping email for \(contactsWithoutEmail.count) contact(s) with no email: \(skipped)")
        }

        // Send emails only to contacts with valid email addresses
        if !contactsWithEmail.isEmpty {
            if let config = settings.smtpConfig {
                log("Using direct SMTP via Gmail for \(contactsWithEmail.count) contact(s)")
                SMTPHelper.sendWellnessAlert(
                    config: config,
                    to: contactsWithEmail,
                    userName: settings.userName.isEmpty ? "User" : settings.userName,
                    userEmail: settings.userEmail,
                    userPhone: settings.userPhone,
                    userAddress: settings.userAddress,
                    personalMessage: settings.personalMessage,
                    lastActivityDate: monitor.lastActivityDate,
                    inactivityDuration: monitor.inactivityDuration
                )
            } else {
                log("SMTP not configured — falling back to Mail.app for \(contactsWithEmail.count) contact(s)")
                EmailHelper.sendWellnessAlert(
                    to: contactsWithEmail,
                    userName: settings.userName.isEmpty ? "User" : settings.userName,
                    userEmail: settings.userEmail,
                    userPhone: settings.userPhone,
                    userAddress: settings.userAddress,
                    personalMessage: settings.personalMessage,
                    lastActivityDate: monitor.lastActivityDate,
                    inactivityDuration: monitor.inactivityDuration
                )
            }
        } else {
            log("No contacts have email addresses — skipping email alerts entirely")
        }

        // Send iMessages to contacts with phone numbers (includes those without email)
        MessageHelper.sendWellnessAlert(
            to: settings.contacts,
            userName: settings.userName.isEmpty ? "User" : settings.userName,
            userPhone: settings.userPhone,
            userAddress: settings.userAddress,
            lastActivityDate: monitor.lastActivityDate,
            inactivityDuration: monitor.inactivityDuration
        )

        // Also send local notification
        let contactsWithPhone = settings.contacts.filter { !$0.phone.isEmpty }
        let content = UNMutableNotificationContent()
        content.title = "Wellness Alert Sent"
        content.body = "No activity detected for \(monitor.inactivityDuration.formattedDuration). Alert emails sent to \(settings.contacts.count) contact(s), iMessages sent to \(contactsWithPhone.count) contact(s)."
        content.sound = .defaultCritical
        let request = UNNotificationRequest(
            identifier: "wellness-alert-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)

        // Dock bounce
        NSApp.requestUserAttention(.criticalRequest)
    }

    private func sendWarningNotification() {
        log("Warning notification sent — inactivity: \(monitor.inactivityDuration.formattedDuration)")

        let content = UNMutableNotificationContent()
        content.title = "Are you there?"
        content.body = "No activity for \(monitor.inactivityDuration.formattedDuration). Move your mouse or click \"I'm Here\" to confirm you're okay."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "wellness-warning-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)

        // Play gentle sound
        NSSound.beep()
    }

    // MARK: - User Actions

    func confirmPresence() {
        log("User confirmed presence (I'm Here) — resetting from \(status.rawValue) to active")
        monitor.confirmPresence()
        status = .active
        lastAlertDate = nil
        WellnessStore.saveLastAlert(nil)
    }

    func togglePause() {
        if status == .paused {
            log("Monitoring resumed")
            status = .active
            monitor.confirmPresence() // Reset timer when unpausing
        } else {
            log("Monitoring paused")
            status = .paused
        }
    }

    func saveSettings() {
        log("Settings saved — threshold: \(settings.thresholdHours)h, repeat: \(settings.repeatAlertHours)h, contacts: \(settings.contacts.count), enabled: \(settings.isEnabled), userEmail: \(settings.userEmail.isEmpty ? "(none)" : settings.userEmail)")
        WellnessStore.saveSettings(settings)
    }

    // MARK: - Computed Properties

    var inactivityDuration: TimeInterval {
        monitor.inactivityDuration
    }

    var lastActivityDate: Date {
        monitor.lastActivityDate
    }

    var timeUntilWarning: TimeInterval {
        max(settings.warningSeconds - monitor.inactivityDuration, 0)
    }

    var timeUntilAlert: TimeInterval {
        max(settings.thresholdSeconds - monitor.inactivityDuration, 0)
    }

    /// Compact countdown string for the menu bar label
    var menuBarCountdown: String {
        guard settings.isEnabled else { return "" }
        switch status {
        case .paused:
            return ""
        case .active, .warning:
            return timeUntilAlert.compactDuration
        case .alertSent:
            return timeUntilAlert.compactDuration
        }
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .criticalAlert]) { _, _ in }
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [WellnessManager] \(message)"
        print(entry)

        let logFile = Self.logFilePath()
        if let data = (entry + "\n").data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    static func logFilePath() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("WellnessCheck")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("wellness.log")
    }
}
