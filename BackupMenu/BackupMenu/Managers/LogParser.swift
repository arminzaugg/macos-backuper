import Foundation

struct LogParser {
    struct LogResult {
        let date: Date?
        let success: Bool
        let message: String
    }

    static func parseLastBackupStatus(from logPath: String) throws -> LogResult {
        guard FileManager.default.fileExists(atPath: logPath) else {
            return LogResult(date: nil, success: false, message: "No log file found")
        }

        let content = try String(contentsOfFile: logPath, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").reversed()

        // Find the last status line (INFO about completion or ERROR about failure)
        for line in lines {
            if line.contains("[INFO] Backup completed successfully at ") {
                let dateString = line.replacingOccurrences(
                    of: "[INFO] Backup completed successfully at ",
                    with: ""
                )
                let date = parseDate(dateString)
                return LogResult(date: date, success: true, message: "Backup completed successfully")
            }

            if line.contains("[ERROR]") {
                let message = line.components(separatedBy: "[ERROR] ").last ?? "Unknown error"
                return LogResult(date: nil, success: false, message: message.trimmingCharacters(in: .whitespaces))
            }
        }

        return LogResult(date: nil, success: false, message: "No backup status found in log")
    }

    private static func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        // Format: Thu Jan 15 02:00:05 PST 2025
        formatter.dateFormat = "EEE MMM d HH:mm:ss zzz yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: trimmed)
    }
}
