import Foundation

enum XtreamError: LocalizedError {
    case invalidURL(String)
    case invalidCredentials
    case httpStatus(Int)
    case decoding(snippet: String)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let attempted):
            return "Μη έγκυρη διεύθυνση server: \(attempted)"
        case .invalidCredentials:
            return "Λάθος όνομα χρήστη ή κωδικός."
        case .httpStatus(let code):
            return "Ο server απάντησε με σφάλμα HTTP \(code). Έλεγξε τη διεύθυνση/θύρα του server."
        case .decoding(let snippet):
            if snippet.isEmpty {
                return "Μη αναμενόμενη (άδεια) απάντηση από τον server. Έλεγξε τη διεύθυνση του server."
            }
            return "Μη αναμενόμενη απάντηση από τον server: \(snippet)"
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

enum MediaKind: String {
    case live
    case movie
    case series
}

/// Minimal client for the Xtream Codes "player_api.php" panel API.
struct XtreamClient {
    let profile: XtreamProfile
    let password: String

    private let decoder: JSONDecoder = JSONDecoder()

    private func endpoint(action: String? = nil, extraQuery: [String: String] = [:]) throws -> URL {
        let base = profile.baseURL + "/player_api.php"
        guard var components = URLComponents(string: base) else {
            throw XtreamError.invalidURL(base)
        }
        var items = [
            URLQueryItem(name: "username", value: profile.username),
            URLQueryItem(name: "password", value: password),
        ]
        if let action {
            items.append(URLQueryItem(name: "action", value: action))
        }
        for (key, value) in extraQuery {
            items.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = items
        guard let url = components.url else {
            let itemsDescription = items.map { item in
                let value = item.name == "password" ? "•••" : (item.value ?? "")
                return "\(item.name)=\(value)"
            }.joined(separator: "&")
            throw XtreamError.invalidURL("\(base)?\(itemsDescription)")
        }
        return url
    }

    /// Verifies the credentials against the panel.
    func authenticate() async throws {
        let url = try endpoint()
        let response: XtreamAuthResponse = try await fetch(url)
        if let auth = response.userInfo?.auth, auth == 0 {
            throw XtreamError.invalidCredentials
        }
    }

    func liveCategories() async throws -> [XtreamCategory] {
        try await fetchList(action: "get_live_categories")
    }

    func vodCategories() async throws -> [XtreamCategory] {
        try await fetchList(action: "get_vod_categories")
    }

    func seriesCategories() async throws -> [XtreamCategory] {
        try await fetchList(action: "get_series_categories")
    }

    /// Fetches every live stream in one request (not scoped to a category) so the
    /// UI can group/search client-side instead of issuing one request per category
    /// — some Xtream providers reject many rapid concurrent connections.
    func liveStreams() async throws -> [LiveStream] {
        try await fetchList(action: "get_live_streams")
    }

    func vodStreams() async throws -> [VODStream] {
        try await fetchList(action: "get_vod_streams")
    }

    func series() async throws -> [SeriesItem] {
        try await fetchList(action: "get_series")
    }

    func seriesEpisodes(seriesId: String) async throws -> [String: [SeriesEpisode]] {
        let url = try endpoint(action: "get_series_info", extraQuery: ["series_id": seriesId])
        let response: SeriesInfoResponse = try await fetch(url)
        return response.episodes ?? [:]
    }

    /// Builds the playable stream URL for a given kind of media.
    func streamURL(kind: MediaKind, id: String, containerExtension: String?) -> URL? {
        let ext = (containerExtension?.isEmpty == false ? containerExtension! : (kind == .live ? "m3u8" : "mp4"))
        let path = "\(profile.baseURL)/\(kind.rawValue)/\(profile.username)/\(password)/\(id).\(ext)"
        return URL(string: path)
    }

    // MARK: - Generic helpers

    private func fetchList<T: Decodable>(action: String, extraQuery: [String: String] = [:]) async throws -> [T] {
        let url = try endpoint(action: action, extraQuery: extraQuery)
        return try await fetch(url)
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw XtreamError.transport(error)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw XtreamError.httpStatus(http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw XtreamError.decoding(snippet: snippet.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
