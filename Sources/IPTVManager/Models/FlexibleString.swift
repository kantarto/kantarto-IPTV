import Foundation

/// Xtream Codes panels are inconsistent about whether numeric fields (ids, etc.)
/// are encoded as JSON numbers or strings. This decodes either into a String.
@propertyWrapper
struct FlexibleString: Codable, Hashable {
    var wrappedValue: String

    init(wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            wrappedValue = string
        } else if let int = try? container.decode(Int.self) {
            wrappedValue = String(int)
        } else if let double = try? container.decode(Double.self) {
            wrappedValue = String(double)
        } else {
            wrappedValue = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

/// Same idea, but for fields that may be missing entirely and should default to "".
@propertyWrapper
struct FlexibleStringOptional: Codable, Hashable {
    var wrappedValue: String

    init(wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            wrappedValue = ""
        } else if let string = try? container.decode(String.self) {
            wrappedValue = string
        } else if let int = try? container.decode(Int.self) {
            wrappedValue = String(int)
        } else if let double = try? container.decode(Double.self) {
            wrappedValue = String(double)
        } else {
            wrappedValue = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}
