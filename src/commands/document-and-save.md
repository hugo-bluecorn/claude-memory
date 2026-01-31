---
description: Document current session progress to a markdown file
---

# Document and Save Workflow

Please follow these steps. Wrap all output at 120 characters maximum.

**CRITICAL**: Execute in this order to prevent data loss from auto-compaction race conditions.

## Step 0: Check for Pending Backup

Check for pending backups (there may be multiple):

1. If your SessionStart context includes `SESSION_BACKUP_PENDING`, note the backup path(s).
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
> Last Session Doc: session-YYYY-MM-DD-HHMMZ.md

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

### Step 2a: Get Timestamp for Filename

**CRITICAL**: Get the current UTC timestamp from the script for the filename and YAML date:

```bash
bash .claude/scripts/get-utc-timestamp.sh
```

Use this timestamp for:
- Session filename: `session-YYYY-MM-DD-HHMMZ.md` (remove seconds, keep Z suffix)
- YAML `date:` field: `YYYY-MM-DDTHH:MMZ` (same format, in frontmatter)

### Step 2b: Create Session Document

Create the document in `.claude/memory/sessions/session-YYYY-MM-DD-HHMMZ.md`:

### Auto-detect Previous Session

Before creating the document, find the most recent existing session:

```bash
ls -t .claude/memory/sessions/session-*.md 2>/dev/null | head -1
```

If a previous session exists, set `previous_session` to its relative path (e.g., `session-2026-01-14-1430Z.md`).
This creates a chain of sessions that can be followed for full project history.

### YAML Frontmatter

   ```yaml
   ---
   date: YYYY-MM-DDTHH:MMZ
   project: <infer from cwd name or package.json>
   status: completed | in-progress | blocked
   tags: [relevant, keywords, for, this, session]
   previous_session: <most recent session file, or null if first session>
   branch: <current git branch, omit if not a git repo>
   ---
   ```

   ## Session Summary
   - Main objectives and goals for this session
   - Overall outcome (completed/partial/blocked)

   ## Accomplishments
   - Detailed list of what was completed
   - Files created or modified (with brief descriptions)
   - Key code changes or features implemented

   ## Key Decisions & Patterns
   - Important architectural decisions made
   - Coding patterns or conventions established
   - Trade-offs considered and chosen approaches

   ## User Preferences & Decisions
   - User preferences captured (style choices, workflow decisions)
   - Key questions asked and answers given during the session
   - Decisions made based on user input

   ## Failed Approaches
   - What was tried and didn't work
   - Why it failed (error messages, performance issues, etc.)
   - **DO NOT retry these approaches in future sessions without good reason**

   ## Git Context (only if in a git repo, otherwise omit this section)
   - Current branch name
   - Commits made this session (with hashes and messages)
   - Uncommitted changes summary (staged and unstaged)
   - Any stashed changes

   ## Current State
   - What's working
   - What's partially complete
   - Any blocking issues or errors (include actual error messages)

   ## Remaining Todos
   - [ ] HIGH: Incomplete high-priority items
   - [ ] MEDIUM: Incomplete medium-priority items
   - [ ] LOW: Incomplete low-priority items
   - [ ] BLOCKED: Items that are blocked (note: reason for blockage)

   ## Next Steps
   - Clear action items for next session
   - Specific tasks remaining
   - Priority order (1, 2, 3...)

   ## Key Files
   - `path/to/file.ts` - purpose/current status
   - List primary files worked on with brief descriptions
   - Note any files that need attention next session

   ## Environment Notes
   - Relevant dependency versions (if they matter for the work)
   - Any config details that are important
   - System-specific notes if applicable

   ## Test Status
   - Tests run: [pass/fail counts, or "not run"]
   - Coverage: [if known]
   - Failing tests: [list any failures with brief descriptions]

   ## Technical Debt
   - Known shortcuts or temporary solutions taken
   - Items needing future refactoring
   - TODOs noted during the session

   ## Code Understanding
   - Architectural insights gained during this session
   - Key patterns learned about the codebase
   - "Aha moments" and paradigm shifts
   - Critical code snippets or patterns for continuation

   ## Warnings & Gotchas
   - Pitfalls discovered during this session
   - Things that don't work as expected
   - Critical "don't do this" notes for future sessions
   - Lessons learned the hard way

   ## References Used
   - Documentation consulted (with links if available)
   - Stack Overflow, GitHub issues, or other resources referenced
   - External tools or services used

## Step 3: Final Steps

1. **Create the session log directory** if it doesn't exist (`.claude/memory/`)
2. **Confirm the file was created** by showing the full file path
3. **Update `active-context.md` with session doc path** for coalescing support:
   - Edit the `> Last Session Doc:` line to contain the actual session document filename
   - Example: `> Last Session Doc: session-2026-01-15-1430.md`
   - This enables `/coalesce` to merge delta work if compaction occurs before the next save
4. **Provide instructions** for resuming:
   - "Next session will auto-load context via CLAUDE.md @imports"
   - For full details: `/resume-from .claude/memory/sessions/session-YYYY-MM-DD-HHMM.md`
   - Alternative: `/resume-latest` to automatically load the most recent session
   - If compaction occurs before next `/document-and-save`, run `/coalesce` to merge delta work

---

## Cross-References

- **[/resume-from](resume-from.md)** - Load a specific session document
- **[/resume-latest](resume-latest.md)** - Load most recent session
- **[/sessions-list](sessions-list.md)** - Browse all session logs
- **[/coalesce](coalesce.md)** - Merge delta work after compaction into last session document
