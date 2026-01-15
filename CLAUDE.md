# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Memory is a session continuity system for Claude Code that automatically preserves context across sessions. It provides automatic backups via hooks, structured session documents, and easy resumption commands.

## Commands

```bash
# Run all tests
./test/lib/bashunit test/

# Run specific test file
./test/lib/bashunit test/unit/session_start_test.sh

# Run with verbose output
./test/lib/bashunit --verbose test/

# Static analysis
shellcheck -x src/hooks/*.sh

# Install to a target project
./setup_memory_management.sh [target_directory]
```

## Architecture

### Three-Layer Context Preservation

```
Auto-loaded context (CLAUDE.md @imports)
├── active-context.md    # Current session state (condensed)
└── project-memory.md    # Permanent project knowledge

Manual session documents
└── planning/sessions/session-YYYY-MM-DD-HHMM.md

Raw backups (safety net)
└── planning/sessions/raw/*.jsonl
```

### Hook System

Hooks in `src/hooks/` are triggered automatically by Claude Code:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `on-session-start.sh` | Session initialization | Outputs `SESSION_BACKUP_PENDING` if pending backup exists |
| `on-session-end.sh` | `/exit`, `/clear`, logout | Saves raw transcript, creates `.pending-backup` marker |
| `on-pre-compact.sh` | Context ~90% full | Saves transcript before auto-compaction |

### Command System

Commands in `src/commands/` are markdown prompts Claude follows:

| Command | Purpose |
|---------|---------|
| `/document-and-save` | Save session to default path with full details |
| `/resume-latest` | Process pending backup or load most recent session |
| `/resume-from <path>` | Load specific session document |
| `/sessions-list` | Browse available sessions |
| `/discard-backup` | Discard pending backup without processing |

### Critical Workflows

**Manual Save (preferred):** When `/document-and-save` runs, update `active-context.md` FIRST, then write full session document. This order prevents data loss from auto-compaction race conditions.

**Backup Processing:** When processing pending backups via `/resume-latest`, read JSONL, generate summary, update `active-context.md`, delete `.pending-backup` marker.

## Testing

Uses bashunit with test bootstrap providing:
- `create_test_environment()` - Isolated test environments
- `mock_hook_input()` - Mock Claude Code hook stdin
- Custom assertions: `assert_backup_created()`, `assert_pending_marker_exists()`, `assert_active_context_updated()`

Test files follow pattern: `test/unit/*_test.sh` for unit tests, `test/functional/*_test.sh` for integration.

## Bash Conventions

- Use `set -euo pipefail` for error safety
- Safe parameter expansion: `${param:-default}`
- Bash 3.2+ compatibility (no associative arrays, no readarray)
- Functions accept environment variable overrides for testability (e.g., `HOOK_PROJECT_DIR`, `HOOK_SESSIONS_DIR`)
- Module namespacing with `::` (e.g., `assert_valid_json`)

## Dependencies

- **jq** - Required for JSON parsing in hooks
- **bash** - Version 3.2+ (macOS default works)

## Git Workflow

Uses GitHub Flow with conventional commits. Commit format: `<type>(<scope>): <subject>` where type is feat/fix/docs/refactor/test/chore.
