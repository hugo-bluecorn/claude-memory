# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
  - Legacy `.pending-backup` still supported for backward compatibility
- PreCompact hook now skips empty transcript files (parity with SessionEnd)
- PreCompact hook validation and error handling improved

### Changed
- PreCompact hook refactored with structured input parsing
- `/resume-latest` now documents all three marker types

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
