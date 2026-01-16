#!/usr/bin/env bash
# Setup script tests - Remote fetch functionality
# Tests for setup_memory_management.sh remote installation
# TDD: RED Phase - Writing tests first

# Get the directory where this test file is located
TEST_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the script under test (absolute path based on test file location)
SCRIPT_PATH="$TEST_FILE_DIR/../../setup_memory_management.sh"

# Path to source files (for mock responses)
SOURCE_DIR="$TEST_FILE_DIR/../../"

function set_up() {
  # Create isolated test environment for each test
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/target"

  # Store original directory
  ORIGINAL_DIR=$(pwd)

  # Reset mock environment variables
  unset SETUP_FORCE_HTTP_CLIENT
  unset SETUP_TEST_MODE
  unset MOCK_CURL_FAIL
  unset MOCK_CURL_EMPTY
}

function tear_down() {
  # Cleanup test environment
  if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
  cd "$ORIGINAL_DIR" 2>/dev/null || true

  # Reset environment variables
  unset SETUP_FORCE_HTTP_CLIENT
  unset SETUP_TEST_MODE
  unset MOCK_CURL_FAIL
  unset MOCK_CURL_EMPTY
}

# === HTTP Client Detection Tests ===

function test_fails_without_curl_or_wget() {
  # When neither curl nor wget is available, should fail with exit code 3
  local target="$TEST_DIR/target"
  local exit_code=0

  export SETUP_FORCE_HTTP_CLIENT="none"

  bash "$SCRIPT_PATH" "$target" 2>/dev/null || exit_code=$?

  assert_equals "3" "$exit_code" "Should exit with code 3 when no HTTP client available"
}

function test_detects_curl_when_available() {
  # When curl is available, should use it
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  local output
  output=$(bash "$SCRIPT_PATH" "$target" 2>&1)

  assert_contains "Using curl" "$output"
}

function test_detects_wget_when_curl_unavailable() {
  # When only wget is available, should use it
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="wget"
  export SETUP_TEST_MODE="mock_local"

  local output
  output=$(bash "$SCRIPT_PATH" "$target" 2>&1)

  assert_contains "Using wget" "$output"
}

# === Remote Fetch Tests - Commands ===

function test_fetches_all_commands() {
  # Should fetch all 12 command files from remote
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"

  # Verify all 12 command files exist
  assert_file_exists "$target/.claude/commands/cleanup-backups.md"
  assert_file_exists "$target/.claude/commands/coalesce.md"
  assert_file_exists "$target/.claude/commands/context-stats.md"
  assert_file_exists "$target/.claude/commands/discard-backup.md"
  assert_file_exists "$target/.claude/commands/document-and-save.md"
  assert_file_exists "$target/.claude/commands/document-and-save-to.md"
  assert_file_exists "$target/.claude/commands/fresh-start.md"
  assert_file_exists "$target/.claude/commands/fresh-start-all.md"
  assert_file_exists "$target/.claude/commands/resume-from.md"
  assert_file_exists "$target/.claude/commands/resume-latest.md"
  assert_file_exists "$target/.claude/commands/search-sessions.md"
  assert_file_exists "$target/.claude/commands/sessions-list.md"
}

# === Remote Fetch Tests - Hooks ===

function test_fetches_all_hooks() {
  # Should fetch all 3 hook files from remote
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"

  # Verify all 3 hook files exist
  assert_file_exists "$target/.claude/hooks/on-session-start.sh"
  assert_file_exists "$target/.claude/hooks/on-session-end.sh"
  assert_file_exists "$target/.claude/hooks/on-pre-compact.sh"
}

function test_sets_executable_permissions_on_hooks() {
  # Hooks should be executable after install
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"

  [[ -x "$target/.claude/hooks/on-session-start.sh" ]]
  assert_exit_code "0" "$?"

  [[ -x "$target/.claude/hooks/on-session-end.sh" ]]
  assert_exit_code "0" "$?"

  [[ -x "$target/.claude/hooks/on-pre-compact.sh" ]]
  assert_exit_code "0" "$?"
}

# === Remote Fetch Tests - Scripts ===

function test_fetches_all_scripts() {
  # Should fetch all 2 script files from remote
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"

  # Verify all 2 script files exist
  assert_file_exists "$target/.claude/scripts/discard-backup.sh"
  assert_file_exists "$target/.claude/scripts/fresh-start.sh"
}

function test_sets_executable_permissions_on_scripts() {
  # Scripts should be executable after install
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"

  [[ -x "$target/.claude/scripts/discard-backup.sh" ]]
  assert_exit_code "0" "$?"

  [[ -x "$target/.claude/scripts/fresh-start.sh" ]]
  assert_exit_code "0" "$?"
}

# === Remote Fetch Tests - Templates ===

function test_fetches_templates_if_not_exist() {
  # Should fetch template files when they don't exist
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"

  # Verify template files exist
  assert_file_exists "$target/.claude/memory/active-context.md"
  assert_file_exists "$target/.claude/memory/project-memory.md"
}

function test_skips_existing_templates() {
  # Should not overwrite existing template files
  local target="$TEST_DIR/target"
  mkdir -p "$target/.claude/memory"
  echo "Custom active context" > "$target/.claude/memory/active-context.md"
  echo "Custom project memory" > "$target/.claude/memory/project-memory.md"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  local output
  output=$(bash "$SCRIPT_PATH" "$target" 2>&1)

  # Verify custom content preserved
  local active_content
  active_content=$(cat "$target/.claude/memory/active-context.md")
  assert_contains "Custom active context" "$active_content"

  local project_content
  project_content=$(cat "$target/.claude/memory/project-memory.md")
  assert_contains "Custom project memory" "$project_content"

  # Verify skip messages shown
  assert_contains "Skipping active-context.md" "$output"
  assert_contains "Skipping project-memory.md" "$output"
}

# === Error Handling Tests ===

function test_handles_network_failure() {
  # Should fail gracefully with exit code 2 on network failure
  local target="$TEST_DIR/target"
  local exit_code=0

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"
  export MOCK_CURL_FAIL="1"

  bash "$SCRIPT_PATH" "$target" 2>/dev/null || exit_code=$?

  assert_equals "2" "$exit_code" "Should exit with code 2 on network failure"
}

function test_validates_empty_files() {
  # Should fail with exit code 2 if downloaded file is empty
  local target="$TEST_DIR/target"
  local exit_code=0

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"
  export MOCK_CURL_EMPTY="1"

  bash "$SCRIPT_PATH" "$target" 2>/dev/null || exit_code=$?

  assert_equals "2" "$exit_code" "Should exit with code 2 when downloaded file is empty"
}

# === Directory Structure Tests ===

function test_creates_directory_structure() {
  # Should create all required directories
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"

  assert_directory_exists "$target/.claude/commands"
  assert_directory_exists "$target/.claude/hooks"
  assert_directory_exists "$target/.claude/scripts"
  assert_directory_exists "$target/.claude/memory"
  assert_directory_exists "$target/.claude/memory/raw"
  assert_directory_exists "$target/.claude/memory/sessions"
}

# === Settings.json Tests ===

function test_creates_settings_json_if_not_exists() {
  # Should create .claude/settings.json with hooks if it doesn't exist
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"

  assert_file_exists "$target/.claude/settings.json"

  # Verify it contains hooks
  local content
  content=$(cat "$target/.claude/settings.json")
  assert_contains "PreCompact" "$content"
  assert_contains "SessionStart" "$content"
  assert_contains "SessionEnd" "$content"
}

function test_merges_hooks_into_existing_settings() {
  # Should merge hooks into existing settings.json without overwriting other settings
  local target="$TEST_DIR/target"
  mkdir -p "$target/.claude"
  echo '{"other_setting": "value"}' > "$target/.claude/settings.json"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"

  local content
  content=$(cat "$target/.claude/settings.json")
  # Should have both old settings and new hooks
  assert_contains "other_setting" "$content"
  assert_contains "PreCompact" "$content"
}

function test_does_not_duplicate_hooks() {
  # Running setup twice should not duplicate hooks
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"
  bash "$SCRIPT_PATH" "$target"

  # Count occurrences of PreCompact - should be exactly 1
  local count
  count=$(grep -c "PreCompact" "$target/.claude/settings.json" || echo "0")
  assert_equals "1" "$count"
}

# === CLAUDE.md Tests ===

function test_creates_claude_md_if_not_exists() {
  # Should create .claude/CLAUDE.md with snippet if it doesn't exist
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"

  assert_file_exists "$target/.claude/CLAUDE.md"

  # Verify it contains session management section
  local content
  content=$(cat "$target/.claude/CLAUDE.md")
  assert_contains "Session Management" "$content"
  assert_contains "@.claude/memory/active-context.md" "$content"
}

function test_appends_to_existing_claude_md() {
  # Should append snippet to existing CLAUDE.md
  local target="$TEST_DIR/target"
  mkdir -p "$target/.claude"
  echo "# My Project" > "$target/.claude/CLAUDE.md"
  echo "" >> "$target/.claude/CLAUDE.md"
  echo "Existing content here." >> "$target/.claude/CLAUDE.md"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"

  local content
  content=$(cat "$target/.claude/CLAUDE.md")
  # Should have both old content and new snippet
  assert_contains "My Project" "$content"
  assert_contains "Existing content here" "$content"
  assert_contains "Session Management" "$content"
}

function test_does_not_duplicate_snippet() {
  # Running setup twice should not duplicate the snippet
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  bash "$SCRIPT_PATH" "$target"
  bash "$SCRIPT_PATH" "$target"

  # Count occurrences of "# Session Management" - should be exactly 1
  local count
  count=$(grep -c "# Session Management" "$target/.claude/CLAUDE.md" || echo "0")
  assert_equals "1" "$count"
}

# === Integration Tests ===

function test_full_installation_succeeds() {
  # Full installation should complete successfully
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  local exit_code=0
  local output
  output=$(bash "$SCRIPT_PATH" "$target" 2>&1) || exit_code=$?

  assert_equals "0" "$exit_code" "Installation should succeed"
  assert_contains "Installation complete" "$output"
}

function test_shows_fetch_source_in_output() {
  # Should show the GitHub URL being fetched from
  local target="$TEST_DIR/target"

  export SETUP_FORCE_HTTP_CLIENT="curl"
  export SETUP_TEST_MODE="mock_local"

  local output
  output=$(bash "$SCRIPT_PATH" "$target" 2>&1)

  assert_contains "Fetching from:" "$output"
}
