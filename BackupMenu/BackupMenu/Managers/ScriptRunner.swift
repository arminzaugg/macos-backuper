import Foundation

actor ScriptRunner {
    struct RunResult {
        let exitCode: Int32
        let output: String
    }

    enum ScriptRunnerError: Error, LocalizedError {
        case resticNotFound
        case timeout(seconds: TimeInterval)

        var errorDescription: String? {
            switch self {
            case .resticNotFound:
                return "Restic binary not found. Install via: brew install restic"
            case .timeout(let seconds):
                return "Process timed out after \(Int(seconds)) seconds"
            }
        }
    }

    private var resticPath: String?
    private var currentProcess: Process?

    private static let defaultTimeout: TimeInterval = 30 * 60 // 30 minutes

    func runScript(at path: String, environment: [String: String], timeout: TimeInterval = defaultTimeout) async throws -> RunResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [path]
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        return try await run(process, timeout: timeout)
    }

    func runRestic(arguments: [String], environment: [String: String], timeout: TimeInterval = defaultTimeout) async throws -> RunResult {
        let path = try resolveResticPath()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        return try await run(process, timeout: timeout)
    }

    func cancel() {
        if let process = currentProcess, process.isRunning {
            process.terminate()
        }
        currentProcess = nil
    }

    // MARK: - Private

    private func resolveResticPath() throws -> String {
        if let cached = resticPath {
            return cached
        }

        let candidates = [
            "/opt/homebrew/bin/restic",
            "/usr/local/bin/restic",
        ]

        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                resticPath = candidate
                return candidate
            }
        }

        // Fallback: try `which restic`
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        whichProcess.arguments = ["-c", "which restic"]
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        whichProcess.standardError = Pipe()

        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            if whichProcess.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                    resticPath = path
                    return path
                }
            }
        } catch {
            // Fall through to error
        }

        throw ScriptRunnerError.resticNotFound
    }

    private func run(_ process: Process, timeout: TimeInterval) async throws -> RunResult {
        currentProcess = process

        return try await withCheckedThrowingContinuation { continuation in
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            var didResume = false
            let lock = NSLock()

            func resumeOnce(with result: Result<RunResult, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            // Timeout handler
            let timeoutWorkItem = DispatchWorkItem { [weak process] in
                guard let process, process.isRunning else { return }
                process.terminate()
                resumeOnce(with: .failure(ScriptRunnerError.timeout(seconds: timeout)))
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)

            process.terminationHandler = { _ in
                timeoutWorkItem.cancel()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                resumeOnce(with: .success(RunResult(
                    exitCode: process.terminationStatus,
                    output: output
                )))
            }

            do {
                try process.run()
            } catch {
                timeoutWorkItem.cancel()
                resumeOnce(with: .failure(error))
            }
        }
    }
}
