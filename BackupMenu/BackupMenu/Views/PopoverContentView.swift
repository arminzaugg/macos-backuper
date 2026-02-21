import SwiftUI

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
            tabBar
            Divider()
            tabContent
        }
        .frame(width: 400, height: 500)
        .background(.background)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
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
                .transition(.opacity)
        case .snapshots:
            SnapshotsTabView()
                .transition(.opacity)
        case .settings:
            SettingsTabView()
                .transition(.opacity)
        }
    }
}
