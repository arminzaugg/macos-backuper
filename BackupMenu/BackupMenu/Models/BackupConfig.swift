import Foundation

struct BackupConfig {
    let repository: String
    let includePaths: [String]
    let excludePaths: [String]
    var dotfilesDir: String?
}
