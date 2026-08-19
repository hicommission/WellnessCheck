import Foundation

/// HTML email templates for WellnessCheck — crisp white background, bold red banner.
enum EmailTemplates {

    // MARK: - Wellness Alert HTML

    static func buildAlertHTML(
        name: String,
        alertSent: String,
        duration: String,
        lastSeen: String,
        userPhone: String,
        userAddress: String,
        personalMessage: String,
        contacts: [EmergencyContact]
    ) -> String {
        // Personal message block
        var personalBlock = ""
        if !personalMessage.isEmpty {
            let escaped = esc(personalMessage)
            personalBlock = """
                        <tr>
                          <td style="padding:24px 32px 0 32px;background-color:#FFFFFF;">
                            <p style="margin:0 0 12px 0;font-size:15px;color:#333333;line-height:1.5;font-style:italic;">\(escaped)</p>
                            <hr style="border:none;border-top:1px solid #EEEEEE;margin:0;">
                          </td>
                        </tr>
            """
        }

        // Phone / Address rows
        var contactInfo = ""
        if !userPhone.isEmpty {
            contactInfo += """
                              <tr>
                                <td style="padding:4px 0;color:#555555;font-size:14px;width:90px;vertical-align:top;font-weight:600;">Phone:</td>
                                <td style="padding:4px 0;color:#333333;font-size:14px;">\(esc(userPhone))</td>
                              </tr>
            """
        }
        if !userAddress.isEmpty {
            contactInfo += """
                              <tr>
                                <td style="padding:4px 0;color:#555555;font-size:14px;width:90px;vertical-align:top;font-weight:600;">Address:</td>
                                <td style="padding:4px 0;color:#333333;font-size:14px;">\(esc(userAddress))</td>
                              </tr>
            """
        }

        var contactInfoSection = ""
        if !contactInfo.isEmpty {
            contactInfoSection = """
                            <table cellpadding="0" cellspacing="0" style="margin-top:8px;">
                              \(contactInfo)
                            </table>
            """
        }

        // Emergency contacts list
        var contactsSection = ""
        if contacts.contains(where: { !$0.phone.isEmpty }) {
            var rows = ""
            for c in contacts {
                let phone = c.phone.isEmpty ? "" : "<br><span style=\"color:#888888;font-size:12px;\">\(esc(c.phone))</span>"
                rows += """
                                <tr>
                                  <td style="padding:8px 12px;border-bottom:1px solid #F0F0F0;font-size:14px;color:#333333;">
                                    <strong>\(esc(c.name))</strong>
                                    <span style="color:#888888;font-size:12px;margin-left:4px;">(\(esc(c.relationship)))</span>
                                  </td>
                                  <td style="padding:8px 12px;border-bottom:1px solid #F0F0F0;font-size:13px;color:#555555;">
                                    \(esc(c.email))\(phone)
                                  </td>
                                </tr>
                """
            }

            contactsSection = """
                            <p style="margin:20px 0 8px 0;font-size:13px;color:#777777;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;">Emergency Contacts Notified</p>
                            <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #EEEEEE;border-radius:6px;overflow:hidden;">
                              \(rows)
                            </table>
            """
        }

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>WellnessCheck Alert</title>
        </head>
        <body style="margin:0;padding:0;background-color:#F2F2F7;font-family:-apple-system,'Helvetica Neue',Arial,sans-serif;">
          <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#F2F2F7;">
            <tr>
              <td align="center" style="padding:32px 16px;">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color:#FFFFFF;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08);max-width:600px;width:100%;">

                  <!-- RED BANNER -->
                  <tr>
                    <td style="background-color:#CC0000;padding:28px 32px;text-align:center;">
                      <h1 style="margin:0;color:#FFFFFF;font-size:24px;font-weight:800;letter-spacing:1px;">WELLNESS CHECK ALERT</h1>
                    </td>
                  </tr>

        \(personalBlock)

                  <!-- MAIN CONTENT -->
                  <tr>
                    <td style="padding:28px 32px;background-color:#FFFFFF;">

                      <!-- Alert timestamp -->
                      <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#FFF5F5;border-left:4px solid #CC0000;border-radius:0 6px 6px 0;margin-bottom:20px;">
                        <tr>
                          <td style="padding:14px 18px;">
                            <p style="margin:0;font-size:13px;color:#CC0000;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;">Alert Sent</p>
                            <p style="margin:4px 0 0 0;font-size:16px;color:#333333;font-weight:700;">\(esc(alertSent))</p>
                          </td>
                        </tr>
                      </table>

                      <!-- Inactivity message -->
                      <p style="margin:0 0 16px 0;font-size:16px;color:#333333;line-height:1.6;">
                        No computer activity has been detected for <strong>\(esc(name))</strong> in the last <strong>\(esc(duration))</strong>.
                      </p>

                      <!-- Last activity -->
                      <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#F8F8FA;border-radius:8px;margin-bottom:16px;">
                        <tr>
                          <td style="padding:14px 18px;">
                            <p style="margin:0;font-size:12px;color:#888888;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;">Last Activity</p>
                            <p style="margin:4px 0 0 0;font-size:15px;color:#333333;font-weight:600;">\(esc(lastSeen))</p>
                          </td>
                        </tr>
                      </table>

        \(contactInfoSection)

                      <!-- Call to action -->
                      <table width="100%" cellpadding="0" cellspacing="0" style="margin-top:24px;">
                        <tr>
                          <td align="center">
                            <table cellpadding="0" cellspacing="0" style="background-color:#CC0000;border-radius:8px;">
                              <tr>
                                <td style="padding:14px 36px;">
                                  <p style="margin:0;color:#FFFFFF;font-size:16px;font-weight:700;text-align:center;">Please check on \(esc(name))</p>
                                </td>
                              </tr>
                            </table>
                          </td>
                        </tr>
                      </table>

        \(contactsSection)

        \(localResourcesHTML)

                    </td>
                  </tr>

                  <!-- FOOTER -->
                  <tr>
                    <td style="padding:20px 32px;background-color:#F8F8FA;border-top:1px solid #EEEEEE;text-align:center;">
                      <p style="margin:0 0 4px 0;font-size:13px;color:#888888;font-weight:600;">WellnessCheck</p>
                      <p style="margin:0 0 8px 0;font-size:11px;color:#AAAAAA;">by HiCommission</p>
                      <p style="margin:0;font-size:11px;color:#BBBBBB;line-height:1.4;">
                        This is an automated message. If \(esc(name)) is fine, they can dismiss this alert by using their computer or clicking &ldquo;I&rsquo;m Here&rdquo; in the app.
                      </p>
                    </td>
                  </tr>

                </table>
              </td>
            </tr>
          </table>
        </body>
        </html>
        """
    }

    // MARK: - Test Email HTML

    static func buildTestHTML(
        name: String,
        contactName: String,
        relationship: String
    ) -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>WellnessCheck Test</title>
        </head>
        <body style="margin:0;padding:0;background-color:#F2F2F7;font-family:-apple-system,'Helvetica Neue',Arial,sans-serif;">
          <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#F2F2F7;">
            <tr>
              <td align="center" style="padding:32px 16px;">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color:#FFFFFF;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08);max-width:600px;width:100%;">

                  <!-- RED BANNER -->
                  <tr>
                    <td style="background-color:#CC0000;padding:24px 32px;text-align:center;">
                      <h1 style="margin:0;color:#FFFFFF;font-size:22px;font-weight:800;letter-spacing:1px;">WELLNESSCHECK TEST</h1>
                    </td>
                  </tr>

                  <!-- CONTENT -->
                  <tr>
                    <td style="padding:32px;background-color:#FFFFFF;">
                      <p style="margin:0 0 16px 0;font-size:16px;color:#333333;line-height:1.6;">
                        Hi <strong>\(esc(contactName))</strong>,
                      </p>
                      <p style="margin:0 0 16px 0;font-size:15px;color:#333333;line-height:1.6;">
                        This is a test message from <strong>WellnessCheck</strong>.
                      </p>
                      <p style="margin:0 0 16px 0;font-size:15px;color:#333333;line-height:1.6;">
                        If <strong>\(esc(name))</strong> becomes inactive for an extended period, you will receive an alert email asking you to check on him.
                      </p>

                      <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#F8F8FA;border-radius:8px;margin:20px 0;">
                        <tr>
                          <td style="padding:16px 20px;">
                            <p style="margin:0;font-size:13px;color:#888888;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;">Your Role</p>
                            <p style="margin:6px 0 0 0;font-size:15px;color:#333333;">You are listed as an emergency contact (<strong>\(esc(relationship))</strong>).</p>
                          </td>
                        </tr>
                      </table>

                      <p style="margin:16px 0 0 0;font-size:14px;color:#888888;line-height:1.5;">
                        No action is needed &mdash; this was just a test to verify email delivery. <strong>The block below is what you will see in a real alert</strong> &mdash; save the numbers now.
                      </p>

        \(localResourcesHTML)

                    </td>
                  </tr>

                  <!-- FOOTER -->
                  <tr>
                    <td style="padding:20px 32px;background-color:#F8F8FA;border-top:1px solid #EEEEEE;text-align:center;">
                      <p style="margin:0 0 4px 0;font-size:13px;color:#888888;font-weight:600;">WellnessCheck</p>
                      <p style="margin:0;font-size:11px;color:#AAAAAA;">by HiCommission</p>
                    </td>
                  </tr>

                </table>
              </td>
            </tr>
          </table>
        </body>
        </html>
        """
    }

    // MARK: - Local Emergency Resources (3308 Sugar Berry Way, Tallahassee FL 32303)

    /// Tallahassee-specific emergency reference info appended to every
    /// wellness alert. Recipients can use these numbers to request a
    /// wellness check or call the closest hospital directly. Drive
    /// times are approximate (Leon County, normal traffic).
    ///
    /// Edit this block when the user moves or local numbers change.
    /// Keep telephone numbers formatted as `tel:` links so they're
    /// one-tap on iPhone Mail.
    private static let localResourcesHTML: String = """
                <p style="margin:24px 0 8px 0;font-size:13px;color:#777777;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;">Local Emergency Resources</p>
                <p style="margin:0 0 6px 0;font-size:13px;color:#333333;font-weight:700;">3308 Sugar Berry Way, Tallahassee, FL 32303</p>
                <p style="margin:0 0 12px 0;font-size:12px;color:#888888;font-style:italic;">For use when calling on behalf of the user.</p>

                <!-- OUT-OF-STATE WARNING -->
                <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#FFF5F5;border-left:4px solid #CC0000;border-radius:0 6px 6px 0;margin-bottom:14px;">
                  <tr>
                    <td style="padding:12px 16px;">
                      <p style="margin:0 0 6px 0;font-size:14px;color:#333333;line-height:1.5;">
                        <strong style="color:#CC0000;">DIALING 911 WILL NOT REACH TALLAHASSEE if you are calling from another state</strong> &mdash; it routes to your own local 911 center. Use the direct Tallahassee numbers below.
                      </p>
                      <p style="margin:0;font-size:13px;color:#555555;line-height:1.5;">
                        For a life-threatening emergency, call <strong><a href="tel:8506065800" style="color:#CC0000;text-decoration:none;">(850) 606-5800</a></strong> (Leon County Consolidated Dispatch &mdash; this is Tallahassee&rsquo;s 911 center; they dispatch police, fire, and EMS).
                      </p>
                    </td>
                  </tr>
                </table>

                <!-- DIRECT-CALL NUMBERS (PROMINENT, TOP-OF-BLOCK) -->
                <p style="margin:14px 0 6px 0;font-size:13px;color:#CC0000;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">&#x260E;&#xFE0F; Direct Tallahassee Numbers &mdash; dial from anywhere</p>
                <table width="100%" cellpadding="0" cellspacing="0" style="border:2px solid #CC0000;border-radius:8px;overflow:hidden;margin-bottom:16px;">
                  <tr>
                    <td style="padding:10px 14px;border-bottom:1px solid #F0F0F0;font-size:14px;color:#333333;background-color:#FFFAFA;">
                      <a href="tel:8506065800" style="color:#CC0000;text-decoration:none;font-weight:700;font-size:15px;">(850) 606-5800</a><br>
                      <span style="color:#555555;font-size:12px;">Leon County Consolidated Dispatch &mdash; Tallahassee&rsquo;s 911 equivalent. Use this for an EMERGENCY (police, fire, or EMS) when calling from out of state.</span>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:10px 14px;border-bottom:1px solid #F0F0F0;font-size:14px;color:#333333;">
                      <a href="tel:8506063300" style="color:#0066CC;text-decoration:none;font-weight:700;font-size:15px;">(850) 606-3300</a><br>
                      <span style="color:#555555;font-size:12px;">Leon County Sheriff&rsquo;s Office (non-emergency) &mdash; ask them to dispatch a welfare check to 3308 Sugar Berry Way.</span>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:10px 14px;border-bottom:1px solid #F0F0F0;font-size:14px;color:#333333;">
                      <a href="tel:8503255000" style="color:#0066CC;text-decoration:none;font-weight:700;font-size:15px;">(850) 325-5000</a><br>
                      <span style="color:#555555;font-size:12px;">HCA Florida Capital Hospital ER &mdash; closest 24/7 hospital, ~8&ndash;12 min from the user. Call to ask if he was admitted.</span>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:10px 14px;border-bottom:1px solid #F0F0F0;font-size:14px;color:#333333;">
                      <a href="tel:8504311155" style="color:#0066CC;text-decoration:none;font-weight:700;font-size:15px;">(850) 431-1155</a><br>
                      <span style="color:#555555;font-size:12px;">Tallahassee Memorial HealthCare &mdash; regional trauma center, 24/7. Call to ask if he was admitted.</span>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:10px 14px;border-bottom:1px solid #F0F0F0;font-size:14px;color:#333333;">
                      <a href="tel:18002221222" style="color:#0066CC;text-decoration:none;font-weight:700;font-size:15px;">1-800-222-1222</a><br>
                      <span style="color:#555555;font-size:12px;">Florida Poison Control &mdash; 24/7. Toll-free from anywhere in the US.</span>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:10px 14px;font-size:14px;color:#333333;background-color:#FAFAFA;">
                      <a href="tel:911" style="color:#888888;text-decoration:none;font-weight:600;font-size:14px;">911</a><br>
                      <span style="color:#888888;font-size:12px;font-style:italic;">Only effective if YOU are physically in Tallahassee. Otherwise routes to your local PSAP; use (850) 606-5800 above instead.</span>
                    </td>
                  </tr>
                </table>

                <p style="margin:18px 0 8px 0;font-size:12px;color:#999999;text-transform:uppercase;letter-spacing:0.5px;">Reference &mdash; facility details</p>

                <!-- LAW ENFORCEMENT -->
                <p style="margin:14px 0 6px 0;font-size:12px;color:#666666;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">&#x1F693; Law Enforcement</p>
                <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #EEEEEE;border-radius:6px;overflow:hidden;margin-bottom:14px;">
                  <tr>
                    <td style="padding:10px 12px;border-bottom:1px solid #F0F0F0;font-size:13px;color:#333333;">
                      <strong>Leon County Sheriff&rsquo;s Office</strong><br>
                      <span style="color:#888888;font-size:12px;">2825 Municipal Way, Tallahassee, FL 32304 &middot; ~10&ndash;15 min</span><br>
                      Non-emergency: <a href="tel:8506063300" style="color:#0066CC;text-decoration:none;">(850) 606-3300</a>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:10px 12px;font-size:13px;color:#333333;">
                      <strong>Leon County / Tallahassee Consolidated Dispatch</strong><br>
                      <span style="color:#888888;font-size:12px;">Dispatcher for police, fire, and EMS (emergency and non-emergency)</span><br>
                      <a href="tel:8506065800" style="color:#0066CC;text-decoration:none;">(850) 606-5800</a>
                    </td>
                  </tr>
                </table>

                <!-- FIRE -->
                <p style="margin:14px 0 6px 0;font-size:12px;color:#666666;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">&#x1F692; Fire Services</p>
                <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #EEEEEE;border-radius:6px;overflow:hidden;margin-bottom:14px;">
                  <tr>
                    <td style="padding:10px 12px;border-bottom:1px solid #F0F0F0;font-size:13px;color:#333333;">
                      <strong>Tallahassee Fire Station #8</strong> (closest)<br>
                      <span style="color:#888888;font-size:12px;">2423 Hartsfield Road, Tallahassee, FL 32303 &middot; ~5&ndash;8 min</span><br>
                      <span style="color:#888888;font-size:11px;font-style:italic;">Fire stations don&rsquo;t take direct emergency calls &mdash; call (850) 606-5800 to dispatch.</span>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:10px 12px;font-size:13px;color:#333333;">
                      <strong>Tallahassee Fire Station #2</strong><br>
                      <span style="color:#888888;font-size:12px;">2805 Sharer Road, Tallahassee, FL 32312 &middot; ~10&ndash;12 min</span>
                    </td>
                  </tr>
                </table>

                <!-- HOSPITALS -->
                <p style="margin:14px 0 6px 0;font-size:12px;color:#666666;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">&#x1F3E5; Hospitals &amp; Emergency Rooms</p>
                <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #EEEEEE;border-radius:6px;overflow:hidden;margin-bottom:14px;">
                  <tr>
                    <td style="padding:10px 12px;border-bottom:1px solid #F0F0F0;font-size:13px;color:#333333;">
                      <strong>HCA Florida Capital Hospital</strong> (closest, 24/7)<br>
                      <span style="color:#888888;font-size:12px;">2626 Capital Medical Blvd, Tallahassee, FL 32308 &middot; ~8&ndash;12 min</span><br>
                      <a href="tel:8503255000" style="color:#0066CC;text-decoration:none;">(850) 325-5000</a>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:10px 12px;font-size:13px;color:#333333;">
                      <strong>Tallahassee Memorial HealthCare</strong> (regional trauma center, 24/7)<br>
                      <span style="color:#888888;font-size:12px;">1300 Miccosukee Road, Tallahassee, FL 32308 &middot; ~15&ndash;20 min</span><br>
                      <a href="tel:8504311155" style="color:#0066CC;text-decoration:none;">(850) 431-1155</a>
                    </td>
                  </tr>
                </table>
    """

    // MARK: - Helpers

    /// Escapes special HTML characters.
    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&#39;")
    }
}
