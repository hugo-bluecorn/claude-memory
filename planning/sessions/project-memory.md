# Project Memory

Permanent knowledge about claude-memory that should persist across all sessions.

## Key Patterns

- **Update order matters**: Always update `active-context.md` FIRST, then full session document
- **Hooks are testable**: Use `HOOK_PROJECT_DIR` and `HOOK_SESSIONS_DIR` env vars for isolation
- **Graceful degradation**: Hooks exit 0 even on errors to avoid blocking Claude Code

## Architecture Decisions

- **File-based, single-instance**: All solutions must preserve this constraint
- **Opt-in recovery**: User controls when to restore context (not automatic)
- **Make compaction SAFE, not RARE**: Focus on reliable backups, not preventing compaction

## Known Gotchas

- PreCompact and SessionEnd both write to `.pending-backup` - **BUG: can overwrite each other**
- `on-pre-compact.sh` is less robust than `on-session-end.sh` - needs hardening
- SessionStart output goes to Claude context, not user terminal - user may miss it

## Important Context

- Competitive analysis: 13+ implementations analyzed in `research/similar-implementations.md`
- Implementation roadmap: 28 problems + solutions in `research/implementation-analysis.md`
- Post-fix positioning: "most capable file-based solution with unmatched reliability"
