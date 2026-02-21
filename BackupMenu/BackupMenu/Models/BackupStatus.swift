import Foundation

enum BackupStatus: Equatable {
    case idle
    case running(operation: String)
    case success(date: Date)
    case error(message: String)

    var sfSymbolName: String {
        switch self {
        case .idle:
            return "externaldrive.fill"
        case .running:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}
