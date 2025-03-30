#!/bin/bash

set -euo pipefail

# === Config ===
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$BASE_DIR/config/restic.env"
LOG_FILE="$HOME/Library/Logs/backup-prune.log"

# === Logging ===
exec >> "$LOG_FILE" 2>&1
echo "[INFO] Prune started at $(date)"

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

# === Forget + Prune ===
echo "[INFO] Applying retention policy..."

restic forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --prune

FORGET_EXIT=$?
if [ $FORGET_EXIT -eq 0 ]; then
  echo "[INFO] Prune completed successfully at $(date)"
else
  echo "[ERROR] Prune failed with exit code $FORGET_EXIT"
fi