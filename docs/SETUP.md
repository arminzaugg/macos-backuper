# 🔧 Full Setup Guide: macOS Backup System (Restic + S3 + launchd)

This guide walks you through setting up a fully automated macOS backup system using:

- ✅ [Restic](https://restic.net/) for encrypted, incremental backups
- ☁️ S3-compatible object storage (AWS, Wasabi, etc.)
- ⏱️ macOS `launchd` for scheduled execution
- 🔐 macOS Keychain for secure credentials

---

## 📦 1. Install Dependencies

Install restic using [Homebrew](https://brew.sh/):

```bash
brew install restic
```

Install awscli v2.22.35 or below when using Hetzner object storage [Hetzner Docs](https://docs.hetzner.com/storage/object-storage/getting-started/using-s3-api-tools)

```bash
curl "https://awscli.amazonaws.com/AWSCLIV2-2.22.35.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target
```

---

## 🔐 2. Secure Credential Storage (macOS Keychain)

Store all sensitive credentials using the macOS Keychain.

### Add credentials:

```bash
# Restic repository password
security add-generic-password -s restic-password -w 'your-secure-password'

# AWS credentials
security add-generic-password -s aws-access-key-id -w 'YOUR_AWS_KEY_ID'
security add-generic-password -s aws-secret-access-key -w 'YOUR_AWS_SECRET'
```

### Verify a key:

```bash
security find-generic-password -s restic-password -w
```

---

## ⚙️ 3. Configure Backup Options

Edit the backup configuration:

```bash
cp config/restic.env config/restic.env.local
open -a TextEdit config/restic.env.local
```

Update the following fields:

- `RESTIC_REPOSITORY`: e.g. `s3:s3.amazonaws.com/your-bucket`
- `BACKUP_INCLUDE`: Important folders to back up (e.g. `Documents`, `Pictures`)
- `BACKUP_EXCLUDE`: Paths to skip (e.g. `Library`, `caches`, `.Trash`)

✅ This file is automatically sourced by all backup scripts.

---

## ⏱️ 4. Setup Scheduled Backups with launchd

### 4.1 Customize the launchd plist

Edit the file:

```bash
open -a TextEdit config/com.user.backup.plist
```

Replace `/path/to/backup-system` with the absolute path to your cloned repository.

### 4.2 Install and load the Launch Agent

```bash
cp config/com.user.backup.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.backup.plist
```

### 4.3 Confirm the backup job is running

```bash
launchctl list | grep com.user.backup
```

The backup will now run daily at 2:00 AM, with logs written to:

- `~/Library/Logs/backup.log`
- `~/Library/Logs/backup.err`

---

## 🚨 5. Run Your First Backup Manually

To ensure everything works, run a backup manually:

```bash
bash scripts/backup.sh
```

Check logs to verify the output:

```bash
tail -f ~/Library/Logs/backup.log
```

---

## 🔁 6. Restore from a Backup

Run the interactive restore script:

```bash
bash scripts/restore.sh
```

You will be prompted to:

- Choose a snapshot (or use the latest)
- Choose a destination path for restore

---

## 🧪 7. Validate Backup Integrity

Run a full integrity check:

```bash
bash scripts/check.sh
```

This will ensure your backup repo is healthy and consistent.

---

## 🧼 8. Prune Old Snapshots

Apply retention policies and prune:

```bash
bash scripts/forget.sh
```

By default, this script keeps:

- 7 daily backups
- 4 weekly backups
- 6 monthly backups

You can customize this policy in `forget.sh`.

---

## 🛠️ 9. Troubleshooting

| Symptom                      | Fix                                                                 |
|-----------------------------|----------------------------------------------------------------------|
| Missing Keychain item       | Re-add it using `security add-generic-password ...`                 |
| `restic: command not found` | Make sure it’s installed via `brew install restic`                 |
| No job running              | Check plist path and make sure it's loaded                           |
| S3 access errors            | Validate key/secret + bucket existence                               |
| Backup not scheduled        | Double-check plist paths and `launchctl load`                        |
| Slow backups                | Exclude large dirs (e.g. `node_modules`) or adjust paths             |

---

## 🔐 Security Best Practices

- 🔒 Store all secrets in macOS Keychain — never commit passwords or keys.
- ✅ Lock your keychain when not in use.
- 🧼 Avoid backing up sensitive system files or unneeded large folders.
- 🔁 Run integrity checks (`check.sh`) regularly.
- 🧾 Monitor logs in `~/Library/Logs/` for issues.

---

## ✅ Recap

You're now running:

- Secure, encrypted S3 backups
- On a daily schedule via `launchd`
- With full restore and retention support
- All secrets safely stored in Keychain

