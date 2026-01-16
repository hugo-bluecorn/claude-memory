---
description: Clear ALL session data including project-memory
---

# Fresh Start (Complete Reset)

Reset session management completely, including permanent project knowledge.

## What Gets Cleared

Everything from `/fresh-start` PLUS:
- `.claude/memory/project-memory.md` - Reset to template

This is a **complete reset** - all session history and project learnings will be lost.

## Steps

### 1. Confirm with User (Strong Warning)

Before proceeding, show a clear warning:

```
WARNING: Complete reset will clear EVERYTHING:
- All session documents in .claude/memory/sessions/
- All raw backups in .claude/memory/raw/
- All pending backup markers
- Active context will be reset to template
- PROJECT-MEMORY WILL ALSO BE RESET (all learnings lost!)

This cannot be undone.
```

Ask: "Are you sure you want to reset everything including project-memory? [y/N]"

If user declines, suggest using `/fresh-start` instead to preserve project-memory.

### 2. Execute Complete Reset

Run the helper script with the FRESH_START_ALL flag:

```bash
FRESH_START_ALL=true bash "$CLAUDE_PROJECT_DIR/.claude/scripts/fresh-start.sh"
```

### 3. Report Results

After the script completes, inform the user:
- Number of session documents removed
- Number of backup files removed
- Number of markers cleared
- Confirmation that active-context.md was reset
- Confirmation that project-memory.md was also reset

## Cross-References

- **[/fresh-start](fresh-start.md)** - Preserve project-memory (recommended)
- **[/document-and-save](document-and-save.md)** - Save session before reset
