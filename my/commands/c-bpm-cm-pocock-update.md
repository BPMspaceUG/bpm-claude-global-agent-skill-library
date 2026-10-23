---
name: c-bpm-cm-pocock-update
description: "Update Matt Pocock's skills plugin and unlock every skill for model invocation — pocock update, update pocock skills, unlock pocock skills, remove disable-model-invocation, pocock skills not callable. Checks upstream, runs the plugin update, then strips the invocation lock from every installed SKILL.md."
allowed-tools: Bash, Read
argument-hint: "[--check] [--no-update]"
---

# /c-bpm-cm-pocock-update — Update and unlock Matt Pocock's skills

Arguments passed by the user: $ARGUMENTS

## Why this command exists

Matt Pocock's plugin (`mattpocock-skills@mattpocock`) ships most of its skills
with `disable-model-invocation: true` in the SKILL.md frontmatter. Claude Code
then hides those skills from the model: the user can type `/to-spec`, but
Claude cannot call `to-spec`, `to-tickets`, `implement`, `implement-spec`,
`retro`, `triage`, `wayfinder`, `grill-me`, `ask-matt` or `grill-with-docs` on
its own. Rob's overnight flows (`c-bpm-cm-spec-oneshot`, `c-bpm-sk-gogo`) need
exactly these skills to be callable by the model.

Every plugin update overwrites the installed copies, so the unlock has to be
re-applied after each update. This command does both in one pass and is
idempotent: running it twice changes nothing the second time.

## What it never does

- It never edits the marketplace clone under `~/.claude/plugins/marketplaces/`
  (that is a git checkout; local edits would break the next refresh). Only the
  installed copy under `~/.claude/plugins/cache/…` is patched.
- It never changes anything in a SKILL.md other than removing the single
  `disable-model-invocation: true` line from the frontmatter.
- It never pins a model, version or commit anywhere.

## Procedure

Save the script below to a temporary file and run it with Bash, passing the
user's arguments through:

    bash /path/to/pocock-update.sh $ARGUMENTS

Then report the table it prints. Do not improvise around it. `--check` only
reports; `--no-update` skips the plugin update and only unlocks.

```bash
set -euo pipefail

PLUGIN="mattpocock-skills@mattpocock"
MANIFEST_URL="${POCOCK_MANIFEST_URL:-https://raw.githubusercontent.com/mattpocock/skills/main/.claude-plugin/plugin.json}"
INSTALLED_JSON="${HOME}/.claude/plugins/installed_plugins.json"
CHECK_ONLY=0; NO_UPDATE=0
for a in "$@"; do
  case "$a" in
    --check) CHECK_ONLY=1 ;;
    --no-update) NO_UPDATE=1 ;;
    *) echo "unknown argument: $a" >&2; exit 2 ;;
  esac
done

installed_field() { # <field>
  python3 -I - "$INSTALLED_JSON" "$PLUGIN" "$1" <<'PY'
import json, sys
path, plugin, field = sys.argv[1:4]
d = json.load(open(path))
entries = d.get("plugins", d).get(plugin, [])
print(entries[0].get(field, "") if entries else "")
PY
}

[ -f "$INSTALLED_JSON" ] || { echo "ERROR: $INSTALLED_JSON not found — install the plugin first: claude plugin install $PLUGIN" >&2; exit 1; }

BEFORE_VERSION="$(installed_field version)"
BEFORE_PATH="$(installed_field installPath)"
[ -n "$BEFORE_PATH" ] || { echo "ERROR: $PLUGIN is not installed — run: claude plugin install $PLUGIN" >&2; exit 1; }

UPSTREAM_VERSION="$(curl -fsSL "$MANIFEST_URL" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["version"])' || echo unknown)"

if [ "$CHECK_ONLY" -eq 1 ]; then
  LOCKED="$({ grep -rlE '^disable-model-invocation:[[:space:]]*true' "$BEFORE_PATH/skills" 2>/dev/null || true; } | wc -l)"
  printf '| Field | Value |\n|---|---|\n'
  printf '| installed version | %s |\n| upstream version | %s |\n| locked skills | %s |\n' "$BEFORE_VERSION" "$UPSTREAM_VERSION" "$LOCKED"
  exit 0
fi

UPDATE_RESULT="skipped (--no-update)"
if [ "$NO_UPDATE" -eq 0 ]; then
  UPDATE_LOG="$(mktemp -t pocock-update.XXXXXX.log)"
  if claude plugin update -y "$PLUGIN" >"$UPDATE_LOG" 2>&1; then
    UPDATE_RESULT="ok"
  else
    UPDATE_RESULT="failed — see $UPDATE_LOG"
  fi
fi

AFTER_VERSION="$(installed_field version)"
AFTER_PATH="$(installed_field installPath)"

UNLOCKED=()
while IFS= read -r f; do
  # Frontmatter only: delete the lock line between the first two '---' lines.
  python3 -I - "$f" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
m = re.match(r'^---\n(.*?)\n---\n', s, re.S)
if m:
    fm = re.sub(r'^disable-model-invocation:[ \t]*true[ \t]*\n', '', m.group(1) + "\n", flags=re.M)
    s = "---\n" + fm.rstrip("\n") + "\n---\n" + s[m.end():]
    open(p, "w", encoding="utf-8").write(s)
PY
  UNLOCKED+=("$(basename "$(dirname "$f")")")
done < <(grep -rlE '^disable-model-invocation:[[:space:]]*true' "$AFTER_PATH/skills" 2>/dev/null | sort)

REMAINING="$({ grep -rlE '^disable-model-invocation:[[:space:]]*true' "$AFTER_PATH/skills" 2>/dev/null || true; } | wc -l)"
TOTAL="$(find "$AFTER_PATH/skills" -name SKILL.md | wc -l)"

printf '| Field | Value |\n|---|---|\n'
printf '| version before | %s |\n' "$BEFORE_VERSION"
printf '| upstream version | %s |\n' "$UPSTREAM_VERSION"
printf '| plugin update | %s |\n' "$UPDATE_RESULT"
printf '| version after | %s |\n' "$AFTER_VERSION"
printf '| install path | %s |\n' "$AFTER_PATH"
printf '| skills total | %s |\n' "$TOTAL"
printf '| unlocked this run | %s |\n' "${#UNLOCKED[@]}"
printf '| still locked | %s |\n' "$REMAINING"
if [ "${#UNLOCKED[@]}" -gt 0 ]; then
  printf '\nUnlocked: %s\n' "${UNLOCKED[*]}"
fi
[ "$REMAINING" -eq 0 ] || { echo "ERROR: $REMAINING skill(s) still locked" >&2; exit 1; }
echo
echo "Restart Claude Code to load the updated plugin."
```

## Report

Print the table verbatim, then one line: whether a restart is needed (always
after `plugin update: ok` or `unlocked this run > 0`). Nothing else.

If `plugin update` failed, print the last 10 lines of the log file named in
the table and stop; do not retry with other flags. The unlock step still ran on the
currently installed version, so the table is still valid.
