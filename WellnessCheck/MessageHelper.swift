import Foundation
import AppKit
import UserNotifications

enum MessageHelper {
    /// Sends an iMessage wellness alert to all contacts with phone numbers
    static func sendWellnessAlert(
        to contacts: [EmergencyContact],
        userName: String,
        userPhone: String,
        userAddress: String,
        lastActivityDate: Date,
        inactivityDuration: TimeInterval
    ) {
        let contactsWithPhone = contacts.filter { !$0.phone.isEmpty }
        guard !contactsWithPhone.isEmpty else {
            log("No contacts with phone numbers -- skipping iMessage")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short

        let lastSeen = dateFormatter.string(from: lastActivityDate)
        let duration = inactivityDuration.formattedDuration
        let name = userName.isEmpty ? "User" : userName

        let alertSent = dateFormatter.string(from: Date())

        var messageLines = [
            "WELLNESS CHECK NEEDED -- \(name)",
            "",
            "ALERT SENT: \(alertSent)",
            "",
            "No computer activity detected for \(duration).",
            "Last activity: \(lastSeen)"
        ]
        if !userPhone.isEmpty {
            messageLines.append("Phone: \(userPhone)")
        }
        if !userAddress.isEmpty {
            messageLines.append("Address: \(userAddress)")
        }
        messageLines.append("")
        messageLines.append("Please check on \(name) to make sure they are okay.")
        messageLines.append("")
        messageLines.append("-- WellnessCheck (automated)")

        let message = messageLines.joined(separator: "\n")

        log("Sending iMessage alert to \(contactsWithPhone.count) contact(s)...")

        for contact in contactsWithPhone {
            sendMessage(message, to: contact.phone, contactName: contact.name)
        }
    }

    /// Sends a test iMessage to verify configuration
    static func sendTestMessage(to contact: EmergencyContact, userName: String) {
        guard !contact.phone.isEmpty else {
            log("No phone number for \(contact.name) -- skipping test message")
            notifyFailure("No phone number for \(contact.name)")
            return
        }

        let name = userName.isEmpty ? "User" : userName
        let message = "This is a test message from WellnessCheck. If \(name) becomes inactive for an extended period, you will receive an alert asking you to check on him. You are listed as an emergency contact (\(contact.relationship)). -- WellnessCheck"

        log("Sending test iMessage to \(contact.name) at \(contact.phone)...")
        sendMessage(message, to: contact.phone, contactName: contact.name)
    }

    // MARK: - iMessage via osascript

    private static func sendMessage(_ message: String, to phoneNumber: String, contactName: String) {
        let escapedMessage = escapeForAppleScript(message)
        let escapedPhone = escapeForAppleScript(phoneNumber)

        // Use Messages app via AppleScript
        let script = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(escapedPhone)" of targetService
            send "\(escapedMessage)" to targetBuddy
        end tell
        """

        log("AppleScript (Messages):\n\(script)")

        DispatchQueue.global(qos: .utility).async {
            let result = runOsascript(script)

            DispatchQueue.main.async {
                if result.success {
                    log("SUCCESS: iMessage sent to \(contactName) (\(phoneNumber))")
                    notifySuccess("iMessage sent to \(contactName)")
                } else {
                    let errorMsg = result.error ?? "Unknown error"
                    log("ERROR sending iMessage to \(contactName): \(errorMsg)")

                    // Try fallback with SMS buddy format
                    log("Trying fallback SMS format for \(contactName)...")
                    sendMessageFallback(escapedMessage, to: escapedPhone, contactName: contactName, phoneNumber: phoneNumber)
                }
            }
        }
    }

    /// Fallback: try sending via a simpler buddy lookup
    private static func sendMessageFallback(_ escapedMessage: String, to escapedPhone: String, contactName: String, phoneNumber: String) {
        let script = """
        tell application "Messages"
            send "\(escapedMessage)" to buddy "\(escapedPhone)" of (1st account whose service type = iMessage)
        end tell
        """

        log("Fallback AppleScript:\n\(script)")

        DispatchQueue.global(qos: .utility).async {
            let result = runOsascript(script)

            DispatchQueue.main.async {
                if result.success {
                    log("SUCCESS (fallback): iMessage sent to \(contactName) (\(phoneNumber))")
                    notifySuccess("iMessage sent to \(contactName)")
                } else {
                    let errorMsg = result.error ?? "Unknown error"
                    log("ERROR (fallback) sending iMessage to \(contactName): \(errorMsg)")
                    notifyFailure("iMessage to \(contactName) failed: \(errorMsg)")
                }
            }
        }
    }

    // MARK: - osascript Execution

    private static func runOsascript(_ script: String) -> (success: Bool, error: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (false, "Failed to launch osascript: \(error.localizedDescription)")
        }

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 {
            return (false, "osascript exit code \(process.terminationStatus): \(stderrText)")
        }

        return (true, nil)
    }

    // MARK: - Logging

    private static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [MessageHelper] \(message)"
        print(entry)

        // Log to the shared wellness log
        let logFile = WellnessManager.logFilePath()
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

    // MARK: - User Notifications

    private static func notifyFailure(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "WellnessCheck iMessage Failed"
        content.body = message + "\nCheck: System Settings > Privacy > Automation > WellnessCheck > Messages"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "wc-msg-fail-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func notifySuccess(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "WellnessCheck"
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "wc-msg-ok-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    private static func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
