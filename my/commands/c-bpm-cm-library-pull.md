---
allowed-tools: Bash
description: Pull my-prefixed items (skills, agents, commands, runbooks) from the Git repository to local ~/.claude/. Supports --dry-run, --only-skills, --only-agents, --only-commands, --only-runbooks, --verbose.
argument-hint: "[--dry-run] [--force] [--clean] [--only-skills] [--verbose]"
---

# /c-bpm-cm-library-pull — Pull my-items from repo to local

Run the `c-bpm-cm-library-pull` command to synchronise custom `my-` items from the Git repository to the local `~/.claude/` directory.

Pass any arguments the user provided via `$ARGUMENTS`.

```bash
c-bpm-cm-library-pull $ARGUMENTS
```

After execution, summarise:
- How many items were new, modified, unchanged
- If `--dry-run` was used, note that no changes were made
- If errors occurred, suggest fixes (e.g., "run `git pull` in the repo first")
