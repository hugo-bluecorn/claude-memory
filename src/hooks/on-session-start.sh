#!/usr/bin/env bash
# Hook: SessionStart
# Purpose: Check for pending backups and output notification to stdout (for Claude context)
# Input: JSON via stdin with session_id, transcript_path, source
# Exit codes:
#   0 = success (always - SessionStart cannot block, exit 2 only shows stderr to user)
# Note: stdout is added as context for Claude, enabling awareness of pending backups
#
# Supports marker types:
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

# Staleness threshold in seconds (24 hours)
STALENESS_THRESHOLD=${HOOK_STALENESS_THRESHOLD:-86400}

# Overhead threshold in bytes (20KB)
OVERHEAD_THRESHOLD=${HOOK_OVERHEAD_THRESHOLD:-20480}

# Check if sessions directory exists
if [[ ! -d "$SESSIONS_DIR" ]]; then
  exit 0
fi

# === Functions ===

# Check if context files are too large (>20KB combined)
check_overhead() {
  local active_context="$SESSIONS_DIR/active-context.md"
  local project_memory="$SESSIONS_DIR/project-memory.md"
  local total_size=0

  # Get size of active-context.md
  if [[ -f "$active_context" ]]; then
    local ac_size
    ac_size=$(wc -c < "$active_context" 2>/dev/null || echo 0)
    total_size=$((total_size + ac_size))
  fi

  # Get size of project-memory.md
  if [[ -f "$project_memory" ]]; then
    local pm_size
    pm_size=$(wc -c < "$project_memory" 2>/dev/null || echo 0)
    total_size=$((total_size + pm_size))
  fi

  if [[ $total_size -gt $OVERHEAD_THRESHOLD ]]; then
    local size_kb=$((total_size / 1024))
    echo "CONTEXT_OVERHEAD: Context files are ${size_kb}KB (threshold: $((OVERHEAD_THRESHOLD / 1024))KB). Consider trimming active-context.md."
  fi
}

# Check if active-context.md is stale (>24h since last update)
check_staleness() {
  local active_context="$SESSIONS_DIR/active-context.md"

  if [[ ! -f "$active_context" ]]; then
    return 0
  fi

  # Extract timestamp from "> Last Updated: YYYY-MM-DD HH:MM:SS" line
  local timestamp_line
  timestamp_line=$(grep -E "^> Last Updated:" "$active_context" 2>/dev/null || echo "")

  if [[ -z "$timestamp_line" ]]; then
    # No timestamp found, can't check staleness (backwards compatible)
    return 0
  fi

  # Extract the timestamp part
  local timestamp
  timestamp=$(echo "$timestamp_line" | sed 's/^> Last Updated: //')

  # Convert timestamp to epoch seconds (handle both old and new formats)
  local context_epoch
  if [[ "$timestamp" == *"Z" ]]; then
    # ISO 8601 UTC format (new): 2026-01-26T03:30:00Z
    local ts_no_z="${timestamp%Z}"
    context_epoch=$(date -u -d "$ts_no_z" +%s 2>/dev/null || \
                    date -j -u -f "%Y-%m-%dT%H:%M:%S" "$ts_no_z" +%s 2>/dev/null || echo "")
  else
    # Legacy format: YYYY-MM-DD HH:MM:SS
    context_epoch=$(date -d "$timestamp" +%s 2>/dev/null || \
                    date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" +%s 2>/dev/null || echo "")
  fi

  if [[ -z "$context_epoch" ]]; then
    # Could not parse timestamp
    return 0
  fi

  local current_epoch
  current_epoch=$(date +%s)

  local age_seconds=$((current_epoch - context_epoch))

  if [[ $age_seconds -gt $STALENESS_THRESHOLD ]]; then
    local age_hours=$((age_seconds / 3600))
    echo "CONTEXT_STALE: active-context.md is stale (last updated ${age_hours}h ago). Consider running /document-and-save to update."
  fi
}

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

# === Main ===

# Check for staleness first
check_staleness

# Check for context file overhead
check_overhead

# Check for marker types
process_marker "$SESSIONS_DIR/.pending-backup-compact" "compact"
process_marker "$SESSIONS_DIR/.pending-backup-exit" "exit"

# If any pending backups were found, output instructions
if [[ "$found_pending" == "true" ]]; then
  echo "User should run /resume-latest to restore context, or /discard-backup to discard."
fi

exit 0
