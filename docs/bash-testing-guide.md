# Bash Testing Best Practices and Guidelines

This guide covers best practices for testing bash scripts using bashunit, derived from the bashunit project's own practices and documentation.

## Table of Contents

1. [TDD Workflow](#tdd-workflow)
2. [Test Organization](#test-organization)
3. [Bash Coding Standards](#bash-coding-standards)
4. [Test File Structure](#test-file-structure)
5. [Assertions Reference](#assertions-reference)
6. [Test Doubles (Mock/Spy)](#test-doubles-mockspy)
7. [Data Providers](#data-providers)
8. [Lifecycle Hooks](#lifecycle-hooks)
9. [Custom Assertions](#custom-assertions)
10. [Error Handling in Tests](#error-handling-in-tests)
11. [Snapshot Testing](#snapshot-testing)
12. [Common Patterns](#common-patterns)
13. [Anti-Patterns to Avoid](#anti-patterns-to-avoid)

---

## TDD Workflow

### Double-Loop TDD

Practice two nested feedback loops:

**Outer Loop (Acceptance First)**
- Start from user value
- Write high-level acceptance test exercising the public entry point
- Keep acceptance test red until the behavior is implemented
- Split broad tests into thin vertical slices

**Inner Loop (Design-Driving Tests)**
1. **RED**: Write failing test for next micro-behavior
2. **GREEN**: Write minimum code to pass
3. **REFACTOR**: Improve design while keeping tests green

### Test Inventory

Maintain a living test inventory:
- Track acceptance, unit, and functional tests
- After every refactor, review and re-prioritize
- Top priority is always the currently red test

### Important Rules

- **Never stop at tests only**: Always add production code that uses the behavior
- **Avoid speculative tests**: Write tests only when needed
- **Keep tests deterministic**: No hidden time, randomness, or cross-test coupling
- **Prefer observable behavior**: If refactoring breaks a test without changing behavior, fix the test

---

## Test Organization

### Directory Structure

```
tests/
├── unit/              # Unit tests for individual functions
│   ├── module_test.sh
│   └── fixtures/
├── functional/        # Integration tests
│   ├── feature_test.sh
│   └── fixtures/
├── acceptance/        # End-to-end tests
│   ├── cli_test.sh
│   └── fixtures/
└── bootstrap.sh       # Shared setup
```

### File Naming

- Test files: `*_test.sh` or `*test.sh`
- Fixtures: Place in `fixtures/` subdirectory
- Snapshots: Place in `snapshots/` subdirectory

### Test Function Naming

```bash
# Descriptive names indicating what is being tested
function test_successful_operation_with_valid_input() { ... }
function test_unsuccessful_operation_with_invalid_input() { ... }
function test_edge_case_with_empty_string() { ... }

# Pattern: test_<success/failure>_<what>_<condition>
function test_successful_assert_file_exists() { ... }
function test_unsuccessful_assert_file_exists_when_missing() { ... }
```

---

## Bash Coding Standards

### Compatibility (Bash 3.2+)

```bash
# GOOD - Works on Bash 3.2+
[[ -n "${var:-}" ]] && echo "set"
array=("item1" "item2")
local param="${1:-}"

# BAD - Bash 4+ only (avoid)
declare -A assoc_array      # associative arrays
readarray -t lines < file   # readarray
${var^^}                    # uppercase expansion
```

### Error Handling & Safety

```bash
# Start test files with strict mode
set -euo pipefail

# Safe parameter expansion
local param="${1:-}"           # default to empty
local param="${1:-default}"    # default value
[[ -z "${param}" ]] && return 1

# Safe file operations
[[ -f "${file:-}" ]] && rm -f "${file}"
[[ -d "${dir:-}" ]] && rm -rf "${dir}"
```

### Function Naming (Module Namespacing)

```bash
# Use :: for module namespacing
function console_results::print_failed_test() { ... }
function state::add_assertions_failed() { ... }
function helper::normalize_name() { ... }

# For custom assertions
function assert_valid_json() { ... }
function assert_http_success() { ... }
```

### Boolean Patterns (ADR-002)

```bash
# Return values: use numbers
return 0  # success
return 1  # failure

# Variables: use true/false commands (not strings!)
if true; then ...   # always succeeds
if false; then ...  # always fails

# Extract conditions into functions
function is_feature_enabled() {
    [[ "$FEATURE_FLAG" == "true" ]]
}

if is_feature_enabled; then
    # ...
fi
```

### String Handling

```bash
# Line continuation for readability
assert_same\
    "$(expected_output)"\
    "$(actual_output)"

# Proper quoting
local colored=$(printf '\e[31mHello\e[0m World!')
local output="$(command_with_output)"
```

---

## Test File Structure

### Basic Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

# Script-level setup (once before all tests)
function set_up_before_script() {
    TEST_ENV_FILE="path/to/fixtures/.env"
    SCRIPT_TEMP_DIR=$(bashunit::temp_dir "prefix")
}

# Test-level setup (before each test)
function set_up() {
    TEST_FILE=$(bashunit::temp_file "test")
    source "path/to/module.sh"
}

# Test-level teardown (after each test)
function tear_down() {
    [[ -f "${TEST_FILE:-}" ]] && rm -f "${TEST_FILE}"
}

# Script-level teardown (once after all tests)
function tear_down_after_script() {
    [[ -d "${SCRIPT_TEMP_DIR:-}" ]] && rm -rf "${SCRIPT_TEMP_DIR}"
}

# Test functions
function test_feature_works_correctly() {
    # Arrange
    local input="test data"

    # Act
    local result
    result=$(my_function "$input")

    # Assert
    assert_same "expected" "$result"
}
```

---

## Assertions Reference

### Equality

```bash
assert_same "expected" "${actual}"
assert_not_same "unexpected" "${actual}"
assert_equals "expected" "${actual}"         # alias
assert_not_equals "unexpected" "${actual}"   # alias
```

### Truthiness & Exit Codes

```bash
assert_true "command_or_function"
assert_false "failing_command"
assert_successful_code "command"       # exit code 0
assert_general_error "failing_cmd"     # exit code != 0
assert_exit_code 127 "command"         # specific exit code
```

### String Assertions

```bash
assert_contains "needle" "${haystack}"
assert_not_contains "needle" "${haystack}"
assert_matches "^[0-9]+$" "${value}"           # regex
assert_not_matches "pattern" "${value}"
assert_string_starts_with "prefix" "${string}"
assert_string_ends_with "suffix" "${string}"
assert_empty "${maybe_empty}"
assert_not_empty "${something}"
```

### Numeric Assertions

```bash
assert_greater_than 10 "${n}"
assert_less_than 5 "${m}"
assert_greater_or_equal_than 10 "${n}"
assert_less_or_equal_than 5 "${m}"
```

### File & Directory Assertions

```bash
assert_file_exists "${filepath}"
assert_file_not_exists "${filepath}"
assert_is_file "${filepath}"
assert_is_file_empty "${filepath}"
assert_file_contains "${filepath}" "content"
assert_file_not_contains "${filepath}" "content"
assert_files_equals "${file1}" "${file2}"
assert_files_not_equals "${file1}" "${file2}"

assert_directory_exists "${dirpath}"
assert_directory_not_exists "${dirpath}"
assert_is_directory "${dirpath}"
assert_is_directory_empty "${dirpath}"
assert_is_directory_not_empty "${dirpath}"
```

### Array Assertions

```bash
assert_array_contains "element" "${array[@]}"
assert_array_not_contains "element" "${array[@]}"
```

### Snapshot Assertions

```bash
assert_match_snapshot "${output}"
assert_match_snapshot "${output}" "custom_name"
assert_match_snapshot_ignore_colors "${colored_output}"
```

---

## Test Doubles (Mock/Spy)

### Mocking Commands

```bash
# Mock with simple output
bashunit::mock ps echo "hello world"
assert_same "hello world" "$(ps)"

# Mock with file content
bashunit::mock ps cat ./fixtures/ps_output.txt

# Mock with heredoc
bashunit::mock ps<<EOF
PID TTY          TIME CMD
13525 pts/7    00:00:01 bash
EOF

# Mocks are automatically cleared between tests
```

### Spying on Commands

```bash
function test_spy_verifies_calls() {
    bashunit::spy ps
    bashunit::spy awk

    # Execute code that uses these commands
    my_function_using_ps_and_awk

    # Verify calls
    assert_have_been_called ps
    assert_have_been_called awk
}

function test_spy_call_counts() {
    bashunit::spy ps

    ps first_call
    ps second_call

    assert_have_been_called_times 2 ps
}

function test_spy_with_arguments() {
    bashunit::spy ps

    ps -aux --sort=-%mem

    assert_have_been_called_with ps "-aux --sort=-%mem"
}

function test_spy_not_called() {
    bashunit::spy ps

    # Don't call ps

    assert_not_called ps
}
```

### Spying Sourced Functions

```bash
function test_spy_sourced_function() {
    source ./fixtures/my_functions.sh
    bashunit::spy function_to_spy

    function_to_spy "arg1" "arg2"

    assert_have_been_called function_to_spy
    assert_have_been_called_with function_to_spy "arg1 arg2"
}
```

---

## Data Providers

### Basic Usage

```bash
# @data_provider provide_test_cases
function test_with_data_provider() {
    local input="$1"
    local expected="$2"

    local result
    result=$(my_function "$input")

    assert_same "$expected" "$result"
}

function provide_test_cases() {
    bashunit::data_set "input1" "expected1"
    bashunit::data_set "input2" "expected2"
    bashunit::data_set "input3" "expected3"
}
```

### Single Parameter, Multiple Cases

```bash
# @data_provider provide_valid_inputs
function test_valid_input() {
    local input="$1"
    assert_successful_code "validate '$input'"
}

function provide_valid_inputs() {
    bashunit::data_set "value1"
    bashunit::data_set "value2"
    bashunit::data_set "value3"
}
```

### Handling Edge Cases

```bash
# @data_provider provide_edge_cases
function test_edge_cases() {
    local first="$1"
    local second="$2"

    assert_same "" "$first"       # empty value
    assert_same "two" "$second"
}

function provide_edge_cases() {
    bashunit::data_set "" "two"                    # empty first param
    bashunit::data_set "value with spaces" "ok"    # spaces
    bashunit::data_set "value	with	tabs" "ok"    # tabs
}
```

### Dynamic Test Names

```bash
# @data_provider provide_multipliers
function test_multiplication_of_::1::_and_::2::() {
    local a="$1"
    local b="$2"
    local expected="$3"

    assert_same "$expected" "$(( a * b ))"
}

function provide_multipliers() {
    bashunit::data_set 2 3 6
    bashunit::data_set 4 5 20
}
# Output: "Multiplication of '2' and '3'"
```

---

## Lifecycle Hooks

### Execution Order

```
set_up_before_script()   # Once before all tests in file
  └─ set_up()            # Before each test
       └─ test_*()       # The test
       └─ tear_down()    # After each test
  └─ set_up()
       └─ test_*()
       └─ tear_down()
  ... (repeat for each test)
tear_down_after_script() # Once after all tests in file
```

### Practical Example

```bash
#!/usr/bin/env bash
set -euo pipefail

# Expensive setup done once
function set_up_before_script() {
    export TEST_DB_DIR=$(bashunit::temp_dir "db")
    initialize_test_database "$TEST_DB_DIR"
}

# Per-test isolation
function set_up() {
    export TEST_FILE=$(bashunit::temp_file "test")
    export COUNTER=0
}

function tear_down() {
    [[ -f "$TEST_FILE" ]] && rm -f "$TEST_FILE"
    unset COUNTER
}

# Cleanup expensive resources
function tear_down_after_script() {
    [[ -d "$TEST_DB_DIR" ]] && rm -rf "$TEST_DB_DIR"
}
```

### Global Utilities

```bash
# Auto-cleaned temp files (cleaned after test)
local temp=$(bashunit::temp_file "prefix")

# Auto-cleaned temp directories
local dir=$(bashunit::temp_dir "prefix")

# Random strings for isolation
local name="test_$(bashunit::random_str 8)"

# Timestamps
local ts=$(bashunit::current_timestamp)

# Command availability check
if bashunit::is_command_available jq; then
    # use jq
fi

# Logging (requires BASHUNIT_DEV_LOG)
bashunit::log "info" "message"
bashunit::log "error" "error message"
bashunit::log "warning" "warning message"
```

---

## Custom Assertions

### Implementation Pattern

```bash
function assert_valid_json() {
    local json="$1"

    if ! echo "$json" | jq . > /dev/null 2>&1; then
        bashunit::assertion_failed "valid JSON" "$json"
        return
    fi

    bashunit::assertion_passed
}

function assert_positive_number() {
    local actual="$1"

    if [[ "$actual" -le 0 ]]; then
        bashunit::assertion_failed "positive number" "$actual" "got"
        return
    fi

    bashunit::assertion_passed
}

function assert_http_success() {
    local status_code="$1"

    if [[ "$status_code" -lt 200 ]] || [[ "$status_code" -ge 300 ]]; then
        bashunit::assertion_failed "HTTP success (2xx)" "$status_code"
        return
    fi

    bashunit::assertion_passed
}
```

### Testing Custom Assertions

```bash
function test_assert_valid_json_passes() {
    assert_valid_json '{"key": "value"}'
}

function test_assert_valid_json_fails() {
    # Test that invalid JSON produces expected failure output
    local result
    result=$(assert_valid_json "not json")

    assert_contains "valid JSON" "$result"
}
```

---

## Error Handling in Tests

### Testing Error Conditions

```bash
function test_error_message_on_failure() {
    local output
    output=$(./script.sh invalid_input 2>&1 || true)

    assert_contains "Error:" "$output"
    assert_general_error "./script.sh invalid_input"
}

function test_specific_exit_code() {
    assert_exit_code 127 "./script.sh --missing-file"
}
```

### Testing Assertion Failures

```bash
# Pattern from bashunit's own tests
function test_unsuccessful_assert_equals() {
    assert_same\
        "$(bashunit::console_results::print_failed_test\
            "Test name" \
            "expected" \
            "but got" "actual")"\
        "$(assert_equals "expected" "actual")"
}
```

### Error Detection (ADR-001)

Bashunit detects errors via stderr, not just exit codes:
- If any execution writes to stderr, the test fails
- Tests run to completion even after failures
- This enables true TDD with accurate failure reporting

---

## Snapshot Testing

### Basic Usage

```bash
function test_cli_output_matches_snapshot() {
    local output
    output=$(./my_cli --help)

    assert_match_snapshot "$output"
}
```

### Ignoring Dynamic Content

Use placeholders for timestamps or dynamic values:

```bash
# In snapshot file, use ::ignore:: for dynamic parts
# Content: "Run at ::ignore::"
# Matches: "Run at 2024-01-15 10:30:00"

function test_log_format() {
    local log
    log=$(generate_log_entry)

    # Strip dynamic parts before snapshot
    log=$(echo "$log" | sed 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/DATE/g')

    assert_match_snapshot "$log"
}
```

### Colored Output

```bash
function test_colored_output() {
    local output
    output=$(./colorful_script)

    # Ignore ANSI color codes
    assert_match_snapshot_ignore_colors "$output"
}
```

---

## Common Patterns

### Testing CLI Scripts

```bash
function test_cli_help() {
    assert_match_snapshot "$(./script.sh --help)"
    assert_successful_code "./script.sh --help"
}

function test_cli_with_args() {
    local output
    output=$(./script.sh --verbose process input.txt)

    assert_contains "Processing" "$output"
    assert_successful_code "./script.sh --verbose process input.txt"
}
```

### Testing with Piped Input

```bash
function test_filter_with_pipe() {
    local input="line1
line2
line3"

    local output
    output=$(echo "$input" | ./filter.sh)

    assert_contains "line2" "$output"
}

function test_json_processing() {
    local input='{"name":"test"}'

    local output
    output=$(echo "$input" | ./process_json.sh)

    assert_valid_json "$output"
}
```

### Testing File Operations

```bash
function test_creates_output_file() {
    local output_file=$(bashunit::temp_file "output")

    ./script.sh --output "$output_file"

    assert_file_exists "$output_file"
    assert_file_contains "$output_file" "expected content"
}

function test_modifies_file() {
    local test_file=$(bashunit::temp_file "test")
    echo "original" > "$test_file"

    ./modify.sh "$test_file"

    assert_file_contains "$test_file" "modified"
    assert_file_not_contains "$test_file" "original"
}
```

### Testing Environment Variables

```bash
function test_respects_env_var() {
    export MY_CONFIG="custom_value"

    local output
    output=$(./script.sh)

    assert_contains "custom_value" "$output"

    unset MY_CONFIG
}
```

---

## Anti-Patterns to Avoid

### Don't Invent New Patterns

```bash
# BAD - Inventing new assertion style
if [[ "$result" == "expected" ]]; then
    echo "PASS"
else
    echo "FAIL"
fi

# GOOD - Use existing assertions
assert_same "expected" "$result"
```

### Don't Skip Cleanup

```bash
# BAD - Leaving temp files
function test_something() {
    echo "data" > /tmp/test_file
    # ... test ...
    # Forgot to clean up!
}

# GOOD - Use temp utilities
function test_something() {
    local temp=$(bashunit::temp_file "test")
    echo "data" > "$temp"
    # ... test ...
    # Auto-cleaned by bashunit
}
```

### Don't Use External State

```bash
# BAD - Depends on external file
function test_config_loading() {
    assert_file_exists "/etc/myapp/config"  # External dependency!
}

# GOOD - Create test fixtures
function set_up() {
    TEST_CONFIG=$(bashunit::temp_file "config")
    echo "test_setting=value" > "$TEST_CONFIG"
}
```

### Don't Couple Tests

```bash
# BAD - Tests depend on each other
function test_first() {
    SHARED_STATE="initialized"
}

function test_second() {
    assert_same "initialized" "$SHARED_STATE"  # Fails if order changes!
}

# GOOD - Each test is independent
function set_up() {
    SHARED_STATE="initialized"
}
```

### Don't Test Implementation Details

```bash
# BAD - Testing internal variables
function test_internal_counter() {
    my_function
    assert_same "3" "$_internal_counter"  # Exposes implementation!
}

# GOOD - Test observable behavior
function test_function_output() {
    local result
    result=$(my_function)
    assert_same "expected output" "$result"
}
```

---

## Quick Reference

### Running Tests

```bash
# Run all tests
./lib/bashunit tests/

# Run specific file
./lib/bashunit tests/unit/my_test.sh

# Run with verbose output
./lib/bashunit --verbose tests/

# Run in parallel
./lib/bashunit --parallel tests/
```

### Quality Checks

```bash
# Static analysis
shellcheck -x script.sh

# Find all and check
shellcheck -x $(find . -name "*.sh")

# Format code
shfmt -w script.sh
```

### Configuration (.env)

```bash
BASHUNIT_DEFAULT_PATH=tests
BASHUNIT_BOOTSTRAP=tests/bootstrap.sh
BASHUNIT_SIMPLE_OUTPUT=false
BASHUNIT_SHOW_EXECUTION_TIME=true
BASHUNIT_DEV_LOG=tests/test.log
```

---

## References

- [bashunit Documentation](https://bashunit.typeddevs.com/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [ShellCheck](https://www.shellcheck.net/)
- [bashunit GitHub](https://github.com/TypedDevs/bashunit)
