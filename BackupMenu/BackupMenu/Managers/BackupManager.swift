import Foundation
import Observation

enum BackupError: Error, LocalizedError {
    case scriptNotFound(path: String)
    case configurationError(detail: String)
    case networkError(detail: String)
    case timeout
    case resticError(code: Int32, output: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .scriptNotFound(let path):
            return "Script not found: \(path)"
        case .configurationError(let detail):
            return "Configuration error: \(detail)"
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .timeout:
            return "Operation timed out"
        case .resticError(let code, let output):
            let truncated = output.suffix(200)
            return "Restic failed (exit \(code)): \(truncated)"
        case .cancelled:
            return "Operation was cancelled"
        }
    }
}

@Observable
final class BackupManager {
    var status: BackupStatus = .idle
    var lastBackupDate: Date?
    var snapshots: [Snapshot] = []
    var lastError: BackupError?
    var backupDuration: TimeInterval?

    var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    let scriptRunner = ScriptRunner()
    let configManager: ConfigManager

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    func cancelRunningOperation() async {
        await scriptRunner.cancel()
        status = .error(message: userFriendlyMessage(for: .cancelled))
    }

    func userFriendlyMessage(for error: BackupError) -> String {
        switch error {
        case .scriptNotFound:
            return "Backup script not found. Make sure the app is configured correctly in Settings."
        case .configurationError(let msg):
            return "Configuration error: \(msg). Check Settings to fix."
        case .timeout:
            return "The operation timed out after 30 minutes. Check your network connection."
        case .resticError(code: 1, _):
            return "Connection failed. Check your internet and repository URL."
        case .resticError(code: 3, _):
            return "Repository not initialized. Run setup from Settings."
        case .resticError(let code, _):
            return "Backup failed (error \(code)). Check logs for details."
        case .cancelled:
            return "Operation was cancelled."
        case .networkError(let detail):
            return "Network error: \(detail). Check your internet connection."
        }
    }

    func initializeRepository() async -> (success: Bool, message: String) {
        do {
            let env = try configManager.buildEnvironment()
            let result = try await scriptRunner.runRestic(
                arguments: ["init"],
                environment: env
            )
            if result.exitCode == 0 {
                return (true, "Repository initialized successfully.")
            } else {
                // Exit code 1 with "already initialized" is not an error
                if result.output.contains("already initialized") {
                    return (true, "Repository already initialized.")
                }
                return (false, "Init failed (exit \(result.exitCode)): \(String(result.output.suffix(200)))")
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }

    func runBackup() async {
        guard !isRunning else { return }
        status = .running(operation: "Backup")
        lastError = nil
        let startTime = Date()

        do {
            let env = try configManager.buildEnvironment()
            let scriptPath = configManager.scriptsDirectory + "/backup.sh"

            guard FileManager.default.fileExists(atPath: scriptPath) else {
                let error = BackupError.scriptNotFound(path: scriptPath)
                lastError = error
                status = .error(message: userFriendlyMessage(for: error))
                return
            }

            let result = try await scriptRunner.runScript(at: scriptPath, environment: env)
            backupDuration = Date().timeIntervalSince(startTime)

            if result.exitCode == 0 {
                let logResult = try LogParser.parseLastBackupStatus(from: Constants.backupLogPath)
                lastBackupDate = logResult.date ?? Date()
                status = .success(date: lastBackupDate ?? Date())
            } else {
                let error = BackupError.resticError(code: result.exitCode, output: result.output)
                lastError = error
                status = .error(message: userFriendlyMessage(for: error))
            }
        } catch let error as ScriptRunner.ScriptRunnerError {
            backupDuration = Date().timeIntervalSince(startTime)
            let backupError: BackupError
            switch error {
            case .timeout:
                backupError = .timeout
            case .resticNotFound:
                backupError = .configurationError(detail: error.localizedDescription)
            }
            lastError = backupError
            status = .error(message: userFriendlyMessage(for: backupError))
        } catch {
            backupDuration = Date().timeIntervalSince(startTime)
            let backupError = BackupError.configurationError(detail: error.localizedDescription)
            lastError = backupError
            status = .error(message: userFriendlyMessage(for: backupError))
        }
    }

    func runCheck() async {
        guard !isRunning else { return }
        status = .running(operation: "Integrity Check")
        lastError = nil

        do {
            let env = try configManager.buildEnvironment()
            let scriptPath = configManager.scriptsDirectory + "/check.sh"

            guard FileManager.default.fileExists(atPath: scriptPath) else {
                let error = BackupError.scriptNotFound(path: scriptPath)
                lastError = error
                status = .error(message: userFriendlyMessage(for: error))
                return
            }

            let result = try await scriptRunner.runScript(at: scriptPath, environment: env)

            if result.exitCode == 0 {
                status = .success(date: Date())
            } else {
                let error = BackupError.resticError(code: result.exitCode, output: result.output)
                lastError = error
                status = .error(message: userFriendlyMessage(for: error))
            }
        } catch let error as ScriptRunner.ScriptRunnerError {
            let backupError: BackupError
            switch error {
            case .timeout:
                backupError = .timeout
            case .resticNotFound:
                backupError = .configurationError(detail: error.localizedDescription)
            }
            lastError = backupError
            status = .error(message: userFriendlyMessage(for: backupError))
        } catch {
            let backupError = BackupError.configurationError(detail: error.localizedDescription)
            lastError = backupError
            status = .error(message: userFriendlyMessage(for: backupError))
        }
    }

    func loadSnapshots() async {
        do {
            let env = try configManager.buildEnvironment()
            let result = try await scriptRunner.runRestic(
                arguments: ["snapshots", "--json"],
                environment: env
            )

            guard result.exitCode == 0 else {
                let error = BackupError.resticError(code: result.exitCode, output: result.output)
                lastError = error
                status = .error(message: userFriendlyMessage(for: error))
                return
            }

            guard let data = result.output.data(using: .utf8) else { return }
            var decoded = try Snapshot.dateDecoder.decode([Snapshot].self, from: data)
            decoded.sort { $0.time > $1.time }
            snapshots = decoded
        } catch {
            let backupError = BackupError.configurationError(detail: error.localizedDescription)
            lastError = backupError
            status = .error(message: userFriendlyMessage(for: backupError))
        }
    }

    func forgetSnapshot(id: String) async {
        guard !isRunning else { return }
        status = .running(operation: "Removing Snapshot")
        lastError = nil

        do {
            let env = try configManager.buildEnvironment()
            let result = try await scriptRunner.runRestic(
                arguments: ["forget", id, "--prune"],
                environment: env
            )

            if result.exitCode == 0 {
                status = .success(date: Date())
                await loadSnapshots()
            } else {
                let error = BackupError.resticError(code: result.exitCode, output: result.output)
                lastError = error
                status = .error(message: userFriendlyMessage(for: error))
            }
        } catch {
            let backupError = BackupError.configurationError(detail: error.localizedDescription)
            lastError = backupError
            status = .error(message: userFriendlyMessage(for: backupError))
        }
    }

    func forgetWithPolicy(policy: RetentionPolicy) async {
        guard !isRunning else { return }
        status = .running(operation: "Pruning Snapshots")
        lastError = nil

        do {
            let env = try configManager.buildEnvironment()
            let result = try await scriptRunner.runRestic(
                arguments: [
                    "forget",
                    "--keep-daily", String(policy.keepDaily),
                    "--keep-weekly", String(policy.keepWeekly),
                    "--keep-monthly", String(policy.keepMonthly),
                    "--prune",
                ],
                environment: env
            )

            if result.exitCode == 0 {
                status = .success(date: Date())
                await loadSnapshots()
            } else {
                let error = BackupError.resticError(code: result.exitCode, output: result.output)
                lastError = error
                status = .error(message: userFriendlyMessage(for: error))
            }
        } catch {
            let backupError = BackupError.configurationError(detail: error.localizedDescription)
            lastError = backupError
            status = .error(message: userFriendlyMessage(for: backupError))
        }
    }
}
