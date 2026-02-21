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

    private let scriptRunner = ScriptRunner()
    let configManager: ConfigManager

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    func cancelRunningOperation() async {
        await scriptRunner.cancel()
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
                status = .error(message: error.localizedDescription)
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
                status = .error(message: error.localizedDescription)
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
            status = .error(message: backupError.localizedDescription)
        } catch {
            backupDuration = Date().timeIntervalSince(startTime)
            lastError = .configurationError(detail: error.localizedDescription)
            status = .error(message: error.localizedDescription)
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
                status = .error(message: error.localizedDescription)
                return
            }

            let result = try await scriptRunner.runScript(at: scriptPath, environment: env)

            if result.exitCode == 0 {
                status = .success(date: Date())
            } else {
                let error = BackupError.resticError(code: result.exitCode, output: result.output)
                lastError = error
                status = .error(message: error.localizedDescription)
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
            status = .error(message: backupError.localizedDescription)
        } catch {
            lastError = .configurationError(detail: error.localizedDescription)
            status = .error(message: error.localizedDescription)
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
                status = .error(message: "Failed to load snapshots")
                return
            }

            guard let data = result.output.data(using: .utf8) else { return }
            snapshots = try Snapshot.dateDecoder.decode([Snapshot].self, from: data)
        } catch {
            lastError = .configurationError(detail: error.localizedDescription)
            status = .error(message: error.localizedDescription)
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
                status = .error(message: "Failed to remove snapshot")
            }
        } catch {
            lastError = .configurationError(detail: error.localizedDescription)
            status = .error(message: error.localizedDescription)
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
                status = .error(message: "Prune failed with exit code \(result.exitCode)")
            }
        } catch {
            lastError = .configurationError(detail: error.localizedDescription)
            status = .error(message: error.localizedDescription)
        }
    }
}
