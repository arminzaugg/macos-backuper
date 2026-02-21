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
    var setupCompleted: Bool = false

    var showError: Bool {
        errorMessage != nil
    }

    var currentStatus: BackupStatus {
        backupManager.status
    }

    var menuBarIcon: String {
        currentStatus.sfSymbolName
    }

    var needsSetup: Bool {
        if setupCompleted { return false }

        // Check if config file exists and is loadable
        let configExists = (try? configManager.loadConfig()) != nil

        // Check if all keychain keys are present
        let keychainOK = KeychainManager.checkKeyExists(
            service: Constants.keychainService(Constants.keychainResticPassword)
        ) && KeychainManager.checkKeyExists(
            service: Constants.keychainService(Constants.keychainAWSAccessKey)
        ) && KeychainManager.checkKeyExists(
            service: Constants.keychainService(Constants.keychainAWSSecretKey)
        )

        return !configExists || !keychainOK
    }

    var isResticInstalled: Bool {
        let candidates = [
            "/opt/homebrew/bin/restic",
            "/usr/local/bin/restic",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        return false
    }

    func completeSetup() {
        setupCompleted = true
    }

    func initializeRepository() async -> (success: Bool, message: String) {
        await backupManager.initializeRepository()
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

    private static func findConfigPath() -> String {
        let fm = FileManager.default
        let configRel = "config/restic.env.local"

        // 1. Check UserDefaults for a previously stored path
        if let stored = UserDefaults.standard.string(forKey: "configPath"),
           fm.fileExists(atPath: stored) {
            return stored
        }

        // 2. Use ProjectRoot embedded in Info.plist at build time (SRCROOT/..)
        if let projectRoot = Bundle.main.infoDictionary?["ProjectRoot"] as? String {
            let candidate = (projectRoot as NSString).appendingPathComponent(configRel)
            if fm.fileExists(atPath: candidate) {
                UserDefaults.standard.set(candidate, forKey: "configPath")
                return candidate
            }
        }

        // 3. Walk up from the app bundle (works when app is inside the project)
        var dir = (Bundle.main.bundlePath as NSString).deletingLastPathComponent
        for _ in 0..<5 {
            let candidate = (dir as NSString).appendingPathComponent(configRel)
            if fm.fileExists(atPath: candidate) {
                UserDefaults.standard.set(candidate, forKey: "configPath")
                return candidate
            }
            dir = (dir as NSString).deletingLastPathComponent
        }

        // 4. Last resort: return the ProjectRoot-based path even if file doesn't exist yet
        if let projectRoot = Bundle.main.infoDictionary?["ProjectRoot"] as? String {
            return (projectRoot as NSString).appendingPathComponent(configRel)
        }

        return (Bundle.main.bundlePath as NSString)
            .deletingLastPathComponent
            .appending("/\(configRel)")
    }
}
