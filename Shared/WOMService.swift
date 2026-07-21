import Foundation

enum WOMError: LocalizedError {
    case notFound
    case rateLimited
    case badRequest(String)
    case server(Int)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "That player isn't tracked on Wise Old Man yet. Tap “Update” to add them from the hiscores."
        case .rateLimited:
            return "Too many requests — Wise Old Man is rate-limiting us. Wait a moment and try again."
        case .badRequest(let msg):
            return msg
        case .server(let code):
            return "Wise Old Man returned an error (HTTP \(code)). Try again shortly."
        case .decoding:
            return "Couldn't read the response from Wise Old Man."
        case .transport(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }
}

/// Thin async client for the Wise Old Man v2 API.
/// Docs: https://docs.wiseoldman.net/
struct WOMService {
    static let shared = WOMService()

    private let base = URL(string: "https://api.wiseoldman.net/v2")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // GET /players/{username}
    func player(_ username: String) async throws -> PlayerDetails {
        try await get(path: "players/\(encode(username))")
    }

    // GET /players/{username}/gained?period={period}
    func gains(_ username: String, period: String) async throws -> PlayerGains {
        try await get(path: "players/\(encode(username))/gained", query: [
            URLQueryItem(name: "period", value: period)
        ])
    }

    // GET /players/{username}/gained?startDate=…&endDate=…
    // Uses a custom date range so "today" means the current calendar day
    // (local midnight → now), matching WOM's daily XP graph rather than the
    // rolling-24h `period=day`.
    func gains(_ username: String, from start: Date, to end: Date) async throws -> PlayerGains {
        try await get(path: "players/\(encode(username))/gained", query: [
            URLQueryItem(name: "startDate", value: Self.iso.string(from: start)),
            URLQueryItem(name: "endDate", value: Self.iso.string(from: end)),
        ])
    }

    /// Gains since the start of today (local time) up to now.
    func gainsToday(_ username: String) async throws -> PlayerGains {
        let start = Calendar.current.startOfDay(for: Date())
        return try await gains(username, from: start, to: Date())
    }

    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // POST /players/{username} — tracks a new player or refreshes an existing
    // one from the official hiscores, returning the updated details.
    func update(_ username: String) async throws -> PlayerDetails {
        try await send(path: "players/\(encode(username))", method: "POST")
    }

    // MARK: - Plumbing

    private func get<T: Decodable>(path: String, query: [URLQueryItem] = []) async throws -> T {
        try await send(path: path, method: "GET", query: query)
    }

    private func send<T: Decodable>(path: String, method: String, query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw WOMError.badRequest("Invalid request URL.") }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // WOM asks integrations to identify themselves.
        request.setValue("WiseOldManStats-iOS", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw WOMError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw WOMError.server(-1)
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw WOMError.decoding(error)
            }
        case 404:
            throw WOMError.notFound
        case 429:
            throw WOMError.rateLimited
        case 400:
            throw WOMError.badRequest(message(from: data) ?? "Bad request.")
        default:
            throw WOMError.server(http.statusCode)
        }
    }

    private func message(from data: Data) -> String? {
        (try? JSONDecoder().decode(WOMErrorBody.self, from: data))?.message
    }

    private func encode(_ username: String) -> String {
        username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
    }
}
