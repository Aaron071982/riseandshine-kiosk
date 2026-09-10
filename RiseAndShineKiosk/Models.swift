import Foundation

enum CheckDirection: String, Codable, Hashable {
    case `in`
    case `out`

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self))?.lowercased() ?? ""
        switch raw {
        case "in", "check-in", "check_in", "checkin", "signed_in", "signed-in":
            self = .in
        case "out", "check-out", "check_out", "checkout", "signed_out", "signed-out":
            self = .out
        default:
            self = .out
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var verbTitle: String { self == .in ? "Sign in" : "Sign out" }
    var pastPhrase: String { self == .in ? "checked in" : "checked out" }
    var statusLabel: String { self == .in ? "Signed in" : "Signed out" }
}

struct DeviceInfo: Codable, Hashable {
    var id: String
    var label: String
    var locationLabel: String
}

struct SessionValidateResponse: Codable {
    var device: DeviceInfo
}

struct TodaySession: Codable, Hashable {
    var scheduleAssignmentId: String?
    var startTime: String?
    var endTime: String?
    var btName: String?
    var location: String?

    var timeRange: String {
        let start = formatTime(startTime)
        let end = formatTime(endTime)
        switch (start, end) {
        case (nil, nil): return "Today"
        case (let s?, nil): return s
        case (nil, let e?): return "until \(e)"
        case (let s?, let e?): return "\(s) – \(e)"
        }
    }

    private func formatTime(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if let date = ISO8601Parsing.date(from: raw) {
            return TimeFormatting.timeOnly.string(from: date)
        }
        if raw.count <= 8, raw.contains(":") {
            return raw
        }
        return raw
    }
}

struct DirectoryClient: Codable, Identifiable, Hashable {
    var id: String
    var firstName: String
    var lastName: String
    var parentName: String?
    var parentRelationship: String?
    var outstandingForms: Int
    var currentStatus: CheckDirection
    var todaySession: TodaySession?

    var displayName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }

    var isSignedIn: Bool { currentStatus == .in }
    var nextAction: CheckDirection { isSignedIn ? .out : .in }

    enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, parentName, parentRelationship
        case outstandingForms, currentStatus, todaySession
    }

    init(
        id: String,
        firstName: String,
        lastName: String,
        parentName: String? = nil,
        parentRelationship: String? = nil,
        outstandingForms: Int = 0,
        currentStatus: CheckDirection = .out,
        todaySession: TodaySession? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.parentName = parentName
        self.parentRelationship = parentRelationship
        self.outstandingForms = outstandingForms
        self.currentStatus = currentStatus
        self.todaySession = todaySession
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName) ?? ""
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName) ?? ""
        parentName = try c.decodeIfPresent(String.self, forKey: .parentName)
        parentRelationship = try c.decodeIfPresent(String.self, forKey: .parentRelationship)
        outstandingForms = try c.decodeIfPresent(Int.self, forKey: .outstandingForms) ?? 0
        currentStatus = try c.decodeIfPresent(CheckDirection.self, forKey: .currentStatus) ?? .out
        todaySession = try c.decodeIfPresent(TodaySession.self, forKey: .todaySession)
    }
}

struct AttendanceEvent: Codable, Identifiable, Hashable {
    var id: String
    var clientId: String?
    var clientFirstName: String?
    var clientLastName: String?
    var type: CheckDirection?
    var signerName: String?
    var signerRelationship: String?
    var capturedAt: Date?
    var createdAt: Date?
    var locationLabel: String?

    var clientDisplayName: String {
        let name = [clientFirstName, clientLastName].compactMap { $0 }.joined(separator: " ")
        return name.isEmpty ? "Client" : name
    }

    enum CodingKeys: String, CodingKey {
        case id, clientId, clientFirstName, clientLastName
        case type, direction, eventType
        case signerName, signerRelationship
        case capturedAt, createdAt, locationLabel
        case client
    }

    private struct NestedClient: Codable {
        var id: String?
        var firstName: String?
        var lastName: String?
    }

    init(
        id: String,
        clientId: String? = nil,
        clientFirstName: String? = nil,
        clientLastName: String? = nil,
        type: CheckDirection? = nil,
        signerName: String? = nil,
        signerRelationship: String? = nil,
        capturedAt: Date? = nil,
        createdAt: Date? = nil,
        locationLabel: String? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.clientFirstName = clientFirstName
        self.clientLastName = clientLastName
        self.type = type
        self.signerName = signerName
        self.signerRelationship = signerRelationship
        self.capturedAt = capturedAt
        self.createdAt = createdAt
        self.locationLabel = locationLabel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        clientId = try c.decodeIfPresent(String.self, forKey: .clientId)
        clientFirstName = try c.decodeIfPresent(String.self, forKey: .clientFirstName)
        clientLastName = try c.decodeIfPresent(String.self, forKey: .clientLastName)
        if let nested = try c.decodeIfPresent(NestedClient.self, forKey: .client) {
            if clientId == nil { clientId = nested.id }
            if clientFirstName == nil { clientFirstName = nested.firstName }
            if clientLastName == nil { clientLastName = nested.lastName }
        }
        type = try c.decodeIfPresent(CheckDirection.self, forKey: .type)
            ?? c.decodeIfPresent(CheckDirection.self, forKey: .direction)
            ?? c.decodeIfPresent(CheckDirection.self, forKey: .eventType)
        signerName = try c.decodeIfPresent(String.self, forKey: .signerName)
        signerRelationship = try c.decodeIfPresent(String.self, forKey: .signerRelationship)
        capturedAt = Self.decodeDate(c, key: .capturedAt)
        createdAt = Self.decodeDate(c, key: .createdAt)
        locationLabel = try c.decodeIfPresent(String.self, forKey: .locationLabel)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(clientId, forKey: .clientId)
        try c.encodeIfPresent(clientFirstName, forKey: .clientFirstName)
        try c.encodeIfPresent(clientLastName, forKey: .clientLastName)
        try c.encodeIfPresent(type, forKey: .type)
        try c.encodeIfPresent(signerName, forKey: .signerName)
        try c.encodeIfPresent(signerRelationship, forKey: .signerRelationship)
        try c.encodeIfPresent(capturedAt, forKey: .capturedAt)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(locationLabel, forKey: .locationLabel)
    }

    private static func decodeDate(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        if let date = try? c.decode(Date.self, forKey: key) { return date }
        if let raw = try? c.decode(String.self, forKey: key) { return ISO8601Parsing.date(from: raw) }
        return nil
    }
}

struct CreateAttendanceEventRequest: Codable {
    var clientId: String
    var type: String
    var signerName: String
    var signerRelationship: String
    var signaturePngBase64: String
    var signatureHash: String
    var capturedAt: String
    var scheduleAssignmentId: String?
}

struct ConfirmPayload: Hashable {
    var client: DirectoryClient
    var direction: CheckDirection
    var eventId: String
    var queuedOffline: Bool
}

enum TimeFormatting {
    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, MMM d  •  h:mm a"
        return f
    }()

    static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm"
        return f
    }()

    static let meridiem: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "a"
        return f
    }()
}

enum ISO8601Parsing {
    static func date(from raw: String) -> Date? {
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFrac.date(from: raw) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: raw) { return d }
        return nil
    }

    static func string(from date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}
