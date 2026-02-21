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
                snapshotContent
            }

            bottomBar
        }
        .onAppear {
            Task { await backupManager.loadSnapshots() }
        }
    }

    // MARK: - Main Content

    private var snapshotContent: some View {
        Group {
            if backupManager.snapshots.isEmpty {
                emptyState
            } else {
                snapshotList
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.quaternary)

            Text("No Snapshots")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Run a backup to create your first snapshot.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Snapshot List

    private var snapshotList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(backupManager.snapshots) { snapshot in
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func snapshotRow(_ snapshot: Snapshot) -> some View {
        HStack(spacing: 10) {
            // Date column
            VStack(alignment: .center, spacing: 0) {
                Text(snapshot.time.formatted(.dateTime.day()))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(snapshot.time.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .frame(width: 38)

            // Separator
            RoundedRectangle(cornerRadius: 0.5)
                .fill(.quaternary)
                .frame(width: 1, height: 28)

            // Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(snapshot.id)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(snapshot.time.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(snapshot.paths.joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.background)
        }
    }

    // MARK: - Forget Confirmation

    private func forgetConfirmView(_ snapshot: Snapshot) -> some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.red.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: "trash")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.red)
            }

            VStack(spacing: 4) {
                Text("Forget Snapshot?")
                    .font(.system(size: 15, weight: .semibold))
                Text("Snapshot ")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                + Text(snapshot.id)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                + Text(" will be permanently removed.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            HStack(spacing: 10) {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        snapshotToForget = nil
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .keyboardShortcut(.cancelAction)

                Button("Forget") {
                    let id = snapshot.id
                    withAnimation(.easeInOut(duration: 0.2)) {
                        snapshotToForget = nil
                    }
                    Task { await backupManager.forgetSnapshot(id: id) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Retention Confirmation

    private var retentionConfirmView: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.orange.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: "scissors")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 4) {
                Text("Apply Retention Policy?")
                    .font(.system(size: 15, weight: .semibold))
                Text("Keep 7 daily, 4 weekly, 6 monthly snapshots. Older snapshots and unused data will be removed.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 10) {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRetentionConfirm = false
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRetentionConfirm = false
                    }
                    Task { await backupManager.forgetWithPolicy(policy: .defaults) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.regular)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button {
                    Task { await backupManager.loadSnapshots() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                        Text("Refresh")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(backupManager.isRunning)

                if !backupManager.snapshots.isEmpty {
                    Text("\(backupManager.snapshots.count) snapshot\(backupManager.snapshots.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRetentionConfirm = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "scissors")
                            .font(.system(size: 11, weight: .medium))
                        Text("Prune")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(backupManager.isRunning || backupManager.snapshots.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
