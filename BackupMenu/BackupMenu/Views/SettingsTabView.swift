import SwiftUI
import ServiceManagement

struct SettingsTabView: View {
    @Environment(AppState.self) private var appState
    @State private var repository = ""
    @State private var includePaths: [String] = []
    @State private var excludePaths: [String] = []
    @State private var scheduleTimes: [ScheduleTime] = ScheduleConfig.defaults.times
    @State private var retention = RetentionPolicy.defaults
    @State private var launchAtLogin = false
    @State private var loaded = false

    var body: some View {
        Form {
            repositorySection
            includePathsSection
            excludePathsSection
            scheduleSection
            retentionSection
            keychainSection
            launchAtLoginSection
        }
        .formStyle(.grouped)
        .onAppear { loadConfig() }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveConfig() }
            }
        }
    }

    // MARK: - Repository

    private var repositorySection: some View {
        Section("Repository") {
            TextField("s3:https://...", text: $repository)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Include Paths

    private var includePathsSection: some View {
        Section("Include Paths") {
            ForEach(includePaths.indices, id: \.self) { index in
                HStack {
                    TextField("/path/to/include", text: $includePaths[index])
                        .textFieldStyle(.roundedBorder)
                    Button(role: .destructive) {
                        includePaths.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
            Button {
                includePaths.append("")
            } label: {
                Label("Add Path", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - Exclude Paths

    private var excludePathsSection: some View {
        Section("Exclude Paths") {
            ForEach(excludePaths.indices, id: \.self) { index in
                HStack {
                    TextField("pattern or path", text: $excludePaths[index])
                        .textFieldStyle(.roundedBorder)
                    Button(role: .destructive) {
                        excludePaths.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
            Button {
                excludePaths.append("")
            } label: {
                Label("Add Pattern", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section("Schedule") {
            @Bindable var schedule = appState.scheduleManager
            Toggle("Enable Schedule", isOn: Binding(
                get: { appState.scheduleManager.isEnabled },
                set: { newValue in
                    if newValue {
                        appState.scheduleManager.start()
                    } else {
                        appState.scheduleManager.stop()
                    }
                }
            ))

            ForEach(scheduleTimes.indices, id: \.self) { index in
                HStack {
                    Picker("Hour", selection: $scheduleTimes[index].hour) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%02d", h)).tag(h)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 60)

                    Text(":")

                    Picker("Minute", selection: $scheduleTimes[index].minute) {
                        ForEach(0..<60, id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 60)

                    Spacer()

                    Button(role: .destructive) {
                        scheduleTimes.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }

            Button {
                scheduleTimes.append(ScheduleTime(hour: 12, minute: 0))
            } label: {
                Label("Add Time", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - Retention

    private var retentionSection: some View {
        Section("Retention Policy") {
            Stepper("Daily: \(retention.keepDaily)", value: $retention.keepDaily, in: 1...30)
            Stepper("Weekly: \(retention.keepWeekly)", value: $retention.keepWeekly, in: 1...12)
            Stepper("Monthly: \(retention.keepMonthly)", value: $retention.keepMonthly, in: 1...24)
        }
    }

    // MARK: - Keychain

    private var keychainSection: some View {
        Section("Keychain Status") {
            keychainRow(label: "Restic Password", service: "client-backup-luza-restic-password")
            keychainRow(label: "AWS Access Key", service: "client-backup-luza-aws-access-key-id")
            keychainRow(label: "AWS Secret Key", service: "client-backup-luza-aws-secret-access-key")
        }
    }

    private func keychainRow(label: String, service: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            if KeychainManager.checkKeyExists(service: service) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Launch at Login

    private var launchAtLoginSection: some View {
        Section {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = !newValue
                    }
                }
        }
    }

    // MARK: - Load / Save

    private func loadConfig() {
        guard !loaded else { return }
        loaded = true

        do {
            let config = try appState.configManager.loadConfig()
            repository = config.repository
            includePaths = config.includePaths
            excludePaths = config.excludePaths
        } catch {
            // Use empty defaults on first load failure
        }

        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func saveConfig() {
        let config = BackupConfig(
            repository: repository,
            includePaths: includePaths.filter { !$0.isEmpty },
            excludePaths: excludePaths.filter { !$0.isEmpty }
        )
        do {
            try appState.configManager.saveConfig(config)
        } catch {
            // Save failed silently for now
        }

        let scheduleConfig = ScheduleConfig(times: scheduleTimes)
        appState.scheduleManager.updateSchedule(scheduleConfig)
    }
}
