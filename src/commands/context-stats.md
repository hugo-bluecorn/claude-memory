---
description: Show statistics about session management files and context overhead
---

# Context Stats

Display statistics about your session management system, helping you understand context overhead and storage usage.

## Usage

```
/context-stats
```

## Steps

### 1. Check Context File Sizes

Calculate the size of files that are auto-loaded into context:

```bash
# Active context
wc -c .claude/memory/active-context.md 2>/dev/null || echo "0"

# Project memory
wc -c .claude/memory/project-memory.md 2>/dev/null || echo "0"
```

Display:
```
Context Overhead
────────────────────────────────────────────────────────────────────────────────
  active-context.md:    4.2 KB
  project-memory.md:    2.1 KB
  ─────────────────────────────
  Total overhead:       6.3 KB  (threshold: 20 KB)
  Status: ✓ OK
```

If total > 20KB, show warning:
```
  Status: ⚠ LARGE - Consider trimming active-context.md
```

### 2. Check Active Context Freshness

Parse the `> Last Updated:` timestamp from active-context.md:

```bash
grep "^> Last Updated:" .claude/memory/active-context.md 2>/dev/null
```

Display:
```
Context Freshness
────────────────────────────────────────────────────────────────────────────────
  Last updated:         2026-01-15 14:30:00
  Age:                  2 hours ago
  Status: ✓ Fresh
```

If > 24h old:
```
  Status: ⚠ STALE - Run /document-and-save to update
```

### 3. Count Session Documents

```bash
ls .claude/memory/sessions/session-*.md 2>/dev/null | wc -l
```

Display:
```
Session Documents
────────────────────────────────────────────────────────────────────────────────
  Total sessions:       12
  Oldest:               session-2026-01-01-0900.md (14 days ago)
  Newest:               session-2026-01-15-1200.md (3 hours ago)
```

### 4. Count Raw Backups

```bash
ls .claude/memory/raw/*.jsonl 2>/dev/null | wc -l
du -sh .claude/memory/raw/ 2>/dev/null
```

Display:
```
Raw Backups
────────────────────────────────────────────────────────────────────────────────
  Total backups:        25
  Total size:           15.2 MB
  Oldest:               20260101_090000_prompt_input_exit.jsonl (14 days)
  Newest:               20260115_143000_compact.jsonl (1 hour ago)
```

### 5. Check Pending Backups

```bash
cat .claude/memory/.pending-backup-exit 2>/dev/null
cat .claude/memory/.pending-backup-compact 2>/dev/null
cat .claude/memory/.pending-backup 2>/dev/null
```

Display:
```
Pending Backups
────────────────────────────────────────────────────────────────────────────────
  .pending-backup-exit:    ✓ Present (raw/20260115_143000_prompt_input_exit.jsonl)
  .pending-backup-compact: ✗ None
  .pending-backup:         ✗ None (legacy)

  Action: Run /resume-latest to process pending backup
```

### 6. Summary

```
═══════════════════════════════════════════════════════════════════════════════
Summary
═══════════════════════════════════════════════════════════════════════════════
  Context overhead:     6.3 KB / 20 KB (31%)
  Context age:          2 hours (fresh)
  Sessions:             12 documents
  Backups:              25 files (15.2 MB)
  Pending:              1 backup awaiting processing

Recommendations:
  • Run /resume-latest to process pending backup
  • Consider /cleanup-backups if backup storage is high
═══════════════════════════════════════════════════════════════════════════════
```

## Example Output

```
/context-stats

Context Overhead
────────────────────────────────────────────────────────────────────────────────
  active-context.md:    4.2 KB
  project-memory.md:    2.1 KB
  ─────────────────────────────
  Total overhead:       6.3 KB  (threshold: 20 KB)
  Status: ✓ OK

Context Freshness
────────────────────────────────────────────────────────────────────────────────
  Last updated:         2026-01-15 14:30:00
  Age:                  2 hours ago
  Status: ✓ Fresh

Session Documents
────────────────────────────────────────────────────────────────────────────────
  Total sessions:       12
  Oldest:               session-2026-01-01-0900.md
  Newest:               session-2026-01-15-1200.md

Raw Backups
────────────────────────────────────────────────────────────────────────────────
  Total backups:        25
  Total size:           15.2 MB

Pending Backups
────────────────────────────────────────────────────────────────────────────────
  .pending-backup-exit: ✓ Present

Recommendations:
  • Run /resume-latest to process pending backup
```

---

## Cross-References

- **[/cleanup-backups](cleanup-backups.md)** - Remove old backups to free space
- **[/document-and-save](document-and-save.md)** - Update context files
- **[/resume-latest](resume-latest.md)** - Process pending backups
