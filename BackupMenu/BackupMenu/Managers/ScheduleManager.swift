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
    private var firedSlots: Set<String> = []
    private var firedSlotsDate: Date?

    init() {
        if let data = UserDefaults.standard.data(forKey: Constants.userDefaultsScheduleKey),
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
            UserDefaults.standard.set(data, forKey: Constants.userDefaultsScheduleKey)
        }
        calculateNextFireDate()
    }

    func calculateNextFireDate() {
        let calendar = Calendar.current
        let now = Date()
        var nearest: Date?

        for time in schedule.times {
            if var candidate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now) {
                if candidate <= now {
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
        timer = Timer.scheduledTimer(withTimeInterval: Constants.scheduleCheckInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkSchedule()
            }
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
           Date().timeIntervalSince(last) < Constants.minimumBackupInterval {
            return
        }

        let calendar = Calendar.current
        let now = Date()

        // Reset fired slots at the start of each new day
        if let slotsDate = firedSlotsDate, !calendar.isDate(slotsDate, inSameDayAs: now) {
            firedSlots.removeAll()
            firedSlotsDate = now
        } else if firedSlotsDate == nil {
            firedSlotsDate = now
        }

        for time in schedule.times {
            let slotKey = String(format: "%02d:%02d", time.hour, time.minute)

            // Skip if already fired for this slot today
            guard !firedSlots.contains(slotKey) else { continue }

            // Check if current time is at or past the scheduled time
            guard let scheduledDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now) else {
                continue
            }

            if now >= scheduledDate {
                firedSlots.insert(slotKey)
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
