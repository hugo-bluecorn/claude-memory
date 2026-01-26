---
description: List all available session logs for discovery and selection
---

# List Session Logs

Please follow these steps. Wrap all output at 120 characters maximum.

## 0. Check for Pending Backup

If your SessionStart context includes `SESSION_BACKUP_PENDING`, extract the backup path from that message.

Otherwise, check the marker files:
```bash
cat .claude/memory/.pending-backup-exit 2>/dev/null
cat .claude/memory/.pending-backup-compact 2>/dev/null
```

If a pending backup exists, display it prominently before the session list:

> **Pending backup:** `[filename.jsonl]` (unprocessed)
> Run `/resume-latest` to process, or `/discard-backup` to discard.

## 1. Find All Sessions

- Look in `.claude/memory/` directory
- Find all `.md` files
- Sort by date (newest first, based on filename pattern `session-YYYY-MM-DD-HHMM.md`)

If the directory doesn't exist or is empty:
- Inform the user: "No session logs found in `.claude/memory/`. Use `/document-and-save` to create your first session log."
- End here

## 2. Display Session List

For each session file, parse the YAML frontmatter and display in a table or list format:

| # | Date | Project | Status | Branch | Summary |
|---|------|---------|--------|--------|---------|
| 1 | 2024-01-15 14:30 | my-project | in-progress | feature/auth | Implementing user authentication... |
| 2 | 2024-01-14 10:00 | my-project | completed | main | Fixed database connection issues... |
| ... | ... | ... | ... | ... | ... |

For each session show:
- **Date/Time**: From filename or frontmatter
- **Project**: From frontmatter (or "unknown" if not present)
- **Status**: completed | in-progress | blocked (from frontmatter)
- **Branch**: From frontmatter (if present, otherwise "-")
- **Tags**: From frontmatter (if present)
- **Summary**: First line of the "Session Summary" section (truncated if long)

## 3. Show Session Chains

If any sessions have `previous_session` links in their frontmatter:
- Note which sessions are continuations of others
- Example: "Session #1 is a continuation of Session #3"

## 4. Offer Options

After displaying the list, ask:

> **What would you like to do?**
> 1. Resume a specific session (enter number)
> 2. View details of a specific session (enter number)
> 3. Resume the most recent session (`/resume-latest`)
> 4. Done browsing

Wait for user input.

## 5. Handle User Choice

- **Resume session**: Run the equivalent of `/resume-from <session-path>`
- **View details**: Read and display the full session document
- **Resume latest**: Follow `/resume-latest` steps
- **Done**: End the command

---

## Cross-References

- **[/document-and-save](document-and-save.md)** - Creates session documents listed by this command
- **[/document-and-save-to](document-and-save-to.md)** - Creates session documents at custom paths
- **[/resume-from](resume-from.md)** - Load a specific session from the list
- **[/resume-latest](resume-latest.md)** - Quickly load most recent session
