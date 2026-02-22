import SwiftUI
import AppKit

struct PopoverContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: AppTab = .status

    enum AppTab: String, CaseIterable {
        case status = "Status"
        case snapshots = "Snapshots"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .status: "circle.dotted.circle"
            case .snapshots: "clock.arrow.circlepath"
            case .settings: "gearshape"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if appState.needsSetup {
                SetupView()
            } else {
                tabBar
                Divider()
                tabContent
                    .frame(maxHeight: .infinity)
                    .clipped()
                Divider()
                quitButton
            }
        }
        .frame(width: 400, height: 500)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.quaternary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .status:
            StatusTabView()
        case .snapshots:
            SnapshotsTabView()
        case .settings:
            SettingsTabView()
        }
    }

    // MARK: - Quit Button

    private var quitButton: some View {
        HStack {
            Button {
                appState.forceShowSetup = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .medium))
                    Text("Setup")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.tertiary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .medium))
                    Text("Quit BackupMenu")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
