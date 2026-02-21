# UX Improvement Spec -- BackupMenu

## Executive Summary

BackupMenu is a macOS menu bar app for managing Restic backups to S3-compatible storage. After a full audit of every view, model, and manager, this spec catalogs usability problems a real user would encounter and proposes concrete fixes. Issues are ordered by severity -- things that would make someone uninstall come first.

---

## 1. Critical: First-Launch Experience is Broken

### Problem

There is no onboarding flow. A new user who opens the app sees the Status tab with "Ready" and "Last Backup: Never." They have no idea:

- What this app does or that it needs Restic installed
- That three Keychain entries must exist before anything works
- That a config file (`config/restic.env.local`) must be in place with a valid repository URL
- Where to start

If they click "Backup Now," it fails silently or shows a cryptic error like `Script not found: .../scripts/backup.sh` or `Keychain item not found: client-backup-luza-restic-password`.

### Current State

- `AppState.findConfigPath()` walks up from the bundle to find the config file. If the app is installed in /Applications (as most users would do), this will fail every time.
- No setup wizard, no first-run detection, no guided configuration.
- Errors from missing config or Keychain entries are shown as terse one-line messages in the status card.

### Proposed Fix

**P0 -- Add a first-run setup flow:**

1. Detect first launch (no config file found, or no Keychain entries present).
2. Show a setup view instead of the normal Status tab, with clear steps:
   - Step 1: "Install Restic" -- detect if `restic` is installed, show install instructions or a "brew install restic" button.
   - Step 2: "Configure Repository" -- text field for the S3 repository URL.
   - Step 3: "Add Credentials" -- fields for Restic password, AWS access key, and AWS secret key, with a button to save them to Keychain.
   - Step 4: "Choose Paths" -- let the user pick folders to back up via a folder picker (NSOpenPanel).
   - Step 5: "Set Schedule" -- configure backup times.
3. On completion, write `restic.env.local` and store credentials in Keychain.
4. Show a "Run First Backup" button.

---

## 2. Critical: No Way to Add Keychain Credentials from the App

### Problem

The Settings > Keychain Credentials section is read-only. It shows green/red indicators for whether each secret exists in Keychain, but provides no way to add or update them. A user must open Terminal and run `security add-generic-password` commands manually, which most people will never figure out.

### Current State (`SettingsTabView.swift:232-259`)

```swift
private func keychainRow(label: String, service: String) -> some View {
    let exists = KeychainManager.checkKeyExists(service: service)
    // ... shows checkmark or X, "Found" or "Missing" -- that's it
}
```

### Proposed Fix

**P0 -- Add credential input fields:**

- When a credential is "Missing," show a SecureField to enter it and a "Save" button that writes to Keychain using `security add-generic-password`.
- When a credential is "Found," show a "Update" button to replace it and a "Remove" button (with confirmation).
- `KeychainManager` needs a `writePassword(service:password:)` method.

---

## 3. Critical: Errors Fail Silently or Show Unhelpful Messages

### Problem

Multiple places swallow errors or show messages only a developer would understand:

1. **Config save failures are silent** (`SettingsTabView.swift:355-359`):
   ```swift
   } catch {
       // Save failed silently for now
   }
   ```
   The user clicks "Save Changes," sees the green "Saved" confirmation, but nothing was actually saved.

2. **Config load failures are silent** (`SettingsTabView.swift:342-344`):
   ```swift
   } catch {
       // Use empty defaults on first load failure
   }
   ```
   The user sees empty fields with no explanation of why.

3. **Error messages are developer-facing**: `"Restic failed (exit 3): ..."` with the last 200 chars of stdout is not actionable for a user.

4. **No persistent error log viewer**: The error message disappears as soon as a new operation starts. There is no way to review what happened.

### Proposed Fix

**P0 -- Never swallow errors:**

- Show an alert or inline error banner when config save/load fails, with a human-readable explanation.
- Replace `// Save failed silently for now` with actual user feedback.

**P1 -- Translate error messages:**

- Map common Restic exit codes to user-friendly messages:
  - Exit 1: "Connection failed -- check your internet and repository URL"
  - Exit 3: "Repository not initialized -- run initial setup"
  - Keychain missing: "Credentials not configured -- go to Settings > Keychain to add them"
- Keep the raw error available behind a "Show Details" disclosure.

**P1 -- Add a log viewer:**

- Add a "Logs" section or tab where users can see recent backup/check/prune log entries.
- Parse `~/Library/Logs/backup.log` and display the last N entries in a scrollable list.

---

## 4. High: No Progress Indication During Long Operations

### Problem

When a backup is running, the user sees "Backup" with a small spinner. There is no indication of:

- How long it has been running
- What is being backed up
- Whether it is stuck or making progress
- How large the backup is
- Estimated time remaining

A backup can run for 30 minutes (the timeout in `ScriptRunner`). During that time, the user sees the same spinner with no feedback.

### Current State (`StatusTabView.swift:73-80`)

```swift
case .running(let operation):
    VStack(spacing: 4) {
        Text(operation)       // Just "Backup" or "Integrity Check"
        ProgressView()
            .controlSize(.small)
    }
```

### Proposed Fix

**P1 -- Add progress feedback:**

- Show elapsed time since the operation started (a live-updating timer).
- Parse Restic's JSON progress output (`--json` flag) to show: files processed, bytes transferred, percentage complete.
- Add a "Cancel" button during operations. The cancel infrastructure exists (`BackupManager.cancelRunningOperation()`, `ScriptRunner.cancel()`) but is never exposed in the UI.

---

## 5. High: No Way to Browse or Restore Files

### Problem

The Snapshots tab shows a list of snapshots with their IDs, dates, and paths. But the user cannot do anything useful with them except delete them. There is no way to:

- Browse the contents of a snapshot
- Restore a specific file or folder from a snapshot
- Restore an entire snapshot
- Compare snapshots

The shell script `restore.sh` exists for interactive restore, but it is never called from the app.

### Proposed Fix

**P1 -- Add restore capabilities:**

- Add a "Restore" context menu item on each snapshot (alongside the existing "Forget Snapshot").
- Allow the user to choose a destination folder for the restore.
- For advanced use: add a file browser that runs `restic ls --json <snapshot-id>` and lets the user select specific files to restore.

---

## 6. High: Snapshots Tab Has No Sort Order or Grouping

### Problem

Snapshots are displayed in whatever order Restic returns them (oldest first by default). For a user with dozens of snapshots, finding a specific one requires scrolling through the entire list. There is no:

- Sort control (newest first would be more useful as default)
- Grouping by date (today, this week, this month, older)
- Search or filter
- Total size information per snapshot

### Proposed Fix

**P1 -- Improve snapshot browsing:**

- Default sort to newest-first.
- Add section headers grouping snapshots by relative time period.
- Show snapshot count in the tab bar badge.
- Consider adding a search field for filtering by date or path.

---

## 7. High: Retention Policy Is Not Connected to Settings Save

### Problem

The retention policy steppers in Settings adjust the values, but the retention values are only saved to UserDefaults when the user clicks "Save Changes." However, the "Apply" (prune) button in the Snapshots tab always uses `.defaults` (hardcoded), not the user's configured values.

### Current State (`SnapshotsTabView.swift:234`)

```swift
Task { await backupManager.forgetWithPolicy(policy: .defaults) }
```

This ignores any retention changes the user made in Settings.

### Proposed Fix

**P0 -- Use the saved retention policy:**

- Load `RetentionPolicy.loadFromUserDefaults()` when applying retention, not `.defaults`.
- The retention confirmation dialog should show the actual configured values, not hardcoded "7 daily, 4 weekly, 6 monthly."
- The `saveConfig()` in Settings should also persist the retention policy (it currently does not call `retention.saveToUserDefaults()`).

---

## 8. Medium: Confusing Config Path Resolution

### Problem

The app hunts for `config/restic.env.local` by walking up directories from the app bundle (`AppState.findConfigPath()`). This works during development (app is inside the project), but breaks when the app is installed normally to `/Applications`. The user gets no feedback about where the app is looking for the config or what to do when it cannot find one.

### Proposed Fix

**P1 -- Make config path user-configurable:**

- Add a "Config File" row in Settings showing the current resolved path.
- Add a "Browse" button that lets the user point to their config file (or project directory).
- Store the chosen path in UserDefaults (this mechanism already exists but is never exposed).
- Show a clear warning when the config file is not found, with instructions.

---

## 9. Medium: Settings Are Not Auto-Saved

### Problem

All settings changes (repository URL, paths, schedule times, retention policy) require clicking "Save Changes." There is no visual indicator that unsaved changes exist. A user can modify several fields, switch to the Status tab, switch back, and all changes are lost because `loaded` prevents re-reading from disk and the `@State` variables were reset.

### Proposed Fix

**P1 -- Add unsaved changes indicator:**

- Track dirty state by comparing current values to the last-saved values.
- Show a dot or asterisk on the Settings tab when there are unsaved changes.
- Optionally warn the user if they switch tabs with unsaved changes.
- Consider auto-saving on each field change (common for menu bar apps where users expect immediate effect).

---

## 10. Medium: Schedule Changes Not Saved Until "Save Changes"

### Problem

The auto-backup toggle takes effect immediately (it directly calls `scheduleManager.start()/stop()`), but the schedule times do not. The user can add a new time slot, see it in the UI, and assume it is active, but it only takes effect after clicking "Save Changes." This is inconsistent.

### Proposed Fix

**P1 -- Make schedule behavior consistent:**

- Either make all schedule changes immediate (save on each change), or make the toggle also require "Save Changes."
- The toggle's immediate behavior is more intuitive -- extend that to the time pickers.

---

## 11. Medium: No Quit Button

### Problem

The app is an `LSUIElement` (no Dock icon). The only way to quit it is Force Quit from Activity Monitor, or right-clicking the menu bar icon (if macOS shows that option). There is no "Quit" button anywhere in the UI.

### Proposed Fix

**P0 -- Add a Quit button:**

- Add a "Quit BackupMenu" option at the bottom of the popover, separated by a divider.
- Standard macOS menu bar apps always provide this.

---

## 12. Medium: No Feedback on Keychain Prefix

### Problem

`Constants.swift` defines a `defaultKeychainPrefix` of `"client-backup-luza"` and supports overriding it via UserDefaults (`keychainPrefix`), but there is no UI to view or change this. If a user has credentials under a different prefix, the app silently fails to find them.

### Proposed Fix

**P1 -- Surface the Keychain prefix in Settings:**

- Add an "Advanced" or "Keychain Prefix" field in the Keychain section.
- Default to the current value, allow editing, save to UserDefaults.

---

## 13. Low: Popover Size Is Fixed

### Problem

The popover is hardcoded to 400x500 (`PopoverContentView.swift:28`). On smaller screens or when the user has many snapshots, this can be constraining. On larger screens, it feels cramped for Settings.

### Proposed Fix

**P2 -- Allow dynamic sizing:**

- Let the height adapt to content within a min/max range (e.g., 400-600).
- Or add a resize handle / "compact/expanded" toggle.

---

## 14. Low: No Keyboard Shortcuts

### Problem

There are no keyboard shortcuts for common actions. A power user cannot trigger a backup or switch tabs without clicking.

### Proposed Fix

**P2 -- Add keyboard shortcuts:**

- Cmd+1/2/3 for tab switching.
- Cmd+B for "Backup Now."
- Cmd+R for "Refresh Snapshots."
- Esc to close the popover.

---

## 15. Low: No App Icon

### Problem

The `AppIcon.appiconset` has all size slots defined but no actual image files. The app shows a blank icon.

### Proposed Fix

**P2 -- Design and add an app icon.**

---

## 16. Low: Snapshot Paths Shown as Raw Strings

### Problem

Snapshot paths like `/Users/aza/Documents` are shown as-is. For paths that include the username, this is fine, but backup paths like `/Users/aza/Library/Application Support/...` get truncated and are hard to read.

### Proposed Fix

**P2 -- Use tilde abbreviation and smarter truncation:**

- Replace `/Users/<username>` with `~`.
- Truncate from the middle rather than the tail for long paths.

---

## Summary Table

| # | Issue | Severity | Effort |
|---|-------|----------|--------|
| 1 | No first-launch/onboarding experience | P0 | Large |
| 2 | No way to add Keychain credentials from UI | P0 | Medium |
| 3 | Errors fail silently or show developer messages | P0 | Medium |
| 7 | Retention policy prune uses hardcoded defaults | P0 | Small |
| 11 | No Quit button | P0 | Small |
| 4 | No progress feedback during long operations | P1 | Medium |
| 5 | No file restore capability | P1 | Large |
| 6 | Snapshots unsorted, no grouping or search | P1 | Medium |
| 8 | Config path not user-configurable | P1 | Small |
| 9 | No unsaved-changes indicator in Settings | P1 | Small |
| 10 | Schedule time changes not saved until explicit save | P1 | Small |
| 12 | Keychain prefix not visible or editable | P1 | Small |
| 13 | Fixed popover size | P2 | Small |
| 14 | No keyboard shortcuts | P2 | Small |
| 15 | No app icon | P2 | Small |
| 16 | Snapshot paths shown as raw strings | P2 | Small |

---

## Recommended Implementation Order

1. **Quit button** (#11) -- 15 minutes, prevents user frustration immediately.
2. **Fix retention policy bug** (#7) -- 15 minutes, this is an actual functional bug.
3. **Keychain credential input** (#2) -- makes the app self-contained.
4. **Error handling cleanup** (#3) -- stop swallowing errors, add user-facing messages.
5. **First-run onboarding** (#1) -- requires #2 and #3 to be useful.
6. **Cancel button + elapsed time** (#4) -- quick win from existing infrastructure.
7. **Snapshot sorting + restore** (#5, #6) -- feature completeness.
8. Everything else as time permits.
