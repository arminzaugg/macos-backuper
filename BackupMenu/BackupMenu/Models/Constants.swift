import Foundation

enum Constants {
    static let keychainResticPassword = "restic-password"
    static let keychainAWSAccessKey = "aws-access-key-id"
    static let keychainAWSSecretKey = "aws-secret-access-key"

    static let backupLogPath = NSHomeDirectory() + "/Library/Logs/backup.log"
    static let checkLogPath = NSHomeDirectory() + "/Library/Logs/backup-check.log"
    static let pruneLogPath = NSHomeDirectory() + "/Library/Logs/backup-prune.log"

    static let userDefaultsScheduleKey = "backupSchedule"
    static let userDefaultsRetentionKey = "retentionPolicy"
    static let userDefaultsKeychainPrefixKey = "keychainPrefix"

    static let defaultKeychainPrefix = "client-backup-luza"

    static let minimumBackupInterval: TimeInterval = 60 * 60
    static let scheduleCheckInterval: TimeInterval = 30

    static func keychainService(_ key: String, prefix: String? = nil) -> String {
        let p = prefix ?? UserDefaults.standard.string(forKey: userDefaultsKeychainPrefixKey) ?? defaultKeychainPrefix
        return "\(p)-\(key)"
    }
}
