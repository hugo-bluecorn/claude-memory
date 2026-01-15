#!/usr/bin/env bash
# Hook: PreCompact
# Purpose: Save raw transcript backup before compaction occurs
# Input: JSON via stdin with session_id, transcript_path, trigger

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

# Read input
INPUT=$(cat)

# Validate JSON and parse fields
if [[ -z "$INPUT" ]] || ! echo "$INPUT" | jq -e . >/dev/null 2>&1; then
  # Invalid or empty input - exit gracefully
  exit 0
fi

# Parse JSON input
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
TRIGGER=$(echo "$INPUT" | jq -r '.trigger // empty')
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create directories if needed
mkdir -p "$SESSIONS_DIR/raw"

# Only proceed if transcript exists
if [[ -f "$TRANSCRIPT" ]]; then
  # Save raw backup
  BACKUP_PATH="$SESSIONS_DIR/raw/${TIMESTAMP}.jsonl"
  cp "$TRANSCRIPT" "$BACKUP_PATH"

  # Create pending marker with backup path
  # Uses .pending-backup-compact to avoid conflict with SessionEnd's .pending-backup-exit
  echo "$BACKUP_PATH" > "$SESSIONS_DIR/.pending-backup-compact"

  # Log the event
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] PreCompact ($TRIGGER): Saved backup to $BACKUP_PATH" >> "$SESSIONS_DIR/.backup-log"
fi

exit 0
