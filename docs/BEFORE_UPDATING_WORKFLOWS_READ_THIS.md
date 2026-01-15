# Before Updating Workflows - User Guide

This document captures lessons learned from the workflow integration audit of 2025-12-08.

## The Problem

Workflows developed independently can miss cross-dependencies. Claude reads CLAUDE.md's "ALWAYS follow" sections as the primary directive source. Rules documented elsewhere (like `version-control.md`) may not be enforced unless explicitly referenced.

## What To Say When Creating or Updating Workflows

### Minimum Request

When developing a new workflow or command, add this to your request:

> "Cross-reference this workflow with existing workflows and update CLAUDE.md if needed."

### Better Request

Be explicit about which workflows to check:

> "Verify this workflow integrates with:
> - CLAUDE.md (does it need an ALWAYS follow rule?)
> - version-control.md (git branching, commits, PRs)
> - session management commands (context preservation)"

### Best Request

Ask for the interaction check:

> "What other workflows does this interact with? Update both the new workflow AND any affected existing workflows to cross-reference each other."

## Checklist For Workflow Changes

When Claude creates or modifies a workflow, ask:

1. **CLAUDE.md Impact**: "Does this need an entry in the 'ALWAYS follow' section?"
2. **Bidirectional References**: "Do affected workflows reference each other?"
3. **Command Integration**: "Do any slash commands need updating?"
4. **Session Awareness**: "Should this be captured in session documentation?"

## Why This Matters

Claude prioritizes rules in this order:
1. CLAUDE.md "ALWAYS follow" sections (highest priority)
2. Linked documentation in CLAUDE.md
3. Individual workflow files
4. General knowledge

If a rule isn't in the "ALWAYS follow" section, it may be overlooked during execution even if documented elsewhere.

## Example: The Branch Oversight

**What happened:**
- `version-control.md` clearly stated "All work happens in feature branches"
- `/tdd-workflow` said "ensure you're on correct branch" (passive check)
- CLAUDE.md had commit rules but no branch rules
- Result: TDD work was committed directly to main

**The fix:**
- Added "Feature branches required" to CLAUDE.md "ALWAYS follow" section
- Updated `/tdd-workflow` to actively create branch, not just check
- Added gotcha to project-memory.md for institutional learning

**Prevention:**
- When `/tdd-workflow` was created, asking "Does this integrate with version-control.md branching rules?" would have caught the gap.

## Cross-References

This guide interacts with:

**Core Configuration:**
- **[version-control.md](./version-control.md)** - Git branching and commit rules

**Session Management Commands:**
- **[/document-and-save](../src/commands/document-and-save.md)** - Document session (default path)
- **[/document-and-save-to](../src/commands/document-and-save-to.md)** - Document session (custom path)
- **[/resume-from](../src/commands/resume-from.md)** - Resume specific session
- **[/resume-latest](../src/commands/resume-latest.md)** - Resume most recent session
- **[/sessions-list](../src/commands/sessions-list.md)** - Browse session logs
- **[/discard-backup](../src/commands/discard-backup.md)** - Discard pending backup

**Documentation:**
- **[session-continuity-workflow.md](./session-continuity-workflow.md)** - Full workflow docs
- **[bash-testing-guide.md](./bash-testing-guide.md)** - How to test bash scripts with bashunit
