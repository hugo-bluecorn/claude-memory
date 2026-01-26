---
description: Merge delta work from compact backup into last session document
---

# Coalesce Session Delta

Merge work done after the last `/document-and-save` but before context compaction into the existing session document.

## When to Use

Run `/coalesce` when:
1. You previously ran `/document-and-save` (creating a session document)
2. You continued working after that save
3. Context compaction occurred (PreCompact hook ran)
4. You want to merge that "delta" work into the existing session document

## Prerequisites Check

Before proceeding, verify coalescing is possible:

### Step 1: Check for Last Session Doc

Read `.claude/memory/active-context.md` and look for the `> Last Session Doc:` field.

```bash
grep "^> Last Session Doc:" .claude/memory/active-context.md
```

If this field is empty or missing, coalescing is **not possible** - there's no target session document.
Inform the user and suggest running `/document-and-save` instead.

### Step 2: Check for Pending Compact Backup

Check for the compact backup marker:

```bash
cat .claude/memory/.pending-backup-compact 2>/dev/null
```

If this file doesn't exist, coalescing is **not possible** - there's no delta to merge.
Inform the user: "No pending compact backup found. Nothing to coalesce."

### Step 3: Verify Files Exist

1. Verify the session document exists:
   ```bash
   ls .claude/memory/[session-doc-name] 2>/dev/null
   ```

2. Verify the backup file exists (path from marker file):
   ```bash
   ls [backup-path-from-marker] 2>/dev/null
   ```

If either is missing, inform the user and suggest appropriate action:
- Missing session doc: "Session document not found. Run `/resume-latest --process` to create a new session."
- Missing backup: "Backup file not found. Run `/discard-backup` to clean up stale marker."

### Step 4: Verify Timestamps

Extract the session document date from its YAML frontmatter:

```bash
grep "^date:" .claude/memory/[session-doc-name] | head -1
```

Extract the backup timestamp from its filename (format: `YYYYMMDD_HHMMSSZ_compact.jsonl` - note the Z suffix for UTC).

If the backup is **older** than the session document, coalescing is **not appropriate**.
Inform the user: "Backup is older than session document. Nothing to coalesce."

## Coalesce Process

If all prerequisites pass, proceed with coalescing:

### Step 1: Read the Compact Backup

Read the JSONL backup file. Each line is a JSON object with conversation history.

**JSONL Format Reference:**
```json
{"type":"summary","summary":"Brief session description"}
{"type":"user","message":{"role":"user","content":"User message"}}
{"type":"assistant","message":{"role":"assistant","content":"Claude response"}}
{"type":"tool_use","tool":"Bash","input":{"command":"..."}}
{"type":"tool_result","output":"..."}
```

### Step 2: Extract Delta Work

From the backup, identify work done AFTER the session document timestamp:
- Look at message timestamps or sequence
- Focus on: user requests, Claude responses, tool uses, decisions made
- Identify: new files modified, new accomplishments, new decisions

### Step 3: Generate Session Continuation Section

Create a "Session Continuation" section with this format:

```markdown

---

## Session Continuation (YYYY-MM-DDTHH:MMZ)

> Coalesced from: raw/YYYYMMDD_HHMMSSZ_compact.jsonl

### Additional Work
- [Work completed after the original save]
- [New features implemented]
- [Bugs fixed]

### Files Modified
- `path/to/file` - [what changed]

### Decisions Made
- [Any architectural or design decisions]
- [User preferences captured]

### Updated State
- [Current state after this additional work]
- [Any new blockers or issues]
```

### Step 4: Append to Session Document

Append the "Session Continuation" section to the end of the session document.

### Step 5: Update Session Document Frontmatter

Update the YAML frontmatter:
- Update `date:` to the compaction timestamp (UTC with Z suffix)
- Optionally update `status:` if work changed the state

### Step 6: Update active-context.md

Update `.claude/memory/active-context.md`:
1. Update `> Last Updated:` to current UTC timestamp (YYYY-MM-DDTHH:MM:SSZ)
2. Keep `> Last Session Doc:` pointing to same file (now updated)
3. Update other sections to reflect the coalesced work
4. Remove or update the `## Compaction` section

### Step 7: Clean Up

Delete the pending backup marker:

```bash
rm .claude/memory/.pending-backup-compact
```

Optionally delete the backup file (or keep for reference):
- If keeping: inform user where it is
- If deleting: confirm with user first

## Output

After successful coalescing, inform the user:

```
Successfully coalesced delta work into session document.

Session document: .claude/memory/[session-doc-name]
- Added "Session Continuation" section with [N] additional items
- Updated frontmatter date to [timestamp]

Backup marker deleted. The session document now contains all work up to compaction.

Next: Continue working, or run /document-and-save when ready to create a new session.
```

## Error Handling

| Condition | Action |
|-----------|--------|
| No Last Session Doc field | Suggest `/document-and-save` |
| No pending compact marker | Inform "Nothing to coalesce" |
| Session doc missing | Suggest `/resume-latest --process` |
| Backup file missing | Suggest `/discard-backup` |
| Backup older than session | Inform "Nothing to coalesce" |
| Parse error in JSONL | Skip malformed lines, continue |

## Cross-References

- **[/document-and-save](document-and-save.md)** - Create session document (sets Last Session Doc)
- **[/resume-latest](resume-latest.md)** - Process backup as new session (alternative to coalesce)
- **[/discard-backup](discard-backup.md)** - Discard backup without processing
