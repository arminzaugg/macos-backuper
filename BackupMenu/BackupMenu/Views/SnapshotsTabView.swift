import SwiftUI

struct SnapshotsTabView: View {
    @Environment(AppState.self) private var appState
    @State private var snapshotToForget: Snapshot?
    @State private var showRetentionConfirm = false

    private var backupManager: BackupManager {
        appState.backupManager
    }

    var body: some View {
        VStack(spacing: 0) {
            if showRetentionConfirm {
                retentionConfirmView
            } else if let snapshot = snapshotToForget {
                forgetConfirmView(snapshot)
            } else {
                snapshotList
            }

            Divider()

            bottomBar
        }
        .onAppear {
            Task { await backupManager.loadSnapshots() }
        }
    }

    // MARK: - Inline Confirmation: Forget Snapshot

    private func forgetConfirmView(_ snapshot: Snapshot) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "trash.circle")
                .font(.system(size: 36))
                .foregroundStyle(.red)
            Text("Forget Snapshot?")
                .font(.headline)
            Text("This will permanently remove snapshot \(snapshot.id). This cannot be undone.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            HStack(spacing: 12) {
                Button("Cancel") {
                    snapshotToForget = nil
                }
                .keyboardShortcut(.cancelAction)
                Button("Forget", role: .destructive) {
                    let id = snapshot.id
                    snapshotToForget = nil
                    Task { await backupManager.forgetSnapshot(id: id) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Inline Confirmation: Retention Policy

    private var retentionConfirmView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "scissors.circle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("Apply Retention Policy?")
                .font(.headline)
            Text("Remove snapshots outside policy (keep 7 daily, 4 weekly, 6 monthly) and prune unused data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            HStack(spacing: 12) {
                Button("Cancel") {
                    showRetentionConfirm = false
                }
                .keyboardShortcut(.cancelAction)
                Button("Apply", role: .destructive) {
                    showRetentionConfirm = false
                    Task { await backupManager.forgetWithPolicy(policy: .defaults) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Snapshot List

    private var snapshotList: some View {
        Group {
            if backupManager.snapshots.isEmpty {
                ContentUnavailableView {
                    Label("No Snapshots", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("No backup snapshots found.")
                }
            } else {
                List(backupManager.snapshots) { snapshot in
                    snapshotRow(snapshot)
                        .contextMenu {
                            Button(role: .destructive) {
                                snapshotToForget = snapshot
                            } label: {
                                Label("Forget Snapshot", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func snapshotRow(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(snapshot.id)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Spacer()
                Text(snapshot.time, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(snapshot.paths.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button {
                Task { await backupManager.loadSnapshots() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(backupManager.isRunning)

            Spacer()

            Button {
                showRetentionConfirm = true
            } label: {
                Label("Apply Retention Policy", systemImage: "scissors")
            }
            .disabled(backupManager.isRunning)
        }
        .padding(12)
    }
}
