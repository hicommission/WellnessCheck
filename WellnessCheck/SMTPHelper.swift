import Foundation
import UserNotifications

/// Sends email directly via Gmail SMTP using curl — no Mail.app dependency.
enum SMTPHelper {

    struct SMTPConfig {
        let senderEmail: String
        let appPassword: String
        let smtpServer: String
        let smtpPort: Int

        static var gmail: (String, String) -> SMTPConfig = { email, password in
            SMTPConfig(
                senderEmail: email,
                appPassword: password.replacingOccurrences(of: " ", with: ""),
                smtpServer: "smtps://smtp.gmail.com",
                smtpPort: 465
            )
        }
    }

    // MARK: - Send Email

    /// Sends an email via SMTP using curl
    static func sendEmail(
        config: SMTPConfig,
        to recipients: [(name: String, email: String)],
        cc: [(name: String, email: String)] = [],
        subject: String,
        body: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard !recipients.isEmpty else {
            log("No recipients -- skipping SMTP send")
            completion(false, "No recipients")
            return
        }

        DispatchQueue.global(qos: .utility).async {
            // Build RFC 2822 email message
            let boundary = UUID().uuidString
            let date = rfc2822Date()

            var toHeader = recipients.map { formatAddress($0.name, $0.email) }.joined(separator: ", ")
            var ccHeader = ""
            if !cc.isEmpty {
                ccHeader = "Cc: \(cc.map { formatAddress($0.name, $0.email) }.joined(separator: ", "))\r\n"
            }

            var message = ""
            message += "From: \(formatAddress("WellnessCheck", config.senderEmail))\r\n"
            message += "To: \(toHeader)\r\n"
            message += ccHeader
            message += "Subject: \(subject)\r\n"
            message += "Date: \(date)\r\n"
            message += "MIME-Version: 1.0\r\n"
            message += "Content-Type: text/html; charset=UTF-8\r\n"
            message += "Content-Transfer-Encoding: 8bit\r\n"
            message += "X-Mailer: WellnessCheck/1.0\r\n"
            message += "\r\n"
            message += body
            message += "\r\n"

            // Write message to temp file (curl reads from file)
            let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("wc-email-\(UUID().uuidString).eml")
            do {
                try message.write(to: tempFile, atomically: true, encoding: .utf8)
            } catch {
                let msg = "Failed to write temp email file: \(error.localizedDescription)"
                log("ERROR: \(msg)")
                DispatchQueue.main.async { completion(false, msg) }
                return
            }

            defer {
                try? FileManager.default.removeItem(at: tempFile)
            }

            // Build curl command
            var curlArgs = [
                "--ssl-reqd",
                "--url", "\(config.smtpServer):\(config.smtpPort)",
                "--user", "\(config.senderEmail):\(config.appPassword)",
                "--mail-from", config.senderEmail
            ]

            // Add all recipients (to + cc)
            for r in recipients {
                curlArgs.append(contentsOf: ["--mail-rcpt", r.email])
            }
            for r in cc {
                curlArgs.append(contentsOf: ["--mail-rcpt", r.email])
            }

            curlArgs.append(contentsOf: [
                "--upload-file", tempFile.path,
                "--silent",
                "--show-error"
            ])

            log("Sending via SMTP to: \(recipients.map(\.email).joined(separator: ", "))\(cc.isEmpty ? "" : " (CC: \(cc.map(\.email).joined(separator: ", ")))")")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            process.arguments = curlArgs

            let stderrPipe = Pipe()
            let stdoutPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = stdoutPipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                let msg = "Failed to launch curl: \(error.localizedDescription)"
                log("ERROR: \(msg)")
                DispatchQueue.main.async { completion(false, msg) }
                return
            }

            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrText = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if process.terminationStatus != 0 {
                let msg = "curl exit code \(process.terminationStatus): \(stderrText)"
                log("ERROR: \(msg)")
                DispatchQueue.main.async { completion(false, msg) }
            } else {
                log("SUCCESS: Email sent via SMTP to \(recipients.map(\.email).joined(separator: ", "))")
                DispatchQueue.main.async { completion(true, nil) }
            }
        }
    }

    // MARK: - Wellness Alert Email

    static func sendWellnessAlert(
        config: SMTPConfig,
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
            log("No contacts configured -- skipping SMTP email")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short

        let lastSeen = dateFormatter.string(from: lastActivityDate)
        let duration = inactivityDuration.formattedDuration
        let name = userName.isEmpty ? "User" : userName

        let subject = "WELLNESS CHECK NEEDED -- \(name)"
        let alertSent = dateFormatter.string(from: Date())

        let body = EmailTemplates.buildAlertHTML(
            name: name,
            alertSent: alertSent,
            duration: duration,
            lastSeen: lastSeen,
            userPhone: userPhone,
            userAddress: userAddress,
            personalMessage: personalMessage,
            contacts: contacts
        )
        // Filter out contacts with empty email addresses to prevent RCPT failures
        let validContacts = contacts.filter { !$0.email.isEmpty }
        guard !validContacts.isEmpty else {
            log("No contacts have valid email addresses -- skipping SMTP send")
            return
        }
        if validContacts.count < contacts.count {
            let skipped = contacts.filter { $0.email.isEmpty }.map(\.name).joined(separator: ", ")
            log("Skipping \(contacts.count - validContacts.count) contact(s) with no email: \(skipped)")
        }
        let recipients = validContacts.map { (name: $0.name, email: $0.email) }
        var cc: [(name: String, email: String)] = []
        if !userEmail.isEmpty {
            cc.append((name: name, email: userEmail))
        }

        sendEmail(config: config, to: recipients, cc: cc, subject: subject, body: body) { success, error in
            if success {
                let names = contacts.map(\.name).joined(separator: ", ")
                notifySuccess("SMTP alert sent to \(names)")
            } else {
                notifyFailure("SMTP email failed: \(error ?? "Unknown")")
            }
        }
    }

    /// Sends a test email via SMTP
    static func sendTestEmail(
        config: SMTPConfig,
        to contact: EmergencyContact,
        userName: String,
        userEmail: String
    ) {
        guard !contact.email.isEmpty else {
            log("Cannot send test email to \(contact.name) -- no email address configured")
            notifyFailure("No email address for \(contact.name)")
            return
        }
        let name = userName.isEmpty ? "User" : userName
        let subject = "WellnessCheck Test -- \(name)"

        let body = EmailTemplates.buildTestHTML(
            name: name,
            contactName: contact.name,
            relationship: contact.relationship
        )

        let recipients = [(name: contact.name, email: contact.email)]
        var cc: [(name: String, email: String)] = []
        if !userEmail.isEmpty {
            cc.append((name: name, email: userEmail))
        }

        sendEmail(config: config, to: recipients, cc: cc, subject: subject, body: body) { success, error in
            if success {
                notifySuccess("SMTP test sent to \(contact.name)")
            } else {
                notifyFailure("SMTP test failed: \(error ?? "Unknown")")
            }
        }
    }

    // MARK: - Helpers

    private static func formatAddress(_ name: String, _ email: String) -> String {
        if name.isEmpty { return email }
        return "\"\(name)\" <\(email)>"
    }

    private static func rfc2822Date() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    // MARK: - Logging

    private static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [SMTPHelper] \(message)"
        print(entry)

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

    // MARK: - Notifications

    private static func notifySuccess(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "WellnessCheck"
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(identifier: "smtp-ok-\(Date().timeIntervalSince1970)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func notifyFailure(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "WellnessCheck SMTP Failed"
        content.body = message
        content.sound = .defaultCritical
        let request = UNNotificationRequest(identifier: "smtp-fail-\(Date().timeIntervalSince1970)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
