#!/usr/bin/env bash
# Script: discard-backup.sh
# Purpose: Discard pending session backup(s) without restoring
# Usage: Called via /discard-backup slash command
#
# Handles marker types:
#   .pending-backup-compact - Created by PreCompact hook
#   .pending-backup-exit - Created by SessionEnd hook

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
  SESSIONS_DIR="$PROJECT_DIR/.claude/memory"
fi

# === Helper Functions ===

# Discard a single backup marker
# Returns: 0 if processed, 1 if no marker found
discard_marker() {
  local marker_file="$1"
  local marker_type="$2"

  if [[ ! -f "$marker_file" ]]; then
    return 1
  fi

  # Read the backup path from marker
  local backup_path
  backup_path=$(cat "$marker_file" 2>/dev/null || echo "")

  # Handle empty marker
  if [[ -z "$backup_path" ]]; then
    rm -f "$marker_file"
    echo "Cleaned up empty $marker_type marker."
    return 0
  fi

  # Delete backup file if it exists
  if [[ -f "$backup_path" ]]; then
    rm -f "$backup_path"
    echo "Session backup discarded ($marker_type): $backup_path"
  else
    echo "Backup file not found ($marker_type, already cleaned up): $backup_path"
  fi

  # Always remove the marker
  rm -f "$marker_file"
  return 0
}

# === Main Logic ===

found_any=false

# Process marker types
if discard_marker "$SESSIONS_DIR/.pending-backup-compact" "compact"; then
  found_any=true
fi

if discard_marker "$SESSIONS_DIR/.pending-backup-exit" "exit"; then
  found_any=true
fi

# Report if nothing was found
if [[ "$found_any" == "false" ]]; then
  echo "No pending backup to discard."
fi

exit 0
