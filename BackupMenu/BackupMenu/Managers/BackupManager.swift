import Foundation
import Observation

@Observable
final class BackupManager {
    var status: BackupStatus = .idle
    var lastBackupDate: Date?
    var snapshots: [Snapshot] = []

    var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    private let scriptRunner = ScriptRunner()
    let configManager: ConfigManager

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    func runBackup() async {
        guard !isRunning else { return }
        status = .running(operation: "Backup")

        do {
            let env = try configManager.buildEnvironment()
            let scriptPath = configManager.scriptsDirectory + "/backup.sh"
            let result = try await scriptRunner.runScript(at: scriptPath, environment: env)

            if result.exitCode == 0 {
                let logPath = NSHomeDirectory() + "/Library/Logs/backup.log"
                let logResult = try LogParser.parseLastBackupStatus(from: logPath)
                lastBackupDate = logResult.date ?? Date()
                status = .success(date: lastBackupDate ?? Date())
            } else {
                status = .error(message: "Backup failed with exit code \(result.exitCode)")
            }
        } catch {
            status = .error(message: error.localizedDescription)
        }
    }

    func runCheck() async {
        guard !isRunning else { return }
        status = .running(operation: "Integrity Check")

        do {
            let env = try configManager.buildEnvironment()
            let scriptPath = configManager.scriptsDirectory + "/check.sh"
            let result = try await scriptRunner.runScript(at: scriptPath, environment: env)

            if result.exitCode == 0 {
                status = .success(date: Date())
            } else {
                status = .error(message: "Check failed with exit code \(result.exitCode)")
            }
        } catch {
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
                status = .error(message: "Failed to load snapshots")
                return
            }

            guard let data = result.output.data(using: .utf8) else { return }
            snapshots = try Snapshot.dateDecoder.decode([Snapshot].self, from: data)
        } catch {
            status = .error(message: error.localizedDescription)
        }
    }

    func forgetSnapshot(id: String) async {
        guard !isRunning else { return }
        status = .running(operation: "Removing Snapshot")

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
                status = .error(message: "Failed to remove snapshot")
            }
        } catch {
            status = .error(message: error.localizedDescription)
        }
    }

    func forgetWithPolicy(policy: RetentionPolicy) async {
        guard !isRunning else { return }
        status = .running(operation: "Pruning Snapshots")

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
                status = .error(message: "Prune failed with exit code \(result.exitCode)")
            }
        } catch {
            status = .error(message: error.localizedDescription)
        }
    }
}
