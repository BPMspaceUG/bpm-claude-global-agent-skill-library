---
name: c-bpm-cm-library-pull
description: "Pull skills from repo — pull from repo, sync skills, update skills, download skills. Syncs c-bpm items (skills, agents, commands, runbooks) from Git repo to local ~/.claude/."
allowed-tools: Bash
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
