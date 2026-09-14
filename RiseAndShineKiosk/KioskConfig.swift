import Foundation

enum KioskConfig {
    private static let baseURLKey = "kiosk.baseURL"
    private static let staffPINKey = "kiosk.staffPIN"

    static var baseURLString: String {
        get { UserDefaults.standard.string(forKey: baseURLKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: baseURLKey) }
    }

    static var baseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    static var staffPIN: String {
        get {
            let stored = UserDefaults.standard.string(forKey: staffPINKey) ?? ""
            return stored.isEmpty ? "2580" : stored
        }
        set { UserDefaults.standard.set(newValue, forKey: staffPINKey) }
    }

    static var isConfigured: Bool {
        baseURL != nil && !(KeychainStore.loadToken() ?? "").isEmpty
    }
}
