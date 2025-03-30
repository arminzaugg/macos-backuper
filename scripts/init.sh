#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$BASE_DIR/config/restic.env.local"

# Load env first
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
else
  echo "[ERROR] Missing $ENV_FILE"
  exit 1
fi

# Load secrets
export RESTIC_PASSWORD="$(security find-generic-password -s "client-backup-luza-restic-password" -w)"
export AWS_ACCESS_KEY_ID="$(security find-generic-password -s "client-backup-luza-aws-access-key-id" -w)"
export AWS_SECRET_ACCESS_KEY="$(security find-generic-password -s "client-backup-luza-aws-secret-access-key" -w)"
export AWS_DEFAULT_REGION=eu-central-2

# Initialize repo
restic init
