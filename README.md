# Claude Memory

A session continuity system for Claude Code that automatically preserves context across sessions.

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SESSION LIFECYCLE                                    │
└─────────────────────────────────────────────────────────────────────────────┘

   START SESSION              WORK                    END SESSION
        │                      │                           │
        ▼                      ▼                           ▼
  ┌───────────┐         ┌───────────┐              ┌───────────┐
  │ Session   │         │ PreCompact│              │ SessionEnd│
  │ Start     │         │ Hook      │              │ Hook      │
  │ Hook      │         │ (backup)  │              │ (backup)  │
  └─────┬─────┘         └─────┬─────┘              └─────┬─────┘
        │                     │                          │
        ▼                     ▼                          ▼
  ┌───────────┐         ┌───────────┐              ┌───────────┐
  │ Detect    │         │ Context   │              │ Create    │
  │ pending   │         │ saved to  │              │ backup    │
  │ backups   │         │ raw/      │              │ marker    │
  └─────┬─────┘         └───────────┘              └───────────┘
        │
        ▼
  ┌───────────────────┐
  │ /resume-latest    │
  │ to restore        │
  │ context           │
  └───────────────────┘
```

## What This Does

Claude Code sessions have limited context. When context fills up or you exit, valuable information can be lost. This system provides:

- **Automatic backups** - Hooks save raw transcripts when sessions end or auto-compact
- **Session documents** - Create structured summaries of your work with `/document-and-save`
- **Easy resumption** - Restore context with `/resume-latest` or `/resume-from`
- **Searchable history** - Find past work with `/search-sessions`
- **Permanent memory** - Store project knowledge in `project-memory.md`

## Quick Start

### Automatic Installation

Download and run the setup script in your project directory:

```bash
# Download the setup script (using curl)
curl -sSL https://raw.githubusercontent.com/hugo-bluecorn/claude-memory/master/setup_memory_management.sh -o setup_memory_management.sh

# Or using wget
wget -q https://raw.githubusercontent.com/hugo-bluecorn/claude-memory/master/setup_memory_management.sh

# Run it
bash setup_memory_management.sh .
```

The script automatically:
- Creates all directories and fetches all files
- Configures `.claude/settings.json` with hooks
- Adds session management to `.claude/CLAUDE.md`

Start a new Claude Code session to activate the hooks.

### Upgrading from Previous Versions

If you have an existing installation, re-run the setup script to update:

```bash
bash setup_memory_management.sh .
```

**Breaking Change (v0.2.0+):** All timestamps now use UTC with Z suffix. After upgrading:

1. Run `/fresh-start` to clear old session data with incompatible timestamp formats
2. Or manually delete old files:
   ```bash
   rm -rf .claude/memory/sessions/session-*.md
   rm -rf .claude/memory/raw/*.jsonl
   ```

The `active-context.md` and `project-memory.md` files are preserved. Update the `> Last Updated:` line in `active-context.md` to use the new format: `> Last Updated: YYYY-MM-DDTHH:MM:SSZ`

### Manual Installation

First clone the repository, then copy files to your project:

```bash
git clone https://github.com/hugo-bluecorn/claude-memory.git
cd claude-memory
```

1. Copy the files to your project:
   ```bash
   TARGET=/path/to/your/project

   # Create directories
   mkdir -p $TARGET/.claude/commands
   mkdir -p $TARGET/.claude/hooks
   mkdir -p $TARGET/.claude/scripts
   mkdir -p $TARGET/.claude/memory/raw
   mkdir -p $TARGET/.claude/memory/sessions

   # Copy files
   cp src/commands/*.md $TARGET/.claude/commands/
   cp src/hooks/*.sh $TARGET/.claude/hooks/
   cp src/scripts/*.sh $TARGET/.claude/scripts/
   cp src/templates/*.md $TARGET/.claude/memory/

   # Make scripts executable
   chmod +x $TARGET/.claude/hooks/*.sh
   chmod +x $TARGET/.claude/scripts/*.sh
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
               "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/on-pre-compact.sh\""
             }
           ]
         }
       ],
       "SessionStart": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/on-session-start.sh\""
             }
           ]
         }
       ],
       "SessionEnd": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/on-session-end.sh\""
             }
           ]
         }
       ]
     }
   }
   ```

   > **Note**: The `bash` prefix ensures cross-platform compatibility (required on Windows).

3. Add session management section to your `.claude/CLAUDE.md`:
   - Copy contents of `CLAUDE.md.snippet` and append to your CLAUDE.md

## Commands

| Command | Description |
|---------|-------------|
| `/document-and-save` | Save current session to `.claude/memory/sessions/session-YYYY-MM-DD-HHMMZ.md` (UTC) |
| `/document-and-save-to <path>` | Save session to a custom path |
| `/resume-latest` | Process pending backup or load most recent session |
| `/resume-from <path>` | Load a specific session document |
| `/coalesce` | Merge delta work from compaction into last session document |
| `/sessions-list` | Browse all available session logs |
| `/search-sessions <keyword>` | Search across session documents |
| `/cleanup-backups` | Delete old backups to free space |
| `/discard-backup` | Discard pending backup without processing |
| `/context-stats` | View session management statistics |
| `/fresh-start` | Clear session data, reset to clean state (keeps project-memory) |
| `/fresh-start-all` | Full reset including project-memory |

Use `--yes` flag with `/resume-latest` or `/resume-from` to skip confirmation prompts.

## How It Works

### Automatic Backup (Safety Net)

1. **Session End** - When you run `/exit` or close the terminal, `on-session-end.sh` saves the raw transcript to `.claude/memory/raw/`
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
└── .claude/
    ├── commands/
    │   ├── cleanup-backups.md
    │   ├── coalesce.md
    │   ├── context-stats.md
    │   ├── discard-backup.md
    │   ├── document-and-save.md
    │   ├── document-and-save-to.md
    │   ├── fresh-start.md
    │   ├── fresh-start-all.md
    │   ├── resume-from.md
    │   ├── resume-latest.md
    │   ├── search-sessions.md
    │   └── sessions-list.md
    ├── hooks/
    │   ├── on-pre-compact.sh
    │   ├── on-session-end.sh
    │   └── on-session-start.sh
    ├── scripts/
    │   ├── discard-backup.sh
    │   └── fresh-start.sh
    ├── memory/
    │   ├── active-context.md        # Current session state (auto-loaded)
    │   ├── project-memory.md        # Permanent knowledge (auto-loaded)
    │   ├── sessions/                # Archived session documents
    │   │   └── session-*.md
    │   └── raw/                     # Raw transcript backups
    └── settings.json
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

- **[User Manual](docs/user-manual.md)** - Complete guide with workflow diagrams
- **[Best Practices](docs/best-practices.md)** - Tips for effective usage
- [Session Continuity Workflow](docs/session-continuity-workflow.md) - Detailed system design
- [Bash Testing Guide](docs/bash-testing-guide.md) - How to write tests for bash scripts
- [Version Control](docs/version-control.md) - Git workflow and commit conventions

## License

MIT
