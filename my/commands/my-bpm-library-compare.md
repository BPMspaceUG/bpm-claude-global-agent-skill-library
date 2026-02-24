---
allowed-tools: Bash, Read, Glob, Grep
description: Compare local my-bpm items with the Git repository and show differences. Optionally repair (pull missing, push missing) after user confirmation.
---

# /my-bpm-library-compare — Compare local vs repo inventory

Compare which `my-bpm-*` items exist locally (`~/.claude/`) vs in the Git repository (`~/bpm-claude-global-agent-skill-library/my/`), and which have content differences.

## Step 1: Git pull (read-only, no local changes)

```bash
cd ~/bpm-claude-global-agent-skill-library && git pull --ff-only
```

## Step 2: Compare all categories

For each category (skills, commands, agents, runbooks), run:

```bash
REPO="$HOME/bpm-claude-global-agent-skill-library"
LOCAL="$HOME/.claude"
HOST=$(hostname)

echo "=== Host: $HOST ==="
echo ""

for cat in skills commands agents runbooks; do
  echo "--- $cat ---"
  REPO_DIR="$REPO/my/$cat"
  LOCAL_DIR="$LOCAL/$cat"

  # Get lists (skills = directories, rest = files)
  if [ "$cat" = "skills" ]; then
    REPO_LIST=$(ls "$REPO_DIR/" 2>/dev/null | grep '^my-bpm-' | sort)
    LOCAL_LIST=$(ls "$LOCAL_DIR/" 2>/dev/null | grep '^my-bpm-' | sort)
  else
    REPO_LIST=$(ls "$REPO_DIR/" 2>/dev/null | grep '^my-bpm-.*\.md$' | sort)
    LOCAL_LIST=$(ls "$LOCAL_DIR/" 2>/dev/null | grep '^my-bpm-.*\.md$' | sort)
  fi

  REPO_COUNT=$(echo "$REPO_LIST" | grep -c . 2>/dev/null || echo 0)
  LOCAL_COUNT=$(echo "$LOCAL_LIST" | grep -c . 2>/dev/null || echo 0)

  # Items in repo but not local
  MISSING_LOCAL=$(comm -23 <(echo "$REPO_LIST") <(echo "$LOCAL_LIST"))
  # Items local but not in repo
  MISSING_REPO=$(comm -13 <(echo "$REPO_LIST") <(echo "$LOCAL_LIST"))

  # Content differences (items that exist in both)
  BOTH=$(comm -12 <(echo "$REPO_LIST") <(echo "$LOCAL_LIST"))
  CONTENT_DIFF=""
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    if [ "$cat" = "skills" ]; then
      diff -rq "$REPO_DIR/$item" "$LOCAL_DIR/$item" >/dev/null 2>&1 || CONTENT_DIFF="$CONTENT_DIFF  $item"$'\n'
    else
      diff -q "$REPO_DIR/$item" "$LOCAL_DIR/$item" >/dev/null 2>&1 || CONTENT_DIFF="$CONTENT_DIFF  $item"$'\n'
    fi
  done <<< "$BOTH"

  if [ -z "$MISSING_LOCAL" ] && [ -z "$MISSING_REPO" ] && [ -z "$CONTENT_DIFF" ]; then
    echo "  SYNC ($LOCAL_COUNT/$REPO_COUNT)"
  else
    echo "  Repo: $REPO_COUNT | Lokal: $LOCAL_COUNT"
    [ -n "$MISSING_LOCAL" ] && echo "  Fehlt lokal (pull needed):" && echo "$MISSING_LOCAL" | sed 's/^/    /'
    [ -n "$MISSING_REPO" ] && echo "  Fehlt im Repo (push needed):" && echo "$MISSING_REPO" | sed 's/^/    /'
    [ -n "$CONTENT_DIFF" ] && echo "  Inhalt unterschiedlich:" && echo "$CONTENT_DIFF"
  fi
  echo ""
done
```

## Step 3: Show host inventories

```bash
echo "=== Host-Inventories im Repo ==="
for hostdir in "$REPO/my/hosts"/*/; do
  [ -d "$hostdir" ] || continue
  h=$(basename "$hostdir")
  sk=$(grep -c '^my-bpm-' "$hostdir/skills.txt" 2>/dev/null || echo 0)
  cm=$(grep -c '^my-bpm-' "$hostdir/commands.txt" 2>/dev/null || echo 0)
  ag=$(grep -c '^my-bpm-' "$hostdir/agents.txt" 2>/dev/null || echo 0)
  ts=$(grep '^# Updated:' "$hostdir/skills.txt" 2>/dev/null | head -1 | cut -d' ' -f3-)
  echo "  $h: $sk skills, $cm commands, $ag agents (Stand: $ts)"
done
```

## Step 4: Present results as a table

Show the user a clear summary table with all categories and their sync status.

## Step 5: Repair (ONLY if differences found)

If there are differences, ask the user:

> **Soll ich die Unterschiede reparieren?**
> - `pull` — Fehlende lokal nachholen (Repo gewinnt)
> - `push` — Fehlende ins Repo pushen (Lokal gewinnt)
> - `both` — Beides (pull first, then push)
> - `nein` — Nichts tun

Based on the user's answer:
- `pull`: Run `my-bpm-library-pull`
- `push`: Run `my-bpm-library-push`
- `both`: Run `my-bpm-library-pull` then `my-bpm-library-push`
- `nein`: Do nothing

For content differences, always ask which version should win before overwriting.
