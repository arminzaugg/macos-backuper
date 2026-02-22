#!/bin/bash

set -euo pipefail

# === Config ===
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$BASE_DIR/config/restic.env.local"
LOG_FILE="$HOME/Library/Logs/backup.log"

# === Logging ===
exec >> "$LOG_FILE" 2>&1
echo "[INFO] Backup started at $(date)"

# Check if the environment file exists
if [[ -f "$ENV_FILE" ]]; then
  set -a               # Start automatically exporting variables
  source "$ENV_FILE"   # Source the environment file
  set +a               # Stop automatically exporting variables
else
  echo "[ERROR] Environment file not found at $ENV_FILE"
  exit 1
fi

# === Pre-flight Checks ===
check_requirements() {
  command -v restic >/dev/null || { echo "[ERROR] restic not installed"; exit 1; }
  ping -q -c 1 nbg1.your-objectstorage.com >/dev/null || { echo "[ERROR] No network"; exit 1; }

  for key in "client-backup-luza-restic-password" "client-backup-luza-aws-access-key-id" "client-backup-luza-aws-secret-access-key"; do
    security find-generic-password -s "$key" -w >/dev/null 2>&1 || {
      echo "[ERROR] Missing Keychain item: $key"
      exit 1
    }
  done
}

# === Load Secrets ===
export RESTIC_PASSWORD="$(security find-generic-password -s "client-backup-luza-restic-password" -w)"
export AWS_ACCESS_KEY_ID="$(security find-generic-password -s "client-backup-luza-aws-access-key-id" -w)"
export AWS_SECRET_ACCESS_KEY="$(security find-generic-password -s "client-backup-luza-aws-secret-access-key" -w)"

# === Backup Execution ===
check_requirements

echo "[INFO] Starting restic backup..."

INCLUDE_ARGS=()
for path in "${BACKUP_INCLUDE[@]}"; do
  INCLUDE_ARGS+=("$path")
done

EXCLUDE_ARGS=()
for path in "${BACKUP_EXCLUDE[@]}"; do
  EXCLUDE_ARGS+=("--exclude=$path")
done

restic backup "${INCLUDE_ARGS[@]}" "${EXCLUDE_ARGS[@]}"
RESTIC_EXIT=$?

if [ $RESTIC_EXIT -eq 0 ]; then
  echo "[INFO] Backup completed successfully at $(date)"
else
  echo "[ERROR] Backup failed with exit code $RESTIC_EXIT"
fi
