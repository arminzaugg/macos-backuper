import Foundation

struct Snapshot: Codable, Identifiable, Hashable {
    let id: String
    let time: Date
    let paths: [String]
    let hostname: String
    let username: String
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "short_id"
        case time
        case paths
        case hostname
        case username
        case tags
    }

    static var dateDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) {
                return date
            }
            // Fallback for dates without fractional seconds
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            if let date = fallback.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }
}
