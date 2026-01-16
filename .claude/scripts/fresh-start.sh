#!/usr/bin/env bash
# Script: fresh-start.sh
# Purpose: Clear all session data and reset to clean state
# Usage: bash fresh-start.sh
#        FRESH_START_ALL=true bash fresh-start.sh  (also reset project-memory)

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

# Whether to also reset project-memory.md
RESET_ALL="${FRESH_START_ALL:-false}"

# Path to templates
TEMPLATES_DIR="$PROJECT_DIR/src/templates"

# Counters for summary
SESSIONS_REMOVED=0
BACKUPS_REMOVED=0
MARKERS_REMOVED=0

# === Helper Functions ===

remove_session_documents() {
  local sessions_path="$SESSIONS_DIR/sessions"

  if [[ -d "$sessions_path" ]]; then
    local count
    count=$(find "$sessions_path" -name "*.md" -type f 2>/dev/null | wc -l)
    SESSIONS_REMOVED=$count

    if [[ $count -gt 0 ]]; then
      find "$sessions_path" -name "*.md" -type f -delete 2>/dev/null || true
    fi
  fi
}

remove_raw_backups() {
  local raw_path="$SESSIONS_DIR/raw"

  if [[ -d "$raw_path" ]]; then
    local count
    count=$(find "$raw_path" -name "*.jsonl" -type f 2>/dev/null | wc -l)
    BACKUPS_REMOVED=$count

    if [[ $count -gt 0 ]]; then
      find "$raw_path" -name "*.jsonl" -type f -delete 2>/dev/null || true
    fi
  fi
}

remove_pending_markers() {
  local markers=(".pending-backup-exit" ".pending-backup-compact" ".pending-backup")

  for marker in "${markers[@]}"; do
    local marker_path="$SESSIONS_DIR/$marker"
    if [[ -f "$marker_path" ]]; then
      rm -f "$marker_path"
      ((MARKERS_REMOVED++)) || true
    fi
  done
}

reset_active_context() {
  local context_path="$SESSIONS_DIR/active-context.md"
  local template_path="$TEMPLATES_DIR/active-context.md"

  # If template exists, copy it; otherwise create minimal template
  if [[ -f "$template_path" ]]; then
    cp "$template_path" "$context_path"
  else
    cat > "$context_path" << 'EOF'
# Active Session Context
> Last Updated: [YYYY-MM-DD HH:MM:SS]
> Last Session Doc: [session-YYYY-MM-DD-HHMM.md or empty if none]

## Current Task
[What you're currently working on or should work on next]

## Completed This/Last Session
- [Brief list of accomplishments]

## In Progress
- [Items partially complete]

## Next Steps
1. [Priority-ordered action items]

## Blockers
- None

## Key Files Modified
- [List of important files changed this session]
EOF
  fi
}

reset_project_memory() {
  local memory_path="$SESSIONS_DIR/project-memory.md"
  local template_path="$TEMPLATES_DIR/project-memory.md"

  # If template exists, copy it; otherwise create minimal template
  if [[ -f "$template_path" ]]; then
    cp "$template_path" "$memory_path"
  else
    cat > "$memory_path" << 'EOF'
# Project Memory

Permanent knowledge about this project that should persist across all sessions.

## Key Patterns

[Document important patterns or conventions used in this project]

## Architecture Decisions

[Record significant architectural decisions and their rationale]

## Known Gotchas

[List things that have caused problems or confusion]

## Important Context

[Any other permanent knowledge that shouldn't be lost]
EOF
  fi
}

# === Main Logic ===

main() {
  # Remove all session-related data
  remove_pending_markers
  remove_raw_backups
  remove_session_documents

  # Reset active context to template
  reset_active_context

  # Optionally reset project memory
  if [[ "$RESET_ALL" == "true" ]]; then
    reset_project_memory
    echo "Fresh start complete (including project-memory reset)."
    echo "  - Sessions removed: $SESSIONS_REMOVED"
    echo "  - Backups removed: $BACKUPS_REMOVED"
    echo "  - Markers removed: $MARKERS_REMOVED"
    echo "  - active-context.md: reset to template"
    echo "  - project-memory.md: reset to template"
  else
    echo "Fresh start complete."
    echo "  - Sessions removed: $SESSIONS_REMOVED"
    echo "  - Backups removed: $BACKUPS_REMOVED"
    echo "  - Markers removed: $MARKERS_REMOVED"
    echo "  - active-context.md: reset to template"
    echo "  - project-memory.md: preserved"
  fi
}

main "$@"
exit 0
