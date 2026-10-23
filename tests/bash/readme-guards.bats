#!/usr/bin/env bats
#
# readme-guards.bats — drift guards for README.md (Issue #123, trimmed 2026-10-23)
# Run with: bats tests/bash/readme-guards.bats
#
# The README is the entry point a new machine reads before it has any local
# context. These guards keep it honest: every referenced item, CLI and flag
# must exist, no model version may be pinned (Issue #98), external links open
# in a new tab, the prose is English, and the install/update facts stay.
#
#   NOTE: the model-pin regex below intentionally spells out "gpt-5"/"opus-4".
#   This file lives under tests/ (outside my/), so it does not trip the
#   acceptance grep over my/ from Issue #98.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
README="${REPO_ROOT}/README.md"

# Emit the README with fenced code blocks removed (prose only).
readme_prose() {
  awk '/^[[:space:]]*```/ { f = !f; next } !f' "${README}"
}

# Emit only the lines inside fenced code blocks.
readme_fences() {
  awk '/^[[:space:]]*```/ { f = !f; next } f' "${README}"
}

# ------------------------------------------------------------------
# 1: the five required top-level sections exist
# ------------------------------------------------------------------

@test "README has the five required top-level sections" {
  [ -f "${README}" ] || { printf 'README.md not found at %s\n' "${README}" >&2; return 1; }
  local missing=0 h
  for h in \
    '## 1. What This Is' \
    '## 2. Installation' \
    '## 3. Items' \
    '## 4. Testing' \
    '## 5. Maintenance'
  do
    if ! grep -qF -- "${h}" "${README}"; then
      printf 'Missing required README section heading: %s\n' "${h}" >&2
      missing=1
    fi
  done
  return "${missing}"
}

# ------------------------------------------------------------------
# 2: every c-bpm-* item the README names actually exists
# ------------------------------------------------------------------

@test "every c-bpm-* item referenced in README exists on disk" {
  local bad=0 tok
  for tok in $(grep -oE 'c-bpm-(sk|cm|ag)-[a-z0-9-]+(\.bats)?' "${README}" | sed 's/-*$//' | sort -u); do
    case "${tok}" in
      *.bats)
        [ -f "${REPO_ROOT}/tests/bash/${tok}" ] || {
          printf 'README references test %s but tests/bash/%s does not exist\n' "${tok}" "${tok}" >&2; bad=1; }
        ;;
      c-bpm-sk-*)
        [ -f "${REPO_ROOT}/my/skills/${tok}/SKILL.md" ] || {
          printf 'README references skill %s but my/skills/%s/SKILL.md does not exist\n' "${tok}" "${tok}" >&2; bad=1; }
        ;;
      c-bpm-cm-*)
        if [ ! -f "${REPO_ROOT}/my/commands/${tok}.md" ] && [ ! -f "${REPO_ROOT}/${tok}" ]; then
          printf 'README references command %s but neither my/commands/%s.md nor ./%s exists\n' "${tok}" "${tok}" "${tok}" >&2
          bad=1
        fi
        ;;
      c-bpm-ag-*)
        [ -f "${REPO_ROOT}/my/agents/${tok}.md" ] || {
          printf 'README references agent %s but my/agents/%s.md does not exist\n' "${tok}" "${tok}" >&2; bad=1; }
        ;;
    esac
  done
  return "${bad}"
}

@test "every item under my/ is named in the README" {
  local bad=0 f name
  for f in "${REPO_ROOT}"/my/commands/c-bpm-cm-*.md; do
    name="$(basename "${f}" .md)"
    grep -qF -- "${name}" "${README}" || { printf 'README does not mention command %s\n' "${name}" >&2; bad=1; }
  done
  for f in "${REPO_ROOT}"/my/skills/c-bpm-sk-*/SKILL.md; do
    name="$(basename "$(dirname "${f}")")"
    grep -qF -- "${name}" "${README}" || { printf 'README does not mention skill %s\n' "${name}" >&2; bad=1; }
  done
  return "${bad}"
}

@test "every test file named in the README exists" {
  local bad=0 t
  for t in $(grep -oE '[a-z0-9-]+\.bats' "${README}" | sort -u); do
    [ -f "${REPO_ROOT}/tests/bash/${t}" ] || { printf 'README names tests/bash/%s but it does not exist\n' "${t}" >&2; bad=1; }
  done
  return "${bad}"
}

@test "every root CLI referenced in README exists and is executable" {
  local bad=0 cli
  for cli in bcgasl install sync; do
    if grep -qE "(^|[^a-z-])${cli}([^a-z-]|$)" "${README}"; then
      [ -x "${REPO_ROOT}/${cli}" ] || {
        printf 'README references ./%s but it is missing or not executable\n' "${cli}" >&2; bad=1; }
    fi
  done
  return "${bad}"
}

@test "README does not present removed machinery as live (hook installer, judge skills)" {
  # The hook names themselves may appear in the one-time removal recipe.
  local hits
  hits="$(grep -nE 'install-hooks|HOOK_REGISTRY|c-bpm-sk-devils-advocate|c-bpm-sk-llm-selection' "${README}" || true)"
  if [ -n "${hits}" ]; then
    printf 'README references removed machinery:\n%s\n' "${hits}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 3: every documented flag exists in the script it is documented for
# ------------------------------------------------------------------

@test "every --flag documented in a README code fence exists in its script" {
  local bad=0
  while IFS= read -r line; do
    local owner="" tok base flag
    line="${line%%#*}"
    for tok in ${line}; do
      base="${tok##*/}"
      base="${base%\"}"; base="${base%\'}"; base="${base%;}"
      [ -n "${base}" ] || continue
      if [ -z "${owner}" ] && [ -f "${REPO_ROOT}/${base}" ]; then owner="${base}"; fi
    done
    [ -n "${owner}" ] || continue
    for tok in ${line}; do
      case "${tok}" in
        --[a-z]*)
          flag="${tok%%=*}"
          if ! grep -qF -- "${flag}" "${REPO_ROOT}/${owner}"; then
            printf 'README documents %s for ./%s but that flag is not in the script\n' "${flag}" "${owner}" >&2
            bad=1
          fi
          ;;
      esac
    done
  done < <(readme_fences)
  return "${bad}"
}

# ------------------------------------------------------------------
# 4: no model version pin (Issue #98 single-source model policy)
# ------------------------------------------------------------------

@test "README pins no model version (#98)" {
  local hits
  hits="$(grep -nEi -- '(gpt-[0-9]|opus[- ][0-9]|sonnet[- ][0-9]|haiku[- ][0-9]|claude-[0-9]|gemini[- ][0-9])' "${README}" || true)"
  if [ -n "${hits}" ]; then
    printf 'README pins a model version (forbidden by #98):\n%s\n' "${hits}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 5: external links open in a new tab, and use HTML not Markdown
# ------------------------------------------------------------------

@test "every external href carries target=\"_blank\" and no Markdown http links in prose" {
  local bad=0 hits
  hits="$(grep -oE '<a [^>]*href="https?://[^>]*>' "${README}" | grep -v 'target="_blank"' || true)"
  if [ -n "${hits}" ]; then
    printf 'External anchor(s) without target="_blank":\n%s\n' "${hits}" >&2
    bad=1
  fi
  hits="$(readme_prose | grep -nE '\]\(https?://' || true)"
  if [ -n "${hits}" ]; then
    printf 'Markdown-style external link(s) outside code fences:\n%s\n' "${hits}" >&2
    bad=1
  fi
  return "${bad}"
}

# ------------------------------------------------------------------
# 6: English only
# ------------------------------------------------------------------

@test "README prose is English only" {
  local hits
  hits="$(grep -nE -- '(Maschine|Komplettes|geklont|Aktualisiert|Vorschau|Änderungen|Typischer|Nur Standard|Ohne Repo|Danach stehen|anlegen|z\.B\.)' "${README}" || true)"
  if [ -n "${hits}" ]; then
    printf 'German prose found in README (English only, per global rules):\n%s\n' "${hits}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 7: mandatory facts the install + operate path depends on
# ------------------------------------------------------------------

@test "README states the mandatory install/operate facts" {
  local bad=0
  _fact() { # <description> <grep-mode-args...>
    local desc="$1"; shift
    if ! grep -q "$@" "${README}"; then
      printf 'README is missing a mandatory fact: %s\n' "${desc}" >&2
      bad=1
    fi
  }
  _fact 'the fresh-install pull step'                         -F -- 'c-bpm-cm-library-pull'
  _fact 'the "Updating an existing installation" subsection'  -F -- '### Updating an existing installation'
  _fact 'the Pocock plugin install line'                      -F -- 'claude plugin install mattpocock-skills@mattpocock'
  _fact 'the unlock step after installing the plugin'         -F -- '/c-bpm-cm-pocock-update'
  _fact 'the codex requirement'                               -F -- 'codex'
  _fact 'how the two overnight flows relate'                  -F -- 'How the two overnight flows relate'
  _fact 'the checksum maintenance pointer'                    -F -- 'checksums.sha256'
  return "${bad}"
}
