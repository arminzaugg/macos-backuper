import Foundation

struct RetentionPolicy: Codable, Equatable {
    var keepDaily: Int
    var keepWeekly: Int
    var keepMonthly: Int

    static let defaults = RetentionPolicy(
        keepDaily: 7,
        keepWeekly: 4,
        keepMonthly: 6
    )

    // MARK: - UserDefaults Persistence

    static let userDefaultsKey = "retentionPolicy"

    static func loadFromUserDefaults() -> RetentionPolicy {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let policy = try? JSONDecoder().decode(RetentionPolicy.self, from: data) {
            return policy
        }
        return .defaults
    }

    func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
}
