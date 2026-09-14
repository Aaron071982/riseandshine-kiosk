import Foundation

enum KioskAPIError: LocalizedError {
    case notConfigured
    case unauthorized
    case http(Int, String?)
    case decoding
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "This iPad hasn’t been provisioned yet."
        case .unauthorized:
            return "This device is not authorized."
        case .http(let code, let message):
            return message ?? "Request failed (\(code))."
        case .decoding:
            return "The server sent an unexpected response."
        case .network(let error):
            return error.localizedDescription
        }
    }

    var isUnauthorized: Bool {
        if case .unauthorized = self { return true }
        if case .http(401, _) = self { return true }
        return false
    }

    /// True only for a genuine transport failure (no HTTP response).
    var isTransportError: Bool {
        if case .network(let error) = self { return error is URLError }
        return false
    }
}

final class KioskAPIClient {
    static let shared = KioskAPIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let date = try? container.decode(Date.self) { return date }
            let raw = try container.decode(String.self)
            if let date = ISO8601Parsing.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date")
        }
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func validateSession() async throws -> DeviceInfo {
        // Spec table lists GET; setup copy says POST. Try GET, then POST on 405.
        do {
            let response: SessionValidateResponse = try await request(
                method: "GET",
                path: "/api/kiosk/session/validate"
            )
            return response.device
        } catch let KioskAPIError.http(code, _) where code == 404 || code == 405 {
            let response: SessionValidateResponse = try await request(
                method: "POST",
                path: "/api/kiosk/session/validate"
            )
            return response.device
        } catch KioskAPIError.decoding {
            let device: DeviceInfo = try await request(
                method: "GET",
                path: "/api/kiosk/session/validate"
            )
            return device
        }
    }

    func directory(query: String) async throws -> [DirectoryClient] {
        var items: [URLQueryItem] = []
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        let data = try await rawRequest(method: "GET", path: "/api/kiosk/directory", query: items)
        return try decodeDirectory(data)
    }

    func createEvent(_ body: CreateAttendanceEventRequest) async throws -> AttendanceEvent {
        guard let base = KioskConfig.baseURL else { throw KioskAPIError.notConfigured }
        guard let token = KeychainStore.loadToken(), !token.isEmpty else { throw KioskAPIError.notConfigured }

        let urlString = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/kiosk/events"
        guard let url = URL(string: urlString) else { throw KioskAPIError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw KioskAPIError.network(urlError)
        } catch {
            throw KioskAPIError.http(-1, error.localizedDescription)
        }

        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 || status == 201 else {
            print("KIOSK POST status:", (resp as? HTTPURLResponse)?.statusCode ?? -1)
            print("KIOSK POST body:", String(data: data, encoding: .utf8) ?? "")
            if status == 401 { throw KioskAPIError.unauthorized }
            throw KioskAPIError.http(status, serverMessage(data))
        }

        do {
            return try decodeEvent(data)
        } catch {
            throw KioskAPIError.decoding
        }
    }

    func todaysEvents() async throws -> [AttendanceEvent] {
        let data = try await rawRequest(method: "GET", path: "/api/kiosk/events/today")
        return try decodeEvents(data)
    }

    private func request<T: Decodable>(method: String, path: String, query: [URLQueryItem] = [], body: Data? = nil) async throws -> T {
        let data = try await rawRequest(method: method, path: path, query: query, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw KioskAPIError.decoding
        }
    }

    private func rawRequest(method: String, path: String, query: [URLQueryItem] = [], body: Data? = nil) async throws -> Data {
        guard let base = KioskConfig.baseURL else { throw KioskAPIError.notConfigured }
        guard let token = KeychainStore.loadToken(), !token.isEmpty else { throw KioskAPIError.notConfigured }

        let urlString = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path
        var components = URLComponents(string: urlString)
        if !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else { throw KioskAPIError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw KioskAPIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw KioskAPIError.http(-1, "No HTTP response")
        }
        if http.statusCode == 401 {
            throw KioskAPIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw KioskAPIError.http(http.statusCode, serverMessage(data))
        }
        return data
    }

    private func decodeDirectory(_ data: Data) throws -> [DirectoryClient] {
        if let list = try? decoder.decode([DirectoryClient].self, from: data) {
            return list
        }
        struct Wrap: Decodable { var clients: [DirectoryClient]?; var data: [DirectoryClient]?; var results: [DirectoryClient]? }
        if let wrap = try? decoder.decode(Wrap.self, from: data) {
            return wrap.clients ?? wrap.data ?? wrap.results ?? []
        }
        throw KioskAPIError.decoding
    }

    private func decodeEvent(_ data: Data) throws -> AttendanceEvent {
        if let event = try? decoder.decode(AttendanceEvent.self, from: data) {
            return event
        }
        struct Wrap: Decodable { var event: AttendanceEvent?; var data: AttendanceEvent? }
        if let wrap = try? decoder.decode(Wrap.self, from: data), let event = wrap.event ?? wrap.data {
            return event
        }
        throw KioskAPIError.decoding
    }

    private func decodeEvents(_ data: Data) throws -> [AttendanceEvent] {
        if let list = try? decoder.decode([AttendanceEvent].self, from: data) {
            return list
        }
        struct Wrap: Decodable { var events: [AttendanceEvent]?; var data: [AttendanceEvent]?; var results: [AttendanceEvent]? }
        if let wrap = try? decoder.decode(Wrap.self, from: data) {
            return wrap.events ?? wrap.data ?? wrap.results ?? []
        }
        throw KioskAPIError.decoding
    }
}

private struct ServerError: Decodable {
    var error: String?
    var message: String?
    var messageResolved: String? { message ?? error }
}

extension KioskAPIClient {
    fileprivate func serverMessage(_ data: Data) -> String? {
        (try? JSONDecoder().decode(ServerError.self, from: data))?.messageResolved
    }
}
