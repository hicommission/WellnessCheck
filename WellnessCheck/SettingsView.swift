import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var manager: WellnessManager
    @Environment(\.dismiss) private var dismiss

    @State private var newContactName = ""
    @State private var newContactEmail = ""
    @State private var newContactPhone = ""
    @State private var newContactRelationship = "Family"

    private let relationships = ["Son", "Daughter", "Spouse", "Sibling", "Parent", "Friend", "Neighbor", "Other"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "heart.text.clipboard")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                Text("WellnessCheck Settings")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Personal Info
                    sectionHeader("Your Information")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("Your full name", text: $manager.settings.userName)
                            .textFieldStyle(.roundedBorder)

                        Text("Email (you'll be CC'd on all alerts)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("your@email.com", text: $manager.settings.userEmail)
                            .textFieldStyle(.roundedBorder)

                        Text("Phone")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("Your phone number", text: $manager.settings.userPhone)
                            .textFieldStyle(.roundedBorder)

                        Text("Address (included in alert emails)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("Street, City, State, ZIP", text: $manager.settings.userAddress)
                            .textFieldStyle(.roundedBorder)

                        Text("Personal Message (shown at top of alert email)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextEditor(text: $manager.settings.personalMessage)
                            .font(.system(size: 12))
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading, content: {
                                if manager.settings.personalMessage.isEmpty {
                                    Text("e.g. Hi boys, if you're reading this I may need help. Please try calling me first...")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            })
                    }

                    Divider()

                    // Emergency Contacts
                    sectionHeader("Emergency Contacts")

                    if manager.settings.contacts.isEmpty {
                        Text("No contacts added yet. Add at least one contact below.")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(manager.settings.contacts) { contact in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("\(contact.email) • \(contact.relationship)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    if !contact.phone.isEmpty {
                                        Text("📱 \(contact.phone)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()

                                // Test email button
                                Button(action: {
                                    if let config = manager.settings.smtpConfig {
                                        SMTPHelper.sendTestEmail(
                                            config: config,
                                            to: contact,
                                            userName: manager.settings.userName,
                                            userEmail: manager.settings.userEmail
                                        )
                                    } else {
                                        EmailHelper.sendTestEmail(
                                            to: contact,
                                            userName: manager.settings.userName,
                                            userEmail: manager.settings.userEmail
                                        )
                                    }
                                }) {
                                    Image(systemName: "paperplane")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.bordered)
                                .help("Send test email")

                                // Test iMessage button (only if phone number exists)
                                if !contact.phone.isEmpty {
                                    Button(action: {
                                        MessageHelper.sendTestMessage(
                                            to: contact,
                                            userName: manager.settings.userName
                                        )
                                    }) {
                                        Image(systemName: "message")
                                            .font(.system(size: 11))
                                    }
                                    .buttonStyle(.bordered)
                                    .help("Send test iMessage")
                                }

                                // Remove button
                                Button(action: {
                                    manager.settings.contacts.removeAll { $0.id == contact.id }
                                    manager.saveSettings()
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                        }
                    }

                    // Add new contact
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add Contact")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            TextField("Name", text: $newContactName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 110)

                            TextField("Email", text: $newContactEmail)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)

                            TextField("Phone", text: $newContactPhone)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 110)

                            Picker("", selection: $newContactRelationship) {
                                ForEach(relationships, id: \.self) { r in
                                    Text(r).tag(r)
                                }
                            }
                            .frame(width: 90)
                        }

                        HStack {
                            Spacer()
                            Button("Add Contact") {
                                addContact()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .disabled(newContactName.isEmpty || newContactEmail.isEmpty)
                        }
                    }

                    Divider()

                    // Threshold Settings
                    sectionHeader("Monitoring Settings")

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Inactivity threshold:")
                                .font(.system(size: 12))
                            Spacer()
                            Picker("", selection: $manager.settings.thresholdHours) {
                                Text("1 hour").tag(1.0)
                                Text("6 hours").tag(6.0)
                                Text("12 hours").tag(12.0)
                                Text("18 hours").tag(18.0)
                                Text("24 hours").tag(24.0)
                                Text("36 hours").tag(36.0)
                                Text("48 hours").tag(48.0)
                                Text("1 minute (test)").tag(1.0/60.0)
                            }
                            .frame(width: 160)
                        }

                        HStack {
                            Text("Repeat alert every:")
                                .font(.system(size: 12))
                            Spacer()
                            Picker("", selection: $manager.settings.repeatAlertHours) {
                                Text("1 hour").tag(1.0)
                                Text("3 hours").tag(3.0)
                                Text("6 hours").tag(6.0)
                                Text("12 hours").tag(12.0)
                            }
                            .frame(width: 160)
                        }

                        Toggle("Show warning at 50% of threshold", isOn: $manager.settings.warningEnabled)
                            .font(.system(size: 12))

                        Toggle("Monitoring enabled", isOn: $manager.settings.isEnabled)
                            .font(.system(size: 12))
                    }

                    Divider()

                    // SMTP Settings
                    sectionHeader("Email Delivery (Gmail SMTP)")

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Use direct Gmail SMTP (recommended)", isOn: $manager.settings.useDirectSMTP)
                            .font(.system(size: 12, weight: .semibold))

                        if manager.settings.useDirectSMTP {
                            Text("Gmail Address")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextField("yourname@gmail.com", text: $manager.settings.smtpEmail)
                                .textFieldStyle(.roundedBorder)

                            Text("App Password (16 characters from Google)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            SecureField("xxxx xxxx xxxx xxxx", text: $manager.settings.smtpAppPassword)
                                .textFieldStyle(.roundedBorder)

                            if manager.settings.smtpConfig != nil {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("SMTP configured")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                            } else if !manager.settings.smtpEmail.isEmpty || !manager.settings.smtpAppPassword.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Enter both Gmail address and App Password")
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange)
                                }
                            }

                            Text("Sends email directly through Gmail servers. No Mail.app needed. Get an App Password at: Google Account > Security > 2-Step Verification > App passwords")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Falling back to Mail.app (less reliable)")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    }

                    Divider()

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How it works")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("WellnessCheck monitors your mouse and keyboard activity. If no activity is detected for the configured period, an alert email is automatically sent to all your emergency contacts asking them to check on you.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Sleep time is excluded — closing your laptop overnight won't trigger a false alarm.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                .padding(16)
            }

            // Bottom bar
            HStack(spacing: 10) {
                Button("Export Config") {
                    exportConfig()
                }
                .buttonStyle(.bordered)

                Button("Load Config") {
                    importConfig()
                }
                .buttonStyle(.bordered)

                Button("View Logs") {
                    openLogs()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save & Close") {
                    manager.saveSettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 580, height: 650)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.primary)
    }

    private func addContact() {
        let contact = EmergencyContact(
            name: newContactName.trimmingCharacters(in: .whitespaces),
            email: newContactEmail.trimmingCharacters(in: .whitespaces),
            phone: newContactPhone.trimmingCharacters(in: .whitespaces),
            relationship: newContactRelationship
        )
        manager.settings.contacts.append(contact)
        manager.saveSettings()
        newContactName = ""
        newContactEmail = ""
        newContactPhone = ""
    }

    private func exportConfig() {
        manager.saveSettings()
        let panel = NSSavePanel()
        panel.title = "Export WellnessCheck Config"
        panel.nameFieldStringValue = "WellnessCheck-config.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try WellnessStore.exportSettings(manager.settings, to: url)
                NSSound.beep()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.title = "Load WellnessCheck Config"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let loaded = try WellnessStore.importSettings(from: url)
                manager.settings = loaded
                manager.saveSettings()
                NSSound.beep()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Import Failed"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    private func openLogs() {
        let logDir = WellnessStore.defaultConfigDir()
        NSWorkspace.shared.open(logDir)
    }
}
