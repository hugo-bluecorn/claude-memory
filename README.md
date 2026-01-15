# Claude Memory

A session continuity system for Claude Code that automatically preserves context across sessions.

## What This Does

Claude Code sessions have limited context. When context fills up or you exit, valuable information can be lost. This system provides:

- **Automatic backups** - Hooks save raw transcripts when sessions end or auto-compact
- **Session documents** - Create structured summaries of your work with `/document-and-save`
- **Easy resumption** - Restore context with `/resume-latest` or `/resume-from`
- **Permanent memory** - Store project knowledge in `project-memory.md`

## Quick Start

### Automatic Installation (Coming Soon)

```bash
curl -sSL https://raw.githubusercontent.com/hugo-bluecorn/claude-memory/main/setup_memory_management.sh | bash
```

### Manual Installation

1. Copy the files to your project:
   ```bash
   # Commands
   cp -r src/commands/* .claude/commands/

   # Hooks
   cp -r src/hooks/* .claude/hooks/
   chmod +x .claude/hooks/*.sh

   # Scripts
   cp -r src/scripts/* .claude/scripts/
   chmod +x .claude/scripts/*.sh

   # Create sessions directory
   mkdir -p planning/sessions/raw
   cp src/templates/active-context.md planning/sessions/
   cp src/templates/project-memory.md planning/sessions/
   ```

2. Merge hooks into your `.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PreCompact": [
         {
           "matcher": "auto|manual",
           "hooks": [
             {
               "type": "command",
               "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/on-pre-compact.sh"
             }
           ]
         }
       ],
       "SessionStart": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/on-session-start.sh"
             }
           ]
         }
       ],
       "SessionEnd": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/on-session-end.sh"
             }
           ]
         }
       ]
     }
   }
   ```

3. Add session management section to your `.claude/CLAUDE.md`:
   - Copy contents of `CLAUDE.md.snippet` and append to your CLAUDE.md

## Commands

| Command | Description |
|---------|-------------|
| `/document-and-save` | Save current session to `planning/sessions/session-YYYY-MM-DD-HHMM.md` |
| `/document-and-save-to <path>` | Save session to a custom path |
| `/resume-latest` | Process pending backup or load most recent session |
| `/resume-from <path>` | Load a specific session document |
| `/sessions-list` | Browse all available session logs |
| `/discard-backup` | Discard pending backup without processing |

## How It Works

### Automatic Backup (Safety Net)

1. **Session End** - When you run `/exit` or close the terminal, `on-session-end.sh` saves the raw transcript to `planning/sessions/raw/`
2. **Auto-Compact** - When context reaches ~90%, `on-pre-compact.sh` saves the transcript before compaction
3. **Next Session** - `on-session-start.sh` detects the pending backup and notifies Claude

### Manual Save (Recommended)

Run `/document-and-save` at natural milestones:
1. Updates `active-context.md` with condensed summary (critical step)
2. Creates full session document with all sections
3. Provides resume instructions

### Resumption

- **Auto-loaded**: `active-context.md` is imported via `@` syntax in CLAUDE.md
- **Full details**: Run `/resume-latest` or `/resume-from <path>` for complete context

## File Structure

After installation, your project will have:

```
your-project/
├── .claude/
│   ├── commands/
│   │   ├── document-and-save.md
│   │   ├── document-and-save-to.md
│   │   ├── resume-from.md
│   │   ├── resume-latest.md
│   │   ├── sessions-list.md
│   │   └── discard-backup.md
│   ├── hooks/
│   │   ├── on-pre-compact.sh
│   │   ├── on-session-end.sh
│   │   └── on-session-start.sh
│   └── scripts/
│       └── discard-backup.sh
│
└── planning/sessions/
    ├── active-context.md    # Current session state (auto-loaded)
    ├── project-memory.md    # Permanent knowledge (auto-loaded)
    ├── session-*.md         # Archived session documents
    ├── raw/                 # Raw transcript backups
    └── .pending-backup      # Marker for unprocessed backup
```

## Testing

This system includes comprehensive tests using bashunit:

```bash
# Run all tests
./test/lib/bashunit test/

# Run specific test file
./test/lib/bashunit test/unit/session_start_test.sh

# Run with verbose output
./test/lib/bashunit --verbose test/
```

## Requirements

- **jq** - Required for JSON parsing in hooks and tests
  - macOS: `brew install jq`
  - Ubuntu/Debian: `sudo apt install jq`
  - Windows (Git Bash): Download from https://stedolan.github.io/jq/
- **bash** - Version 3.2+ (macOS default works)

## Documentation

- [Session Continuity Workflow](docs/session-continuity-workflow.md) - Full system documentation
- [Bash Testing Guide](docs/bash-testing-guide.md) - How to write tests for bash scripts
- [Version Control](docs/version-control.md) - Git workflow and commit conventions

## License

MIT
