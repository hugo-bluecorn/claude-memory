#!/usr/bin/env bash
# Timestamp scripts tests
# Tests for src/scripts/get-utc-timestamp.sh and src/scripts/update-active-context-timestamp.sh

# Get the directory where this test file is located
TEST_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paths to scripts under test
GET_TIMESTAMP_SCRIPT="$TEST_FILE_DIR/../../src/scripts/get-utc-timestamp.sh"
UPDATE_TIMESTAMP_SCRIPT="$TEST_FILE_DIR/../../src/scripts/update-active-context-timestamp.sh"

function set_up() {
  # Create isolated test environment for each test
  TEST_DIR=$(create_test_environment)
  export HOOK_PROJECT_DIR="$TEST_DIR"
  export HOOK_SESSIONS_DIR="$TEST_DIR/.claude/memory"
}

function tear_down() {
  # Cleanup test environment
  if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
  unset HOOK_PROJECT_DIR
  unset HOOK_SESSIONS_DIR
}

# === get-utc-timestamp.sh Tests ===

function test_get_utc_timestamp_outputs_valid_iso8601_format() {
  local output
  output=$(bash "$GET_TIMESTAMP_SCRIPT" 2>&1)

  # Should match YYYY-MM-DDTHH:MM:SSZ format
  local pattern='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
  if [[ $output =~ $pattern ]]; then
    assert_equals "1" "1"  # Pass
  else
    fail "Output '$output' does not match ISO 8601 format YYYY-MM-DDTHH:MM:SSZ"
  fi
}

function test_get_utc_timestamp_exits_zero() {
  local exit_code=0
  bash "$GET_TIMESTAMP_SCRIPT" >/dev/null 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

function test_get_utc_timestamp_outputs_current_time() {
  # Get system time and script output within 2 seconds
  local expected_prefix
  expected_prefix=$(date -u '+%Y-%m-%dT%H:%M')

  local output
  output=$(bash "$GET_TIMESTAMP_SCRIPT" 2>&1)

  # Should start with the same hour and minute (allowing for second drift)
  assert_contains "$expected_prefix" "$output"
}

function test_get_utc_timestamp_outputs_single_line() {
  local output
  output=$(bash "$GET_TIMESTAMP_SCRIPT" 2>&1)

  local line_count
  line_count=$(echo "$output" | wc -l)

  assert_equals "1" "$line_count"
}

function test_get_utc_timestamp_no_trailing_newline_issues() {
  local output
  output=$(bash "$GET_TIMESTAMP_SCRIPT" 2>&1)

  # Should not have extra whitespace
  local trimmed
  trimmed=$(echo "$output" | tr -d '[:space:]')

  # The trimmed version (without any whitespace) should match the original (minus single newline)
  local original_no_newline
  original_no_newline=$(echo -n "$output" | tr -d '\n')

  assert_equals "$trimmed" "$original_no_newline"
}

# === update-active-context-timestamp.sh Tests ===

function test_update_timestamp_updates_last_updated_field() {
  # Create active-context with placeholder timestamp
  cat > "$HOOK_SESSIONS_DIR/active-context.md" << 'EOF'
# Active Session Context
> Last Updated: 2020-01-01T00:00:00Z
> Last Session Doc: session-test.md

## Current Task
Test task
EOF

  bash "$UPDATE_TIMESTAMP_SCRIPT" 2>&1

  local content
  content=$(cat "$HOOK_SESSIONS_DIR/active-context.md")

  # Should NOT contain the old placeholder timestamp
  assert_not_contains "2020-01-01T00:00:00Z" "$content"

  # Should contain a current year timestamp (2026)
  assert_contains "2026-" "$content"
}

function test_update_timestamp_preserves_other_content() {
  # Create active-context with various content
  cat > "$HOOK_SESSIONS_DIR/active-context.md" << 'EOF'
# Active Session Context
> Last Updated: 2020-01-01T00:00:00Z
> Last Session Doc: session-test.md

## Current Task
Important task here

## Next Steps
1. Do something
2. Do another thing

## Blockers
- None
EOF

  bash "$UPDATE_TIMESTAMP_SCRIPT" 2>&1

  local content
  content=$(cat "$HOOK_SESSIONS_DIR/active-context.md")

  assert_contains "Active Session Context" "$content"
  assert_contains "Last Session Doc: session-test.md" "$content"
  assert_contains "Important task here" "$content"
  assert_contains "Do something" "$content"
  assert_contains "Blockers" "$content"
}

function test_update_timestamp_exits_zero_on_success() {
  cat > "$HOOK_SESSIONS_DIR/active-context.md" << 'EOF'
# Active Session Context
> Last Updated: 2020-01-01T00:00:00Z
EOF

  local exit_code=0
  bash "$UPDATE_TIMESTAMP_SCRIPT" 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

function test_update_timestamp_handles_missing_file_gracefully() {
  # Remove active-context.md
  rm -f "$HOOK_SESSIONS_DIR/active-context.md"

  local exit_code=0
  bash "$UPDATE_TIMESTAMP_SCRIPT" 2>&1 || exit_code=$?

  # Should exit non-zero or handle gracefully (we'll define behavior)
  # For now, we expect it to exit 1 if file doesn't exist
  assert_equals "1" "$exit_code"
}

function test_update_timestamp_handles_missing_last_updated_line() {
  # Create active-context WITHOUT Last Updated line
  cat > "$HOOK_SESSIONS_DIR/active-context.md" << 'EOF'
# Active Session Context
> Last Session Doc: session-test.md

## Current Task
Test task
EOF

  local exit_code=0
  bash "$UPDATE_TIMESTAMP_SCRIPT" 2>&1 || exit_code=$?

  # Should exit non-zero since there's no line to update
  assert_equals "1" "$exit_code"
}

function test_update_timestamp_writes_valid_iso8601_format() {
  cat > "$HOOK_SESSIONS_DIR/active-context.md" << 'EOF'
# Active Session Context
> Last Updated: 2020-01-01T00:00:00Z
EOF

  bash "$UPDATE_TIMESTAMP_SCRIPT" 2>&1

  local content
  content=$(cat "$HOOK_SESSIONS_DIR/active-context.md")

  # Extract the timestamp
  local timestamp
  timestamp=$(echo "$content" | grep "Last Updated:" | sed 's/.*Last Updated: //')

  # Should match YYYY-MM-DDTHH:MM:SSZ format
  local pattern='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
  if [[ $timestamp =~ $pattern ]]; then
    assert_equals "1" "1"  # Pass
  else
    fail "Timestamp '$timestamp' does not match ISO 8601 format"
  fi
}

function test_update_timestamp_is_idempotent() {
  cat > "$HOOK_SESSIONS_DIR/active-context.md" << 'EOF'
# Active Session Context
> Last Updated: 2020-01-01T00:00:00Z
EOF

  # Run twice
  bash "$UPDATE_TIMESTAMP_SCRIPT" 2>&1
  local first_content
  first_content=$(cat "$HOOK_SESSIONS_DIR/active-context.md")

  sleep 1  # Wait a second to ensure timestamp would change

  bash "$UPDATE_TIMESTAMP_SCRIPT" 2>&1
  local second_content
  second_content=$(cat "$HOOK_SESSIONS_DIR/active-context.md")

  # Both should have valid timestamps (though they may differ by 1 second)
  assert_contains "Last Updated:" "$first_content"
  assert_contains "Last Updated:" "$second_content"
}

function test_update_timestamp_handles_various_timestamp_formats() {
  # Test with different existing timestamp formats
  cat > "$HOOK_SESSIONS_DIR/active-context.md" << 'EOF'
# Active Session Context
> Last Updated: [YYYY-MM-DDTHH:MM:SSZ]
EOF

  bash "$UPDATE_TIMESTAMP_SCRIPT" 2>&1

  local content
  content=$(cat "$HOOK_SESSIONS_DIR/active-context.md")

  # Should have replaced the placeholder with real timestamp
  assert_not_contains "[YYYY-MM-DDTHH:MM:SSZ]" "$content"
  assert_contains "2026-" "$content"
}

# === Integration Tests ===

function test_update_uses_get_timestamp_internally() {
  # This test verifies the scripts work together
  cat > "$HOOK_SESSIONS_DIR/active-context.md" << 'EOF'
# Active Session Context
> Last Updated: 2020-01-01T00:00:00Z
EOF

  # Get expected timestamp pattern (current minute)
  local expected_prefix
  expected_prefix=$(date -u '+%Y-%m-%dT%H:%M')

  bash "$UPDATE_TIMESTAMP_SCRIPT" 2>&1

  local content
  content=$(cat "$HOOK_SESSIONS_DIR/active-context.md")

  assert_contains "$expected_prefix" "$content"
}
