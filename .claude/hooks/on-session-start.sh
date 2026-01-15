#!/usr/bin/env bash
# Hook: SessionStart
# Purpose: Check for pending backups and output notification to stdout (for Claude context)
# Input: JSON via stdin with session_id, transcript_path, source
# Exit codes:
#   0 = success (always - SessionStart cannot block, exit 2 only shows stderr to user)
# Note: stdout is added as context for Claude, enabling awareness of pending backups

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

if [[ -f "$MARKER" ]]; then
  # Read marker content, trim leading/trailing whitespace only
  BACKUP_PATH=$(cat "$MARKER" 2>/dev/null || echo "")
  BACKUP_PATH="${BACKUP_PATH#"${BACKUP_PATH%%[![:space:]]*}"}"  # trim leading
  BACKUP_PATH="${BACKUP_PATH%"${BACKUP_PATH##*[![:space:]]}"}"  # trim trailing

  if [[ -z "$BACKUP_PATH" ]]; then
    # Empty marker, clean up
    rm -f "$MARKER"
    exit 0
  elif [[ ! -f "$BACKUP_PATH" ]]; then
    # Backup file doesn't exist, clean up marker
    rm -f "$MARKER"
    exit 0
  fi

  # Valid pending backup exists - output notification to stdout for Claude context
  # SessionStart cannot block (exit 2 only shows stderr to user, doesn't require acknowledgment)
  echo "SESSION_BACKUP_PENDING: A previous session backup exists at $BACKUP_PATH"
  echo "User should run /resume-latest to restore context, or /discard-backup to discard."
  exit 0
fi

exit 0
