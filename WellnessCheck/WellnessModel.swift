import Foundation

// MARK: - Emergency Contact

struct EmergencyContact: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var email: String
    var phone: String
    var relationship: String

    init(name: String, email: String, phone: String = "", relationship: String) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.phone = phone
        self.relationship = relationship
    }
}

// MARK: - Wellness Settings

struct WellnessSettings: Codable {
    var userName: String
    var userEmail: String
    var userPhone: String
    var userAddress: String
    var personalMessage: String
    var contacts: [EmergencyContact]
    var thresholdHours: Double
    var warningEnabled: Bool
    var repeatAlertHours: Double
    var isEnabled: Bool

    // SMTP settings (Gmail direct send)
    var smtpEmail: String
    var smtpAppPassword: String
    var useDirectSMTP: Bool

    // Resilient decoding — new fields get defaults so adding fields never wipes data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userName = (try? container.decode(String.self, forKey: .userName)) ?? ""
        userEmail = (try? container.decode(String.self, forKey: .userEmail)) ?? ""
        userPhone = (try? container.decode(String.self, forKey: .userPhone)) ?? ""
        userAddress = (try? container.decode(String.self, forKey: .userAddress)) ?? ""
        personalMessage = (try? container.decode(String.self, forKey: .personalMessage)) ?? ""
        contacts = (try? container.decode([EmergencyContact].self, forKey: .contacts)) ?? []
        thresholdHours = (try? container.decode(Double.self, forKey: .thresholdHours)) ?? 24
        warningEnabled = (try? container.decode(Bool.self, forKey: .warningEnabled)) ?? true
        repeatAlertHours = (try? container.decode(Double.self, forKey: .repeatAlertHours)) ?? 6
        isEnabled = (try? container.decode(Bool.self, forKey: .isEnabled)) ?? true
        smtpEmail = (try? container.decode(String.self, forKey: .smtpEmail)) ?? ""
        smtpAppPassword = (try? container.decode(String.self, forKey: .smtpAppPassword)) ?? ""
        useDirectSMTP = (try? container.decode(Bool.self, forKey: .useDirectSMTP)) ?? true
    }

    init(
        userName: String,
        userEmail: String,
        userPhone: String,
        userAddress: String,
        personalMessage: String,
        contacts: [EmergencyContact],
        thresholdHours: Double,
        warningEnabled: Bool,
        repeatAlertHours: Double,
        isEnabled: Bool,
        smtpEmail: String = "",
        smtpAppPassword: String = "",
        useDirectSMTP: Bool = true
    ) {
        self.userName = userName
        self.userEmail = userEmail
        self.userPhone = userPhone
        self.userAddress = userAddress
        self.personalMessage = personalMessage
        self.contacts = contacts
        self.thresholdHours = thresholdHours
        self.warningEnabled = warningEnabled
        self.repeatAlertHours = repeatAlertHours
        self.isEnabled = isEnabled
        self.smtpEmail = smtpEmail
        self.smtpAppPassword = smtpAppPassword
        self.useDirectSMTP = useDirectSMTP
    }

    /// Returns an SMTP config if credentials are set
    var smtpConfig: SMTPHelper.SMTPConfig? {
        guard useDirectSMTP, !smtpEmail.isEmpty, !smtpAppPassword.isEmpty else { return nil }
        return SMTPHelper.SMTPConfig.gmail(smtpEmail, smtpAppPassword)
    }

    static var `default`: WellnessSettings {
        WellnessSettings(
            userName: "",
            userEmail: "",
            userPhone: "",
            userAddress: "",
            personalMessage: "",
            contacts: [],
            thresholdHours: 24,
            warningEnabled: true,
            repeatAlertHours: 6,
            isEnabled: true
        )
    }

    var thresholdSeconds: TimeInterval {
        thresholdHours * 3600
    }

    var warningSeconds: TimeInterval {
        thresholdSeconds * 0.5
    }

    var repeatAlertSeconds: TimeInterval {
        repeatAlertHours * 3600
    }
}

// MARK: - Monitoring State

enum MonitoringStatus: String {
    case active = "active"         // 🟢 Recent activity
    case warning = "warning"       // 🟡 Past 50% threshold
    case alertSent = "alertSent"   // 🔴 Emails dispatched
    case paused = "paused"         // ⏸️ Temporarily disabled

    var icon: String {
        switch self {
        case .active: return "heart.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .alertSent: return "heart.slash.fill"
        case .paused: return "pause.circle.fill"
        }
    }

    var menuBarIcon: String {
        switch self {
        case .active: return "heart.fill"
        case .warning: return "heart.text.clipboard"
        case .alertSent: return "heart.slash.fill"
        case .paused: return "pause.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .active: return "Active"
        case .warning: return "Warning — No activity detected"
        case .alertSent: return "Alert Sent"
        case .paused: return "Paused"
        }
    }
}

// MARK: - Persistence

final class WellnessStore {
    private static let settingsKey = "com.hicommission.wellnesscheck.settings"
    private static let lastActivityKey = "com.hicommission.wellnesscheck.lastActivity"
    private static let lastAlertKey = "com.hicommission.wellnesscheck.lastAlert"

    static func saveSettings(_ settings: WellnessSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    static func loadSettings() -> WellnessSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(WellnessSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    static func saveLastActivity(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastActivityKey)
    }

    static func loadLastActivity() -> Date {
        UserDefaults.standard.object(forKey: lastActivityKey) as? Date ?? Date()
    }

    static func saveLastAlert(_ date: Date?) {
        UserDefaults.standard.set(date, forKey: lastAlertKey)
    }

    static func loadLastAlert() -> Date? {
        UserDefaults.standard.object(forKey: lastAlertKey) as? Date
    }

    // MARK: - Export / Import Config

    static func exportSettings(_ settings: WellnessSettings, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: url)
    }

    static func importSettings(from url: URL) throws -> WellnessSettings {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WellnessSettings.self, from: data)
    }

    static func defaultConfigDir() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("WellnessCheck")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

// MARK: - Formatting Helpers

extension TimeInterval {
    var formattedDuration: String {
        let absInterval = abs(self)
        let days = Int(absInterval) / 86400
        let hours = (Int(absInterval) % 86400) / 3600
        let minutes = (Int(absInterval) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Ultra-compact format for the menu bar (2–6 chars, e.g. "1d11h", "11h59m",
    /// "59m", "45s"). Kept as short as possible so the status item is less likely
    /// to be hidden by macOS when the menu bar is crowded near the notch. It also
    /// only redraws each minute (not each second) except in the final minute.
    /// Full precision is still shown in the dropdown ("Alert in: …") via
    /// formattedDuration.
    var compactDuration: String {
        let absInterval = abs(self)
        let days = Int(absInterval) / 86400
        let hours = (Int(absInterval) % 86400) / 3600
        let minutes = (Int(absInterval) % 3600) / 60
        let seconds = Int(absInterval) % 60

        if days > 0 {
            return "\(days)d\(hours)h"        // e.g. 1d11h
        } else if hours > 0 {
            return "\(hours)h\(minutes)m"     // e.g. 11h59m
        } else if minutes > 0 {
            return "\(minutes)m"              // e.g. 59m
        } else {
            return "\(seconds)s"              // e.g. 45s
        }
    }
}
