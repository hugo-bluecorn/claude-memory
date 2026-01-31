#!/usr/bin/env bash
# Script: update-active-context-timestamp.sh
# Purpose: Update the "Last Updated" timestamp in active-context.md
# Usage: bash update-active-context-timestamp.sh
#
# This script handles timestamp updates internally, removing the need for
# Claude to write timestamps (which can result in fabricated/rounded values).

set -euo pipefail

# === Configuration ===
# Environment variable overrides (for testing)
if [[ -n "${HOOK_PROJECT_DIR:-}" ]]; then
  PROJECT_DIR="$HOOK_PROJECT_DIR"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

if [[ -n "${HOOK_SESSIONS_DIR:-}" ]]; then
  SESSIONS_DIR="$HOOK_SESSIONS_DIR"
else
  SESSIONS_DIR="$PROJECT_DIR/.claude/memory"
fi

ACTIVE_CONTEXT="$SESSIONS_DIR/active-context.md"

# === Main Logic ===

main() {
  # Check if active-context.md exists
  if [[ ! -f "$ACTIVE_CONTEXT" ]]; then
    echo "Error: active-context.md not found at $ACTIVE_CONTEXT" >&2
    exit 1
  fi

  # Check if file contains "Last Updated:" line
  if ! grep -q "^> Last Updated:" "$ACTIVE_CONTEXT"; then
    echo "Error: No '> Last Updated:' line found in $ACTIVE_CONTEXT" >&2
    exit 1
  fi

  # Get current UTC timestamp
  local timestamp
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  # Update the Last Updated line using sed
  # Pattern matches: "> Last Updated: <anything>"
  # Replaces with: "> Last Updated: <new timestamp>"
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS requires different sed syntax
    sed -i '' "s/^> Last Updated:.*$/> Last Updated: $timestamp/" "$ACTIVE_CONTEXT"
  else
    # Linux sed
    sed -i "s/^> Last Updated:.*$/> Last Updated: $timestamp/" "$ACTIVE_CONTEXT"
  fi

  echo "Updated timestamp to: $timestamp"
}

main "$@"
exit 0
