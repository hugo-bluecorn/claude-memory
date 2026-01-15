---
description: Resume work from a previous session document. Usage: /resume-from <filepath>
---

# Resume From Session Document

Please follow these steps. Wrap all output at 120 characters maximum.

## 0. Check for Pending Backup

**FIRST**, check for pending backup:

1. If your SessionStart context includes `SESSION_BACKUP_PENDING`, extract the backup path from that message.
2. Otherwise, check the marker file:
   ```bash
   cat planning/sessions/.pending-backup 2>/dev/null
   ```

If a pending backup exists, ask the user:

> A pending backup exists at `[path]`. Choose:
> 1. Process pending backup first (runs /resume-latest flow)
> 2. Skip and load requested session: $ARGUMENTS

**Wait for user choice before proceeding.**

- If choice 1: Process the backup following /resume-latest steps, then ask if they still want to load the
  originally requested session.
- If choice 2: Continue with Step 1 below.

If no pending backup exists, continue to Step 1.

## 1. Locate and Validate the Session Document

- Read the file at: $ARGUMENTS
- If the file is not found or $ARGUMENTS is empty:
  - List available sessions in `planning/sessions/`
  - Ask which session to load, or offer to load the most recent one
- If the path is a directory, list sessions in that directory

## 2. Parse and Display Session Metadata

From the YAML frontmatter, display:
- **Date**: When the session occurred
- **Project**: Project name
- **Status**: completed | in-progress | blocked
- **Branch**: Git branch (if present)
- **Tags**: Relevant keywords
- **Continuation**: Note if this was a continuation of a previous session (previous_session field)

## 3. Summarize Previous Work

Briefly summarize:
- Main objectives from the session
- Key accomplishments (what was completed)
- Current state (what's working, what's partial, any blockers)

## 4. Restore Critical Context

**IMPORTANT**: Read and internalize the following sections to restore full context:

### Failed Approaches
- Note what was tried and didn't work
- **DO NOT retry these approaches** unless the user explicitly requests it or circumstances have changed

### Clarifications & Decisions
- Restore user preferences and decisions made during the session
- Apply these preferences to subsequent work

### Environment Notes
- Note any dependency versions, config details, or system-specific information

### Code Context
- Review critical code snippets or patterns
- Use these for reference when continuing implementation

## 5. Verify Current State

Check if key files mentioned in the session still exist:
- List files from "Key Files" section and verify they exist
- Note any files that are missing or have been deleted

If in a git repo:
- Check current branch vs documented branch
- Report any uncommitted changes since the session
- Note if there have been new commits since the session was documented

Skip git verification gracefully if not in a git repo.

## 6. Restore Todos

If a "Remaining Todos" section exists:
- Parse the todo items
- Recreate them using the TodoWrite tool with appropriate priorities
- Check if any todos appear to be already completed based on current file state
- Mark those as completed and note the observation

## 7. Present Next Steps

Show the documented "Next Steps" from the session, then ask:

> **How would you like to proceed?**
> 1. Continue with the documented next steps (recommended)
> 2. Review accomplishments and context in more detail first
> 3. Start fresh with different priorities
> 4. Focus on a specific task from the remaining todos

Wait for user input before proceeding.

## 8. Apply Context to Subsequent Work

Once the user chooses how to proceed, use all the restored context to inform your work:
- Apply established patterns and conventions
- Remember user preferences and decisions
- Avoid failed approaches
- Build on completed work
- Reference the key files and code context as needed

---

## Notes

**Auto-loaded context**: `planning/sessions/active-context.md` is automatically loaded via CLAUDE.md `@import`. This provides a condensed version of the most recent session state. Use `/resume-from` when you need the full detailed context.

---

## Cross-References

- **[/document-and-save](document-and-save.md)** - Creates session documents that this command loads
- **[/document-and-save-to](document-and-save-to.md)** - Creates session documents at custom paths
- **[/resume-latest](resume-latest.md)** - Automatically loads most recent session
- **[/sessions-list](sessions-list.md)** - Browse available sessions
