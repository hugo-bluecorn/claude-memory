---
description: Clean up old backup files in .claude/memory/raw/
---

# Cleanup Backups

Remove old raw transcript backups from `.claude/memory/raw/` to free up disk space.

## Usage

```
/cleanup-backups [options]
```

## Options

| Option | Description |
|--------|-------------|
| `--older-than <days>` | Delete backups older than N days (default: 30) |
| `--keep-last <n>` | Keep at least the N most recent backups (default: 5) |
| `--dry-run` | Show what would be deleted without actually deleting |

## Steps

### 1. List All Backup Files

Find all `.jsonl` files in `.claude/memory/raw/`:

```bash
ls -la .claude/memory/raw/*.jsonl 2>/dev/null
```

If no backups exist, inform the user and exit.

### 2. Parse Timestamps

Extract timestamps from filenames. Backup files follow the pattern:
- `YYYYMMDD_HHMMSS_<reason>.jsonl` (from SessionEnd)
- `YYYYMMDD_HHMMSS_compact.jsonl` (from PreCompact)

### 3. Apply Filters

**Filter by age** (if `--older-than` specified):
- Calculate the cutoff date
- Mark files older than cutoff for deletion

**Ensure minimum retention** (always apply `--keep-last`):
- Sort files by timestamp (newest first)
- Ensure at least N files are kept, even if they're older than cutoff

### 4. Show Summary

Display what will be deleted:

```
Found 15 backup files total.
Will delete 10 backups (older than 30 days):
  - 20251201_143022_prompt_input_exit.jsonl (45 days old, 1.2 MB)
  - 20251205_091500_compact.jsonl (41 days old, 0.8 MB)
  ...

Keeping 5 most recent backups.
Total to delete: 8.5 MB

Proceed with deletion? [y/N]
```

### 5. Execute Deletion

If user confirms (or `--dry-run` not specified and user confirms):

```bash
rm .claude/memory/raw/<filename>.jsonl
```

Report results:
```
Deleted 10 backup files (8.5 MB freed).
Remaining: 5 backup files.
```

### 6. Clean Up Stale Markers

After deletion, check if any pending backup markers point to deleted files:

```bash
# Check each marker
for marker in .pending-backup-compact .pending-backup-exit .pending-backup; do
  if [[ -f ".claude/memory/$marker" ]]; then
    backup_path=$(cat ".claude/memory/$marker")
    if [[ ! -f "$backup_path" ]]; then
      rm ".claude/memory/$marker"
      echo "Cleaned up stale marker: $marker"
    fi
  fi
done
```

## Examples

```bash
# Show what would be deleted (dry run)
/cleanup-backups --dry-run

# Delete backups older than 7 days, keep at least 3
/cleanup-backups --older-than 7 --keep-last 3

# Delete backups older than 14 days (default keep-last 5)
/cleanup-backups --older-than 14

# Use defaults (30 days, keep 5)
/cleanup-backups
```

## Safety Notes

- **Always keeps minimum backups**: Even with aggressive settings, at least `--keep-last` backups are preserved
- **Dry run recommended**: Use `--dry-run` first to see what would be deleted
- **No undo**: Deleted backups cannot be recovered
- **Pending backups protected**: Current pending backups (referenced by markers) are never deleted

---

## Cross-References

- **[/resume-latest](resume-latest.md)** - Uses raw backups for context restoration
- **[/sessions-list](sessions-list.md)** - Browse session documents (not affected by cleanup)
