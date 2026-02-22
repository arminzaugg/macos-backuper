# macOS Backup System

Automated, encrypted macOS backups using [Restic](https://restic.net/) with S3-compatible storage. Includes a native SwiftUI menu bar app and standalone shell scripts.

## What It Does

- Encrypted, deduplicated backups to any S3-compatible storage (Hetzner, AWS, Backblaze, Wasabi)
- Native macOS menu bar app with backup status, snapshot management, and scheduling
- Credentials stored in macOS Keychain — never in files
- Retention policies with automatic pruning
- Works with or without the menu bar app (scripts run standalone)

## Requirements

- macOS 14.0+ (menu bar app) or macOS 12+ (scripts only)
- [Restic](https://restic.net/) — `brew install restic`
- S3-compatible storage bucket with access credentials

## Quick Start

### 1. Install Restic

```bash
brew install restic
```

### 2. Store Credentials in Keychain

```bash
security add-generic-password -a "$USER" -s "client-backup-luza-restic-password" -w "YOUR_RESTIC_PASSWORD"
security add-generic-password -a "$USER" -s "client-backup-luza-aws-access-key-id" -w "YOUR_ACCESS_KEY"
security add-generic-password -a "$USER" -s "client-backup-luza-aws-secret-access-key" -w "YOUR_SECRET_KEY"
```

### 3. Create Configuration

```bash
cp config/restic.env config/restic.env.local
```

Edit `config/restic.env.local` with your repository URL and backup paths:

```bash
export RESTIC_REPOSITORY="s3:your-s3-endpoint.com/bucket-name/subfolder"

BACKUP_INCLUDE=(
  "/Users/you/Documents"
  "/Users/you/Desktop"
)

BACKUP_EXCLUDE=(
  "Library"
  ".Trash"
  "node_modules"
)
```

> **Note:** For Hetzner Object Storage, use path-style URLs without `https://`: `s3:nbg1.your-objectstorage.com/bucket/subfolder`

### 4. Initialize Repository

```bash
bash scripts/init.sh
```

### 5. Run First Backup

```bash
bash scripts/backup.sh
```

## Menu Bar App

The BackupMenu app lives in your menu bar and provides a GUI for managing backups.

### Building

Open `BackupMenu/BackupMenu.xcodeproj` in Xcode and build (Cmd+B). The app requires:

- macOS 14.0+
- No App Sandbox (needs to run shell commands)
- Hardened Runtime
- Ad-hoc code signing (runs locally)

### Features

- **Status tab** — current backup status, last backup time, next scheduled, repository info. Backup Now and Verify buttons.
- **Snapshots tab** — list all snapshots, forget individual snapshots, apply retention policy with pruning.
- **Settings tab** — edit repository URL, include/exclude paths, schedule times, retention policy, keychain status, launch at login.
- **Onboarding wizard** — guided 5-step setup for first-time users (checks Restic, configures repository, stores credentials, selects paths, initializes repo).
- **Notifications** — macOS notifications on backup success or failure.
- **Dynamic menu bar icon** — changes based on status (idle, running, success, error).

## Scripts

All scripts are standalone and can be run from the terminal independently of the menu bar app.

| Script | Purpose |
|--------|---------|
| `scripts/backup.sh` | Run a backup |
| `scripts/check.sh` | Verify repository integrity |
| `scripts/forget.sh` | Apply retention policy (7 daily, 4 weekly, 6 monthly) and prune |
| `scripts/restore.sh` | Interactive snapshot restore |
| `scripts/init.sh` | Initialize repository (one-time) |
| `scripts/env.sh` | Print loaded environment variables (debug) |

Each script sources `config/restic.env.local`, loads secrets from Keychain, runs pre-flight checks, then executes the operation. Logs go to `~/Library/Logs/`.

## Scheduling

### Option A: Menu Bar App (recommended)

Enable auto-backup in Settings > Schedule. The app checks every 30 seconds and runs backups at configured times. Minimum 60 minutes between automatic backups.

### Option B: launchd

```bash
cp config/com.user.backup.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.backup.plist
```

Default schedule: 2 AM and 2 PM daily, with catch-up on wake from sleep.

```bash
# Check status
launchctl list | grep com.user.backup

# Uninstall
launchctl unload ~/Library/LaunchAgents/com.user.backup.plist
```

## Project Structure

```
macos-backuper/
  scripts/              Shell scripts for backup operations
  config/
    restic.env          Configuration template
    restic.env.local    Your active config (gitignored)
    com.user.backup.plist  launchd schedule
  docs/
    SETUP.md            Detailed setup guide
  BackupMenu/           SwiftUI menu bar app
    BackupMenu/
      App/              Entry point and state management
      Models/           Data types (Snapshot, BackupConfig, etc.)
      Managers/         Business logic (BackupManager, ConfigManager, etc.)
      Views/            SwiftUI views (Status, Snapshots, Settings, Setup)
```

## Logs

| Log File | Source |
|----------|--------|
| `~/Library/Logs/backup.log` | Backup operations |
| `~/Library/Logs/backup-check.log` | Integrity checks |
| `~/Library/Logs/backup-prune.log` | Retention + prune |
| `~/Library/Logs/restore.log` | Restore operations |

## Security

- All secrets (Restic password, AWS keys) are stored in macOS Keychain and loaded at runtime via the `security` CLI
- The `.local` config file is gitignored — only the template is tracked
- Scripts validate credentials exist before running any operation
- The menu bar app uses hardened runtime with no sandbox (required for `Process()` execution)

## License

MIT
