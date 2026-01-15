#!/usr/bin/env bash
# Infrastructure verification tests
# These tests verify that the test infrastructure is working correctly

function test_bootstrap_loads_successfully() {
  # If we got here, bootstrap loaded
  assert_equals "1" "1"
}

function test_jq_is_available() {
  assert_exit_code "0" "$(jq --version >/dev/null 2>&1; echo $?)"
}

function test_create_test_environment_creates_directories() {
  local test_dir
  test_dir=$(create_test_environment)

  assert_directory_exists "$test_dir/planning/sessions/raw"
  assert_file_exists "$test_dir/planning/sessions/active-context.md"

  # Cleanup
  rm -rf "$test_dir"
}

function test_mock_hook_input_creates_valid_json() {
  local json
  json=$(mock_hook_input "/path/to/transcript.jsonl" "prompt_input_exit" "session-123")

  # Verify it's valid JSON
  echo "$json" | jq . >/dev/null 2>&1
  assert_exit_code "0" "$?"

  # Verify fields
  local session_id
  session_id=$(echo "$json" | jq -r '.session_id')
  assert_equals "session-123" "$session_id"
}
