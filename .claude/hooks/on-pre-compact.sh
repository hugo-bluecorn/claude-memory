#!/usr/bin/env bash
# Hook: PreCompact
# Purpose: Save raw transcript backup before compaction occurs
# Input: JSON via stdin with session_id, transcript_path, trigger
#
# This hook ensures session context is preserved before Claude Code auto-compacts.
# The saved transcript can be processed by /resume-latest in the next session.

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

# === Functions ===

# Log a message (only in debug mode)
log_debug() {
  local msg="$1"
  if [[ "${HOOK_DEBUG:-false}" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] PreCompact: $msg" >> "$SESSIONS_DIR/.debug-log"
  fi
}

# Validate JSON input and extract fields
# Returns: 0 if valid, 1 if invalid
parse_input() {
  local input="$1"

  # Check if input is empty
  if [[ -z "$input" ]]; then
    log_debug "Empty input received"
    return 1
  fi

  # Validate JSON structure
  if ! echo "$input" | jq -e . >/dev/null 2>&1; then
    log_debug "Invalid JSON input"
    return 1
  fi

  # Extract fields (use // empty to handle null values)
  TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path // empty')
  TRIGGER=$(echo "$input" | jq -r '.trigger // empty')
  SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')

  # Validate required fields
  if [[ -z "$TRANSCRIPT" ]]; then
    log_debug "transcript_path is null or empty"
    return 1
  fi

  log_debug "Parsed: TRANSCRIPT=$TRANSCRIPT, TRIGGER=$TRIGGER, SESSION_ID=$SESSION_ID"
  return 0
}

# Create backup of transcript file
create_backup() {
  local transcript="$1"
  local trigger="$2"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)

  # Ensure raw directory exists
  mkdir -p "$SESSIONS_DIR/raw"

  # Create backup with timestamp only (PreCompact doesn't have reason like SessionEnd)
  local backup_path="$SESSIONS_DIR/raw/${timestamp}_compact.jsonl"

  if cp "$transcript" "$backup_path"; then
    log_debug "Created backup: $backup_path"
    echo "$backup_path"
    return 0
  else
    log_debug "Failed to create backup"
    return 1
  fi
}

# Create pending backup marker
# Uses .pending-backup-compact to avoid conflict with SessionEnd's .pending-backup-exit
create_pending_marker() {
  local backup_path="$1"
  echo "$backup_path" > "$SESSIONS_DIR/.pending-backup-compact"
  log_debug "Created pending marker (.pending-backup-compact)"
}

# Update backup log
update_backup_log() {
  local trigger="$1"
  local backup_path="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] PreCompact ($trigger): Saved backup to $backup_path" >> "$SESSIONS_DIR/.backup-log"
  log_debug "Updated backup log"
}

# Update active-context.md with compaction info
update_active_context() {
  local trigger="$1"
  local backup_path="$2"
  local active_context="$SESSIONS_DIR/active-context.md"

  if [[ ! -f "$active_context" ]]; then
    log_debug "active-context.md not found, skipping update"
    return 0
  fi

  # Add Compaction section if it doesn't exist
  if ! grep -q "## Compaction" "$active_context"; then
    echo "" >> "$active_context"
    echo "## Compaction" >> "$active_context"
  fi

  # Remove existing "Last compaction" line and add new one
  local temp_file
  temp_file=$(mktemp)
  grep -v "^- Last compaction:" "$active_context" > "$temp_file" || true
  mv "$temp_file" "$active_context"

  # Add compaction info
  echo "- Last compaction: $(date '+%Y-%m-%d %H:%M:%S') (trigger: $trigger)" >> "$active_context"
  echo "- Transcript backup: $backup_path" >> "$active_context"

  log_debug "Updated active-context.md"
}

# === Main ===

main() {
  log_debug "=== PreCompact Hook Started ==="

  # Read input from stdin
  local input
  input=$(cat)

  # Parse and validate input
  if ! parse_input "$input"; then
    log_debug "Input validation failed, exiting gracefully"
    exit 0
  fi

  # Check if transcript file exists
  if [[ ! -f "$TRANSCRIPT" ]]; then
    log_debug "Transcript file does not exist: $TRANSCRIPT"
    exit 0
  fi

  # Check if transcript file has content (parity with SessionEnd)
  if [[ ! -s "$TRANSCRIPT" ]]; then
    log_debug "Transcript file is empty: $TRANSCRIPT"
    exit 0
  fi

  log_debug "Transcript exists and has content, proceeding with backup"

  # Create backup
  local backup_path
  if ! backup_path=$(create_backup "$TRANSCRIPT" "$TRIGGER"); then
    log_debug "Backup creation failed"
    exit 0
  fi

  # Create pending marker
  create_pending_marker "$backup_path"

  # Update backup log
  update_backup_log "$TRIGGER" "$backup_path"

  # Update active context
  update_active_context "$TRIGGER" "$backup_path"

  log_debug "=== PreCompact Hook Completed ==="
  exit 0
}

# Run main function
main
