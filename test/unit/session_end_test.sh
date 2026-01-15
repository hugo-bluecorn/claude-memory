#!/usr/bin/env bash
# SessionEnd hook tests
# Tests for src/hooks/on-session-end.sh

# Get the directory where this test file is located
TEST_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the hook under test (absolute path based on test file location)
HOOK_PATH="$TEST_FILE_DIR/../../src/hooks/on-session-end.sh"

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

function test_session_end_fails_gracefully_with_no_input() {
  # When hook receives empty input, it should exit gracefully (not crash)
  local output
  local exit_code=0

  output=$(echo "" | bash "$HOOK_PATH" 2>&1) || exit_code=$?

  # Should exit with 0 (graceful handling) and not crash
  assert_equals "0" "$exit_code"
}

function test_session_end_validates_json_input() {
  # When hook receives invalid JSON, it should handle gracefully
  local output
  local exit_code=0

  output=$(echo "not valid json" | bash "$HOOK_PATH" 2>&1) || exit_code=$?

  # Should exit with 0 (graceful handling)
  assert_equals "0" "$exit_code"
}

function test_session_end_skips_when_transcript_null() {
  # When transcript_path is null, hook should skip backup
  local json
  json=$(mock_hook_input "" "prompt_input_exit" "session-123")

  local output
  local exit_code=0

  output=$(echo "$json" | bash "$HOOK_PATH" 2>&1) || exit_code=$?

  assert_equals "0" "$exit_code"
  # No backup should be created
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "0" "$backup_count"
}

function test_session_end_skips_when_transcript_missing() {
  # When transcript_path points to non-existent file, hook should skip
  local json
  json=$(mock_hook_input "/nonexistent/path/transcript.jsonl" "prompt_input_exit" "session-123")

  local output
  local exit_code=0

  output=$(echo "$json" | bash "$HOOK_PATH" 2>&1) || exit_code=$?

  assert_equals "0" "$exit_code"
  # No backup should be created
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "0" "$backup_count"
}

function test_session_end_skips_when_transcript_empty() {
  # When transcript file exists but is empty, hook should skip
  local transcript_file="$TEST_DIR/empty_transcript.jsonl"
  touch "$transcript_file"

  local json
  json=$(mock_hook_input "$transcript_file" "prompt_input_exit" "session-123")

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

function test_session_end_creates_backup_successfully() {
  # When transcript exists and has content, backup should be created
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json
  json=$(mock_hook_input "$transcript_file" "prompt_input_exit" "session-123")

  local output
  local exit_code=0

  output=$(echo "$json" | bash "$HOOK_PATH" 2>&1) || exit_code=$?

  assert_equals "0" "$exit_code"

  # Backup should be created in raw directory
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "1" "$backup_count"
}

function test_session_end_creates_pending_marker() {
  # Pending backup marker should be created with backup path
  # NOTE: As of Phase 1.1, SessionEnd uses .pending-backup-exit
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json
  json=$(mock_hook_input "$transcript_file" "prompt_input_exit" "session-123")

  echo "$json" | bash "$HOOK_PATH" 2>&1

  # Pending marker should exist (using new name)
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup-exit"

  # Marker should contain path to backup
  local marker_content
  marker_content=$(cat "$HOOK_SESSIONS_DIR/.pending-backup-exit")
  assert_contains ".jsonl" "$marker_content"
}

function test_session_end_updates_backup_log() {
  # Backup log should be updated with entry
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json
  json=$(mock_hook_input "$transcript_file" "prompt_input_exit" "session-123")

  echo "$json" | bash "$HOOK_PATH" 2>&1

  # Backup log should exist and contain entry
  assert_file_exists "$HOOK_SESSIONS_DIR/.backup-log"

  local log_content
  log_content=$(cat "$HOOK_SESSIONS_DIR/.backup-log")
  assert_contains "SessionEnd" "$log_content"
  assert_contains "prompt_input_exit" "$log_content"
}

function test_session_end_updates_active_context() {
  # Active context should be updated with session exit info
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  # Create initial active-context.md
  echo "# Active Session Context" > "$HOOK_SESSIONS_DIR/active-context.md"
  echo "" >> "$HOOK_SESSIONS_DIR/active-context.md"
  echo "## Current Task" >> "$HOOK_SESSIONS_DIR/active-context.md"
  echo "Test task" >> "$HOOK_SESSIONS_DIR/active-context.md"

  local json
  json=$(mock_hook_input "$transcript_file" "prompt_input_exit" "session-123")

  echo "$json" | bash "$HOOK_PATH" 2>&1

  # Active context should contain session exit section
  local context_content
  context_content=$(cat "$HOOK_SESSIONS_DIR/active-context.md")
  assert_contains "Session Exit" "$context_content"
  assert_contains "prompt_input_exit" "$context_content"
}

function test_session_end_creates_raw_directory() {
  # If raw directory doesn't exist, it should be created
  rm -rf "$HOOK_SESSIONS_DIR/raw"

  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json
  json=$(mock_hook_input "$transcript_file" "prompt_input_exit" "session-123")

  echo "$json" | bash "$HOOK_PATH" 2>&1

  assert_directory_exists "$HOOK_SESSIONS_DIR/raw"
}

# === Reason Handling Tests (data provider pattern) ===

function test_session_end_handles_reason_clear() {
  _test_reason_handling "clear"
}

function test_session_end_handles_reason_logout() {
  _test_reason_handling "logout"
}

function test_session_end_handles_reason_prompt_input_exit() {
  _test_reason_handling "prompt_input_exit"
}

function test_session_end_handles_reason_other() {
  _test_reason_handling "other"
}

# Helper for reason tests
function _test_reason_handling() {
  local reason="$1"

  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json
  json=$(mock_hook_input "$transcript_file" "$reason" "session-123")

  local output
  local exit_code=0

  output=$(echo "$json" | bash "$HOOK_PATH" 2>&1) || exit_code=$?

  assert_equals "0" "$exit_code"

  # Backup filename should contain the reason
  local backup_file
  backup_file=$(find "$HOOK_SESSIONS_DIR/raw" -name "*${reason}.jsonl" -type f 2>/dev/null | head -1)
  assert_not_empty "$backup_file"
}

# === Edge Case Tests: JSON Input ===

function test_session_end_handles_empty_json_object() {
  # Empty JSON object {} should be handled gracefully
  local exit_code=0
  echo '{}' | bash "$HOOK_PATH" 2>&1 || exit_code=$?
  assert_equals "0" "$exit_code"
}

function test_session_end_handles_json_with_null_values() {
  # JSON with explicit null values should skip backup
  local json='{"transcript_path":null,"stop_reason":null,"session_id":null}'
  local exit_code=0

  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "0" "$backup_count"
}

function test_session_end_handles_json_missing_stop_reason() {
  # JSON without stop_reason should use empty reason in filename
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json="{\"transcript_path\":\"$transcript_file\",\"session_id\":\"test-123\"}"
  local exit_code=0

  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
  # Backup should still be created
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "1" "$backup_count"
}

function test_session_end_handles_extra_json_fields() {
  # Extra unexpected fields should be ignored
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json="{\"transcript_path\":\"$transcript_file\",\"stop_reason\":\"test\",\"session_id\":\"123\",\"extra_field\":\"ignored\",\"another\":42}"
  local exit_code=0

  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "1" "$backup_count"
}

function test_session_end_handles_malformed_json_partial() {
  # Partial/truncated JSON should be handled gracefully
  local exit_code=0
  echo '{"transcript_path":"/some/path' | bash "$HOOK_PATH" 2>&1 || exit_code=$?
  assert_equals "0" "$exit_code"
}

# === Edge Case Tests: File Paths ===

function test_session_end_handles_path_with_spaces() {
  # Transcript path containing spaces should work
  local transcript_dir="$TEST_DIR/path with spaces"
  mkdir -p "$transcript_dir"
  local transcript_file="$transcript_dir/transcript file.jsonl"
  create_test_transcript "$transcript_file"

  local json
  json=$(mock_hook_input "$transcript_file" "test" "session-123")

  local exit_code=0
  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "1" "$backup_count"
}

function test_session_end_handles_special_characters_in_reason() {
  # Reason with special chars should be sanitized or handled
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  # Note: actual Claude Code only sends known reason values, but test resilience
  local json="{\"transcript_path\":\"$transcript_file\",\"stop_reason\":\"test-reason_123\",\"session_id\":\"session-123\"}"
  local exit_code=0

  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

# === Edge Case Tests: Backup Content ===

function test_session_end_backup_preserves_content() {
  # Backup file should have identical content to original
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"
  local original_hash
  original_hash=$(md5sum "$transcript_file" | cut -d' ' -f1)

  local json
  json=$(mock_hook_input "$transcript_file" "test" "session-123")
  echo "$json" | bash "$HOOK_PATH" 2>&1

  local backup_file
  backup_file=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | head -1)
  local backup_hash
  backup_hash=$(md5sum "$backup_file" | cut -d' ' -f1)

  assert_equals "$original_hash" "$backup_hash"
}

function test_session_end_handles_large_transcript() {
  # Large transcript file should be backed up successfully
  local transcript_file="$TEST_DIR/large_transcript.jsonl"

  # Create ~1MB transcript
  for i in $(seq 1 10000); do
    echo "{\"type\":\"message\",\"content\":\"This is line $i with some content to make it longer\"}" >> "$transcript_file"
  done

  local json
  json=$(mock_hook_input "$transcript_file" "test" "session-123")

  local exit_code=0
  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "1" "$backup_count"
}

# === Edge Case Tests: Active Context ===

function test_session_end_handles_missing_active_context() {
  # Should work even if active-context.md doesn't exist
  rm -f "$HOOK_SESSIONS_DIR/active-context.md"

  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json
  json=$(mock_hook_input "$transcript_file" "test" "session-123")

  local exit_code=0
  echo "$json" | bash "$HOOK_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
  # Backup should still be created
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "1" "$backup_count"
}

function test_session_end_appends_to_existing_session_exit() {
  # If Session Exit section exists, should update not duplicate
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  # Create active-context with existing Session Exit
  cat > "$HOOK_SESSIONS_DIR/active-context.md" << 'EOF'
# Active Context

## Current Task
Test

## Session Exit
- Last exit: 2025-01-01 00:00:00 (reason: old_reason)
- Transcript backup: /old/path.jsonl
EOF

  local json
  json=$(mock_hook_input "$transcript_file" "new_reason" "session-123")
  echo "$json" | bash "$HOOK_PATH" 2>&1

  local context_content
  context_content=$(cat "$HOOK_SESSIONS_DIR/active-context.md")

  # Should have updated exit info
  assert_contains "new_reason" "$context_content"
  # Should not have duplicate Session Exit headers
  local section_count
  section_count=$(grep -c "## Session Exit" "$HOOK_SESSIONS_DIR/active-context.md")
  assert_equals "1" "$section_count"
}

# === Edge Case Tests: Idempotency ===

function test_session_end_multiple_runs_create_separate_backups() {
  # Running hook twice should create two separate backups
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json
  json=$(mock_hook_input "$transcript_file" "run1" "session-123")
  echo "$json" | bash "$HOOK_PATH" 2>&1

  sleep 1  # Ensure different timestamp

  json=$(mock_hook_input "$transcript_file" "run2" "session-456")
  echo "$json" | bash "$HOOK_PATH" 2>&1

  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "2" "$backup_count"
}

# === Phase 1.1: Multi-Marker Support Tests ===
# These tests enforce the new marker naming convention to prevent overwrites

function test_session_end_creates_exit_marker() {
  # SessionEnd should use .pending-backup-exit (not .pending-backup)
  # This prevents overwrites when PreCompact also runs
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  local json
  json=$(mock_hook_input "$transcript_file" "prompt_input_exit" "session-123")
  echo "$json" | bash "$HOOK_PATH" 2>&1

  # New marker should exist
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup-exit"

  # Old marker should NOT exist (breaking change)
  assert_file_not_exists "$HOOK_SESSIONS_DIR/.pending-backup"

  # Marker should contain backup path
  local marker_content
  marker_content=$(cat "$HOOK_SESSIONS_DIR/.pending-backup-exit")
  assert_contains ".jsonl" "$marker_content"
}

function test_session_end_does_not_overwrite_compact_marker() {
  # If .pending-backup-compact exists, SessionEnd should not touch it
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  # Pre-create a compact marker
  echo "/path/to/compact-backup.jsonl" > "$HOOK_SESSIONS_DIR/.pending-backup-compact"

  local json
  json=$(mock_hook_input "$transcript_file" "prompt_input_exit" "session-123")
  echo "$json" | bash "$HOOK_PATH" 2>&1

  # Compact marker should be preserved
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup-compact"
  local compact_content
  compact_content=$(cat "$HOOK_SESSIONS_DIR/.pending-backup-compact")
  assert_contains "compact-backup" "$compact_content"

  # Exit marker should also exist
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup-exit"
}
