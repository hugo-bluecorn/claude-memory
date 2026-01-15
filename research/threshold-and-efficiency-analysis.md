# Analysis: Compaction Threshold & Token Efficiency

> **Questions Analyzed**:
> 1. Should the system's threshold be lower since it consumes tokens itself?
> 2. Is token efficiency a must-have feature?

---

## Concern 1: Compaction Threshold and System Overhead

### Understanding the Current Situation

**How Claude Code's Compaction Works:**
```
Session Start
     │
     ▼
┌─────────────────────────────────────────┐
│  Context Window (~200K tokens)          │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ Auto-loaded context:            │    │  ◄── Loaded at START
│  │ • CLAUDE.md                     │    │
│  │ • @imported files               │    │
│  │   - active-context.md           │    │
│  │   - project-memory.md           │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ Conversation context:           │    │  ◄── Grows during session
│  │ • User messages                 │    │
│  │ • Assistant responses           │    │
│  │ • Tool calls & results          │    │
│  └─────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
     │
     ▼
  When total reaches threshold (75-90%)
     │
     ▼
  PreCompact hook fires → Compaction occurs
```

**Key Insight**: The memory system's files are loaded at session start and count AGAINST the context budget from the very beginning.

### The Math

**Claude Code Context Budget:**
- Claude Sonnet: ~200,000 tokens
- Auto-compact threshold: varies (was 90%, now often 75%)

**Assume 75% threshold (conservative):**
```
Total available before compact: 200K × 0.75 = 150,000 tokens
```

**Memory System Overhead (typical):**

| File | Typical Size | Tokens (~4 chars/token) |
|------|-------------|-------------------------|
| CLAUDE.md (base) | 2 KB | ~500 tokens |
| CLAUDE.md.snippet | 3 KB | ~750 tokens |
| active-context.md | 1-4 KB | 250-1,000 tokens |
| project-memory.md | 1-4 KB | 250-1,000 tokens |
| **Total Overhead** | **7-13 KB** | **1,750-3,250 tokens** |

**Impact Analysis:**
```
Scenario: 75% threshold, 3,000 token overhead

Available for work: 150,000 - 3,000 = 147,000 tokens
Overhead percentage: 3,000 / 150,000 = 2%

Scenario: 75% threshold, 10,000 token overhead (large files)

Available for work: 150,000 - 10,000 = 140,000 tokens
Overhead percentage: 10,000 / 150,000 = 6.7%
```

### The Real Problem

The issue isn't the absolute overhead (2-7% is manageable). The problem is:

1. **No visibility**: Users don't know how much overhead they're paying
2. **No limits**: Files can grow unbounded
3. **No warnings**: No alert when overhead becomes excessive
4. **Compounding effect**: Large overhead + large codebase = faster compaction

### What We CAN'T Control

Claude Code controls when compaction happens. We cannot:
- Change the threshold percentage
- Delay compaction
- Request more context

The PreCompact hook is **reactive** - it fires WHEN Claude Code decides to compact, not before.

### What We CAN Control

1. **Size of auto-loaded files** - Keep them small
2. **User awareness** - Show overhead stats
3. **Warnings** - Alert when files are too large
4. **Best practices** - Educate on keeping context lean

### Recommended Actions

#### Action 1: Add Context Overhead Tracking (High Priority)

**Enhancement to `/context-stats` command:**
```markdown
# Context Stats

## Auto-Loaded Overhead
| File | Size | Est. Tokens |
|------|------|-------------|
| CLAUDE.md | 2.1 KB | ~525 |
| active-context.md | 3.4 KB | ~850 |
| project-memory.md | 1.8 KB | ~450 |
| **Total** | **7.3 KB** | **~1,825** |

## Budget Impact (assuming 75% threshold)
- Total budget: 150,000 tokens
- Overhead: 1,825 tokens (1.2%)
- Available for work: 148,175 tokens

## Recommendation
✓ Overhead is within recommended limits (<5%)
```

#### Action 2: Add Size Warnings to SessionStart Hook

**Enhancement to `on-session-start.sh`:**
```bash
# Check overhead size
OVERHEAD_TOKENS=0
for file in "$SESSIONS_DIR/active-context.md" "$SESSIONS_DIR/project-memory.md"; do
  if [[ -f "$file" ]]; then
    size=$(wc -c < "$file")
    tokens=$((size / 4))
    OVERHEAD_TOKENS=$((OVERHEAD_TOKENS + tokens))
  fi
done

# Warn if overhead exceeds 5000 tokens (~3% of typical budget)
if [[ $OVERHEAD_TOKENS -gt 5000 ]]; then
  echo "WARNING: Auto-loaded context is large (~$OVERHEAD_TOKENS tokens)"
  echo "Consider condensing active-context.md or project-memory.md"
fi
```

#### Action 3: Add Recommended Limits to Best Practices

**Add to `docs/best-practices.md`:**
```markdown
## Context Overhead Guidelines

Keep auto-loaded files small to maximize working context:

| File | Recommended Max | Tokens |
|------|-----------------|--------|
| active-context.md | 2 KB | ~500 |
| project-memory.md | 4 KB | ~1,000 |
| **Total overhead** | **<10 KB** | **<2,500** |

If your files exceed these limits:
1. Archive old content to session documents
2. Summarize verbose sections
3. Move rarely-needed info to project-memory.md (load on demand)
```

#### Action 4: Consider "Early Warning" Hook (Future Enhancement)

Since we can't control WHEN compaction happens, we could add a UserPromptSubmit hook that estimates remaining context and warns proactively:

```bash
# Hypothetical: on-prompt-submit.sh
# Check if context is getting full and suggest /document-and-save

# This would require Claude Code to provide context usage in hook input
# Currently not available in hook API
```

**Limitation**: Claude Code's hook API doesn't currently expose context usage. This would require a feature request to Anthropic.

### Conclusion on Threshold

**The 98% vs 90% vs 75% question is moot** - we don't control when Claude Code compacts. Our job is to:

1. ✅ **Minimize overhead** - Keep auto-loaded files small
2. ✅ **Provide visibility** - `/context-stats` command
3. ✅ **Warn proactively** - SessionStart overhead check
4. ✅ **Educate users** - Best practices documentation
5. ✅ **Backup reliably** - PreCompact hook already does this

---

## Concern 2: Is Token Efficiency a Must-Have Feature?

### Defining Token Efficiency

Token efficiency mechanisms reduce how much context is consumed for the same functionality:

| Mechanism | How It Works | Savings |
|-----------|--------------|---------|
| Progressive disclosure | Show metadata first, details on demand | ~10x (claude-mem) |
| Attention tiers | HOT/WARM/COLD based on relevance | 64-95% (claude-cognitive) |
| TLDR analysis | AST summaries instead of raw code | 95% (Continuous-Claude) |
| Haiku subagent | Summarize before injecting | Varies (episodic-memory) |
| Quantization | Compress embeddings | 4-32x (claude-flow) |

### Who Needs Token Efficiency?

**Users who NEED it:**
```
┌─────────────────────────────────────────────────────────────────┐
│ HIGH NEED for token efficiency:                                 │
│                                                                 │
│ • Working on codebases >500K lines                              │
│ • Sessions lasting 4+ hours                                     │
│ • Complex multi-file refactoring                                │
│ • Need to load extensive context upfront                        │
│ • Frequent "context full" interruptions                         │
│ • Cost-sensitive (API billing)                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Users who DON'T need it:**
```
┌─────────────────────────────────────────────────────────────────┐
│ LOW NEED for token efficiency:                                  │
│                                                                 │
│ • Working on small-medium projects (<100K lines)                │
│ • Sessions naturally break at 1-2 hours                         │
│ • Focused, single-feature work                                  │
│ • OK with occasional compaction (have good backups)             │
│ • Value simplicity over optimization                            │
│ • Using Claude Code (not API, so no direct billing)             │
└─────────────────────────────────────────────────────────────────┘
```

### claude-memory's Target Users

Based on our positioning analysis, claude-memory targets users who value:

| Value | Implication for Token Efficiency |
|-------|----------------------------------|
| **Reliability** | Backups matter more than preventing compaction |
| **Transparency** | Understanding what's stored > automatic optimization |
| **Control** | Manual management acceptable |
| **Simplicity** | Complexity of efficiency mechanisms unwanted |
| **Version control** | Files must be human-readable, not optimized binary |

### Analysis: Must-Have vs Nice-to-Have

#### Arguments FOR Token Efficiency Being Must-Have

| Argument | Counter-Argument |
|----------|------------------|
| Large codebases need it | Those users should use claude-mem or Continuous-Claude |
| Long sessions hit limits | Backup system handles compaction safely |
| Frequent compaction is disruptive | Compaction is now "instant" in recent Claude Code versions |
| Competitors offer it | We compete on reliability, not features |
| Users pay for tokens | Claude Code users don't pay per-token (subscription) |

#### Arguments AGAINST Token Efficiency Being Must-Have

| Argument | Supporting Evidence |
|----------|---------------------|
| Context windows are large | 200K tokens is substantial |
| Most sessions don't hit limits | Typical sessions are 1-2 hours |
| Compaction is now instant | Claude Code v2.0.64+ |
| Simplicity has value | Our target users explicitly prefer it |
| Efficiency adds complexity | Progressive disclosure requires understanding 3-layer model |
| Our backup system handles it | PreCompact hook ensures no data loss |

### The Verdict

**Token efficiency is NOT a must-have for claude-memory's target users.**

Rationale:
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  claude-memory's philosophy:                                    │
│                                                                 │
│  "Make compaction SAFE, not RARE"                               │
│                                                                 │
│  Instead of:                                                    │
│  • Complex mechanisms to delay compaction                       │
│  • Automatic context pruning                                    │
│  • Tiered loading systems                                       │
│                                                                 │
│  We provide:                                                    │
│  • Reliable backups before compaction (PreCompact hook)         │
│  • Easy recovery after compaction (/resume-latest)              │
│  • Visibility into overhead (/context-stats)                    │
│  • Education on keeping context lean (best practices)           │
│                                                                 │
│  Users who need aggressive token efficiency should use:         │
│  • claude-mem (progressive disclosure)                          │
│  • claude-cognitive (attention tiers)                           │
│  • Continuous-Claude (TLDR analysis)                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### What We SHOULD Do (Instead of Token Efficiency)

#### 1. Provide Visibility (Already Proposed)
- `/context-stats` shows overhead
- SessionStart warns if overhead is large

#### 2. Encourage Small Files
- Best practices with size limits
- Templates that are minimal by default

#### 3. Enable Manual Optimization
- `/context-stats` helps users decide when to trim
- Session documents allow selective loading (future: partial loading)

#### 4. Document the Trade-off
- Clear messaging: "We make compaction safe, not rare"
- Point users who need efficiency to alternatives

### Potential Future Enhancement (Optional)

If user feedback strongly requests it, a **lightweight** efficiency feature could be:

**Selective Section Loading:**
```markdown
# /resume-from --sections "Failed Approaches,Key Decisions"

Load only specific sections from a session document instead of everything.
```

This provides some efficiency without the complexity of progressive disclosure or attention systems.

---

## Summary & Recommendations

### On Compaction Threshold

| Finding | Recommendation |
|---------|----------------|
| We can't control Claude Code's threshold | Accept this limitation |
| Auto-loaded files consume overhead | Keep them small (<10KB total) |
| Users lack visibility | Add `/context-stats` command |
| No proactive warnings | Add overhead check to SessionStart |
| No guidelines exist | Add best practices documentation |

### On Token Efficiency

| Finding | Recommendation |
|---------|----------------|
| Not a must-have for target users | Do not implement complex efficiency mechanisms |
| Visibility is valuable | Implement `/context-stats` |
| Small files help | Add size recommendations |
| Alternative systems exist | Document when users should consider claude-mem et al. |
| Future option exists | Consider selective section loading if requested |

### Updated Philosophy Statement

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  claude-memory's approach to context management:                │
│                                                                 │
│  We don't try to PREVENT compaction.                            │
│  We make compaction SAFE and RECOVERABLE.                       │
│                                                                 │
│  • PreCompact hook ensures backup before compaction             │
│  • /resume-latest restores context after compaction             │
│  • /context-stats provides visibility into overhead             │
│  • Best practices guide users on keeping context lean           │
│                                                                 │
│  For users who need aggressive token optimization:              │
│  → Consider claude-mem, claude-cognitive, or Continuous-Claude  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Action Items

### High Priority
1. ✅ Add `/context-stats` command (already in proposed fixes)
2. 🆕 Add overhead warning to SessionStart hook
3. 🆕 Add size limits to best practices documentation

### Medium Priority
4. 🆕 Update CLAUDE.md.snippet with size guidelines
5. 🆕 Add "when to use alternatives" section to README

### Low Priority (Future)
6. 🆕 Consider selective section loading command
7. 🆕 Feature request to Anthropic for context usage in hook API
