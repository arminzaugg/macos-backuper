import Foundation

actor ScriptRunner {
    struct RunResult {
        let exitCode: Int32
        let output: String
    }

    private let resticPath: String

    init() {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/restic") {
            self.resticPath = "/opt/homebrew/bin/restic"
        } else {
            self.resticPath = "/usr/local/bin/restic"
        }
    }

    func runScript(at path: String, environment: [String: String]) async throws -> RunResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [path]
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        return try await run(process)
    }

    func runRestic(arguments: [String], environment: [String: String]) async throws -> RunResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resticPath)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        return try await run(process)
    }

    private func run(_ process: Process) async throws -> RunResult {
        try await withCheckedThrowingContinuation { continuation in
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: RunResult(
                    exitCode: process.terminationStatus,
                    output: output
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
