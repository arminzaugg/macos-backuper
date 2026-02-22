import SwiftUI

struct StatusTabView: View {
    @Environment(AppState.self) private var appState
    @State private var backupStartTime: Date?
    @State private var cachedRepositoryText: String = "Not configured"

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    statusCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    detailRows
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }

            actionBar
        }
        .onChange(of: appState.currentStatus) { _, newValue in
            if case .running = newValue {
                backupStartTime = Date()
            } else {
                backupStartTime = nil
            }
        }
        .onAppear {
            cachedRepositoryText = loadRepositoryText()
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 10) {
            statusIndicator
            statusLabel
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        let status = appState.currentStatus

        ZStack {
            // Outer glow ring
            Circle()
                .fill(statusColor(for: status).opacity(0.1))
                .frame(width: 64, height: 64)

            // Inner circle
            Circle()
                .fill(statusColor(for: status).opacity(0.15))
                .frame(width: 48, height: 48)

            // Icon
            Image(systemName: status.sfSymbolName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(statusColor(for: status))
                .symbolEffect(.pulse, isActive: isRunning)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch appState.currentStatus {
        case .idle:
            Text("Ready")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

        case .running(let operation):
            VStack(spacing: 4) {
                Text(operation)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)

                if let startTime = backupStartTime {
                    TimelineView(.periodic(from: startTime, by: 1)) { context in
                        let elapsed = context.date.timeIntervalSince(startTime)
                        let minutes = Int(elapsed) / 60
                        let seconds = Int(elapsed) % 60
                        Text("Running for \(minutes):\(String(format: "%02d", seconds))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)

                Button {
                    Task { await appState.backupManager.cancelRunningOperation() }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

        case .success(let date):
            VStack(spacing: 2) {
                Text("Backup Successful")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.green)
                Text(date, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    + Text(" ago")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

        case .error(let message):
            VStack(spacing: 2) {
                Text("Error")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Detail Rows

    private var detailRows: some View {
        VStack(spacing: 1) {
            detailRow(
                icon: "calendar.badge.clock",
                label: "Last Backup",
                value: lastBackupText
            )

            detailRow(
                icon: "clock.arrow.2.circlepath",
                label: "Next Scheduled",
                value: nextScheduledText
            )

            detailRow(
                icon: "externaldrive.connected.to.line.below",
                label: "Repository",
                value: repositoryText
            )
        }
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary.opacity(0.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Button {
                    Task { await appState.backupManager.runBackup() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Backup Now")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isRunning)

                Button {
                    Task { await appState.backupManager.runCheck() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 11, weight: .medium))
                        Text("Verify")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isRunning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Helpers

    private var isRunning: Bool {
        appState.backupManager.isRunning
    }

    private var cardBackground: Color {
        switch appState.currentStatus {
        case .idle: .clear
        case .running: .blue.opacity(0.03)
        case .success: .green.opacity(0.03)
        case .error: .red.opacity(0.03)
        }
    }

    private func statusColor(for status: BackupStatus) -> Color {
        switch status {
        case .idle: .secondary
        case .running: .blue
        case .success: .green
        case .error: .red
        }
    }

    private var lastBackupText: String {
        if let date = appState.backupManager.lastBackupDate {
            return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
        return "Never"
    }

    private var nextScheduledText: String {
        if appState.scheduleManager.isEnabled, let next = appState.scheduleManager.nextFireDate {
            return next.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
        return "Not scheduled"
    }

    private var repositoryText: String {
        cachedRepositoryText
    }

    private func loadRepositoryText() -> String {
        if let config = try? appState.configManager.loadConfig() {
            let repo = config.repository
            // Show just the bucket/path portion for brevity
            if let range = repo.range(of: "//") {
                let afterScheme = repo[range.upperBound...]
                if let slashIndex = afterScheme.firstIndex(of: "/") {
                    return String(afterScheme[slashIndex...])
                }
                return String(afterScheme)
            }
            return repo
        }
        return "Not configured"
    }
}
