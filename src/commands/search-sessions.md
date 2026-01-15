---
description: Search across session documents for keywords or patterns
---

# Search Sessions

Search through all session documents to find past work, decisions, or context.

## Usage

```
/search-sessions <keyword> [options]
```

## Options

| Option | Description |
|--------|-------------|
| `<keyword>` | Required. The search term or pattern |
| `--context <n>` | Lines of context around matches (default: 2) |
| `--limit <n>` | Maximum results to show (default: 10) |
| `--section <name>` | Only search within specific section (e.g., "Failed Approaches") |

## Steps

### 1. Find Session Documents

Search in `.claude/memory/` for session documents:

```bash
ls .claude/memory/session-*.md 2>/dev/null
```

If no session documents exist, inform the user and suggest running `/document-and-save`.

### 2. Search for Keyword

Use grep to find matches across all session files:

```bash
grep -n -i "<keyword>" .claude/memory/session-*.md
```

### 3. Parse and Format Results

For each match found:

1. Extract the session file path and date from filename
2. Extract the line number and matching content
3. Get surrounding context lines
4. Identify which section the match is in (if possible)

### 4. Display Results

Format output as:

```
Found 3 matches for "authentication":

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Session: 2026-01-10 14:30 (session-2026-01-10-1430.md)
📍 Section: Failed Approaches
─────────────────────────────────────────────────────────────────────────────────
   42: - Tried JWT authentication but it conflicted with existing session
   43:   management. The middleware was intercepting requests before our
 > 44:   authentication handler could process them.
   45: - Switched to cookie-based auth instead
─────────────────────────────────────────────────────────────────────────────────

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Session: 2026-01-12 09:15 (session-2026-01-12-0915.md)
📍 Section: Accomplishments
─────────────────────────────────────────────────────────────────────────────────
   18: - Implemented cookie-based authentication successfully
 > 19: - Added authentication middleware to protect API routes
   20: - Created login/logout endpoints
─────────────────────────────────────────────────────────────────────────────────

Load a session? Enter filename or 'n' to cancel:
```

### 5. Offer to Load Session

If user enters a session filename, run `/resume-from <path>` to load it.

## Search Tips

- **Case insensitive**: Searches are case-insensitive by default
- **Partial matches**: "auth" will match "authentication", "authorize", etc.
- **Section filtering**: Use `--section "Failed Approaches"` to find past failures
- **Quotes for phrases**: Use quotes for multi-word searches: `"database migration"`

## Examples

```bash
# Basic search
/search-sessions authentication

# Search with more context
/search-sessions "database error" --context 5

# Search only in Failed Approaches section
/search-sessions bug --section "Failed Approaches"

# Limit results
/search-sessions config --limit 5
```

## Use Cases

1. **Find past failures**: Search for error messages to see if you've encountered them before
2. **Locate decisions**: Search for keywords related to architectural decisions
3. **Find file references**: Search for specific filenames to find sessions that modified them
4. **Recall context**: Search for project-specific terms to find relevant past work

---

## Cross-References

- **[/resume-from](resume-from.md)** - Load a specific session found by search
- **[/sessions-list](sessions-list.md)** - Browse sessions by date instead of searching
- **[/resume-latest](resume-latest.md)** - Load most recent session without searching
