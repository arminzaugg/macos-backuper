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
}
