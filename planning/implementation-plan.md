# Implementation Plan: claude-memory Fixes

> **Created**: 2026-01-15
> **Source**: research/implementation-analysis.md (28 problems, prioritized solutions)
> **Constraint**: File-based, single-instance architecture

---

## Phase 1: Critical Fixes (Do First)

### 1.1 Fix Backup Marker Conflict ✅ COMPLETED
**Problem**: PreCompact and SessionEnd originally wrote to the same marker file, causing overwrites.

**Resolution**: Each hook now uses its own marker file:
- `src/hooks/on-pre-compact.sh` → writes to `.pending-backup-compact`
- `src/hooks/on-session-end.sh` → writes to `.pending-backup-exit`
- `src/hooks/on-session-start.sh` → checks both marker files
- `src/commands/resume-latest.md` → processes multiple pending backups
- `src/scripts/discard-backup.sh` → handles multiple markers

All tests updated and passing.
- `test/unit/discard_backup_test.sh`

**Implementation**:
```bash
# on-pre-compact.sh
MARKER="$SESSIONS_DIR/.pending-backup-compact"

# on-session-end.sh
MARKER="$SESSIONS_DIR/.pending-backup-exit"

# on-session-start.sh
for marker in "$SESSIONS_DIR"/.pending-backup-*; do
  if [[ -f "$marker" ]]; then
    # Output notification for each
  fi
done
```

---

### 1.2 Harden PreCompact Hook
**Problem**: PreCompact lacks empty file check, debug logging, structured parsing.

**Files to modify**:
- `src/hooks/on-pre-compact.sh`

**Changes**:
1. Add `log_debug()` function
2. Add empty file check: `[[ ! -s "$TRANSCRIPT" ]]`
3. Add structured `parse_input()` function
4. Add active-context.md update with compaction timestamp

**Reference**: Copy patterns from `on-session-end.sh`

---

### 1.3 Add JSONL Parsing Specification
**Problem**: `/resume-latest` tells Claude to "parse JSONL" but doesn't specify format.

**Files to modify**:
- `src/commands/resume-latest.md`

**Add section**:
```markdown
### JSONL Format Reference

Each line is a JSON object:

| Type | Structure | Extract |
|------|-----------|---------|
| summary | `{"type":"summary","summary":"..."}` | Session description |
| user | `{"type":"user","message":{"role":"user","content":"..."}}` | User requests |
| assistant | `{"type":"assistant","message":{"role":"assistant","content":"..."}}` | Decisions, explanations |
| tool_use | `{"type":"tool_use","tool":"...","input":{...}}` | Files modified |
| tool_result | `{"type":"tool_result","output":"..."}` | Errors, results |

### Extraction Strategy
1. Collect user messages → Main tasks/questions
2. Collect assistant content → Decisions made
3. Filter tool_use for Write/Edit → Files modified
4. Search tool_result for errors → Failed approaches
```

---

## Phase 2: Core Improvements

### 2.1 Add Staleness Detection
**Problem**: No way to know if active-context.md is stale.

**Files to modify**:
- `src/templates/active-context.md` → add timestamp header
- `src/commands/document-and-save.md` → update timestamp
- `src/commands/document-and-save-to.md` → update timestamp
- `src/hooks/on-session-start.sh` → warn if >24h old

**Template change**:
```markdown
# Active Session Context

> Last Updated: YYYY-MM-DD HH:MM:SS

## Current Task
...
```

---

### 2.2 Add Session Index
**Problem**: No centralized index; slow discovery.

**New file**: `src/scripts/update-session-index.sh`

**Index structure** (`.session-index.json`):
```json
{
  "version": "1.0",
  "updated": "2026-01-15T10:30:00Z",
  "sessions": [
    {
      "path": "planning/sessions/session-2026-01-15-1030.md",
      "date": "2026-01-15T10:30:00Z",
      "project": "claude-memory",
      "status": "completed",
      "branch": "master",
      "tags": ["research"],
      "summary": "First line of Session Summary section",
      "previous_session": null
    }
  ]
}
```

**Integration points**:
- `src/commands/document-and-save.md` → call update script after save
- `src/commands/sessions-list.md` → read from index

---

### 2.3 Add Overhead Warning to SessionStart
**Problem**: Users don't know if auto-loaded files are too large.

**Files to modify**:
- `src/hooks/on-session-start.sh`

**Add check**:
```bash
# Check overhead size
OVERHEAD=0
for file in "$SESSIONS_DIR/active-context.md" "$SESSIONS_DIR/project-memory.md"; do
  if [[ -f "$file" ]]; then
    size=$(wc -c < "$file")
    OVERHEAD=$((OVERHEAD + size))
  fi
done

# Warn if >20KB (~5000 tokens)
if [[ $OVERHEAD -gt 20000 ]]; then
  echo "WARNING: Auto-loaded context is large (~$((OVERHEAD/4)) tokens)"
  echo "Consider condensing active-context.md or project-memory.md"
fi
```

---

## Phase 3: UX Enhancements

### 3.1 Add Backup Cleanup Command
**Problem**: No way to clean old backups from raw/ directory.

**New file**: `src/commands/cleanup-backups.md`

**Functionality**:
- `--older-than <days>` - Delete backups older than N days
- `--keep-last <n>` - Keep only N most recent
- `--dry-run` - Show what would be deleted
- Show disk usage before/after

---

### 3.2 Add Keyword Search Command
**Problem**: Can't search across session history.

**New file**: `src/commands/search-sessions.md`

**Functionality**:
- Grep for keyword in all session-*.md files
- Show matching sessions with context
- Offer to load any match

---

### 3.3 Reduce Confirmation Friction
**Problem**: Resume commands require confirmation every time.

**Files to modify**:
- `src/commands/resume-latest.md`
- `src/commands/resume-from.md`

**Change**: Add `--yes` / `-y` flag to skip confirmation.

---

## Phase 4: Polish

### 4.1 Session Chaining
**Problem**: No automatic linking of related sessions.

**Files to modify**:
- `src/commands/document-and-save.md`
- `src/commands/document-and-save-to.md`

**Logic**:
1. Check session index for most recent session today
2. If found, auto-set `previous_session` in frontmatter
3. Update index with chain info

---

### 4.2 Configurable Paths
**Problem**: Hardcoded `planning/sessions/` path.

**New file**: `.claude/memory-config.json` (optional)

```json
{
  "sessions_dir": "planning/sessions",
  "raw_backups_dir": "planning/sessions/raw",
  "active_context": "planning/sessions/active-context.md",
  "project_memory": "planning/sessions/project-memory.md"
}
```

**Files to modify**: All hooks and scripts to check for config.

---

### 4.3 Context Stats Command
**Problem**: No visibility into token overhead.

**New file**: `src/commands/context-stats.md`

**Output**:
```
## Auto-Loaded Overhead
| File | Size | Est. Tokens |
|------|------|-------------|
| active-context.md | 2.1 KB | ~525 |
| project-memory.md | 1.8 KB | ~450 |
| Total | 3.9 KB | ~975 |

## Recommendation
✓ Overhead within limits (<5%)
```

---

### 4.4 Best Practices Documentation
**Problem**: No guidance on optimal workflow.

**New file**: `docs/best-practices.md`

**Contents**:
- When to run /document-and-save
- Size limits for auto-loaded files
- Backup hygiene
- When to update project-memory.md

---

## Phase 5: Bootstrap (Self-Hosting)

### 5.1 Set Up .claude for This Project

Run setup on self:
```bash
./setup_memory_management.sh .
```

This creates:
- `.claude/commands/` (symlink or copy from src/commands/)
- `.claude/hooks/` (symlink or copy from src/hooks/)
- `.claude/scripts/` (symlink or copy from src/scripts/)

### 5.2 Configure settings.json

Merge `settings-hooks.json` into `.claude/settings.json`.

### 5.3 Update CLAUDE.md

Move `@imports` to `.claude/CLAUDE.md` or keep in root (depending on Claude Code behavior).

---

## Test Plan

### Unit Tests to Add/Update

| Test File | Changes |
|-----------|---------|
| `session_start_test.sh` | Multi-marker detection, staleness warning, overhead warning |
| `session_end_test.sh` | New marker name (.pending-backup-exit) |
| `pre_compact_test.sh` | New marker name, hardened validation |
| `discard_backup_test.sh` | Handle multiple markers |
| NEW: `session_index_test.sh` | Index creation, update, read |

### Integration Tests

| Scenario | Test |
|----------|------|
| PreCompact then SessionEnd | Both markers preserved |
| Large overhead files | Warning output on SessionStart |
| Stale active-context | Warning output on SessionStart |
| Session chaining | previous_session auto-populated |

---

## File Checklist

### Modify Existing
- [ ] `src/hooks/on-pre-compact.sh`
- [ ] `src/hooks/on-session-end.sh`
- [ ] `src/hooks/on-session-start.sh`
- [ ] `src/scripts/discard-backup.sh`
- [ ] `src/commands/resume-latest.md`
- [ ] `src/commands/resume-from.md`
- [ ] `src/commands/document-and-save.md`
- [ ] `src/commands/document-and-save-to.md`
- [ ] `src/commands/sessions-list.md`
- [ ] `src/templates/active-context.md`

### Create New
- [ ] `src/scripts/update-session-index.sh`
- [ ] `src/commands/cleanup-backups.md`
- [ ] `src/commands/search-sessions.md`
- [ ] `src/commands/context-stats.md`
- [ ] `docs/best-practices.md`

### Tests
- [ ] Update all existing unit tests for marker rename
- [ ] Add `test/unit/session_index_test.sh`
- [ ] Add integration test for multi-marker scenario

---

## Estimated Effort

| Phase | Scope | Complexity |
|-------|-------|------------|
| Phase 1 | 5 files + tests | Medium (critical path) |
| Phase 2 | 4 files + new script | Medium |
| Phase 3 | 3 new commands | Low |
| Phase 4 | 4 items | Low-Medium |
| Phase 5 | Bootstrap self | Low |

**Recommended order**: 1 → 5 → 2 → 3 → 4

(Bootstrap early so we dogfood while implementing remaining phases)
