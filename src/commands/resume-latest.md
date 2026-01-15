---
description: Resume from the most recent session log automatically
---

# Resume From Latest Session

Please follow these steps. Wrap all output at 120 characters maximum.

## 0. Check for Pending Raw Transcript

**FIRST**, check for pending backup using one of these methods:

1. If your SessionStart context includes `SESSION_BACKUP_PENDING`, extract the backup path directly from that message.
2. Otherwise, check the marker file:
   ```bash
   cat planning/sessions/.pending-backup 2>/dev/null
   ```

If a pending backup exists:
- Read the raw transcript file indicated in the marker
- Parse the JSONL conversation history
- Generate a high-quality summary
- Update `planning/sessions/active-context.md` with the summary
- Optionally create a session document: `planning/sessions/session-YYYY-MM-DD-HHMM.md`
- Delete the `.pending-backup` marker
- Continue to step 3 (skip steps 1-2 since we just processed the latest)

If no marker, continue to step 1.

## 1. Find the Most Recent Session

Compare timestamps from two sources:

**A. Session Documents:**
- Look in `planning/sessions/` directory
- Find all `.md` files matching the pattern `session-YYYY-MM-DD-HHMM.md`
- Sort by the date/time in the filename (newest first)

**B. Raw Transcripts (if no session documents or transcripts are newer):**
- Look in `planning/sessions/raw/` directory
- Find all `.jsonl` files
- Sort by timestamp in filename (newest first)

**Selection logic:**
- If a raw transcript is newer than the latest session document, process the raw transcript first
- Otherwise, use the session document

If no sessions or raw transcripts exist:
- Inform the user: "No session logs found in `planning/sessions/`"
- Offer to start fresh or ask if sessions are stored elsewhere

## 2. Confirm Before Proceeding

Display the session to be loaded:
- **Source**: Session document OR Raw transcript
- **File**: Full path to the file
- **Date**: From filename or YAML frontmatter
- **Project**: From YAML frontmatter (if available)
- **Status**: From YAML frontmatter (if available)

Ask: "Load this session? (If not, use `/sessions-list` to see all available sessions)"

## 3. Process Based on Source Type

### If loading from Session Document (.md):

Follow all steps from the `/resume-from` command:
1. Parse and display session metadata
2. Summarize previous work
3. Restore critical context (failed approaches, decisions, environment, code context)
4. Verify current state (files exist, git status if applicable)
5. Restore todos using TodoWrite
6. Present next steps and ask how to proceed
7. Apply restored context to subsequent work

### If loading from Raw Transcript (.jsonl):

1. Read and parse the JSONL file (each line is a JSON object)
2. Extract conversation history (user messages, assistant responses, tool calls)
3. Identify key accomplishments, decisions, and context from the conversation
4. Generate a high-quality summary following the session document format
5. Update `planning/sessions/active-context.md` with condensed summary
6. Optionally save full summary to `planning/sessions/session-YYYY-MM-DD-HHMM.md`
7. Present summary and next steps to user

See `/resume-from` for detailed instructions on each step.

---

## Notes

**Auto-loaded context**: `planning/sessions/active-context.md` is automatically loaded via CLAUDE.md `@import`. This provides basic continuity without running any command. Use `/resume-latest` when you need full detailed context from the session document.

**SessionEnd hook**: Raw transcripts in `planning/sessions/raw/` are automatically saved by the SessionEnd hook when sessions end via /exit. These can be processed by this command to recover context.

---

## Cross-References

- **[/resume-from](resume-from.md)** - Detailed steps for loading session context
- **[/document-and-save](document-and-save.md)** - Creates session documents that this command loads
- **[/sessions-list](sessions-list.md)** - Browse and select from all available sessions
