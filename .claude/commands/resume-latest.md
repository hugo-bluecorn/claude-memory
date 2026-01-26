---
description: Resume from the most recent session log automatically
---

# Resume From Latest Session

Please follow these steps. Wrap all output at 120 characters maximum.

## Options

| Option | Description |
|--------|-------------|
| `--yes` | Skip confirmation prompts and proceed automatically |

## 0. Check for Pending Raw Transcript

**FIRST**, check for pending backups. There may be multiple backup markers:

| Marker File | Created By | When |
|-------------|------------|------|
| `.pending-backup-compact` | PreCompact hook | Context auto-compaction |
| `.pending-backup-exit` | SessionEnd hook | Session exit (/exit, logout) |

**Detection methods:**

1. If your SessionStart context includes `SESSION_BACKUP_PENDING`, extract the backup path(s) and type(s) directly.
2. Otherwise, check for markers:
   ```bash
   # Check marker types (newest is usually most relevant)
   cat .claude/memory/.pending-backup-exit 2>/dev/null
   cat .claude/memory/.pending-backup-compact 2>/dev/null
   ```

**If pending backup(s) exist:**

### Check for Linked Session Document

For ANY pending backup (exit OR compact), check if a session document exists:

1. Look for `> Last Session Doc:` field in `.claude/memory/active-context.md`
2. Verify the session document file exists in `.claude/memory/sessions/`
3. If found, **always offer session-first options**:

```
Detected pending backup: [backup-path]
Type: [exit/compact]
Linked session document: [session-doc-name]

The session document was saved before the session ended.
The backup may contain additional work done after /document-and-save.

Options:
1. [RECOMMENDED] Load session document + check for delta work
2. Load session document only (discard backup)
3. Process backup as new session (ignore session document)

Choose option (1-3):
```

**Option 1 Flow:**
1. Load session document using `/resume-from` flow
2. Perform lightweight delta check on JSONL:
   - Count file edits (Write/Edit tool uses)
   - Count substantive user messages (excluding commands)
   - Check time delta between session doc and backup
3. If delta is substantial (file edits > 0 OR time delta > 30min):
   - Present: "Since your last save, you also: [brief delta summary]"
   - Ask: "Add this to your context? [Y/n]"
4. Clean up backup marker (and optionally backup file)

**Option 2 Flow:**
1. Load session document using `/resume-from` flow
2. Delete backup marker and backup file
3. Inform user: "Backup discarded. Proceeding with session document."

**Option 3 Flow:**
Continue to "Standard Backup Processing" below.

If no linked session document exists, skip directly to "Standard Backup Processing".

### Standard Backup Processing

If no linked session document exists, OR user chose option 3:
- Read the raw transcript file(s) indicated in the marker(s)
- Parse the JSONL conversation history (see JSONL Format Reference below)
- Generate a high-quality summary following the Extraction Strategy
- Update `.claude/memory/active-context.md` with the summary
- Optionally create a session document: `.claude/memory/sessions/session-YYYY-MM-DD-HHMM.md`
- Delete the processed marker file(s)
- Continue to step 3 (skip steps 1-2 since we just processed the latest)

**Note:** If both `compact` and `exit` markers exist, the `exit` backup is typically more complete (includes post-compaction work). Process the exit backup and discard the compact backup.

If no markers exist, continue to step 1.

## 1. Find the Most Recent Session

Compare timestamps from two sources:

**A. Session Documents:**
- Look in `.claude/memory/` directory
- Find all `.md` files matching the pattern `session-YYYY-MM-DD-HHMM.md`
- Sort by the date/time in the filename (newest first)

**B. Raw Transcripts (if no session documents or transcripts are newer):**
- Look in `.claude/memory/raw/` directory
- Find all `.jsonl` files
- Sort by timestamp in filename (newest first)

**Selection logic:**
- If a raw transcript is newer than the latest session document, process the raw transcript first
- Otherwise, use the session document

If no sessions or raw transcripts exist:
- Inform the user: "No session logs found in `.claude/memory/`"
- Offer to start fresh or ask if sessions are stored elsewhere

## 2. Confirm Before Proceeding

Display the session to be loaded:
- **Source**: Session document OR Raw transcript
- **File**: Full path to the file
- **Date**: From filename or YAML frontmatter
- **Project**: From YAML frontmatter (if available)
- **Status**: From YAML frontmatter (if available)

**If `--yes` flag is present**: Skip confirmation and proceed directly to Step 3.

**Otherwise**: Ask "Load this session? (If not, use `/sessions-list` to see all available sessions)"

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
2. Extract conversation history using the JSONL Format Reference below
3. Apply the Extraction Strategy to identify key information
4. Generate a high-quality summary following the session document format
5. Update `.claude/memory/active-context.md` with condensed summary
6. Optionally save full summary to `.claude/memory/sessions/session-YYYY-MM-DD-HHMM.md`
7. Present summary and next steps to user

See `/resume-from` for detailed instructions on each step.

---

## JSONL Format Reference

Each line in the raw transcript is a JSON object with one of these structures:

**Summary line** (first line):
```json
{"type":"summary","summary":"Brief session description"}
```

**User message**:
```json
{"type":"user","message":{"role":"user","content":"User's message text"}}
```

**Assistant message**:
```json
{"type":"assistant","message":{"role":"assistant","content":"Claude's response"}}
```

**Tool call**:
```json
{"type":"tool_use","tool":"Bash","input":{"command":"..."}}
```

**Tool result**:
```json
{"type":"tool_result","output":"..."}
```

**Error handling**: Skip malformed lines (invalid JSON) and continue processing. Log skipped lines if debug mode is enabled.

---

## Extraction Strategy

When parsing a raw transcript, follow this strategy to build a useful summary:

1. **Identify main tasks/questions**: Collect all user messages and extract the primary requests
2. **Extract decisions and explanations**: Review assistant messages for key decisions, reasoning, and explanations given
3. **Track files modified**: Look for `tool_use` of type "Write" or "Edit" to identify changed files
4. **Document failed approaches**: Search `tool_result` outputs for error patterns, exceptions, or failed attempts
5. **Note environment details**: Extract any system info, configuration, or environment-specific details mentioned

**Summary structure**: Organize extracted information into these sections:
- **Session Goal**: What the user wanted to accomplish
- **Key Accomplishments**: What was completed successfully
- **Files Changed**: List of files created, modified, or deleted
- **Decisions Made**: Important choices and their rationale
- **Failed Approaches**: What didn't work and why (helps avoid repeating mistakes)
- **Next Steps**: What was planned but not completed

---

## Notes

**Auto-loaded context**: `.claude/memory/active-context.md` is automatically loaded via CLAUDE.md `@import`. This provides basic continuity without running any command. Use `/resume-latest` when you need full detailed context from the session document.

**SessionEnd hook**: Raw transcripts in `.claude/memory/raw/` are automatically saved by the SessionEnd hook when sessions end via /exit. These can be processed by this command to recover context.

---

## Cross-References

- **[/resume-from](resume-from.md)** - Detailed steps for loading session context
- **[/document-and-save](document-and-save.md)** - Creates session documents that this command loads
- **[/sessions-list](sessions-list.md)** - Browse and select from all available sessions
- **[/coalesce](coalesce.md)** - Merge delta work from compact backup into last session document
