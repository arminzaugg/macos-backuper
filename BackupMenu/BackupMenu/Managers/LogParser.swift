import Foundation

struct LogParser {
    struct LogResult {
        let date: Date?
        let success: Bool
        let message: String
        let rawLine: String?
    }

    static func parseLastBackupStatus(from logPath: String) throws -> LogResult {
        guard FileManager.default.fileExists(atPath: logPath) else {
            return LogResult(date: nil, success: false, message: "No log file found", rawLine: nil)
        }

        let content = try String(contentsOfFile: logPath, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").reversed()

        for line in lines {
            if line.contains("[INFO] Backup completed successfully at ") {
                let dateString = line.replacingOccurrences(
                    of: "[INFO] Backup completed successfully at ",
                    with: ""
                )
                let date = parseDate(dateString)
                return LogResult(date: date, success: true, message: "Backup completed successfully", rawLine: line)
            }

            if line.contains("[ERROR]") {
                let message = line.components(separatedBy: "[ERROR] ").last ?? "Unknown error"
                return LogResult(date: nil, success: false, message: message.trimmingCharacters(in: .whitespaces), rawLine: line)
            }
        }

        return LogResult(date: nil, success: false, message: "No backup status found in log", rawLine: nil)
    }

    static func parseLastCheckStatus(from logPath: String) throws -> LogResult {
        guard FileManager.default.fileExists(atPath: logPath) else {
            return LogResult(date: nil, success: false, message: "No check log file found", rawLine: nil)
        }

        let content = try String(contentsOfFile: logPath, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").reversed()

        for line in lines {
            if line.contains("[INFO]") && line.lowercased().contains("no errors") {
                let date = extractTimestamp(from: line)
                return LogResult(date: date, success: true, message: "Repository check passed", rawLine: line)
            }

            if line.contains("[INFO]") && line.lowercased().contains("check completed") {
                let date = extractTimestamp(from: line)
                return LogResult(date: date, success: true, message: "Repository check completed", rawLine: line)
            }

            if line.contains("[ERROR]") {
                let message = line.components(separatedBy: "[ERROR] ").last ?? "Unknown error"
                return LogResult(date: nil, success: false, message: message.trimmingCharacters(in: .whitespaces), rawLine: line)
            }
        }

        return LogResult(date: nil, success: false, message: "No check status found in log", rawLine: nil)
    }

    // MARK: - Date Parsing

    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "EEE MMM d HH:mm:ss zzz yyyy",      // Thu Jan 15 02:00:05 PST 2025
            "EEE MMM dd HH:mm:ss zzz yyyy",     // Thu Jan 15 02:00:05 PST 2025 (zero-padded day)
            "yyyy-MM-dd HH:mm:ss",               // 2025-01-15 02:00:05
            "yyyy-MM-dd'T'HH:mm:ssZ",            // ISO 8601
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",        // ISO 8601 with milliseconds
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }
    }()

    private static func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        for formatter in dateFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    private static func extractTimestamp(from line: String) -> Date? {
        // Try to find a date-like substring in the line
        // Common pattern: "[2025-01-15 02:00:05]" or just the date after known prefixes
        let patterns = [
            "\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}",
            "\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}",
        ]

        for pattern in patterns {
            if let range = line.range(of: pattern, options: .regularExpression) {
                let candidate = String(line[range])
                if let date = parseDate(candidate) {
                    return date
                }
            }
        }

        return nil
    }
}
