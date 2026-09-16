import Foundation

struct XtreamCategory: Codable, Identifiable, Hashable {
    @FlexibleString var categoryId: String
    var categoryName: String

    var id: String { categoryId }

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
    }
}

protocol StreamItem: Identifiable, Hashable {
    var id: String { get }
    var displayName: String { get }
    var streamIcon: String? { get }
    var categoryId: String { get }
}

struct LiveStream: Codable, StreamItem {
    @FlexibleString var streamId: String
    var name: String
    var streamIcon: String?
    @FlexibleStringOptional var categoryId: String

    var id: String { streamId }
    var displayName: String { name }

    enum CodingKeys: String, CodingKey {
        case streamId = "stream_id"
        case name
        case streamIcon = "stream_icon"
        case categoryId = "category_id"
    }
}

struct VODStream: Codable, StreamItem {
    @FlexibleString var streamId: String
    var name: String
    var streamIcon: String?
    @FlexibleStringOptional var categoryId: String
    var containerExtension: String?

    var id: String { streamId }
    var displayName: String { name }

    enum CodingKeys: String, CodingKey {
        case streamId = "stream_id"
        case name
        case streamIcon = "stream_icon"
        case categoryId = "category_id"
        case containerExtension = "container_extension"
    }
}

struct SeriesItem: Codable, StreamItem {
    @FlexibleString var seriesId: String
    var name: String
    var cover: String?
    @FlexibleStringOptional var categoryId: String

    var id: String { seriesId }
    var displayName: String { name }
    var streamIcon: String? { cover }

    enum CodingKeys: String, CodingKey {
        case seriesId = "series_id"
        case name
        case cover
        case categoryId = "category_id"
    }
}

struct SeriesInfoResponse: Codable {
    var episodes: [String: [SeriesEpisode]]?
}

struct SeriesEpisode: Codable, StreamItem {
    @FlexibleString var id: String
    var title: String
    var containerExtension: String?
    var season: Int?

    var displayName: String { title }
    var streamIcon: String? { nil }
    var categoryId: String { "" }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case containerExtension = "container_extension"
        case season
    }
}

struct XtreamAuthResponse: Codable {
    var userInfo: UserInfo?

    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
    }

    struct UserInfo: Codable {
        var auth: Int?
        var status: String?
        var message: String?

        enum CodingKeys: String, CodingKey {
            case auth, status, message
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let intValue = try? container.decode(Int.self, forKey: .auth) {
                auth = intValue
            } else if let stringValue = try? container.decode(String.self, forKey: .auth) {
                auth = Int(stringValue)
            } else if let boolValue = try? container.decode(Bool.self, forKey: .auth) {
                auth = boolValue ? 1 : 0
            } else {
                auth = nil
            }
            status = try? container.decode(String.self, forKey: .status)
            message = try? container.decode(String.self, forKey: .message)
        }
    }
}
