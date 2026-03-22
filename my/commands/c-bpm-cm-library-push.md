---
name: c-bpm-cm-library-push
description: "Push skills to repo — push to repo, upload skills, save skills, publish skills. Syncs c-bpm items from local ~/.claude/ to Git repo. Auto-commits and pushes."
allowed-tools: Bash
argument-hint: "[--dry-run] [--force] [--clean] [--message msg] [--only-skills] [--verbose]"
---

# /c-bpm-cm-library-push — Push my-items from local to repo

Run the `c-bpm-cm-library-push` command to synchronise custom `my-` items from the local `~/.claude/` directory to the Git repository.

Pass any arguments the user provided via `$ARGUMENTS`.

```bash
c-bpm-cm-library-push $ARGUMENTS
```

After execution, summarise:
- How many items were new, modified, unchanged
- If items exist in the repo but not locally, mention them (manual cleanup needed)
- If `--dry-run` was used, note that no changes were made
- If errors occurred, suggest fixes
