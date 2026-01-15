#!/usr/bin/env bash
# DiscardBackup script tests
# Tests for src/scripts/discard-backup.sh

# Get the directory where this test file is located
TEST_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the script under test (absolute path based on test file location)
SCRIPT_PATH="$TEST_FILE_DIR/../../src/scripts/discard-backup.sh"

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

# === Core Functionality Tests ===

function test_discard_removes_backup_file() {
  # When backup file exists and marker points to it, both should be deleted
  local backup_file="$HOOK_SESSIONS_DIR/raw/test_backup.jsonl"
  mkdir -p "$(dirname "$backup_file")"
  create_test_transcript "$backup_file"
  echo "$backup_file" > "$HOOK_SESSIONS_DIR/.pending-backup"

  bash "$SCRIPT_PATH" 2>&1

  assert_file_not_exists "$backup_file"
}

function test_discard_removes_marker() {
  # Marker should be removed after discard
  local backup_file="$HOOK_SESSIONS_DIR/raw/test_backup.jsonl"
  mkdir -p "$(dirname "$backup_file")"
  create_test_transcript "$backup_file"
  echo "$backup_file" > "$HOOK_SESSIONS_DIR/.pending-backup"

  bash "$SCRIPT_PATH" 2>&1

  assert_file_not_exists "$HOOK_SESSIONS_DIR/.pending-backup"
}

function test_discard_returns_success() {
  # Should return exit code 0 on successful discard
  local backup_file="$HOOK_SESSIONS_DIR/raw/test_backup.jsonl"
  mkdir -p "$(dirname "$backup_file")"
  create_test_transcript "$backup_file"
  echo "$backup_file" > "$HOOK_SESSIONS_DIR/.pending-backup"

  local exit_code=0
  bash "$SCRIPT_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

function test_discard_outputs_confirmation() {
  # Should output confirmation message
  local backup_file="$HOOK_SESSIONS_DIR/raw/test_backup.jsonl"
  mkdir -p "$(dirname "$backup_file")"
  create_test_transcript "$backup_file"
  echo "$backup_file" > "$HOOK_SESSIONS_DIR/.pending-backup"

  local output
  output=$(bash "$SCRIPT_PATH" 2>&1)

  assert_contains "discarded" "$output"
}

# === No Pending Backup Tests ===

function test_discard_handles_no_marker() {
  # When no marker exists, should report nothing to discard
  local output
  local exit_code=0

  output=$(bash "$SCRIPT_PATH" 2>&1) || exit_code=$?

  assert_equals "0" "$exit_code"
  assert_contains "No pending backup" "$output"
}

function test_discard_handles_empty_marker() {
  # When marker exists but is empty, should clean up and report
  touch "$HOOK_SESSIONS_DIR/.pending-backup"

  local output
  local exit_code=0

  output=$(bash "$SCRIPT_PATH" 2>&1) || exit_code=$?

  assert_equals "0" "$exit_code"
  assert_file_not_exists "$HOOK_SESSIONS_DIR/.pending-backup"
}

function test_discard_handles_stale_marker() {
  # When marker points to non-existent file, should clean marker
  echo "/nonexistent/backup.jsonl" > "$HOOK_SESSIONS_DIR/.pending-backup"

  local output
  local exit_code=0

  output=$(bash "$SCRIPT_PATH" 2>&1) || exit_code=$?

  assert_equals "0" "$exit_code"
  assert_file_not_exists "$HOOK_SESSIONS_DIR/.pending-backup"
}

# === Edge Cases ===

function test_discard_handles_path_with_spaces() {
  # Backup path with spaces should be handled correctly
  local backup_file="$HOOK_SESSIONS_DIR/raw/path with spaces/backup.jsonl"
  mkdir -p "$(dirname "$backup_file")"
  create_test_transcript "$backup_file"
  echo "$backup_file" > "$HOOK_SESSIONS_DIR/.pending-backup"

  bash "$SCRIPT_PATH" 2>&1

  assert_file_not_exists "$backup_file"
  assert_file_not_exists "$HOOK_SESSIONS_DIR/.pending-backup"
}

function test_discard_handles_missing_sessions_dir() {
  # If sessions directory doesn't exist, should handle gracefully
  rm -rf "$HOOK_SESSIONS_DIR"

  local exit_code=0
  bash "$SCRIPT_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

function test_discard_preserves_other_backups() {
  # Should only delete the specific backup, not others
  local backup_file="$HOOK_SESSIONS_DIR/raw/pending_backup.jsonl"
  local other_backup="$HOOK_SESSIONS_DIR/raw/other_backup.jsonl"
  mkdir -p "$(dirname "$backup_file")"
  create_test_transcript "$backup_file"
  create_test_transcript "$other_backup"
  echo "$backup_file" > "$HOOK_SESSIONS_DIR/.pending-backup"

  bash "$SCRIPT_PATH" 2>&1

  assert_file_not_exists "$backup_file"
  assert_file_exists "$other_backup"
}
