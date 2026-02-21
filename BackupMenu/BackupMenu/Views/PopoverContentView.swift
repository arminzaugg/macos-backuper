import SwiftUI

struct PopoverContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            StatusTabView()
                .tabItem {
                    Label("Status", systemImage: "house")
                }

            SnapshotsTabView()
                .tabItem {
                    Label("Snapshots", systemImage: "clock.arrow.circlepath")
                }

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .frame(width: 380, height: 480)
    }
}
