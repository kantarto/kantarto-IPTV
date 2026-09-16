import Foundation

struct XtreamProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var serverURL: String
    var username: String
    // Stored locally (not in Keychain) on purpose: this is a personal, single-user
    // app and Keychain's per-build re-prompting was too disruptive during active
    // development. See README for the tradeoff.
    var password: String

    init(id: UUID = UUID(), name: String, serverURL: String, username: String, password: String) {
        self.id = id
        self.name = name
        self.serverURL = serverURL
        self.username = username
        self.password = password
    }

    enum CodingKeys: String, CodingKey {
        case id, name, serverURL, username, password
    }

    /// `password` used to live in the Keychain, so profiles saved before that
    /// changed won't have it in their JSON — default to "" instead of failing to
    /// decode (which would silently drop the whole saved profile list).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        serverURL = try container.decode(String.self, forKey: .serverURL)
        username = try container.decode(String.self, forKey: .username)
        password = (try? container.decode(String.self, forKey: .password)) ?? ""
    }

    /// Normalized base URL, without a trailing slash.
    var baseURL: String {
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.contains("://") {
            url = "http://" + url
        }
        while url.hasSuffix("/") {
            url.removeLast()
        }
        return url
    }
}
