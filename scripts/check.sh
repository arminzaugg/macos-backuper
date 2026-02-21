#!/bin/bash
set -euo pipefail

# === Config ===
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$BASE_DIR/config/restic.env.local"
LOG_FILE="$HOME/Library/Logs/backup-check.log"

# === Logging ===
exec >> "$LOG_FILE" 2>&1
echo "[INFO] Backup check started at $(date)"

# Check if the environment file exists
if [[ -f "$ENV_FILE" ]]; then
  set -a               # Start automatically exporting variables
  source "$ENV_FILE"   # Source the environment file
  set +a               # Stop automatically exporting variables
else
  echo "[ERROR] Environment file not found at $ENV_FILE"
  exit 1
fi

# === Load Secrets ===
export RESTIC_PASSWORD="$(security find-generic-password -s "client-backup-luza-restic-password" -w)"
export AWS_ACCESS_KEY_ID="$(security find-generic-password -s "client-backup-luza-aws-access-key-id" -w)"
export AWS_SECRET_ACCESS_KEY="$(security find-generic-password -s "client-backup-luza-aws-secret-access-key" -w)"


# === Run Restic Check ===
echo "[INFO] Running restic check..."

restic check
CHECK_EXIT=$?

if [ $CHECK_EXIT -eq 0 ]; then
  echo "[INFO] Backup integrity verified at $(date)"
else
  echo "[ERROR] Backup integrity check failed with exit code $CHECK_EXIT"
fi