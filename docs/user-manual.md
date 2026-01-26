# Claude Memory User Manual

A session management system for Claude Code that provides persistent memory across sessions.

## Table of Contents

1. [Overview](#overview)
2. [Session Lifecycle](#session-lifecycle)
3. [File Structure](#file-structure)
4. [Commands Reference](#commands-reference)
5. [Hooks Reference](#hooks-reference)
6. [Quick Start](#quick-start)

---

## Overview

Claude Memory solves a fundamental problem: Claude Code sessions are ephemeral. When a session ends or context is compacted, valuable context is lost. This system provides:

- **Automatic backups** of raw transcripts when sessions end
- **Manual documentation** of sessions with rich context
- **Seamless restoration** of context in new sessions
- **Searchable history** of past work

### System Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLAUDE MEMORY SYSTEM                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                   │
│  │  SessionStart │    │  PreCompact  │    │  SessionEnd  │    HOOKS         │
│  │    Hook      │    │    Hook      │    │    Hook      │    (automatic)    │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                   │
│         │                   │                   │                            │
│         ▼                   ▼                   ▼                            │
│  ┌──────────────────────────────────────────────────────┐                   │
│  │              .claude/memory/                       │                   │
│  │  ┌─────────────────────┐  ┌─────────────────────┐    │                   │
│  │  │  active-context.md  │  │  project-memory.md  │    │   AUTO-LOADED    │
│  │  │  (current state)    │  │  (persistent info)  │    │   CONTEXT        │
│  │  └─────────────────────┘  └─────────────────────┘    │                   │
│  │                                                       │                   │
│  │  ┌─────────────────────────────────────────────┐     │                   │
│  │  │  session-YYYY-MM-DD-HHMMZ.md (UTC)          │     │   SESSION        │
│  │  │  (detailed session documents)               │     │   DOCUMENTS      │
│  │  └─────────────────────────────────────────────┘     │                   │
│  │                                                       │                   │
│  │  ┌─────────────────────────────────────────────┐     │                   │
│  │  │  raw/*.jsonl                                │     │   RAW            │
│  │  │  (automatic transcript backups)             │     │   BACKUPS        │
│  │  └─────────────────────────────────────────────┘     │                   │
│  └──────────────────────────────────────────────────────┘                   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────┐                   │
│  │                    COMMANDS (manual)                  │                   │
│  │  /document-and-save  /resume-latest  /search-sessions │                   │
│  │  /resume-from        /sessions-list  /cleanup-backups │                   │
│  │  /discard-backup     /context-stats  /coalesce        │                   │
│  │  /fresh-start        /fresh-start-all                 │                   │
│  └──────────────────────────────────────────────────────┘                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Session Lifecycle

### Complete Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SESSION LIFECYCLE WORKFLOW                           │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────┐
    │   START     │
    │   SESSION   │
    └──────┬──────┘
           │
           ▼
    ┌─────────────────────────────────────┐
    │         SessionStart Hook           │
    │  • Check for pending backups        │
    │  • Check context staleness (>24h)   │
    │  • Check context overhead (>20KB)   │
    └──────┬──────────────────────────────┘
           │
           ▼
    ┌─────────────────────────────────────┐
    │      Pending backup exists?         │
    └──────┬─────────────────┬────────────┘
           │ YES             │ NO
           ▼                 ▼
    ┌─────────────┐   ┌─────────────────┐
    │  /resume-   │   │  Continue with  │
    │   latest    │   │  auto-loaded    │
    │     OR      │   │  context        │
    │  /discard-  │   │                 │
    │   backup    │   │                 │
    └──────┬──────┘   └────────┬────────┘
           │                   │
           └─────────┬─────────┘
                     │
                     ▼
    ┌─────────────────────────────────────┐
    │                                     │
    │           WORK SESSION              │
    │                                     │
    │    • Claude assists with tasks      │
    │    • Context grows over time        │
    │    • TodoWrite tracks progress      │
    │                                     │
    └──────┬─────────────────┬────────────┘
           │                 │
           │ Context full    │ User ready to exit
           ▼                 │
    ┌─────────────────┐      │
    │  PreCompact     │      │
    │  Hook           │      │
    │  • Backup raw   │      │
    │    transcript   │      │
    │  • Create       │      │
    │    .pending-    │      │
    │    backup-      │      │
    │    compact      │      │
    └────────┬────────┘      │
             │               │
             ▼               │
    ┌─────────────────┐      │
    │  Context        │      │
    │  Compaction     │      │
    │  (automatic)    │      │
    └────────┬────────┘      │
             │               │
             └───────┬───────┘
                     │
                     ▼
    ┌─────────────────────────────────────┐
    │      Ready to end session?          │
    └──────┬─────────────────┬────────────┘
           │ YES             │ NO (continue)
           ▼                 │
    ┌─────────────────┐      │
    │  /document-     │      │
    │   and-save      │◄─────┘
    │  (recommended)  │
    │                 │
    │  • Update       │
    │    active-      │
    │    context.md   │
    │  • Create       │
    │    session doc  │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────────────────────────┐
    │          Exit Session               │
    │          (/exit, logout)            │
    └──────────────────┬──────────────────┘
                       │
                       ▼
    ┌─────────────────────────────────────┐
    │         SessionEnd Hook             │
    │  • Backup raw transcript            │
    │  • Create .pending-backup-exit      │
    │  • Update backup log                │
    └──────────────────┬──────────────────┘
                       │
                       ▼
    ┌─────────────────────────────────────┐
    │           SESSION ENDED             │
    │                                     │
    │  Next session will detect pending   │
    │  backup via SessionStart hook       │
    └─────────────────────────────────────┘
```

### Backup Flow Detail

```
                    BACKUP MARKER SYSTEM
    ═══════════════════════════════════════════════════════

    PreCompact Hook                    SessionEnd Hook
    (context getting full)             (session exit)
           │                                  │
           ▼                                  ▼
    ┌──────────────────┐              ┌──────────────────┐
    │ Copy transcript  │              │ Copy transcript  │
    │ to raw/          │              │ to raw/          │
    │ YYYYMMDD_HHMMSSZ_│              │ YYYYMMDD_HHMMSSZ_│
    │ compact.jsonl    │              │ <reason>.jsonl   │
    └────────┬─────────┘              └────────┬─────────┘
             │                                 │
             ▼                                 ▼
    ┌──────────────────┐              ┌──────────────────┐
    │ Create marker:   │              │ Create marker:   │
    │ .pending-backup- │              │ .pending-backup- │
    │ compact          │              │ exit             │
    └────────┬─────────┘              └────────┬─────────┘
             │                                 │
             └────────────┬────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │    Next Session       │
              │    SessionStart       │
              │                       │
              │  Detects marker(s)    │
              │  Outputs notification │
              │  to Claude context    │
              └───────────┬───────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │  User runs:           │
              │  • /resume-latest     │
              │    (process backup)   │
              │        OR             │
              │  • /discard-backup    │
              │    (delete backup)    │
              └───────────────────────┘
```

---

## File Structure

```
project/
└── .claude/
    ├── commands/               # Slash commands
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
    │
    ├── hooks/                  # Lifecycle hooks
    │   ├── on-pre-compact.sh
    │   ├── on-session-end.sh
    │   └── on-session-start.sh
    │
    ├── scripts/                # Utility scripts
    │   ├── discard-backup.sh
    │   └── fresh-start.sh
    │
    ├── memory/                 # Session data
    │   ├── active-context.md   # Current state (auto-loaded)
    │   ├── project-memory.md   # Persistent info (auto-loaded)
    │   ├── sessions/           # Session documents
    │   │   └── session-*.md
    │   └── raw/                # Raw transcript backups
    │       └── *.jsonl
    │
    └── settings.json           # Hook configuration
```

### File Purposes

| File | Purpose | Auto-loaded |
|------|---------|-------------|
| `active-context.md` | Current task, next steps, blockers | Yes |
| `project-memory.md` | Persistent project info, conventions | Yes |
| `session-*.md` | Detailed session documentation | No |
| `raw/*.jsonl` | Raw transcript backups | No |

---

## Commands Reference

### Session Documentation

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/document-and-save` | Save session with full context | Before ending a session |
| `/document-and-save-to <path>` | Save to custom location | Custom organization |

### Session Restoration

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/resume-latest` | Load most recent session | Starting a new session |
| `/resume-from <path>` | Load specific session | Continuing specific work |
| `--yes` flag | Skip confirmation prompts | Automated workflows |

### Session Discovery

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/sessions-list` | Browse available sessions | Finding past work |
| `/search-sessions <keyword>` | Search session content | Finding specific context |

### Session Coalescing

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/coalesce` | Merge delta work into last session doc | After compaction, when continuing same work |

### Maintenance

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/cleanup-backups` | Delete old backups | Freeing disk space |
| `/discard-backup` | Delete pending backup | Skipping restoration |
| `/context-stats` | View system statistics | Monitoring overhead |
| `/fresh-start` | Reset session state | Starting fresh (keeps project-memory) |
| `/fresh-start-all` | Full reset | Complete clean slate |

---

## Hooks Reference

### SessionStart Hook

**Triggers**: When a new Claude Code session begins

**Actions**:
1. Check for pending backup markers
2. Check if active-context.md is stale (>24h)
3. Check if context files exceed overhead threshold (>20KB)
4. Output notifications to Claude context

**Output Example**:
```
SESSION_BACKUP_PENDING (exit): Backup exists at raw/20260115_143000Z_prompt_input_exit.jsonl
User should run /resume-latest to restore context, or /discard-backup to discard.
CONTEXT_STALE: active-context.md is stale (last updated 48h ago). Consider running /document-and-save to update.
```

### PreCompact Hook

**Triggers**: Before Claude Code auto-compacts context

**Actions**:
1. Copy current transcript to `raw/YYYYMMDD_HHMMSSZ_compact.jsonl` (UTC)
2. Create `.pending-backup-compact` marker
3. Update backup log
4. Update active-context.md with compaction info

### SessionEnd Hook

**Triggers**: When session ends (exit, logout, clear)

**Actions**:
1. Copy current transcript to `raw/YYYYMMDD_HHMMSSZ_<reason>.jsonl` (UTC)
2. Create `.pending-backup-exit` marker
3. Update backup log
4. Update active-context.md with exit info

---

## Quick Start

### Installation

```bash
# Download the setup script (using curl)
curl -sSL https://raw.githubusercontent.com/hugo-bluecorn/claude-memory/master/setup_memory_management.sh -o setup_memory_management.sh

# Or using wget
wget -q https://raw.githubusercontent.com/hugo-bluecorn/claude-memory/master/setup_memory_management.sh

# Run it in your project directory
bash setup_memory_management.sh /path/to/your/project
```

The script automatically configures `.claude/settings.json` and `.claude/CLAUDE.md`.
Start a new Claude Code session to activate the hooks.

### Daily Workflow

```
1. START SESSION
   └─► SessionStart notifies you of pending backups
       └─► Run /resume-latest if notified

2. WORK
   └─► Claude assists with your tasks
   └─► Context is automatically backed up if compacted
   └─► IMPORTANT: Periodically run /context to check usage (see below)

3. END SESSION
   └─► Run /document-and-save (recommended)
   └─► Exit normally - SessionEnd backs up transcript

4. NEXT SESSION
   └─► SessionStart detects pending backup
   └─► Run /resume-latest to restore context
```

### Session Coalescing (Delta Work)

If you run `/document-and-save` and then continue working before compaction occurs:

```
1. /document-and-save at T=0
   └─► Creates session-2026-01-15-1800Z.md
   └─► Records "Last Session Doc" in active-context.md

2. Continue working...
   └─► More changes, decisions, progress

3. PreCompact triggers at T=5 (context full)
   └─► Backs up transcript to raw/YYYYMMDD_HHMMSSZ_compact.jsonl
   └─► Context is compacted

4. After compaction, /resume-latest detects:
   └─► Pending compact backup exists
   └─► Last Session Doc is set
   └─► Offers: /coalesce OR process as new session

5. Run /coalesce
   └─► Merges delta work into session-2026-01-15-1800Z.md
   └─► Adds "Session Continuation" section
   └─► Cleans up backup marker
```

**When to use `/coalesce`**: When you want to keep related work in a single session document
rather than creating multiple session files for the same logical work session.

### Proactive Context Monitoring

**Critical**: Claude cannot see token usage - only you can check this by running `/context`.

```
⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁   85k/200k tokens (43%)
⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁ ⛁   ⛁ Messages: 65.8k (32.9%)      ◄── Watch this
⛁ ⛁ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶   ⛶ Free space: 70k (34.8%)
⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶   ⛝ Autocompact buffer: 45k     ◄── Danger zone
```

**When to run `/document-and-save`**:
- When **Messages** reaches 60-70% of total capacity
- When **Free space** approaches the autocompact buffer
- Before long breaks or end of day

**Why this matters**: The PreCompact hook backs up the raw transcript automatically, but
proactive `/document-and-save` creates cleaner, structured documentation with your input
on what's important. Don't rely solely on the safety net.

### First-Time Setup Checklist

- [ ] Run `setup_memory_management.sh` on your project
- [ ] Merge `settings-hooks.json` into `.claude/settings.json`
- [ ] Add session management imports to your `CLAUDE.md`
- [ ] Create initial `active-context.md` with current project state
- [ ] Create `project-memory.md` with persistent project info

---

## Troubleshooting

See [Best Practices](best-practices.md#troubleshooting) for common issues and solutions.

---

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `HOOK_STALENESS_THRESHOLD` | 86400 (24h) | Seconds before context is stale |
| `HOOK_OVERHEAD_THRESHOLD` | 20480 (20KB) | Bytes before overhead warning |
| `HOOK_DEBUG` | false | Enable debug logging |
| `HOOK_PROJECT_DIR` | (auto) | Override project directory |
| `HOOK_SESSIONS_DIR` | (auto) | Override sessions directory |
