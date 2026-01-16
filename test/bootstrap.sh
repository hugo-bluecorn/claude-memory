#!/usr/bin/env bash
# Bootstrap file for bashunit tests
# Provides custom assertions and test helpers for Claude Code hooks

set -euo pipefail

# === DEPENDENCY CHECK ===
# jq is required for hook JSON parsing
if ! command -v jq &> /dev/null; then
  echo "WARNING: jq is not installed. Some tests may fail."
  echo "Install jq for full test coverage:"
  echo "  - macOS: brew install jq"
  echo "  - Ubuntu/Debian: sudo apt install jq"
  echo "  - Windows (Git Bash): Download from https://stedolan.github.io/jq/"
  echo ""
fi

# === TEST ENVIRONMENT HELPERS ===

# Creates an isolated test environment with required directories
# Usage: TEST_ENV=$(create_test_environment)
# Returns: Path to temp directory (auto-cleaned by bashunit)
function create_test_environment() {
  local test_dir
  test_dir=$(mktemp -d)

  mkdir -p "$test_dir/.claude/memory/raw"
  mkdir -p "$test_dir/.claude/memory/sessions"
  touch "$test_dir/.claude/memory/active-context.md"

  echo "$test_dir"
}

# Creates mock JSON input for hooks (simulates Claude Code hook stdin)
# Usage: mock_hook_input "transcript_path" "reason" "session_id" | hook_script
function mock_hook_input() {
  local transcript_path="${1:-}"
  local reason="${2:-prompt_input_exit}"
  local session_id="${3:-test-session-123}"

  local json="{\"session_id\":\"$session_id\",\"stop_reason\":\"$reason\""

  if [[ -n "$transcript_path" ]]; then
    json="$json,\"transcript_path\":\"$transcript_path\""
  fi

  json="$json}"
  echo "$json"
}

# Creates a sample transcript file for testing
# Usage: create_test_transcript "$test_dir/transcript.jsonl"
function create_test_transcript() {
  local filepath="$1"

  cat > "$filepath" << 'EOF'
{"type":"summary","summary":"Test Session"}
{"type":"user","message":{"role":"user","content":"Hello"}}
{"type":"assistant","message":{"role":"assistant","content":"Hi there!"}}
EOF
}

# === CUSTOM ASSERTIONS ===

# Assert that a backup file was created in the raw directory
# Usage: assert_backup_created "$test_dir" "filename_pattern"
function assert_backup_created() {
  local test_dir="$1"
  local pattern="${2:-*.jsonl}"
  local raw_dir="$test_dir/.claude/memory/raw"

  if [[ ! -d "$raw_dir" ]]; then
    fail "Raw directory does not exist: $raw_dir"
    return
  fi

  local count
  count=$(find "$raw_dir" -name "$pattern" -type f 2>/dev/null | wc -l)

  if [[ "$count" -eq 0 ]]; then
    fail "No backup files matching '$pattern' found in $raw_dir"
    return
  fi

  assert_equals "1" "1"  # Pass
}

# Assert that the pending backup marker exists with correct content
# Usage: assert_pending_marker_exists "$test_dir" "expected_path"
function assert_pending_marker_exists() {
  local test_dir="$1"
  local expected_path="${2:-}"
  local marker="$test_dir/.claude/memory/.pending-backup"

  assert_file_exists "$marker"

  if [[ -n "$expected_path" ]]; then
    local actual
    actual=$(cat "$marker")
    assert_contains "$expected_path" "$actual"
  fi
}

# Assert that active-context.md contains session exit info
# Usage: assert_active_context_updated "$test_dir"
function assert_active_context_updated() {
  local test_dir="$1"
  local context_file="$test_dir/.claude/memory/active-context.md"

  assert_file_exists "$context_file"

  local content
  content=$(cat "$context_file")
  assert_contains "Session Exit" "$content"
}

# Assert hook exited with expected code
# Usage: assert_hook_exit_code "0" "$exit_code"
function assert_hook_exit_code() {
  local expected="$1"
  local actual="$2"

  assert_equals "$expected" "$actual" "Hook exit code"
}

# === HOOK EXECUTION HELPERS ===

# Run a hook with test environment and capture output
# Usage: run_hook_with_env "$hook_path" "$test_dir" "$json_input"
# Sets: HOOK_OUTPUT, HOOK_EXIT_CODE
function run_hook_with_env() {
  local hook_path="$1"
  local test_dir="$2"
  local json_input="$3"

  HOOK_OUTPUT=""
  HOOK_EXIT_CODE=0

  # Set environment variables for hook testability
  export HOOK_PROJECT_DIR="$test_dir"
  export HOOK_SESSIONS_DIR="$test_dir/.claude/memory"

  HOOK_OUTPUT=$(echo "$json_input" | bash "$hook_path" 2>&1) || HOOK_EXIT_CODE=$?

  unset HOOK_PROJECT_DIR
  unset HOOK_SESSIONS_DIR
}

# === SETUP SCRIPT TEST HELPERS ===

# Mock HTTP client for testing setup script
# Sets SETUP_TEST_MODE="mock_local" to use local src/ files instead of remote fetch
# Sets SETUP_FORCE_HTTP_CLIENT to simulate specific HTTP client availability
#
# Usage in test:
#   export SETUP_FORCE_HTTP_CLIENT="curl"  # or "wget" or "none"
#   export SETUP_TEST_MODE="mock_local"    # uses local files instead of network
#
# Error simulation:
#   export MOCK_CURL_FAIL="1"    # simulate network failure
#   export MOCK_CURL_EMPTY="1"   # simulate empty response

function mock_http_client_from_local() {
  export SETUP_TEST_MODE="mock_local"
}

# Force use of specific HTTP client for testing
# @param client: "curl", "wget", or "none"
function force_http_client() {
  local client="$1"
  export SETUP_FORCE_HTTP_CLIENT="$client"
}
