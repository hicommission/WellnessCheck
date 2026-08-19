import Foundation
import AppKit
import UserNotifications

enum EmailHelper {
    /// Sends a wellness check alert email to multiple recipients via osascript and Mail.app
    static func sendWellnessAlert(
        to contacts: [EmergencyContact],
        userName: String,
        userEmail: String,
        userPhone: String,
        userAddress: String,
        personalMessage: String,
        lastActivityDate: Date,
        inactivityDuration: TimeInterval
    ) {
        guard !contacts.isEmpty else {
            log("No contacts configured -- skipping email")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short

        let lastSeen = dateFormatter.string(from: lastActivityDate)
        let duration = inactivityDuration.formattedDuration
        let name = userName.isEmpty ? "User" : userName

        let subject = "Wellness Check Needed -- \(name)"
        let alertSent = dateFormatter.string(from: Date())

        let htmlBody = EmailTemplates.buildAlertHTML(
            name: name,
            alertSent: alertSent,
            duration: duration,
            lastSeen: lastSeen,
            userPhone: userPhone,
            userAddress: userAddress,
            personalMessage: personalMessage,
            contacts: contacts
        )

        // Filter out contacts with no email address to prevent AppleScript failures
        let validContacts = contacts.filter { !$0.email.isEmpty }
        guard !validContacts.isEmpty else {
            log("No contacts have valid email addresses -- skipping Mail.app send")
            return
        }
        if validContacts.count < contacts.count {
            let skipped = contacts.filter { $0.email.isEmpty }.map(\.name).joined(separator: ", ")
            log("Skipping \(contacts.count - validContacts.count) contact(s) with no email: \(skipped)")
        }

        // Build AppleScript with multiple recipients + CC to self
        var recipientLines: [String] = []
        for contact in validContacts {
            let escapedName = escapeForAppleScript(contact.name)
            let escapedEmail = escapeForAppleScript(contact.email)
            recipientLines.append("make new to recipient at end of to recipients with properties {name:\"\(escapedName)\", address:\"\(escapedEmail)\"}")
        }

        // CC the user on all alerts
        if !userEmail.isEmpty {
            let escapedUserName = escapeForAppleScript(name)
            let escapedUserEmail = escapeForAppleScript(userEmail)
            recipientLines.append("make new cc recipient at end of cc recipients with properties {name:\"\(escapedUserName)\", address:\"\(escapedUserEmail)\"}")
        }

        let escapedSubject = escapeForAppleScript(subject)
        let escapedBody = escapeForAppleScript(htmlBody)

        let script = """
        tell application "Mail"
            set newMessage to make new outgoing message with properties {subject:"\(escapedSubject)", visible:false}
            set html content of newMessage to "\(escapedBody)"
            tell newMessage
                \(recipientLines.joined(separator: "\n            "))
            end tell
            send newMessage
        end tell
        """

        log("Attempting to send wellness alert to \(contacts.count) contact(s)...")
        log("AppleScript:\n\(script)")

        DispatchQueue.global(qos: .utility).async {
            let result = runOsascript(script)

            DispatchQueue.main.async {
                if result.success {
                    let names = contacts.map(\.name).joined(separator: ", ")
                    log("SUCCESS: Alert email sent to: \(names)")
                    notifySuccess("Alert sent to \(names)")
                } else {
                    let errorMsg = result.error ?? "Unknown error"
                    log("ERROR: \(errorMsg)")
                    notifyFailure("Email failed: \(errorMsg)")
                }
            }
        }
    }

    /// Sends a test email to verify configuration
    static func sendTestEmail(to contact: EmergencyContact, userName: String, userEmail: String) {
        guard !contact.email.isEmpty else {
            log("Cannot send test email to \(contact.name) -- no email address configured")
            notifyFailure("No email address for \(contact.name)")
            return
        }
        let name = userName.isEmpty ? "User" : userName
        let subject = "WellnessCheck Test -- \(name)"

        let htmlBody = EmailTemplates.buildTestHTML(
            name: name,
            contactName: contact.name,
            relationship: contact.relationship
        )

        let escapedSubject = escapeForAppleScript(subject)
        let escapedBody = escapeForAppleScript(htmlBody)
        let escapedName = escapeForAppleScript(contact.name)
        let escapedEmail = escapeForAppleScript(contact.email)

        var ccLine = ""
        if !userEmail.isEmpty {
            let escapedUserName = escapeForAppleScript(name)
            let escapedUserEmail = escapeForAppleScript(userEmail)
            ccLine = "\n            make new cc recipient at end of cc recipients with properties {name:\"\(escapedUserName)\", address:\"\(escapedUserEmail)\"}"
        }

        let script = """
        tell application "Mail"
            set newMessage to make new outgoing message with properties {subject:"\(escapedSubject)", visible:false}
            set html content of newMessage to "\(escapedBody)"
            tell newMessage
                make new to recipient at end of to recipients with properties {name:"\(escapedName)", address:"\(escapedEmail)"}\(ccLine)
            end tell
            send newMessage
        end tell
        """

        log("Sending test email to \(contact.email)...")
        log("AppleScript:\n\(script)")

        DispatchQueue.global(qos: .utility).async {
            let result = runOsascript(script)

            DispatchQueue.main.async {
                if result.success {
                    log("SUCCESS: Test email sent to \(contact.email)")
                    notifySuccess("Test email sent to \(contact.name)")
                } else {
                    let errorMsg = result.error ?? "Unknown error"
                    log("ERROR: \(errorMsg)")
                    notifyFailure("Test email failed: \(errorMsg)")
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
        let entry = "[\(timestamp)] [WellnessCheck] \(message)"
        print(entry)

        let logFile = logFilePath()
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
        return dir.appendingPathComponent("email.log")
    }

    // MARK: - User Notifications

    private static func notifyFailure(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "WellnessCheck Email Failed"
        content.body = message + "\nCheck: System Settings > Privacy > Automation > WellnessCheck > Mail"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "wc-email-fail-\(Date().timeIntervalSince1970)",
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
            identifier: "wc-email-ok-\(Date().timeIntervalSince1970)",
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
