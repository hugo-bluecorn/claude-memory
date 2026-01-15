#!/usr/bin/env bash
# SessionStart hook tests
# Tests for src/hooks/on-session-start.sh

# Get the directory where this test file is located
TEST_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the hook under test (absolute path based on test file location)
HOOK_PATH="$TEST_FILE_DIR/../../src/hooks/on-session-start.sh"

function set_up() {
  # Create isolated test environment for each test
  TEST_DIR=$(create_test_environment)
  export HOOK_PROJECT_DIR="$TEST_DIR"
  export HOOK_SESSIONS_DIR="$TEST_DIR/planning/sessions"
}

function tear_down() {
  # Cleanup test environment
  if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
  unset HOOK_PROJECT_DIR
  unset HOOK_SESSIONS_DIR
}

# === No Pending Backup Tests ===

function test_session_start_silent_when_no_pending() {
  # When no pending backup marker exists, hook should be silent
  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'

  local output
  local exit_code=0

  output=$(echo "$json" | bash "$HOOK_PATH" 2>&1) || exit_code=$?

  assert_equals "0" "$exit_code"
  # Output should be empty (no pending backup message)
  assert_not_contains "pending backup" "$output"
}

# === Pending Backup Detection Tests ===

function test_session_start_outputs_context_with_pending_backup() {
  # When pending backup exists and backup file exists, hook should exit 0
  # and output notification message to stdout (for Claude context)
  # Note: SessionStart hooks cannot block (exit 2 only shows stderr to user)
  local backup_file="$HOOK_SESSIONS_DIR/raw/test_backup.jsonl"
  mkdir -p "$(dirname "$backup_file")"
  create_test_transcript "$backup_file"

  # Create pending marker pointing to backup
  echo "$backup_file" > "$HOOK_SESSIONS_DIR/.pending-backup"

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'

  local stdout_output
  local exit_code=0

  stdout_output=$(echo "$json" | bash "$HOOK_PATH" 2>/dev/null) || exit_code=$?

  # Exit code 0 - success with context output
  assert_equals "0" "$exit_code"
  # Message should include backup path and instructions (output to stdout for Claude)
  assert_contains "SESSION_BACKUP_PENDING" "$stdout_output"
  assert_contains "resume-latest" "$stdout_output"
  assert_contains "discard-backup" "$stdout_output"
}

function test_session_start_preserves_marker_after_notification() {
  # Marker should be preserved after notification so /resume-latest can use it
  local backup_file="$HOOK_SESSIONS_DIR/raw/20251209_120000_test.jsonl"
  mkdir -p "$(dirname "$backup_file")"
  create_test_transcript "$backup_file"

  # Create pending marker pointing to backup
  echo "$backup_file" > "$HOOK_SESSIONS_DIR/.pending-backup"

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'

  # Run hook
  echo "$json" | bash "$HOOK_PATH" 2>&1

  # Marker should still exist with correct path
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup"
  local marker_content
  marker_content=$(cat "$HOOK_SESSIONS_DIR/.pending-backup")
  assert_contains "20251209_120000_test.jsonl" "$marker_content"
}

function test_session_start_cleans_stale_marker() {
  # When marker exists but backup file doesn't, marker should be cleaned
  echo "/nonexistent/backup.jsonl" > "$HOOK_SESSIONS_DIR/.pending-backup"

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'

  echo "$json" | bash "$HOOK_PATH" 2>&1

  # Marker should be removed
  assert_file_not_exists "$HOOK_SESSIONS_DIR/.pending-backup"
}

# === Edge Case Tests: Input Validation ===

function test_session_start_handles_empty_input() {
  # Empty input should be handled gracefully
  local exit_code=0
  echo "" | bash "$HOOK_PATH" 2>&1 || exit_code=$?
  assert_equals "0" "$exit_code"
}

function test_session_start_handles_invalid_json() {
  # Invalid JSON should be handled gracefully
  local exit_code=0
  echo "not valid json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?
  assert_equals "0" "$exit_code"
}

function test_session_start_handles_empty_json_object() {
  # Empty JSON object should be handled gracefully
  local exit_code=0
  echo '{}' | bash "$HOOK_PATH" 2>&1 || exit_code=$?
  assert_equals "0" "$exit_code"
}

# === Edge Case Tests: Marker Content ===

function test_session_start_handles_empty_marker_file() {
  # Empty marker file should be handled gracefully
  touch "$HOOK_SESSIONS_DIR/.pending-backup"

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'
  local exit_code=0

  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
  # Empty marker should be cleaned
  assert_file_not_exists "$HOOK_SESSIONS_DIR/.pending-backup"
}

function test_session_start_handles_marker_with_whitespace() {
  # Marker with extra whitespace should be trimmed and detect the backup
  local backup_file="$HOOK_SESSIONS_DIR/raw/test_backup.jsonl"
  mkdir -p "$(dirname "$backup_file")"
  create_test_transcript "$backup_file"

  # Create marker with extra whitespace
  echo "   $backup_file   " > "$HOOK_SESSIONS_DIR/.pending-backup"

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'
  local exit_code=0
  local stdout_output
  stdout_output=$(echo "$json" | bash "$HOOK_PATH" 2>/dev/null) || exit_code=$?

  # Should detect the backup and output notification (exit 0)
  assert_equals "0" "$exit_code"
  assert_contains "resume-latest" "$stdout_output"
}

# === Edge Case Tests: Source Values ===

function test_session_start_handles_different_sources() {
  # Hook should work regardless of source value
  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"new_session"}'
  local exit_code=0

  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

function test_session_start_handles_missing_source() {
  # Missing source field should be handled gracefully
  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript"}'
  local exit_code=0

  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

# === Edge Case Tests: File System ===

function test_session_start_handles_path_with_spaces_in_marker() {
  # Marker pointing to path with spaces should output notification
  local backup_file="$HOOK_SESSIONS_DIR/raw/path with spaces/backup.jsonl"
  mkdir -p "$(dirname "$backup_file")"
  create_test_transcript "$backup_file"

  echo "$backup_file" > "$HOOK_SESSIONS_DIR/.pending-backup"

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'
  local exit_code=0
  local stdout_output
  stdout_output=$(echo "$json" | bash "$HOOK_PATH" 2>/dev/null) || exit_code=$?

  # Should output notification (exit 0)
  assert_equals "0" "$exit_code"
  assert_contains "resume-latest" "$stdout_output"
  # Marker should be preserved
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup"
}

function test_session_start_handles_missing_sessions_directory() {
  # If sessions directory doesn't exist, should handle gracefully
  rm -rf "$HOOK_SESSIONS_DIR"

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'
  local exit_code=0

  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

# === Phase 1.1: Multi-Marker Support Tests ===
# These tests enforce the new marker naming convention

function test_session_start_detects_compact_marker() {
  # SessionStart should detect .pending-backup-compact
  local backup_file="$HOOK_SESSIONS_DIR/raw/compact_backup.jsonl"
  mkdir -p "$(dirname "$backup_file")"
  create_test_transcript "$backup_file"

  # Create compact marker
  echo "$backup_file" > "$HOOK_SESSIONS_DIR/.pending-backup-compact"

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'
  local stdout_output
  local exit_code=0

  stdout_output=$(echo "$json" | bash "$HOOK_PATH" 2>/dev/null) || exit_code=$?

  assert_equals "0" "$exit_code"
  assert_contains "SESSION_BACKUP_PENDING" "$stdout_output"
  assert_contains "compact" "$stdout_output"
}

function test_session_start_detects_exit_marker() {
  # SessionStart should detect .pending-backup-exit
  local backup_file="$HOOK_SESSIONS_DIR/raw/exit_backup.jsonl"
  mkdir -p "$(dirname "$backup_file")"
  create_test_transcript "$backup_file"

  # Create exit marker
  echo "$backup_file" > "$HOOK_SESSIONS_DIR/.pending-backup-exit"

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'
  local stdout_output
  local exit_code=0

  stdout_output=$(echo "$json" | bash "$HOOK_PATH" 2>/dev/null) || exit_code=$?

  assert_equals "0" "$exit_code"
  assert_contains "SESSION_BACKUP_PENDING" "$stdout_output"
  assert_contains "exit" "$stdout_output"
}

function test_session_start_detects_multiple_markers() {
  # SessionStart should detect BOTH markers when both exist
  local compact_backup="$HOOK_SESSIONS_DIR/raw/compact_backup.jsonl"
  local exit_backup="$HOOK_SESSIONS_DIR/raw/exit_backup.jsonl"
  mkdir -p "$(dirname "$compact_backup")"
  create_test_transcript "$compact_backup"
  create_test_transcript "$exit_backup"

  # Create both markers
  echo "$compact_backup" > "$HOOK_SESSIONS_DIR/.pending-backup-compact"
  echo "$exit_backup" > "$HOOK_SESSIONS_DIR/.pending-backup-exit"

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'
  local stdout_output
  local exit_code=0

  stdout_output=$(echo "$json" | bash "$HOOK_PATH" 2>/dev/null) || exit_code=$?

  assert_equals "0" "$exit_code"
  # Should mention both backups
  assert_contains "compact" "$stdout_output"
  assert_contains "exit" "$stdout_output"
}

function test_session_start_preserves_multiple_markers() {
  # Both markers should be preserved after detection
  local compact_backup="$HOOK_SESSIONS_DIR/raw/compact_backup.jsonl"
  local exit_backup="$HOOK_SESSIONS_DIR/raw/exit_backup.jsonl"
  mkdir -p "$(dirname "$compact_backup")"
  create_test_transcript "$compact_backup"
  create_test_transcript "$exit_backup"

  echo "$compact_backup" > "$HOOK_SESSIONS_DIR/.pending-backup-compact"
  echo "$exit_backup" > "$HOOK_SESSIONS_DIR/.pending-backup-exit"

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'
  echo "$json" | bash "$HOOK_PATH" 2>&1

  # Both markers should still exist
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup-compact"
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup-exit"
}

# === Phase 2.1: Staleness Detection Tests ===

function test_session_start_warns_if_context_stale() {
  # When active-context.md has a timestamp >24h old, should warn
  local active_context="$HOOK_SESSIONS_DIR/active-context.md"

  # Create active-context.md with an old timestamp (48 hours ago)
  local old_timestamp
  old_timestamp=$(date -d "48 hours ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-48H '+%Y-%m-%d %H:%M:%S' 2>/dev/null)

  cat > "$active_context" << EOF
# Active Session Context
> Last Updated: $old_timestamp

## Current Task
Test task
EOF

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'
  local stdout_output
  local exit_code=0

  stdout_output=$(echo "$json" | bash "$HOOK_PATH" 2>/dev/null) || exit_code=$?

  assert_equals "0" "$exit_code"
  # Should contain staleness warning
  assert_contains "stale" "$stdout_output"
}

function test_session_start_no_warning_if_context_fresh() {
  # When active-context.md has a recent timestamp (<24h), no warning
  local active_context="$HOOK_SESSIONS_DIR/active-context.md"

  # Create active-context.md with a fresh timestamp (1 hour ago)
  local fresh_timestamp
  fresh_timestamp=$(date -d "1 hour ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-1H '+%Y-%m-%d %H:%M:%S' 2>/dev/null)

  cat > "$active_context" << EOF
# Active Session Context
> Last Updated: $fresh_timestamp

## Current Task
Test task
EOF

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'
  local stdout_output
  local exit_code=0

  stdout_output=$(echo "$json" | bash "$HOOK_PATH" 2>/dev/null) || exit_code=$?

  assert_equals "0" "$exit_code"
  # Should NOT contain staleness warning
  assert_not_contains "stale" "$stdout_output"
}

function test_session_start_no_warning_if_no_timestamp() {
  # When active-context.md has no timestamp header, no warning (backwards compatible)
  local active_context="$HOOK_SESSIONS_DIR/active-context.md"

  # Create active-context.md without timestamp
  cat > "$active_context" << EOF
# Active Session Context

## Current Task
Test task
EOF

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'
  local stdout_output
  local exit_code=0

  stdout_output=$(echo "$json" | bash "$HOOK_PATH" 2>/dev/null) || exit_code=$?

  assert_equals "0" "$exit_code"
  # Should NOT contain staleness warning
  assert_not_contains "stale" "$stdout_output"
}

function test_session_start_no_warning_if_no_active_context() {
  # When active-context.md doesn't exist, no warning
  rm -f "$HOOK_SESSIONS_DIR/active-context.md"

  local json='{"session_id":"test-123","transcript_path":"/path/to/transcript","source":"resume"}'
  local stdout_output
  local exit_code=0

  stdout_output=$(echo "$json" | bash "$HOOK_PATH" 2>/dev/null) || exit_code=$?

  assert_equals "0" "$exit_code"
  # Should NOT contain staleness warning
  assert_not_contains "stale" "$stdout_output"
}
