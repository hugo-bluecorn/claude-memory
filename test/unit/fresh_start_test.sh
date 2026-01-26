#!/usr/bin/env bash
# FreshStart script tests
# Tests for src/scripts/fresh-start.sh

# Get the directory where this test file is located
TEST_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the script under test (absolute path based on test file location)
SCRIPT_PATH="$TEST_FILE_DIR/../../src/scripts/fresh-start.sh"

# Path to templates
TEMPLATES_DIR="$TEST_FILE_DIR/../../src/templates"

function set_up() {
  # Create isolated test environment for each test
  TEST_DIR=$(create_test_environment)
  export HOOK_PROJECT_DIR="$TEST_DIR"
  export HOOK_SESSIONS_DIR="$TEST_DIR/.claude/memory"
  unset FRESH_START_ALL
}

function tear_down() {
  # Cleanup test environment
  if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
  unset HOOK_PROJECT_DIR
  unset HOOK_SESSIONS_DIR
  unset FRESH_START_ALL
}

# === Core Functionality Tests ===

function test_fresh_start_removes_session_documents() {
  # Create test session documents
  mkdir -p "$HOOK_SESSIONS_DIR/sessions"
  echo "session 1" > "$HOOK_SESSIONS_DIR/sessions/session-2026-01-01-1000.md"
  echo "session 2" > "$HOOK_SESSIONS_DIR/sessions/session-2026-01-02-1000.md"

  bash "$SCRIPT_PATH" 2>&1

  local count
  count=$(find "$HOOK_SESSIONS_DIR/sessions" -name "*.md" -type f 2>/dev/null | wc -l)
  assert_equals "0" "$count"
}

function test_fresh_start_removes_raw_backups() {
  # Create test backup files
  mkdir -p "$HOOK_SESSIONS_DIR/raw"
  create_test_transcript "$HOOK_SESSIONS_DIR/raw/20260101_100000_exit.jsonl"
  create_test_transcript "$HOOK_SESSIONS_DIR/raw/20260102_100000_compact.jsonl"

  bash "$SCRIPT_PATH" 2>&1

  local count
  count=$(find "$HOOK_SESSIONS_DIR/raw" -name "*.jsonl" -type f 2>/dev/null | wc -l)
  assert_equals "0" "$count"
}

function test_fresh_start_removes_pending_markers() {
  # Create all marker types
  echo "/path/to/backup1.jsonl" > "$HOOK_SESSIONS_DIR/.pending-backup-exit"
  echo "/path/to/backup2.jsonl" > "$HOOK_SESSIONS_DIR/.pending-backup-compact"

  bash "$SCRIPT_PATH" 2>&1

  assert_file_not_exists "$HOOK_SESSIONS_DIR/.pending-backup-exit"
  assert_file_not_exists "$HOOK_SESSIONS_DIR/.pending-backup-compact"
}

function test_fresh_start_resets_active_context() {
  # Create active-context with custom content
  echo "# Custom Content" > "$HOOK_SESSIONS_DIR/active-context.md"
  echo "Some work was done" >> "$HOOK_SESSIONS_DIR/active-context.md"

  bash "$SCRIPT_PATH" 2>&1

  local content
  content=$(cat "$HOOK_SESSIONS_DIR/active-context.md")
  assert_contains "Active Session Context" "$content"
  assert_contains "Current Task" "$content"
  assert_not_contains "Custom Content" "$content"
}

# === Preservation Tests ===

function test_fresh_start_preserves_project_memory_by_default() {
  # Create project-memory with custom content
  echo "# Custom Project Memory" > "$HOOK_SESSIONS_DIR/project-memory.md"
  echo "Important knowledge here" >> "$HOOK_SESSIONS_DIR/project-memory.md"

  bash "$SCRIPT_PATH" 2>&1

  local content
  content=$(cat "$HOOK_SESSIONS_DIR/project-memory.md")
  assert_contains "Custom Project Memory" "$content"
  assert_contains "Important knowledge" "$content"
}

function test_fresh_start_all_resets_project_memory() {
  # Create project-memory with custom content
  echo "# Custom Project Memory" > "$HOOK_SESSIONS_DIR/project-memory.md"
  echo "Important knowledge here" >> "$HOOK_SESSIONS_DIR/project-memory.md"

  export FRESH_START_ALL=true
  bash "$SCRIPT_PATH" 2>&1

  local content
  content=$(cat "$HOOK_SESSIONS_DIR/project-memory.md")
  assert_contains "Project Memory" "$content"
  assert_contains "Key Patterns" "$content"
  assert_not_contains "Custom Project Memory" "$content"
}

# === Edge Cases ===

function test_fresh_start_handles_empty_directories() {
  # Sessions and raw directories exist but are empty
  mkdir -p "$HOOK_SESSIONS_DIR/sessions"
  mkdir -p "$HOOK_SESSIONS_DIR/raw"

  local exit_code=0
  bash "$SCRIPT_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

function test_fresh_start_handles_missing_directories() {
  # Remove sessions and raw directories
  rm -rf "$HOOK_SESSIONS_DIR/sessions"
  rm -rf "$HOOK_SESSIONS_DIR/raw"

  local exit_code=0
  bash "$SCRIPT_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

function test_fresh_start_is_idempotent() {
  # Create some test data
  mkdir -p "$HOOK_SESSIONS_DIR/sessions"
  echo "session" > "$HOOK_SESSIONS_DIR/sessions/session-test.md"

  # Run twice
  local exit_code1=0
  local exit_code2=0
  bash "$SCRIPT_PATH" 2>&1 || exit_code1=$?
  bash "$SCRIPT_PATH" 2>&1 || exit_code2=$?

  assert_equals "0" "$exit_code1"
  assert_equals "0" "$exit_code2"
}

function test_fresh_start_handles_path_with_spaces() {
  # Create session with spaces in name
  mkdir -p "$HOOK_SESSIONS_DIR/sessions"
  echo "content" > "$HOOK_SESSIONS_DIR/sessions/session with spaces.md"

  bash "$SCRIPT_PATH" 2>&1

  assert_file_not_exists "$HOOK_SESSIONS_DIR/sessions/session with spaces.md"
}

# === Error Handling ===

function test_fresh_start_exits_zero_on_success() {
  # Create some test data
  mkdir -p "$HOOK_SESSIONS_DIR/sessions"
  echo "session" > "$HOOK_SESSIONS_DIR/sessions/session-test.md"

  local exit_code=0
  bash "$SCRIPT_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

function test_fresh_start_exits_zero_even_on_empty_state() {
  # No data to clean, should still succeed
  local exit_code=0
  bash "$SCRIPT_PATH" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

# === Output Tests ===

function test_fresh_start_outputs_completion_message() {
  local output
  output=$(bash "$SCRIPT_PATH" 2>&1)

  assert_contains "Fresh start complete" "$output"
}

function test_fresh_start_all_indicates_project_memory_reset() {
  echo "# Custom" > "$HOOK_SESSIONS_DIR/project-memory.md"

  export FRESH_START_ALL=true
  local output
  output=$(bash "$SCRIPT_PATH" 2>&1)

  assert_contains "project-memory" "$output"
}
