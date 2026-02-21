import Foundation
import Observation

@Observable
final class ScheduleManager {
    var schedule: ScheduleConfig
    var nextFireDate: Date?
    var isEnabled: Bool {
        didSet {
            if isEnabled {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    var onScheduleFired: (() -> Void)?

    private var timer: Timer?
    private var lastAutoBackupDate: Date?
    private static let userDefaultsKey = "backupSchedule"
    private static let minimumInterval: TimeInterval = 60 * 60 // 60 minutes

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
           let saved = try? JSONDecoder().decode(ScheduleConfig.self, from: data) {
            self.schedule = saved
        } else {
            self.schedule = .defaults
        }
        self.isEnabled = true
        calculateNextFireDate()
        startTimer()
    }

    func start() {
        isEnabled = true
    }

    func stop() {
        isEnabled = false
    }

    func updateSchedule(_ config: ScheduleConfig) {
        schedule = config
        saveSchedule()
    }

    func saveSchedule() {
        if let data = try? JSONEncoder().encode(schedule) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
        calculateNextFireDate()
    }

    func calculateNextFireDate() {
        let calendar = Calendar.current
        let now = Date()
        var nearest: Date?

        for time in schedule.times {
            // Try today
            if var candidate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now) {
                if candidate <= now {
                    // Already passed today, try tomorrow
                    candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
                }
                if nearest == nil || candidate < nearest! {
                    nearest = candidate
                }
            }
        }

        nextFireDate = nearest
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkSchedule()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func checkSchedule() {
        guard isEnabled else { return }

        // Enforce minimum interval between auto backups
        if let last = lastAutoBackupDate,
           Date().timeIntervalSince(last) < Self.minimumInterval {
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        for time in schedule.times {
            if time.hour == currentHour && time.minute == currentMinute {
                lastAutoBackupDate = now
                onScheduleFired?()
                calculateNextFireDate()
                return
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}
