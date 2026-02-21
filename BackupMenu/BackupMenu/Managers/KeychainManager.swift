import Foundation

struct KeychainManager {
    enum KeychainError: Error, LocalizedError {
        case itemNotFound(service: String)
        case unexpectedError(status: OSStatus)

        var errorDescription: String? {
            switch self {
            case .itemNotFound(let service):
                return "Keychain item not found: \(service)"
            case .unexpectedError(let status):
                return "Keychain error: \(status)"
            }
        }
    }

    static func readPassword(service: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-w"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw KeychainError.itemNotFound(service: service)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let password = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return password
    }

    static func checkKeyExists(service: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-w"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func writePassword(service: String, password: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["add-generic-password", "-s", service, "-a", "", "-w", password, "-U"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw KeychainError.unexpectedError(status: process.terminationStatus)
        }
    }

    static func deletePassword(service: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["delete-generic-password", "-s", service]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw KeychainError.itemNotFound(service: service)
        }
    }

    static func loadBackupSecrets() throws -> [String: String] {
        return [
            "RESTIC_PASSWORD": try readPassword(service: Constants.keychainService(Constants.keychainResticPassword)),
            "AWS_ACCESS_KEY_ID": try readPassword(service: Constants.keychainService(Constants.keychainAWSAccessKey)),
            "AWS_SECRET_ACCESS_KEY": try readPassword(service: Constants.keychainService(Constants.keychainAWSSecretKey)),
        ]
    }
}
