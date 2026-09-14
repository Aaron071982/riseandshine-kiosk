import Foundation

struct IntakeSchema: Codable {
    var version: Int?
    var signature: IntakeSignatureBlock
    var forms: [IntakeForm]

    var enabledForms: [IntakeForm] { forms.filter(\.enabled) }
}

struct IntakeSignatureBlock: Codable {
    var consentText: String
}

struct IntakeForm: Codable, Identifiable {
    var code: String
    var title: String
    var enabled: Bool
    var required: Bool?
    var conditionalGate: IntakeConditionalGate?
    var sections: [IntakeSection]

    var id: String { code }
    var isOptional: Bool { required == false }
}

struct IntakeConditionalGate: Codable {
    var id: String?
    var prompt: String
    var showFormWhen: String?

    var showsOnYes: Bool {
        let raw = (showFormWhen ?? "yes").lowercased()
        return raw == "yes" || raw == "true"
    }
}

struct IntakeSection: Codable, Identifiable {
    var id: String
    var title: String
    var body: String?
    var fields: [IntakeField]
}

struct IntakeField: Codable, Identifiable {
    var id: String
    var type: IntakeFieldType
    var label: String
    var required: Bool?
    var requiredWhenFormShown: Bool?
    var options: [IntakeFieldOption]?

    func mustAnswer(formIsShown: Bool) -> Bool {
        if required == true { return true }
        if formIsShown, requiredWhenFormShown == true { return true }
        return false
    }
}

struct IntakeFieldOption: Codable, Identifiable, Hashable {
    var value: String
    var label: String
    var id: String { value }
}

enum IntakeFieldType: String, Codable {
    case text
    case textarea
    case date
    case checkbox
    case radio
}

enum IntakeFieldValue: Equatable {
    case bool(Bool)
    case string(String)

    var isChecked: Bool {
        if case .bool(let v) = self { return v }
        return false
    }

    var stringValue: String {
        switch self {
        case .bool(let v): return v ? "Yes" : "No"
        case .string(let s): return s
        }
    }

    var isPresent: Bool {
        switch self {
        case .bool(let v): return v
        case .string(let s): return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

enum IntakeSchemaLoader {
    static func load() -> IntakeSchema {
        let url =
            Bundle.main.url(forResource: "intake-forms-schema", withExtension: "json")
            ?? Bundle.main.url(forResource: "intake-forms-schema", withExtension: "json", subdirectory: "Resources")
        guard let url, let data = try? Data(contentsOf: url) else {
            preconditionFailure("intake-forms-schema.json is missing from the app bundle")
        }
        do {
            return try JSONDecoder().decode(IntakeSchema.self, from: data)
        } catch {
            preconditionFailure("intake-forms-schema.json could not be decoded: \(error)")
        }
    }
}

enum IntakeJSONValue: Encodable {
    case bool(Bool)
    case string(String)

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        }
    }
}

struct IntakeSubmitRequest: Encodable {
    var serviceClientId: String
    var signerName: String
    var signerRelationship: String
    var signatureHash: String
    var signaturePngBase64: String
    var consentGiven: Bool
    var forms: [String: [String: IntakeJSONValue]]
}

enum DateDisplay {
    static let mmddyyyy: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MM/dd/yyyy"
        return f
    }()

    static func mmddyyyy(from raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if let date = ISO8601Parsing.date(from: raw) {
            return mmddyyyy.string(from: date)
        }
        if raw.count >= 10, raw.contains("-"),
           let date = ymd.date(from: String(raw.prefix(10))) {
            return mmddyyyy.string(from: date)
        }
        if raw.contains("/") { return raw }
        return raw
    }

    private static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
