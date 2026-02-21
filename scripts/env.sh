#!/bin/bash
#set -euo pipefail  # Existing safety settings

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$BASE_DIR/config/restic.env.local"

# Check if the environment file exists
if [[ -f "$ENV_FILE" ]]; then
  set -a               # Start automatically exporting variables
  source "$ENV_FILE"   # Source the environment file
  set +a               # Stop automatically exporting variables
  env | grep RESTIC_REPOSITORY
else
  echo "[ERROR] Environment file not found at $ENV_FILE"
  exit 1
fi

# Load secrets from macOS Keychain
export RESTIC_PASSWORD="$(security find-generic-password -s "client-backup-luza-restic-password" -w)"
env | grep RESTIC_PASSWORD
export AWS_ACCESS_KEY_ID="$(security find-generic-password -s "client-backup-luza-aws-access-key-id" -w)"
env | grep AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY="$(security find-generic-password -s "client-backup-luza-aws-secret-access-key" -w)"
env | grep AWS_SECRET_ACCESS_KEY
