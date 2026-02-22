import SwiftUI
import ServiceManagement

struct SettingsTabView: View {
    @Environment(AppState.self) private var appState
    @State private var repository = ""
    @State private var dotfilesDir = ""
    @State private var includePaths: [String] = []
    @State private var excludePaths: [String] = []
    @State private var scheduleTimes: [ScheduleTime] = ScheduleConfig.defaults.times
    @State private var retention = RetentionPolicy.loadFromUserDefaults()
    @State private var launchAtLogin = false
    @State private var loaded = false
    @State private var showSaveConfirmation = false
    @State private var saveError: String?
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                repositorySection
                pathsSection
                scheduleSection
                retentionSection
                keychainSection
                generalSection
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveBar
        }
        .onAppear { loadConfig() }
    }

    // MARK: - Repository

    private var repositorySection: some View {
        SettingsSection(title: "Repository", icon: "externaldrive.connected.to.line.below") {
            TextField("s3:https://storage.example.com/bucket", text: $repository)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.quaternary.opacity(0.5))
                }
        }
    }

    // MARK: - Paths

    private var pathsSection: some View {
        SettingsSection(title: "Paths", icon: "folder") {
            VStack(alignment: .leading, spacing: 10) {
                // Dotfiles
                VStack(alignment: .leading, spacing: 6) {
                    Text("DOTFILES DIRECTORY")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    TextField("e.g. /Users/aza", text: $dotfilesDir)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(6)
                        .background {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(.quaternary.opacity(0.5))
                        }

                    Text("All dotfiles in this directory are auto-discovered at backup time")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Divider()

                // Include
                VStack(alignment: .leading, spacing: 6) {
                    Text("ADDITIONAL INCLUDE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    ForEach(includePaths.indices, id: \.self) { index in
                        pathRow(text: $includePaths[index], placeholder: "/path/to/include") {
                            includePaths.remove(at: index)
                        }
                    }

                    addButton("Add Path") {
                        includePaths.append("")
                    }
                }

                Divider()

                // Exclude
                VStack(alignment: .leading, spacing: 6) {
                    Text("EXCLUDE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    ForEach(excludePaths.indices, id: \.self) { index in
                        pathRow(text: $excludePaths[index], placeholder: "pattern or path") {
                            excludePaths.remove(at: index)
                        }
                    }

                    addButton("Add Pattern") {
                        excludePaths.append("")
                    }
                }
            }
        }
    }

    private func pathRow(text: Binding<String>, placeholder: String, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(6)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.quaternary.opacity(0.5))
                }

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        SettingsSection(title: "Schedule", icon: "clock") {
            VStack(spacing: 10) {
                HStack {
                    Text("Auto-backup")
                        .font(.system(size: 12))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.scheduleManager.isEnabled },
                        set: { newValue in
                            if newValue {
                                appState.scheduleManager.start()
                            } else {
                                appState.scheduleManager.stop()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                if appState.scheduleManager.isEnabled {
                    Divider()

                    ForEach(scheduleTimes.indices, id: \.self) { index in
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)

                            Picker("", selection: $scheduleTimes[index].hour) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text(String(format: "%02d", h)).tag(h)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 56)
                            .onChange(of: scheduleTimes[index].hour) { _, _ in
                                appState.scheduleManager.updateSchedule(ScheduleConfig(times: scheduleTimes))
                            }

                            Text(":")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            Picker("", selection: $scheduleTimes[index].minute) {
                                ForEach(0..<60, id: \.self) { m in
                                    Text(String(format: "%02d", m)).tag(m)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 56)
                            .onChange(of: scheduleTimes[index].minute) { _, _ in
                                appState.scheduleManager.updateSchedule(ScheduleConfig(times: scheduleTimes))
                            }

                            Spacer()

                            Button {
                                scheduleTimes.remove(at: index)
                                appState.scheduleManager.updateSchedule(ScheduleConfig(times: scheduleTimes))
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    addButton("Add Time") {
                        scheduleTimes.append(ScheduleTime(hour: 12, minute: 0))
                    }
                }
            }
        }
    }

    // MARK: - Retention

    private var retentionSection: some View {
        SettingsSection(title: "Retention Policy", icon: "tray.full") {
            VStack(spacing: 8) {
                retentionRow(label: "Daily", value: $retention.keepDaily, range: 1...30)
                retentionRow(label: "Weekly", value: $retention.keepWeekly, range: 1...12)
                retentionRow(label: "Monthly", value: $retention.keepMonthly, range: 1...24)
            }
        }
    }

    private func retentionRow(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 6) {
                Text("\(value.wrappedValue)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(width: 24, alignment: .trailing)
                Stepper("", value: value, in: range)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Keychain

    private var keychainSection: some View {
        SettingsSection(title: "Keychain Credentials", icon: "key") {
            VStack(spacing: 6) {
                keychainRow(label: "Restic Password", service: "client-backup-luza-restic-password")
                keychainRow(label: "AWS Access Key", service: "client-backup-luza-aws-access-key-id")
                keychainRow(label: "AWS Secret Key", service: "client-backup-luza-aws-secret-access-key")
            }
        }
    }

    private func keychainRow(label: String, service: String) -> some View {
        let exists = KeychainManager.checkKeyExists(service: service)
        return HStack(spacing: 8) {
            Image(systemName: exists ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(exists ? .green : .red)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.primary)

            Spacer()

            Text(exists ? "Found" : "Missing")
                .font(.system(size: 11))
                .foregroundStyle(exists ? Color.secondary : Color.red)
        }
    }

    // MARK: - General

    private var generalSection: some View {
        SettingsSection(title: "General", icon: "gearshape") {
            HStack {
                Text("Launch at Login")
                    .font(.system(size: 12))
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
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
    }

    // MARK: - Save Bar

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if let error = saveError {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if showSaveConfirmation {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                        Text("Saved")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if let error = loadError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                Spacer()

                Button {
                    saveConfig()
                } label: {
                    Text("Save Changes")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.background)
    }

    // MARK: - Load / Save

    private func loadConfig() {
        guard !loaded else { return }
        loaded = true

        do {
            let config = try appState.configManager.loadConfig()
            repository = config.repository
            dotfilesDir = config.dotfilesDir ?? ""
            includePaths = config.includePaths
            excludePaths = config.excludePaths
        } catch {
            loadError = "Could not load config. Using defaults."
        }

        retention = RetentionPolicy.loadFromUserDefaults()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func saveConfig() {
        saveError = nil
        let config = BackupConfig(
            repository: repository,
            includePaths: includePaths.filter { !$0.isEmpty },
            excludePaths: excludePaths.filter { !$0.isEmpty },
            dotfilesDir: dotfilesDir.isEmpty ? nil : dotfilesDir
        )
        do {
            try appState.configManager.saveConfig(config)
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                saveError = "Failed to save configuration."
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    saveError = nil
                }
            }
            return
        }

        retention.saveToUserDefaults()

        let scheduleConfig = ScheduleConfig(times: scheduleTimes)
        appState.scheduleManager.updateSchedule(scheduleConfig)

        withAnimation(.easeInOut(duration: 0.2)) {
            showSaveConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSaveConfirmation = false
            }
        }
    }
}

// MARK: - Settings Section Component

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary.opacity(0.3))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.quaternary.opacity(0.5), lineWidth: 0.5)
                }
        }
    }
}
