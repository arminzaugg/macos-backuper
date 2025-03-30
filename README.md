# macOS S3 Backup System using Restic + launchd

This project provides a complete, automated macOS backup solution using [Restic](https://restic.net/) and S3-compatible object storage. It is designed to run daily backups using `launchd`, securely storing credentials in the macOS Keychain, and offering full restore and pruning capabilities.

## 🚀 Features

- 🔒 **Secure Keychain Integration** — no plaintext secrets
- ☁️ **S3-Compatible Storage** (AWS, Wasabi, etc.)
- 🛠️ **Pre-flight Checks** — connectivity, mount status, and credential validation
- 🧠 **Custom Include/Exclude Paths**
- 🧼 **Automated Pruning** — retention policies built-in
- 📅 **launchd Scheduling** — daily backups at 2 AM
- 🧪 **Integrity Checks** — with `restic check`
- 🧰 **Easy Restore** — interactive CLI script
- 🧾 **Logs Stored Locally** — in `~/Library/Logs/`

## ⚙️ Requirements

- macOS 12+
- [`restic`](https://restic.net/)
- [`awscli`](https://docs.aws.amazon.com/cli/)
- [Homebrew](https://brew.sh/)

## 🧰 Quick Start

See the full [SETUP guide](docs/SETUP.md) for installation and configuration.