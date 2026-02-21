import Foundation
import Observation
import UserNotifications

@Observable
final class AppState {
    let backupManager: BackupManager
    let scheduleManager: ScheduleManager
    let configManager: ConfigManager

    var errorMessage: String?
    var selectedTab: Int = 0

    var showError: Bool {
        errorMessage != nil
    }

    var currentStatus: BackupStatus {
        backupManager.status
    }

    var menuBarIcon: String {
        currentStatus.sfSymbolName
    }

    func clearError() {
        errorMessage = nil
    }

    func openSettings() {
        selectedTab = 2
    }

    init() {
        // Resolve config path: walk up from the app bundle to find config/restic.env.local
        let resolvedPath = Self.findConfigPath()
        let configManager = ConfigManager(configPath: resolvedPath)
        let backupManager = BackupManager(configManager: configManager)
        let scheduleManager = ScheduleManager()

        self.configManager = configManager
        self.backupManager = backupManager
        self.scheduleManager = scheduleManager

        scheduleManager.onScheduleFired = { [weak self, weak backupManager] in
            guard let self, let backupManager else { return }
            Task {
                await backupManager.runBackup()
                let status = backupManager.status
                switch status {
                case .success(let date):
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    formatter.timeStyle = .short
                    await self.sendNotification(
                        title: "Backup Completed",
                        body: "Backup finished successfully at \(formatter.string(from: date))",
                        isError: false
                    )
                case .error(let message):
                    await MainActor.run {
                        self.errorMessage = message
                    }
                    await self.sendNotification(
                        title: "Backup Failed",
                        body: message,
                        isError: true
                    )
                default:
                    break
                }
            }
        }

        loadInitialStatus()
        requestNotificationPermission()
    }

    func sendNotification(title: String, body: String, isError: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = isError ? .defaultCritical : .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    private func loadInitialStatus() {
        let logPath = NSHomeDirectory() + "/Library/Logs/backup.log"
        do {
            let result = try LogParser.parseLastBackupStatus(from: logPath)
            if let date = result.date, result.success {
                backupManager.status = .success(date: date)
                backupManager.lastBackupDate = date
            } else if let message = result.success ? nil : Optional(result.message) {
                backupManager.status = .error(message: message)
            }
        } catch {
            // No log file or parse error — stay at .idle
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Walk up from the app bundle location looking for config/restic.env.local
    private static func findConfigPath() -> String {
        let fm = FileManager.default
        var dir = (Bundle.main.bundlePath as NSString).deletingLastPathComponent

        // Walk up at most 5 levels to find the project root containing config/
        for _ in 0..<5 {
            let candidate = (dir as NSString).appendingPathComponent("config/restic.env.local")
            if fm.fileExists(atPath: candidate) {
                return candidate
            }
            dir = (dir as NSString).deletingLastPathComponent
        }

        // Fallback: check if there's a stored path in UserDefaults
        if let stored = UserDefaults.standard.string(forKey: "configPath"),
           fm.fileExists(atPath: stored) {
            return stored
        }

        // Last resort: assume project is in the same directory as the app
        return (Bundle.main.bundlePath as NSString)
            .deletingLastPathComponent
            .appending("/config/restic.env.local")
    }
}
