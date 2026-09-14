import SwiftUI

struct UnauthorizedView: View {
    @EnvironmentObject private var state: KioskAppState

    var body: some View {
        VStack(spacing: 20) {
            SunriseMark(size: 96)
            Text("Device not authorized")
                .font(RSFont.display(40, weight: .bold))
                .foregroundStyle(Color.espresso)
            Text("This iPad’s kiosk token was rejected by the HRM. Ask an admin to provision the device again.")
                .font(RSFont.body(18))
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            KioskButton(title: "Try again", kind: .secondary) {
                Task { await state.validate() }
            }
            .frame(maxWidth: 280)
            Button("Re-provision this iPad") {
                state.showSetup = true
            }
            .font(RSFont.body(15, weight: .semibold))
            .foregroundStyle(Color.mutedText)
            .padding(.top, 8)
        }
        .padding(40)
    }
}

struct DeviceSetupView: View {
    @EnvironmentObject private var state: KioskAppState
    @State private var baseURL = KioskConfig.baseURLString
    @State private var token = KeychainStore.loadToken() ?? ""
    @State private var pin = KioskConfig.staffPIN
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SunriseMark(size: 72)
                Text("Provision this kiosk")
                    .font(RSFont.display(36, weight: .bold))
                    .foregroundStyle(Color.espresso)
                Text("Paste the device token from the HRM. It stays on this iPad in the Keychain and is never synced to iCloud.")
                    .font(RSFont.body(17))
                    .foregroundStyle(Color.mutedText)

                field("HRM base URL", text: $baseURL, prompt: "https://your-hrm.example.com")
                field("Device token", text: $token, prompt: "Bearer token from provisioning", secret: true)
                field("Staff audit PIN", text: $pin, prompt: "4-digit PIN")

                if let error {
                    Text(error)
                        .font(RSFont.body(15))
                        .foregroundStyle(Color.sunriseDeep)
                }

                KioskButton(title: "Save and validate", enabled: canSave, loading: saving) {
                    Task {
                        saving = true
                        error = nil
                        await state.saveProvisioning(baseURL: baseURL, token: token, staffPIN: pin)
                        if state.auth == .unauthorized {
                            error = "The HRM rejected this token."
                        } else if state.auth == .needsSetup {
                            error = "Check the URL and token, then try again."
                        }
                        saving = false
                    }
                }
            }
            .padding(36)
        }
        .background(Color.canvasBg)
    }

    private var canSave: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !token.trimmingCharacters(in: .whitespaces).isEmpty
            && pin.count >= 4
            && !saving
    }

    private func field(_ title: String, text: Binding<String>, prompt: String, secret: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(RSFont.body(13, weight: .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color.mutedText)
            Group {
                if secret {
                    SecureField(prompt, text: text)
                } else {
                    TextField(prompt, text: text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(title.contains("URL") ? .URL : .default)
                }
            }
            .font(RSFont.body(17))
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            )
        }
    }
}
