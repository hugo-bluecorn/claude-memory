#!/usr/bin/env bash
# Integration tests for Claude Code hooks
# Tests the full lifecycle of session management hooks

SESSION_END_HOOK="../../src/hooks/on-session-end.sh"
PRE_COMPACT_HOOK="../../src/hooks/on-pre-compact.sh"
SESSION_START_HOOK="../../src/hooks/on-session-start.sh"

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

# === Full Session Cycle Test ===

function test_full_session_cycle() {
  # Test: SessionEnd creates backup → SessionStart detects it

  # Step 1: Create a transcript file
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  # Step 2: Run SessionEnd hook
  local session_end_input
  session_end_input=$(mock_hook_input "$transcript_file" "prompt_input_exit" "session-001")
  echo "$session_end_input" | bash "$SESSION_END_HOOK" 2>&1

  # Verify backup was created
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "1" "$backup_count" "SessionEnd should create backup"

  # Verify pending marker exists
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup"

  # Step 3: Run SessionStart hook - outputs context message when pending backup exists
  # Note: SessionStart cannot block (exit 2 only shows stderr to user)
  local session_start_input='{"session_id":"session-002","transcript_path":"/new/session","source":"resume"}'
  local start_output
  local exit_code=0
  start_output=$(echo "$session_start_input" | bash "$SESSION_START_HOOK" 2>/dev/null) || exit_code=$?

  # SessionStart exits 0 with stdout context for Claude
  assert_equals "0" "$exit_code" "SessionStart should exit 0 with context"
  assert_contains "SESSION_BACKUP_PENDING" "$start_output"
  assert_contains "resume-latest" "$start_output"
  # Marker should still exist for /resume-latest
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup"
}

# === PreCompact to SessionStart Flow ===

function test_precompact_to_session_start() {
  # Test: PreCompact creates backup → SessionStart detects it

  # Step 1: Create a transcript file
  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  # Step 2: Run PreCompact hook
  local precompact_input="{\"transcript_path\":\"$transcript_file\",\"trigger\":\"auto\",\"session_id\":\"session-001\"}"
  echo "$precompact_input" | bash "$PRE_COMPACT_HOOK" 2>&1

  # Verify backup was created
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "1" "$backup_count" "PreCompact should create backup"

  # Step 3: Run SessionStart - outputs context message when pending backup exists
  # Note: SessionStart cannot block (exit 2 only shows stderr to user)
  local session_start_input='{"session_id":"session-002","transcript_path":"/new/session","source":"resume"}'
  local start_output
  local exit_code=0
  start_output=$(echo "$session_start_input" | bash "$SESSION_START_HOOK" 2>/dev/null) || exit_code=$?

  # SessionStart exits 0 with stdout context for Claude
  assert_equals "0" "$exit_code" "SessionStart should exit 0 with context"
  assert_contains "SESSION_BACKUP_PENDING" "$start_output"
  assert_contains "resume-latest" "$start_output"
  # Marker preserved for /resume-latest
  assert_file_exists "$HOOK_SESSIONS_DIR/.pending-backup"
}

# === Multiple Sessions Create Unique Backups ===

function test_multiple_sessions_create_unique_backups() {
  # Test: Multiple session ends create separate backup files

  local transcript_file="$TEST_DIR/transcript.jsonl"
  create_test_transcript "$transcript_file"

  # Run SessionEnd multiple times with small delay to ensure unique timestamps
  local input1
  input1=$(mock_hook_input "$transcript_file" "prompt_input_exit" "session-001")
  echo "$input1" | bash "$SESSION_END_HOOK" 2>&1

  sleep 1  # Ensure different timestamp

  local input2
  input2=$(mock_hook_input "$transcript_file" "clear" "session-002")
  echo "$input2" | bash "$SESSION_END_HOOK" 2>&1

  sleep 1

  local input3
  input3=$(mock_hook_input "$transcript_file" "logout" "session-003")
  echo "$input3" | bash "$SESSION_END_HOOK" 2>&1

  # Should have 3 separate backup files
  local backup_count
  backup_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "3" "$backup_count" "Should have 3 unique backups"

  # Verify different reason suffixes
  local prompt_exit_count clear_count logout_count
  prompt_exit_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*prompt_input_exit.jsonl" -type f 2>/dev/null | wc -l)
  clear_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*clear.jsonl" -type f 2>/dev/null | wc -l)
  logout_count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*logout.jsonl" -type f 2>/dev/null | wc -l)

  assert_equals "1" "$prompt_exit_count" "Should have 1 prompt_input_exit backup"
  assert_equals "1" "$clear_count" "Should have 1 clear backup"
  assert_equals "1" "$logout_count" "Should have 1 logout backup"
}
