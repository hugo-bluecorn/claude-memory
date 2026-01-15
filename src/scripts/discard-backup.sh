#!/usr/bin/env bash
# Script: discard-backup.sh
# Purpose: Discard pending session backup without restoring
# Usage: Called via /discard-backup slash command

set -euo pipefail

# === Configuration ===
# Allow environment variable overrides for testing
if [[ -n "${HOOK_PROJECT_DIR:-}" ]]; then
  PROJECT_DIR="$HOOK_PROJECT_DIR"
else
  # Resolve project directory from script location
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

if [[ -n "${HOOK_SESSIONS_DIR:-}" ]]; then
  SESSIONS_DIR="$HOOK_SESSIONS_DIR"
else
  SESSIONS_DIR="$PROJECT_DIR/planning/sessions"
fi

MARKER="$SESSIONS_DIR/.pending-backup"

# === Main Logic ===

# Check if marker exists
if [[ ! -f "$MARKER" ]]; then
  echo "No pending backup to discard."
  exit 0
fi

# Read the backup path from marker
BACKUP_PATH=$(cat "$MARKER" 2>/dev/null || echo "")

# Handle empty marker
if [[ -z "$BACKUP_PATH" ]]; then
  rm -f "$MARKER"
  echo "Cleaned up empty marker. No backup to discard."
  exit 0
fi

# Delete backup file if it exists
if [[ -f "$BACKUP_PATH" ]]; then
  rm -f "$BACKUP_PATH"
  echo "Session backup discarded: $BACKUP_PATH"
else
  echo "Backup file not found (already cleaned up): $BACKUP_PATH"
fi

# Always remove the marker
rm -f "$MARKER"

echo "Pending backup marker removed."
exit 0
