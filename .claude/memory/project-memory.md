# Project Memory

Permanent knowledge about claude-memory that should persist across all sessions.

## Key Patterns

- **Update order matters**: Always update `active-context.md` FIRST, then full session document
- **Hooks are testable**: Use `HOOK_PROJECT_DIR` and `HOOK_SESSIONS_DIR` env vars for isolation
- **Graceful degradation**: Hooks exit 0 even on errors to avoid blocking Claude Code
- **Pre-commit sync**: Always sync `src/` to `.claude/` before committing (commands, hooks, scripts)

## Architecture Decisions

- **File-based, single-instance**: All solutions must preserve this constraint
- **Opt-in recovery**: User controls when to restore context (not automatic)
- **Make compaction SAFE, not RARE**: Focus on reliable backups, not preventing compaction
- **All Claude files in `.claude/`**: Memory lives at `.claude/memory/` to avoid conflicts with future Claude Code features

## Known Gotchas

- SessionStart output goes to Claude context, not user terminal - user may miss it
- Hook configurations are cached at session startup - changes require restart or `/hooks` menu
- **Windows**: Hook commands need `bash` prefix for variable expansion (already configured)

## Important Context

- Competitive analysis: 13+ implementations analyzed in `research/similar-implementations.md`
- Implementation roadmap: 28 problems + solutions in `research/implementation-analysis.md`
- Post-fix positioning: "most capable file-based solution with unmatched reliability"
