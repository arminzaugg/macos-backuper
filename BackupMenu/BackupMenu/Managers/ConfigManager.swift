import Foundation

final class ConfigManager {
    enum ConfigError: Error, LocalizedError {
        case fileNotFound(path: String)
        case parseError(detail: String)

        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "Config file not found: \(path)"
            case .parseError(let detail):
                return "Config parse error: \(detail)"
            }
        }
    }

    let configPath: String

    var baseDirectory: String {
        // configPath is .../config/restic.env.local, base is two levels up
        (configPath as NSString).deletingLastPathComponent
            .replacingOccurrences(of: "/config", with: "")
    }

    var scriptsDirectory: String {
        baseDirectory + "/scripts"
    }

    init(configPath: String) {
        self.configPath = configPath
    }

    func loadConfig() throws -> BackupConfig {
        guard FileManager.default.fileExists(atPath: configPath) else {
            throw ConfigError.fileNotFound(path: configPath)
        }

        let content = try String(contentsOfFile: configPath, encoding: .utf8)
        let repository = parseRepository(from: content)
        let includePaths = parseBashArray(named: "BACKUP_INCLUDE", from: content)
        let excludePaths = parseBashArray(named: "BACKUP_EXCLUDE", from: content)

        guard let repository else {
            throw ConfigError.parseError(detail: "RESTIC_REPOSITORY not found")
        }

        return BackupConfig(
            repository: repository,
            includePaths: includePaths,
            excludePaths: excludePaths
        )
    }

    func saveConfig(_ config: BackupConfig) throws {
        var lines: [String] = []

        // Preserve comment header if the file exists
        if FileManager.default.fileExists(atPath: configPath) {
            let existing = try String(contentsOfFile: configPath, encoding: .utf8)
            for line in existing.components(separatedBy: "\n") {
                if line.hasPrefix("#") || line.trimmingCharacters(in: .whitespaces).isEmpty {
                    lines.append(line)
                } else {
                    break
                }
            }
        }

        lines.append("export RESTIC_REPOSITORY=\"\(config.repository)\"")
        lines.append("")
        lines.append("BACKUP_INCLUDE=(")
        for path in config.includePaths {
            lines.append("  \"\(path)\"")
        }
        lines.append(")")
        lines.append("")
        lines.append("BACKUP_EXCLUDE=(")
        for path in config.excludePaths {
            lines.append("  \"\(path)\"")
        }
        lines.append(")")
        lines.append("")

        let output = lines.joined(separator: "\n")
        try output.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    func buildEnvironment() throws -> [String: String] {
        let config = try loadConfig()
        var env = try KeychainManager.loadBackupSecrets()
        env["RESTIC_REPOSITORY"] = config.repository
        return env
    }

    // MARK: - Parsing

    private func parseRepository(from content: String) -> String? {
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("export RESTIC_REPOSITORY=") || trimmed.hasPrefix("RESTIC_REPOSITORY=") {
                // Extract value between quotes
                if let start = trimmed.firstIndex(of: "\""),
                   let end = trimmed[trimmed.index(after: start)...].firstIndex(of: "\"") {
                    return String(trimmed[trimmed.index(after: start)..<end])
                }
            }
        }
        return nil
    }

    private func parseBashArray(named name: String, from content: String) -> [String] {
        var results: [String] = []
        var inArray = false

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("\(name)=(") {
                inArray = true
                // Check if single-line array
                if trimmed.hasSuffix(")") {
                    let inner = trimmed
                        .replacingOccurrences(of: "\(name)=(", with: "")
                        .dropLast()
                    results.append(contentsOf: extractQuotedStrings(from: String(inner)))
                    inArray = false
                }
                continue
            }

            if inArray {
                if trimmed == ")" {
                    inArray = false
                    continue
                }
                results.append(contentsOf: extractQuotedStrings(from: trimmed))
            }
        }

        return results
    }

    private func extractQuotedStrings(from line: String) -> [String] {
        var results: [String] = []
        var current = line[...]

        while let start = current.firstIndex(of: "\"") {
            let afterStart = current.index(after: start)
            guard afterStart < current.endIndex,
                  let end = current[afterStart...].firstIndex(of: "\"") else { break }
            results.append(String(current[afterStart..<end]))
            current = current[current.index(after: end)...]
        }

        return results
    }
}
