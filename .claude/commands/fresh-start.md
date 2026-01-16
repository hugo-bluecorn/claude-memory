---
description: Clear session data and start fresh (preserves project-memory)
---

# Fresh Start

Reset session management to a clean state while preserving permanent project knowledge.

## What Gets Cleared

- Session documents in `.claude/memory/sessions/`
- Raw backups in `.claude/memory/raw/`
- Pending backup markers (`.pending-backup-*`)
- Active context (reset to template)

## What Gets Preserved

- `.claude/memory/project-memory.md` - Permanent project knowledge

## Steps

### 1. Confirm with User

Before proceeding, show what will be deleted:

```
Fresh start will clear:
- All session documents in .claude/memory/sessions/
- All raw backups in .claude/memory/raw/
- All pending backup markers
- Active context will be reset to template

Project-memory.md will be PRESERVED.
```

Ask: "Proceed with fresh start? [y/N]"

If user declines, abort without changes.

### 2. Execute Fresh Start

Run the helper script:

```bash
bash "$CLAUDE_PROJECT_DIR/.claude/scripts/fresh-start.sh"
```

### 3. Report Results

After the script completes, inform the user of what was cleaned:
- Number of session documents removed
- Number of backup files removed
- Number of markers cleared
- Confirmation that active-context.md was reset
- Confirmation that project-memory.md was preserved

## Cross-References

- **[/fresh-start-all](fresh-start-all.md)** - Also reset project-memory
- **[/document-and-save](document-and-save.md)** - Save session before fresh start
- **[/cleanup-backups](cleanup-backups.md)** - Remove only old backups
- **[/discard-backup](discard-backup.md)** - Remove only pending backup
