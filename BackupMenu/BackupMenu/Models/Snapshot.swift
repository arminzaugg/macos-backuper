import Foundation

struct Snapshot: Codable, Identifiable {
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
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
