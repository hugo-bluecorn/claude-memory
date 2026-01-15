# Session Continuity Workflow

> **Version**: 2.0
> **Status**: Implemented with bashunit tests

## Overview

This document describes the session continuity system for Claude Code. The system automatically
preserves context across sessions using hooks, and provides commands for manual context management.

---

## Architecture

### File Structure (After Installation)

```
<your-project>/
├── .claude/
│   ├── CLAUDE.md                    # Session rules + @imports
│   ├── settings.json                # Hook configurations
│   ├── commands/                    # Slash command definitions
│   │   ├── document-and-save.md     # Save session (default path)
│   │   ├── document-and-save-to.md  # Save session (custom path)
│   │   ├── resume-latest.md         # Resume most recent session
│   │   ├── resume-from.md           # Resume specific session
│   │   ├── sessions-list.md         # List available sessions
│   │   └── discard-backup.md        # Discard pending backup
│   ├── hooks/
│   │   ├── on-session-start.sh      # Outputs context if pending backup
│   │   ├── on-session-end.sh        # Saves transcript on exit
│   │   └── on-pre-compact.sh        # Saves transcript before compaction
│   └── scripts/
│       └── discard-backup.sh        # Script for /discard-backup command
│
└── .claude/memory/
    ├── active-context.md            # Current state (auto-loaded via @import)
    ├── project-memory.md            # Permanent knowledge (auto-loaded)
    ├── session-*.md                 # Archived session documents
    ├── raw/                         # Raw transcript backups
    │   └── YYYYMMDD_HHMMSS_*.jsonl
    ├── .pending-backup              # Marker file (contains path to backup)
    └── .backup-log                  # Log of backup events
```

### Auto-Loaded Files

These files are imported into every session via `@` syntax in CLAUDE.md:

| File | Purpose |
|------|---------|
| `active-context.md` | Current session state, next steps, blockers |
| `project-memory.md` | Permanent project knowledge, gotchas, patterns |

### Backup Files

| File | Purpose |
|------|---------|
| `raw/*.jsonl` | Raw conversation transcripts |
| `.pending-backup` | Marker containing path to unprocessed backup |

---

## Hooks

All hooks are bash scripts in `.claude/hooks/`. They are triggered automatically by Claude Code.

### on-session-start.sh

**Trigger**: Session starts (startup, resume, clear, compact)

**Behavior**:
- Checks for `.pending-backup` marker
- If exists and backup file is valid, outputs to stdout:
  ```
  SESSION_BACKUP_PENDING: A previous session backup exists at [path]
  User should run /resume-latest to restore context, or /discard-backup to discard.
  ```
- If marker is stale (backup file missing), cleans up marker
- Always exits 0 (SessionStart hooks cannot block)

**Note**: Output goes to Claude's context, not to user's terminal. This is a Claude Code limitation.

### on-session-end.sh

**Trigger**: Session ends (`/exit`, `/clear`, logout)

**Behavior**:
- Reads JSON input: `{"session_id", "transcript_path", "stop_reason"}`
- If transcript exists and is non-empty:
  - Copies to `raw/YYYYMMDD_HHMMSS_<reason>.jsonl`
  - Creates `.pending-backup` marker with backup path
  - Updates `active-context.md` with exit timestamp
  - Logs event to `.backup-log`

### on-pre-compact.sh

**Trigger**: Context reaches ~90% (auto-compact) or manual `/compact`

**Behavior**:
- Reads JSON input: `{"transcript_path", "trigger", "session_id"}`
- If transcript exists and is non-empty:
  - Copies to `raw/YYYYMMDD_HHMMSS.jsonl`
  - Creates `.pending-backup` marker
  - Logs event to `.backup-log`

---

## Commands

All commands are markdown files in `.claude/commands/`. They define prompts that Claude follows.

### /document-and-save

Save session to default path: `.claude/memory/session-YYYY-MM-DD-HHMM.md`

**Steps**:
1. Check for pending backup (inform user if exists)
2. Update `active-context.md` **FIRST** (critical for race condition)
3. Create full session document with all sections
4. Provide resume instructions

### /document-and-save-to \<path\>

Same as `/document-and-save` but to specified path.

### /resume-latest

Process pending backup or load most recent session.

**Steps**:
1. Check for `SESSION_BACKUP_PENDING` in context or `.pending-backup` marker
2. If pending backup exists:
   - Read and parse JSONL transcript
   - Generate high-quality summary
   - Update `active-context.md`
   - Delete marker
3. If no pending backup, find most recent session document
4. Present context and ask how to proceed

### /resume-from \<path\>

Load specific session document.

**Steps**:
1. Check for pending backup first (ask user to choose)
2. Load and parse session document
3. Restore context, todos, and state
4. Present next steps and ask how to proceed

### /sessions-list

Browse available session logs.

**Steps**:
1. Check for pending backup (show at top if exists)
2. List all session documents with metadata
3. Offer options: resume, view details, or done

### /discard-backup

Discard pending backup without processing.

**Steps**:
1. Run `discard-backup.sh` script
2. Removes backup file and marker
3. Confirms to user

---

## Workflow Flows

### Flow A: Manual Save (Preferred)

```
User decides to save
       │
       ▼
User runs /document-and-save
       │
       ▼
Claude updates active-context.md FIRST
       │
       ▼
Claude creates full session document
       │
       ▼
Session can end safely

═══════════════ NEW SESSION ═══════════════

Claude starts with active-context.md loaded
       │
       ▼
User can optionally run /resume-from for full details
```

### Flow B: Auto-Compact (Safety Net)

```
Context reaches ~90%
       │
       ▼
PreCompact hook fires
       │
       ▼
Raw transcript saved to sessions/raw/
.pending-backup marker created
       │
       ▼
Compaction happens (system summarizes context)
       │
       ▼
SessionStart hook outputs SESSION_BACKUP_PENDING
       │
       ▼
Claude sees context flag
       │
       ▼
User runs /resume-latest to process backup
       │
       ▼
Claude parses JSONL, updates active-context.md
Deletes .pending-backup marker
```

### Flow C: Session Exit (Safety Net)

```
User runs /exit (or closes terminal)
       │
       ▼
SessionEnd hook fires
       │
       ▼
Raw transcript saved to sessions/raw/
.pending-backup marker created
active-context.md updated with exit timestamp

═══════════════ NEW SESSION ═══════════════

SessionStart hook outputs SESSION_BACKUP_PENDING
       │
       ▼
User runs /resume-latest to process backup
       │
       ▼
Claude parses JSONL, generates summary
Updates active-context.md
```

---

## Key Design Decisions

### Context Recovery is Opt-In

SessionStart hooks cannot block (exit code 2 only shows stderr without requiring acknowledgment).
Therefore, context recovery requires user action:
- Run `/resume-latest` to process pending backup
- Run `/sessions-list` to browse and select
- Run `/discard-backup` to discard and start fresh

### Update Order Matters

When saving a session, always update `active-context.md` **FIRST**, then write the full session
document. This prevents data loss if auto-compaction interrupts the process.

### Raw Backups are Safety Nets

The raw JSONL backups are complete conversation transcripts. They're used as a fallback when the
user didn't run `/document-and-save` before exiting. The backup requires Claude to parse and
summarize it (via `/resume-latest`).

---

## Testing

All hooks are tested with bashunit. Run tests with:

```bash
./test/lib/bashunit test/     # Run all bash tests
shellcheck src/hooks/*.sh     # Run shellcheck linting
```

Test files:
- `test/unit/session_start_test.sh` - Session start hook tests
- `test/unit/session_end_test.sh` - Session end hook tests
- `test/unit/pre_compact_test.sh` - Pre-compact hook tests
- `test/unit/discard_backup_test.sh` - Discard backup script tests
- `test/unit/infrastructure_test.sh` - Test infrastructure verification
- `test/functional/hooks_integration_test.sh` - Integration tests

---

## Related Files

- `docs/bash-testing-guide.md` - How to write bash tests with bashunit
- `docs/version-control.md` - Git workflow and commit conventions
