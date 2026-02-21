import SwiftUI

@main
struct BackupMenuApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView()
                .environment(appState)
        } label: {
            switch appState.currentStatus {
            case .idle:
                Image(systemName: "externaldrive.fill")
            case .running:
                Image(systemName: "arrow.triangle.2.circlepath")
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.multicolor)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
