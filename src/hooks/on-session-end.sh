#!/usr/bin/env bash
# Hook: SessionEnd
# Purpose: Save raw transcript backup when session ends (via /exit or other termination)
# Input: JSON via stdin with session_id, transcript_path, stop_reason
# Reason values: clear, logout, prompt_input_exit, other
#
# This hook ensures session context is preserved even without manual /document-and-save.
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
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $msg" >> "$SESSIONS_DIR/.debug-log"
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
  REASON=$(echo "$input" | jq -r '.stop_reason // empty')
  SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')

  # Validate required fields
  if [[ -z "$TRANSCRIPT" ]]; then
    log_debug "transcript_path is null or empty"
    return 1
  fi

  log_debug "Parsed: TRANSCRIPT=$TRANSCRIPT, REASON=$REASON, SESSION_ID=$SESSION_ID"
  return 0
}

# Create backup of transcript file
create_backup() {
  local transcript="$1"
  local reason="$2"
  local timestamp
  timestamp=$(date -u +%Y%m%d_%H%M%SZ)

  # Ensure raw directory exists
  mkdir -p "$SESSIONS_DIR/raw"

  # Create backup with reason suffix
  local backup_path="$SESSIONS_DIR/raw/${timestamp}_${reason}.jsonl"

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
# Uses .pending-backup-exit to avoid conflict with PreCompact's .pending-backup-compact
create_pending_marker() {
  local backup_path="$1"
  echo "$backup_path" > "$SESSIONS_DIR/.pending-backup-exit"
  log_debug "Created pending marker (.pending-backup-exit)"
}

# Update backup log
update_backup_log() {
  local reason="$1"
  local backup_path="$2"
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] SessionEnd ($reason): Saved backup to $backup_path" >> "$SESSIONS_DIR/.backup-log"
  log_debug "Updated backup log"
}

# Update active-context.md with session exit info
update_active_context() {
  local reason="$1"
  local backup_path="$2"
  local active_context="$SESSIONS_DIR/active-context.md"

  if [[ ! -f "$active_context" ]]; then
    log_debug "active-context.md not found, skipping update"
    return 0
  fi

  # Add Session Exit section if it doesn't exist
  if ! grep -q "## Session Exit" "$active_context"; then
    echo "" >> "$active_context"
    echo "## Session Exit" >> "$active_context"
  fi

  # Remove existing "Last exit" line and add new one
  # Use temp file to avoid sed -i portability issues
  local temp_file
  temp_file=$(mktemp)
  grep -v "^- Last exit:" "$active_context" > "$temp_file" || true
  mv "$temp_file" "$active_context"

  # Add exit info
  echo "- Last exit: $(date -u '+%Y-%m-%dT%H:%M:%SZ') (reason: $reason)" >> "$active_context"
  echo "- Transcript backup: $backup_path" >> "$active_context"

  log_debug "Updated active-context.md"
}

# === Main ===

main() {
  log_debug "=== SessionEnd Hook Started ==="

  # Read input from stdin
  local input
  input=$(cat)

  # Parse and validate input
  if ! parse_input "$input"; then
    log_debug "Input validation failed, exiting gracefully"
    exit 0
  fi

  # Check if transcript file exists and has content
  if [[ ! -f "$TRANSCRIPT" ]]; then
    log_debug "Transcript file does not exist: $TRANSCRIPT"
    exit 0
  fi

  if [[ ! -s "$TRANSCRIPT" ]]; then
    log_debug "Transcript file is empty: $TRANSCRIPT"
    exit 0
  fi

  log_debug "Transcript exists and has content, proceeding with backup"

  # Create backup
  local backup_path
  if ! backup_path=$(create_backup "$TRANSCRIPT" "$REASON"); then
    log_debug "Backup creation failed"
    exit 0
  fi

  # Create pending marker
  create_pending_marker "$backup_path"

  # Update backup log
  update_backup_log "$REASON" "$backup_path"

  # Update active context
  update_active_context "$REASON" "$backup_path"

  log_debug "=== SessionEnd Hook Completed ==="
  exit 0
}

# Run main function
main
