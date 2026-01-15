#!/usr/bin/env bash
# Hook: SessionStart
# Purpose: Check for pending backups and output notification to stdout (for Claude context)
# Input: JSON via stdin with session_id, transcript_path, source
# Exit codes:
#   0 = success (always - SessionStart cannot block, exit 2 only shows stderr to user)
# Note: stdout is added as context for Claude, enabling awareness of pending backups
#
# Supports multiple marker types:
#   .pending-backup-compact - Created by PreCompact hook
#   .pending-backup-exit - Created by SessionEnd hook
#   .pending-backup - Legacy marker (for backward compatibility)

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

# Check if sessions directory exists
if [[ ! -d "$SESSIONS_DIR" ]]; then
  exit 0
fi

# Track if we found any valid pending backups
found_pending=false

# Process a single marker file
process_marker() {
  local marker_file="$1"
  local marker_type="$2"

  if [[ ! -f "$marker_file" ]]; then
    return 0
  fi

  # Read marker content, trim whitespace
  local backup_path
  backup_path=$(cat "$marker_file" 2>/dev/null || echo "")
  backup_path="${backup_path#"${backup_path%%[![:space:]]*}"}"  # trim leading
  backup_path="${backup_path%"${backup_path##*[![:space:]]}"}"  # trim trailing

  if [[ -z "$backup_path" ]]; then
    # Empty marker, clean up
    rm -f "$marker_file"
    return 0
  elif [[ ! -f "$backup_path" ]]; then
    # Backup file doesn't exist, clean up marker
    rm -f "$marker_file"
    return 0
  fi

  # Valid pending backup exists - output notification
  echo "SESSION_BACKUP_PENDING ($marker_type): Backup exists at $backup_path"
  found_pending=true
}

# Check for all marker types
process_marker "$SESSIONS_DIR/.pending-backup-compact" "compact"
process_marker "$SESSIONS_DIR/.pending-backup-exit" "exit"
process_marker "$SESSIONS_DIR/.pending-backup" "legacy"

# If any pending backups were found, output instructions
if [[ "$found_pending" == "true" ]]; then
  echo "User should run /resume-latest to restore context, or /discard-backup to discard."
fi

exit 0
