import Foundation

struct ScheduleTime: Codable, Equatable {
    var hour: Int
    var minute: Int
}

struct ScheduleConfig: Codable, Equatable {
    var times: [ScheduleTime]

    static let defaults = ScheduleConfig(times: [
        ScheduleTime(hour: 2, minute: 0),
        ScheduleTime(hour: 14, minute: 0),
    ])
}
