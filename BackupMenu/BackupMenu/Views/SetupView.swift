import SwiftUI
import AppKit

struct SetupView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0
    @State private var resticFound = false

    // Step 2 - Repository
    @State private var repositoryURL = ""

    // Step 3 - Credentials
    @State private var resticPassword = ""
    @State private var awsAccessKey = ""
    @State private var awsSecretKey = ""
    @State private var credentialsSaved = false
    @State private var credentialError: String?

    // Step 4 - Backup Paths
    @State private var includePaths: [String] = []
    @State private var newExcludePattern = ""
    @State private var excludePaths: [String] = [
        "Library",
        ".Trash",
        ".tmp",
        "node_modules",
    ]

    // Step 5 - Ready
    @State private var initResult: String?
    @State private var isInitializing = false
    @State private var initSuccess = false

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            navigationBar
        }
        .frame(width: 400, height: 500)
        .background(.background)
        .onAppear {
            resticFound = appState.isResticInstalled
            // Pre-populate default include paths
            let home = NSHomeDirectory()
            includePaths = [
                home + "/Documents",
                home + "/Desktop",
            ]
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step == currentStep ? Color.accentColor : (step < currentStep ? Color.green : Color.secondary.opacity(0.3)))
                    .frame(width: 8, height: 8)
                    .overlay {
                        if step < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 5, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: repositoryStep
                case 2: credentialsStep
                case 3: pathsStep
                case 4: readyStep
                default: EmptyView()
                }
            }
            .padding(16)
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.fill.badge.shield.radiations")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
                .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Welcome to BackupMenu")
                    .font(.system(size: 18, weight: .semibold))

                Text("Encrypted backups for your Mac using Restic, stored on S3-compatible storage.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            setupCard {
                HStack(spacing: 10) {
                    Image(systemName: resticFound ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(resticFound ? .green : .red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Restic")
                            .font(.system(size: 13, weight: .medium))
                        Text(resticFound ? "Installed and ready" : "Not found. Install via: brew install restic")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !resticFound {
                        Button("Recheck") {
                            resticFound = appState.isResticInstalled
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            if !resticFound {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("You can continue, but backups will not run without Restic.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Step 2: Repository

    private var repositoryStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)

                Text("Repository URL")
                    .font(.system(size: 16, weight: .semibold))

                Text("Enter the S3-compatible storage URL where your backups will be stored.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            setupCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("REPOSITORY URL")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    TextField("s3:https://s3.us-west-002.backblazeb2.com/my-bucket", text: $repositoryURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.quaternary.opacity(0.5))
                        }

                    Text("Format: s3:https://hostname/bucket-name")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Step 3: Credentials

    private var credentialsStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "key.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)

                Text("Credentials")
                    .font(.system(size: 16, weight: .semibold))

                Text("These are stored securely in your macOS Keychain.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            setupCard {
                VStack(spacing: 12) {
                    credentialField(label: "RESTIC PASSWORD", text: $resticPassword, placeholder: "Encryption password for your backups")
                    Divider()
                    credentialField(label: "AWS ACCESS KEY ID", text: $awsAccessKey, placeholder: "Access key for S3 storage")
                    Divider()
                    credentialField(label: "AWS SECRET ACCESS KEY", text: $awsSecretKey, placeholder: "Secret key for S3 storage")
                }
            }

            if let error = credentialError {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }

            Button {
                saveCredentials()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: credentialsSaved ? "checkmark.circle.fill" : "lock.shield")
                        .font(.system(size: 12))
                    Text(credentialsSaved ? "Saved to Keychain" : "Save to Keychain")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(resticPassword.isEmpty || awsAccessKey.isEmpty || awsSecretKey.isEmpty)
            .tint(credentialsSaved ? .green : .blue)
        }
    }

    private func credentialField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.quaternary.opacity(0.5))
                }
        }
    }

    // MARK: - Step 4: Backup Paths

    private var pathsStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)

                Text("Backup Paths")
                    .font(.system(size: 16, weight: .semibold))

                Text("Choose which folders to back up and which to skip.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            setupCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("INCLUDE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    ForEach(includePaths.indices, id: \.self) { index in
                        pathRow(path: includePaths[index]) {
                            includePaths.remove(at: index)
                        }
                    }

                    Button {
                        openFolderPicker()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 11))
                            Text("Add Folder")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            setupCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("EXCLUDE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    ForEach(excludePaths.indices, id: \.self) { index in
                        HStack(spacing: 6) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                            Text(excludePaths[index])
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                excludePaths.remove(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 6) {
                        TextField("pattern or path", text: $newExcludePattern)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(6)
                        .background {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(.quaternary.opacity(0.5))
                        }
                        .onSubmit {
                            let trimmed = newExcludePattern.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                excludePaths.append(trimmed)
                                newExcludePattern = ""
                            }
                        }
                    }
                }
            }
        }
    }

    private func pathRow(path: String, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 11))
                .foregroundStyle(.blue)

            Text(path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Step 5: Ready

    private var readyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
                .padding(.top, 8)

            VStack(spacing: 6) {
                Text("You're All Set")
                    .font(.system(size: 18, weight: .semibold))

                Text("Review your configuration below.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            setupCard {
                VStack(alignment: .leading, spacing: 8) {
                    summaryRow(icon: "externaldrive.connected.to.line.below", label: "Repository", value: repositoryURL.isEmpty ? "Not set" : repositoryURL)
                    Divider()
                    summaryRow(icon: "key.fill", label: "Credentials", value: credentialsSaved ? "Saved to Keychain" : "Not saved")
                    Divider()
                    summaryRow(icon: "folder.fill", label: "Backing up", value: "\(includePaths.count) folder\(includePaths.count == 1 ? "" : "s")")
                    Divider()
                    summaryRow(icon: "minus.circle", label: "Excluding", value: "\(excludePaths.count) pattern\(excludePaths.count == 1 ? "" : "s")")
                }
            }

            if !initSuccess {
                Button {
                    Task {
                        isInitializing = true
                        initResult = nil
                        let result = await appState.initializeRepository()
                        isInitializing = false
                        initSuccess = result.success
                        initResult = result.message
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isInitializing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "externaldrive.badge.plus")
                                .font(.system(size: 12))
                        }
                        Text(isInitializing ? "Initializing..." : "Initialize Repository")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isInitializing)
            }

            if let result = initResult {
                HStack(spacing: 4) {
                    Image(systemName: initSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(initSuccess ? .green : .red)
                    Text(result)
                        .font(.system(size: 11))
                        .foregroundStyle(initSuccess ? Color.secondary : Color.red)
                        .lineLimit(3)
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 12, weight: .medium))

            Spacer()

            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 180, alignment: .trailing)
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            if currentStep > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentStep -= 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 13))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                Button {
                    if currentStep == 3 {
                        saveConfig()
                    }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentStep += 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!canAdvance)
            } else {
                Button {
                    saveConfig()
                    appState.completeSetup()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Validation

    private var canAdvance: Bool {
        switch currentStep {
        case 0: return true // Allow proceeding even without restic
        case 1: return !repositoryURL.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return credentialsSaved
        case 3: return !includePaths.isEmpty
        default: return true
        }
    }

    // MARK: - Actions

    private func saveCredentials() {
        credentialError = nil
        do {
            try KeychainManager.writePassword(
                service: Constants.keychainService(Constants.keychainResticPassword),
                password: resticPassword
            )
            try KeychainManager.writePassword(
                service: Constants.keychainService(Constants.keychainAWSAccessKey),
                password: awsAccessKey
            )
            try KeychainManager.writePassword(
                service: Constants.keychainService(Constants.keychainAWSSecretKey),
                password: awsSecretKey
            )
            credentialsSaved = true
        } catch {
            credentialError = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func saveConfig() {
        let config = BackupConfig(
            repository: repositoryURL,
            includePaths: includePaths.filter { !$0.isEmpty },
            excludePaths: excludePaths.filter { !$0.isEmpty }
        )
        try? appState.configManager.saveConfig(config)
    }

    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = "Select folders to include in backups"
        panel.prompt = "Add"

        if panel.runModal() == .OK {
            for url in panel.urls {
                let path = url.path
                if !includePaths.contains(path) {
                    includePaths.append(path)
                }
            }
        }
    }

    // MARK: - Card Helper

    private func setupCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
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
