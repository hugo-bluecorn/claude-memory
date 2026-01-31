---
description: Document session to specified file path. Usage: /document-and-save-to <filepath>
---

# Document and Save to Custom Path

Document session to: **$ARGUMENTS** (or default: `.claude/memory/sessions/session-YYYY-MM-DD-HHMM.md`)

Please follow these steps. Wrap all output at 120 characters maximum.

**CRITICAL**: Execute in this order to prevent data loss from auto-compaction race conditions.

## Step 0: Check for Pending Backup

Check for pending backup:

1. If your SessionStart context includes `SESSION_BACKUP_PENDING`, note the backup path.
2. Otherwise, check the marker files:
   ```bash
   cat .claude/memory/.pending-backup-exit 2>/dev/null
   cat .claude/memory/.pending-backup-compact 2>/dev/null
   ```

If a pending backup exists, inform the user:

> Note: An unprocessed backup exists at `[path]`. Creating a new session document will not process it.
> Consider running `/resume-latest` first if you want to preserve that context.

Continue with documentation (don't block).

## Step 1: UPDATE `.claude/memory/active-context.md` FIRST

This is the most critical step - do this BEFORE writing the full session document.

### Step 1a: Update Timestamp via Script

**CRITICAL**: Run the timestamp script to set the `> Last Updated:` field. Do NOT write timestamps manually.

```bash
bash .claude/scripts/update-active-context-timestamp.sh
```

This script updates the timestamp automatically, preventing timestamp fabrication issues.

### Step 1b: Update Content

After running the timestamp script, update the rest of active-context.md with current session state.

**NOTE**: The `> Last Session Doc:` field will be set in Step 3 after creating the session document.
This enables session coalescing - merging delta work done after this save but before compaction.

```markdown
# Active Session Context
> Last Updated: [ALREADY SET BY SCRIPT - DO NOT MODIFY]
> Last Session Doc: [will be set after document creation]

## Current Task
[From Next Steps - what to work on next]

## Completed This/Last Session
- [Brief list of accomplishments]

## In Progress
- [Items partially complete]

## Next Steps
1. [Priority-ordered action items]

## Blockers
- [Any blocking issues, or "None"]

## Warnings/Gotchas
- [Critical things to avoid or remember]

## Key Files Modified
- [List of important files changed this session]
```

## Step 2: Create Full Session Document

### Step 2a: Get Timestamp for YAML

**CRITICAL**: Get the current UTC timestamp from the script for the YAML date field:

```bash
bash .claude/scripts/get-utc-timestamp.sh
```

Use this timestamp for the YAML `date:` field (format: `YYYY-MM-DDTHH:MMZ`, remove seconds).

### Step 2b: Write Session Document

Start with YAML frontmatter:
```yaml
---
date: [USE TIMESTAMP FROM SCRIPT - REMOVE SECONDS]
project: <infer from cwd name or package.json>
status: completed | in-progress | blocked
tags: [relevant, keywords]
previous_session: <path if continuation, or null>
branch: <git branch if applicable>
---
```

Include all sections:
- **Session Summary** - objectives and outcome
- **Accomplishments** - completed work, files modified
- **Key Decisions & Patterns** - architectural decisions, conventions
- **Clarifications & Decisions** - Q&A, user preferences
- **Failed Approaches** - what didn't work (DO NOT retry)
- **Git Context** - branch, commits, changes (if in git repo)
- **TDD Context** (if TDD in progress) - current phase (Red/Green/Refactor), test status, task file path
- **Current State** - working, partial, blockers with error messages
- **Remaining Todos** - incomplete items with priority
- **Next Steps** - action items in priority order
- **Key Files** - files worked on with purpose
- **Environment Notes** - dependencies, config details
- **Code Context** - critical snippets for continuation
- **Context & Notes** - lessons learned, warnings

## Step 3: Final Steps

1. Create parent directories if needed
2. Confirm the file was created with full path
3. **Update `active-context.md` with session doc path** for coalescing support:
   - Edit the `> Last Session Doc:` line to contain the actual document path/filename
   - This enables `/coalesce` to merge delta work if compaction occurs before the next save
4. Provide resume instructions:
   - "Next session will auto-load context via CLAUDE.md @imports"
   - For full details: `/resume-from <filepath>`
   - Alternative: `/resume-latest` to automatically load the most recent session
   - If compaction occurs before next `/document-and-save`, run `/coalesce` to merge delta work

---

## Cross-References

- **[/document-and-save](document-and-save.md)** - Same workflow with default path
- **[/resume-from](resume-from.md)** - Load a specific session document
- **[/resume-latest](resume-latest.md)** - Load most recent session
- **[/sessions-list](sessions-list.md)** - Browse all session logs
- **[/coalesce](coalesce.md)** - Merge delta work after compaction into last session document
