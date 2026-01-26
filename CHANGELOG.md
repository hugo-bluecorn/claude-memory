# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Remote install**: `setup_memory_management.sh` now fetches files from GitHub
  - Uses curl or wget (auto-detected)
  - Downloads 12 commands, 3 hooks, 2 scripts, and 2 templates
  - Validates downloaded files are non-empty
  - Exit codes: 3 (no HTTP client), 2 (download failure), 1 (target not found)
- `/fresh-start` command to clear session data and reset to clean state
  - Removes session documents, raw backups, and pending markers
  - Resets active-context.md to template
  - Preserves project-memory.md by default
- `/fresh-start-all` command for complete reset including project-memory
- `/coalesce` command for merging delta work into last session document
- "Last Session Doc" tracking in active-context.md for coalescing support
- Coalesce detection in `/resume-latest` (offers merge option when compact backup + last session doc exist)
- Session coalescing documentation in user manual and best practices
- `/context-stats` command for viewing session management statistics
- Session chaining: auto-detect and link to previous session in `/document-and-save`
- Best practices documentation (`docs/best-practices.md`)
- `/cleanup-backups` command for managing old raw transcript backups
- `/search-sessions` command for searching across session documents
- `--yes` flag for `/resume-latest` and `/resume-from` to skip confirmations
- Staleness detection for active-context.md (warns if >24h old, configurable via `HOOK_STALENESS_THRESHOLD`)
- Context overhead warning (warns if combined context files >20KB, configurable via `HOOK_OVERHEAD_THRESHOLD`)
- Timestamp header in active-context.md template (`> Last Updated:`)
- JSONL Format Reference section in `/resume-latest` command
- Extraction Strategy documentation for processing raw transcripts
- Multi-marker detection in SessionStart hook
- Debug logging capability in PreCompact hook (`HOOK_DEBUG=true`)
- Active context update on compaction events

### Fixed
- **BREAKING**: Backup marker conflict between PreCompact and SessionEnd hooks
  - PreCompact now uses `.pending-backup-compact`
  - SessionEnd now uses `.pending-backup-exit`
- PreCompact hook now skips empty transcript files (parity with SessionEnd)
- PreCompact hook validation and error handling improved
- **Windows compatibility**: Hook commands now use `bash` prefix for cross-platform support
  - Windows CMD/PowerShell doesn't expand `$VARIABLE` syntax
  - `bash "$CLAUDE_PROJECT_DIR/..."` ensures bash handles variable expansion

### Removed
- **BREAKING**: Legacy `.pending-backup` marker support removed
  - System now exclusively uses `.pending-backup-exit` and `.pending-backup-compact`
  - All references to legacy marker removed from hooks, scripts, commands, and tests

### Changed
- `/resume-latest` now prioritizes session documents over raw JSONL backups
  - When both exist, shows 3 options: load session doc + delta, load session doc only, or process backup
  - Session documents are the primary resumption source; raw backups are safety net for delta work
- **BREAKING**: Session storage moved from `planning/sessions/` to `.claude/memory/`
  - Context files: `.claude/memory/active-context.md`, `.claude/memory/project-memory.md`
  - Session documents: `.claude/memory/sessions/session-*.md`
  - Raw backups: `.claude/memory/raw/*.jsonl`
  - Keeps all Claude-related files together, avoids future naming conflicts
- `/document-and-save` now records session document path for coalescing support
- PreCompact hook refactored with structured input parsing
- `/resume-latest` now documents all three marker types and offers coalesce option

## [0.1.0] - 2026-01-15

### Added
- Initial release of claude-memory session management system
- SessionEnd hook for automatic transcript backup on exit
- PreCompact hook for backup before context compaction
- SessionStart hook for pending backup detection
- `/document-and-save` command for manual session documentation
- `/resume-latest` command for restoring most recent session
- `/resume-from` command for restoring specific sessions
- `/sessions-list` command for browsing available sessions
- `/discard-backup` command for discarding pending backups
- `setup_memory_management.sh` installation script
- Comprehensive bashunit test suite
