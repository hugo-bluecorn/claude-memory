# Claude Memory Best Practices

This guide covers best practices for using the claude-memory session management system effectively.

## Session Management Workflow

### Starting a Session

1. **Check for pending backups**: SessionStart hook automatically notifies you if there's a pending backup
2. **Process or discard**: Run `/resume-latest` to restore context, or `/discard-backup` if not needed
3. **Review active context**: The active-context.md is auto-loaded, giving you immediate context

### During a Session

1. **Work normally**: Claude Code handles everything automatically
2. **Long sessions**: If context gets compacted, PreCompact hook saves a backup
3. **Track progress**: Use TodoWrite to track tasks (Claude does this automatically)

### Proactive Context Monitoring

**Important**: Claude cannot see how much context is being used. Only you can check this.

Periodically run `/context` to see your token usage:

```
⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁   claude-opus-4-5-20251101 · 85k/200k tokens (43%)
⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁   ⛁ Messages: 65.8k tokens (32.9%)
⛁ ⛁ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶   ⛶ Free space: 70k (34.8%)
⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶   ⛝ Autocompact buffer: 45.0k tokens (22.5%)
```

**When to save proactively**:
- When Messages reaches **60-70%** of total capacity, run `/document-and-save`
- This ensures a clean, structured save *before* auto-compaction
- The PreCompact hook is a safety net, but proactive saves are better

**Rule of thumb**: If free space is approaching the autocompact buffer, save now.

### Ending a Session

1. **Before exiting**: Run `/document-and-save` to create a comprehensive session document
2. **Exit normally**: SessionEnd hook automatically backs up the raw transcript
3. **Next session**: SessionStart will notify you of the pending backup

## Context Management

### Keep active-context.md Small

The active-context.md file is loaded into every session. Keep it focused:

- **DO**: Include current task, blockers, immediate next steps
- **DON'T**: Include detailed code snippets, full error logs, or historical context
- **Target size**: Under 5KB for optimal performance

Use `/context-stats` to check your context overhead.

### Use project-memory.md for Persistent Context

Project memory is for information that persists across all sessions:

- Project architecture decisions
- Code conventions and patterns
- Important file locations
- Environment setup notes

### When to Run /document-and-save

Run `/document-and-save` when:
- You're about to exit for the day
- You've completed a significant milestone
- Context is getting large and might be compacted
- You want to preserve detailed context for later

### Handling Stale Context

If SessionStart warns about stale context (>24h old):
1. Review what's in active-context.md
2. Decide if it's still relevant
3. Run `/document-and-save` to update with current state

## Backup Management

### Understanding Backup Types

| Backup Type | When Created | Purpose |
|-------------|--------------|---------|
| Exit backup (`.pending-backup-exit`) | Session exit | Preserve full session |
| Compact backup (`.pending-backup-compact`) | Auto-compaction | Safety net during long sessions |

### Processing Backups

When you see `SESSION_BACKUP_PENDING`:
1. Run `/resume-latest` to process and restore context
2. Or run `/discard-backup` if you don't need it

### Cleaning Up Old Backups

Periodically run `/cleanup-backups` to remove old backups:

```bash
# Preview what would be deleted
/cleanup-backups --dry-run

# Delete backups older than 14 days, keep at least 5
/cleanup-backups --older-than 14 --keep-last 5
```

## Session Documents

### Creating Good Session Documents

When `/document-and-save` runs, it creates comprehensive documentation. Tips:

1. **Clear objectives**: State what you set out to accomplish
2. **Document failures**: The "Failed Approaches" section prevents repeating mistakes
3. **Specific next steps**: Make next steps actionable and clear
4. **Tag appropriately**: Good tags make sessions searchable

### Finding Past Sessions

Use `/search-sessions` to find relevant past work:

```bash
# Search for authentication-related sessions
/search-sessions authentication

# Find past failures
/search-sessions "error" --section "Failed Approaches"
```

### Session Chaining

Sessions automatically link to their predecessor via `previous_session` in frontmatter. This creates a traceable history of work.

### Session Coalescing

When compaction occurs after a `/document-and-save`, you have a choice:

**Use `/coalesce` when:**
- You're continuing the same logical work session
- The delta work is closely related to the saved session
- You want a single comprehensive session document

**Use `/resume-latest` (process as new session) when:**
- You're starting a new task or topic
- The delta work is unrelated to the previous save
- You prefer smaller, more focused session documents

**How it works:**
1. `/document-and-save` records `> Last Session Doc:` in active-context.md
2. If compaction occurs, PreCompact backs up the transcript
3. `/resume-latest` detects both markers and offers `/coalesce`
4. `/coalesce` appends a "Session Continuation" section to the existing document

**Tip**: If you frequently use `/document-and-save` mid-session, coalescing helps maintain a coherent session history.

## Troubleshooting

### "Context is stale" Warning

**Cause**: active-context.md hasn't been updated in >24 hours

**Solution**: Run `/document-and-save` to update context

### "Context overhead" Warning

**Cause**: Combined context files exceed 20KB

**Solution**:
1. Trim active-context.md to essentials
2. Move persistent info to project-memory.md
3. Archive detailed content to session documents

### Pending Backup Not Processing

**Cause**: Marker file exists but backup file is missing

**Solution**: Run `/discard-backup` to clean up stale marker

### Lost Context After Compaction

**Cause**: Context was compacted before you could save

**Solution**:
1. Check for `.pending-backup-compact` marker
2. Run `/resume-latest` to process the backup
3. In future, run `/document-and-save` before long breaks

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HOOK_STALENESS_THRESHOLD` | 86400 (24h) | Seconds before context is considered stale |
| `HOOK_OVERHEAD_THRESHOLD` | 20480 (20KB) | Bytes before overhead warning |
| `HOOK_DEBUG` | false | Enable debug logging |

### Customizing Thresholds

For testing or specific workflows:

```bash
# Lower staleness threshold to 12 hours
export HOOK_STALENESS_THRESHOLD=43200

# Increase overhead threshold to 50KB
export HOOK_OVERHEAD_THRESHOLD=51200
```

## Quick Reference

| Command | Purpose |
|---------|---------|
| `/document-and-save` | Save session to default location |
| `/document-and-save-to <path>` | Save session to custom location |
| `/resume-latest` | Load most recent session |
| `/resume-from <path>` | Load specific session |
| `/sessions-list` | Browse available sessions |
| `/search-sessions <keyword>` | Search session content |
| `/coalesce` | Merge delta work into last session document |
| `/cleanup-backups` | Remove old backups |
| `/discard-backup` | Discard pending backup |
| `/context-stats` | View context statistics |
