#!/usr/bin/env bash
# Setup script tests
# Tests for setup_memory_management.sh
# TDD: GREEN Phase - Making tests pass

# Get the directory where this test file is located
TEST_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the script under test (absolute path based on test file location)
SCRIPT_PATH="$TEST_FILE_DIR/../../setup_memory_management.sh"

# Path to source files
SOURCE_DIR="$TEST_FILE_DIR/../../"

function set_up() {
  # Create isolated test environment for each test
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/target"

  # Store original directory
  ORIGINAL_DIR=$(pwd)
}

function tear_down() {
  # Cleanup test environment
  if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
  cd "$ORIGINAL_DIR" 2>/dev/null || true
}

# === Directory Creation Tests ===

function test_setup_creates_claude_commands_directory() {
  # When setup runs, it should create .claude/commands/
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_directory_exists "$target/.claude/commands"
}

function test_setup_creates_claude_hooks_directory() {
  # When setup runs, it should create .claude/hooks/
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_directory_exists "$target/.claude/hooks"
}

function test_setup_creates_claude_scripts_directory() {
  # When setup runs, it should create .claude/scripts/
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_directory_exists "$target/.claude/scripts"
}

function test_setup_creates_sessions_directory() {
  # When setup runs, it should create .claude/memory/
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_directory_exists "$target/.claude/memory"
}

function test_setup_creates_raw_directory() {
  # When setup runs, it should create .claude/memory/raw/
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_directory_exists "$target/.claude/memory/raw"
}

# === File Copy Tests - Commands ===

function test_setup_copies_document_and_save_command() {
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_file_exists "$target/.claude/commands/document-and-save.md"
}

function test_setup_copies_resume_latest_command() {
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_file_exists "$target/.claude/commands/resume-latest.md"
}

function test_setup_copies_all_commands() {
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_file_exists "$target/.claude/commands/document-and-save.md"
  assert_file_exists "$target/.claude/commands/document-and-save-to.md"
  assert_file_exists "$target/.claude/commands/resume-from.md"
  assert_file_exists "$target/.claude/commands/resume-latest.md"
  assert_file_exists "$target/.claude/commands/sessions-list.md"
  assert_file_exists "$target/.claude/commands/discard-backup.md"
}

# === File Copy Tests - Hooks ===

function test_setup_copies_session_end_hook() {
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_file_exists "$target/.claude/hooks/on-session-end.sh"
}

function test_setup_copies_all_hooks() {
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_file_exists "$target/.claude/hooks/on-session-start.sh"
  assert_file_exists "$target/.claude/hooks/on-session-end.sh"
  assert_file_exists "$target/.claude/hooks/on-pre-compact.sh"
}

function test_setup_makes_hooks_executable() {
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  # Check if hooks are executable
  [[ -x "$target/.claude/hooks/on-session-start.sh" ]]
  assert_exit_code "0" "$?"

  [[ -x "$target/.claude/hooks/on-session-end.sh" ]]
  assert_exit_code "0" "$?"

  [[ -x "$target/.claude/hooks/on-pre-compact.sh" ]]
  assert_exit_code "0" "$?"
}

# === File Copy Tests - Scripts ===

function test_setup_copies_discard_backup_script() {
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_file_exists "$target/.claude/scripts/discard-backup.sh"
}

function test_setup_makes_scripts_executable() {
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  [[ -x "$target/.claude/scripts/discard-backup.sh" ]]
  assert_exit_code "0" "$?"
}

# === Template Files Tests ===

function test_setup_creates_active_context() {
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_file_exists "$target/.claude/memory/active-context.md"
}

function test_setup_creates_project_memory() {
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"

  assert_file_exists "$target/.claude/memory/project-memory.md"
}

# === Error Handling Tests ===

function test_setup_fails_with_nonexistent_target() {
  local exit_code=0

  bash "$SCRIPT_PATH" "/nonexistent/path" 2>/dev/null || exit_code=$?

  assert_not_equals "0" "$exit_code"
}

function test_setup_uses_current_dir_with_no_arguments() {
  # When no argument is provided, setup should use current directory
  cd "$TEST_DIR/target"
  bash "$SCRIPT_PATH" 2>&1

  # Should create .claude in current directory
  assert_directory_exists "$TEST_DIR/target/.claude/commands"
  assert_directory_exists "$TEST_DIR/target/.claude/memory"
}

# === Idempotency Tests ===

function test_setup_is_idempotent() {
  # Running setup twice should not cause errors
  local target="$TEST_DIR/target"

  bash "$SCRIPT_PATH" "$target"
  local first_exit=$?

  bash "$SCRIPT_PATH" "$target"
  local second_exit=$?

  assert_equals "0" "$first_exit"
  assert_equals "0" "$second_exit"
}

function test_setup_does_not_overwrite_existing_active_context() {
  # If active-context.md has custom content, it should be preserved
  local target="$TEST_DIR/target"
  mkdir -p "$target/.claude/memory"
  echo "Custom content" > "$target/.claude/memory/active-context.md"

  bash "$SCRIPT_PATH" "$target"

  local content
  content=$(cat "$target/.claude/memory/active-context.md")
  assert_contains "Custom content" "$content"
}

# === Output Tests ===

function test_setup_shows_success_message() {
  local target="$TEST_DIR/target"

  local output
  output=$(bash "$SCRIPT_PATH" "$target" 2>&1)

  # Should show completion message
  assert_contains "complete" "$output"
}
