#!/bin/bash

set -euo pipefail

# === Config ===
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$BASE_DIR/config/restic.env"
LOG_FILE="$HOME/Library/Logs/restore.log"

# === Logging ===
exec >> "$LOG_FILE" 2>&1
echo "[INFO] Restore started at $(date)"

# === Load Secrets ===
export RESTIC_PASSWORD="$(security find-generic-password -s "client-backup-luza-restic-password" -w)"
export AWS_ACCESS_KEY_ID="$(security find-generic-password -s "client-backup-luza-aws-access-key-id" -w)"
export AWS_SECRET_ACCESS_KEY="$(security find-generic-password -s "client-backup-luza-aws-secret-access-key" -w)"

# === Load env ===
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo "[ERROR] Missing environment file at $ENV_FILE"
  exit 1
fi

# === List Snapshots ===
echo "[INFO] Available snapshots:"
restic snapshots
echo ""

read -rp "Enter snapshot ID or press enter for latest: " SNAPSHOT
if [[ -z "$SNAPSHOT" ]]; then
  SNAPSHOT="latest"
fi

read -rp "Enter restore destination path: " DEST
if [[ -z "$DEST" ]]; then
  echo "[ERROR] No destination provided"
  exit 1
fi

# === Confirm and Restore ===
echo "[INFO] Restoring snapshot [$SNAPSHOT] to [$DEST]"
restic restore "$SNAPSHOT" --target "$DEST"

RESTORE_EXIT=$?
if [ $RESTORE_EXIT -eq 0 ]; then
  echo "[INFO] Restore completed successfully at $(date)"
else
  echo "[ERROR] Restore failed with exit code $RESTORE_EXIT"
fi