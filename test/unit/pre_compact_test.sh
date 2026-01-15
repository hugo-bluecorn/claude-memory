#!/usr/bin/env bash
# PreCompact hook tests
# Tests for src/hooks/on-pre-compact.sh

# Get the directory where this test file is located
TEST_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the hook under test (absolute path based on test file location)
HOOK_PATH="$TEST_FILE_DIR/../../src/hooks/on-pre-compact.sh"

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

# === Input Validation Tests ===

function test_pre_compact_skips_missing_transcript() {
  # When transcript file doesn't exist, hook should skip backup
  local json='{"transcript_path":"/nonexistent/transcript.jsonl","trigger":"auto","session_id":"test-123"}'

  local output
  local exit_code=0

  output=$(echo "$json" | bash "$HOOK_PATH" 2>&1) || exit_code=$?

  assert_equals "0" "$exit_code"

  # No backup should be created
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "0" "$backup_count"
}

# === Successful Backup Tests ===

function test_pre_compact_creates_backup() {
  # When transcript exists, backup should be created
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json="{\"transcript_path\":\"$transcript_file\",\"trigger\":\"auto\",\"session_id\":\"test-123\"}"

  local output
  local exit_code=0

  output=$(echo "$json" | bash "$HOOK_PATH" 2>&1) || exit_code=$?

  assert_equals "0" "$exit_code"

  # Backup should be created
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "1" "$backup_count"
}

function test_pre_compact_creates_pending_marker() {
  # Pending backup marker should be created with backup path
  # NOTE: As of Phase 1.1, PreCompact uses .pending-backup-compact
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json="{\"transcript_path\":\"$transcript_file\",\"trigger\":\"auto\",\"session_id\":\"test-123\"}"

  echo "$json" | bash "$HOOK_PATH" 2>&1

  # Pending marker should exist (using new name)
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup-compact"

  # Marker should contain path to backup
  local marker_content
  marker_content=$(cat "$HOOK_SESSIONS_DIR/.pending-backup-compact")
  assert_contains ".jsonl" "$marker_content"
}

function test_pre_compact_logs_event() {
  # Backup log should be updated with entry
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json="{\"transcript_path\":\"$transcript_file\",\"trigger\":\"auto\",\"session_id\":\"test-123\"}"

  echo "$json" | bash "$HOOK_PATH" 2>&1

  # Backup log should exist and contain entry
  assert_file_exists "$HOOK_SESSIONS_DIR/.backup-log"

  local log_content
  log_content=$(cat "$HOOK_SESSIONS_DIR/.backup-log")
  assert_contains "PreCompact" "$log_content"
  assert_contains "auto" "$log_content"
}

function test_pre_compact_creates_directories() {
  # If raw directory doesn't exist, it should be created
  rm -rf "$HOOK_SESSIONS_DIR/raw"

  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json="{\"transcript_path\":\"$transcript_file\",\"trigger\":\"auto\",\"session_id\":\"test-123\"}"

  echo "$json" | bash "$HOOK_PATH" 2>&1

  assert_directory_exists "$HOOK_SESSIONS_DIR/raw"
}

# === Edge Case Tests: Input Validation ===

function test_pre_compact_handles_empty_input() {
  # Empty input should be handled gracefully
  local exit_code=0
  echo "" | bash "$HOOK_PATH" 2>&1 || exit_code=$?
  assert_equals "0" "$exit_code"
}

function test_pre_compact_handles_invalid_json() {
  # Invalid JSON should be handled gracefully
  local exit_code=0
  echo "not valid json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?
  assert_equals "0" "$exit_code"
}

function test_pre_compact_handles_empty_json_object() {
  # Empty JSON object should be handled gracefully
  local exit_code=0
  echo '{}' | bash "$HOOK_PATH" 2>&1 || exit_code=$?
  assert_equals "0" "$exit_code"
}

function test_pre_compact_handles_null_transcript_path() {
  # Null transcript_path should skip backup
  local json='{"transcript_path":null,"trigger":"auto","session_id":"test-123"}'
  local exit_code=0

  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "0" "$backup_count"
}

function test_pre_compact_handles_empty_transcript_file() {
  # Empty transcript file should still be copied (PreCompact is less strict than SessionEnd)
  local transcript_file="$TEST_DIR/empty_transcript.jsonl"
  touch "$transcript_file"

  local json="{\"transcript_path\":\"$transcript_file\",\"trigger\":\"auto\",\"session_id\":\"test-123\"}"
  local exit_code=0

  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
  # Note: PreCompact doesn't check if file is empty, just if it exists
}

# === Edge Case Tests: File Paths ===

function test_pre_compact_handles_path_with_spaces() {
  # Transcript path containing spaces should work
  local transcript_dir="$TEST_DIR/path with spaces"
  mkdir -p "$transcript_dir"
  local transcript_file="$transcript_dir/transcript file.jsonl"
  create_test_transcript "$transcript_file"

  local json="{\"transcript_path\":\"$transcript_file\",\"trigger\":\"auto\",\"session_id\":\"test-123\"}"
  local exit_code=0

  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "1" "$backup_count"
}

# === Edge Case Tests: Trigger Values ===

function test_pre_compact_handles_manual_trigger() {
  # Manual trigger should work same as auto
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json="{\"transcript_path\":\"$transcript_file\",\"trigger\":\"manual\",\"session_id\":\"test-123\"}"

  echo "$json" | bash "$HOOK_PATH" 2>&1

  local log_content
  log_content=$(cat "$HOOK_SESSIONS_DIR/.backup-log")
  assert_contains "manual" "$log_content"
}

function test_pre_compact_handles_missing_trigger() {
  # Missing trigger field should work (uses empty)
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json="{\"transcript_path\":\"$transcript_file\",\"session_id\":\"test-123\"}"
  local exit_code=0

  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "1" "$backup_count"
}

# === Edge Case Tests: Backup Content ===

function test_pre_compact_backup_preserves_content() {
  # Backup file should have identical content to original
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"
  local original_hash
  original_hash=$(md5sum "$transcript_file" | cut -d' ' -f1)

  local json="{\"transcript_path\":\"$transcript_file\",\"trigger\":\"auto\",\"session_id\":\"test-123\"}"
  echo "$json" | bash "$HOOK_PATH" 2>&1

  local backup_file
  backup_file=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | head -1)
  local backup_hash
  backup_hash=$(md5sum "$backup_file" | cut -d' ' -f1)

  assert_equals "$original_hash" "$backup_hash"
}

# === Phase 1.1: Multi-Marker Support Tests ===
# These tests enforce the new marker naming convention to prevent overwrites

function test_pre_compact_creates_compact_marker() {
  # PreCompact should use .pending-backup-compact (not .pending-backup)
  # This prevents overwrites when SessionEnd also runs
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json="{\"transcript_path\":\"$transcript_file\",\"trigger\":\"auto\",\"session_id\":\"test-123\"}"
  echo "$json" | bash "$HOOK_PATH" 2>&1

  # New marker should exist
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup-compact"

  # Old marker should NOT exist (breaking change)
  assert_file_not_exists "$HOOK_SESSIONS_DIR/.pending-backup"

  # Marker should contain backup path
  local marker_content
  marker_content=$(cat "$HOOK_SESSIONS_DIR/.pending-backup-compact")
  assert_contains ".jsonl" "$marker_content"
}

function test_pre_compact_does_not_overwrite_exit_marker() {
  # If .pending-backup-exit exists, PreCompact should not touch it
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  # Pre-create an exit marker
  echo "/path/to/exit-backup.jsonl" > "$HOOK_SESSIONS_DIR/.pending-backup-exit"

  local json="{\"transcript_path\":\"$transcript_file\",\"trigger\":\"auto\",\"session_id\":\"test-123\"}"
  echo "$json" | bash "$HOOK_PATH" 2>&1

  # Exit marker should be preserved
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup-exit"
  local exit_content
  exit_content=$(cat "$HOOK_SESSIONS_DIR/.pending-backup-exit")
  assert_contains "exit-backup" "$exit_content"

  # Compact marker should also exist
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup-compact"
}
