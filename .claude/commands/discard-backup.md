---
description: Discard pending session backup without restoring
---

# Discard Pending Backup

Run the discard-backup script to remove the pending session backup:

```bash
"$CLAUDE_PROJECT_DIR"/.claude/scripts/discard-backup.sh
```

After discarding, inform the user that the backup has been removed and they can continue with a fresh session.
