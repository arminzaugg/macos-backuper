import SwiftUI

struct StatusTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            statusIcon
            statusMessage

            Divider()

            infoSection

            Divider()

            actionButtons

            Spacer()
        }
        .padding()
    }

    // MARK: - Status Display

    @ViewBuilder
    private var statusIcon: some View {
        let status = appState.currentStatus
        Image(systemName: status.sfSymbolName)
            .font(.system(size: 48))
            .foregroundStyle(iconColor(for: status))
            .symbolEffect(.pulse, isActive: isRunning)
    }

    @ViewBuilder
    private var statusMessage: some View {
        switch appState.currentStatus {
        case .idle:
            Text("Idle")
                .font(.headline)
                .foregroundStyle(.secondary)
        case .running(let operation):
            Text(operation)
                .font(.headline)
                .foregroundStyle(.blue)
        case .success(let date):
            Text("Backup Successful")
                .font(.headline)
                .foregroundStyle(.green)
            Text(date, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        case .error(let message):
            Text("Error")
                .font(.headline)
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Last Backup")
                    .foregroundStyle(.secondary)
                Spacer()
                if let date = appState.backupManager.lastBackupDate {
                    Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                } else {
                    Text("Never")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Next Scheduled")
                    .foregroundStyle(.secondary)
                Spacer()
                if appState.scheduleManager.isEnabled, let next = appState.scheduleManager.nextFireDate {
                    Text(next, format: .dateTime.month(.abbreviated).day().hour().minute())
                } else {
                    Text("Not scheduled")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.callout)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Task { await appState.backupManager.runBackup() }
            } label: {
                Label("Backup Now", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRunning)

            Button {
                Task { await appState.backupManager.runCheck() }
            } label: {
                Label("Check", systemImage: "checkmark.shield")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isRunning)
        }
    }

    // MARK: - Helpers

    private var isRunning: Bool {
        appState.backupManager.isRunning
    }

    private func iconColor(for status: BackupStatus) -> Color {
        switch status {
        case .idle: .secondary
        case .running: .blue
        case .success: .green
        case .error: .red
        }
    }
}
