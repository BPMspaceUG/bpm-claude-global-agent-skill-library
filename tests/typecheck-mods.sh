#!/usr/bin/env bash
# tests/typecheck-mods.sh - tsc --noEmit over every mod under my/mods/.
# A mod's tsconfig.json extends .claude-plugin/types/tsconfig.json, which
# Claude Code writes (git-ignored) when it loads the mod; without it the check
# fails and says how to get it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TSC=(npx -y -p typescript@5 tsc)
command -v npx >/dev/null 2>&1 || { echo "ERROR: npx (Node.js) is required for the mod type check." >&2; exit 2; }

rc=0
for cfg in "${REPO_ROOT}"/my/mods/*/tsconfig.json; do
  [ -e "${cfg}" ] || continue
  mod="$(dirname "${cfg}")"
  if [ ! -f "${mod}/.claude-plugin/types/tsconfig.json" ]; then
    echo "ERROR: ${mod#"${REPO_ROOT}"/} has no .claude-plugin/types/; start claude once with --plugin-dir ${mod} so Claude Code writes them." >&2
    rc=1
    continue
  fi
  if (cd "${mod}" && "${TSC[@]}" --noEmit -p tsconfig.json); then
    echo "ok ${mod#"${REPO_ROOT}"/}"
  else
    rc=1
  fi
done
exit "${rc}"
