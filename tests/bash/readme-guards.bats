#!/usr/bin/env bats
#
# readme-guards.bats — drift guards for README.md (Issue #123)
# Run with: bats tests/bash/readme-guards.bats
#
# The README is the entry point a new machine reads before it has any local
# context. Issue #123 replaced a stale hand-maintained inventory (a 145-line
# Mermaid graph claiming 27 skills / 8 commands against a repo that had 33/9,
# plus German prose and unverified flags) with a short operational README.
# These guards keep it honest: every referenced item and flag must exist, no
# model version may be pinned (Issue #98), links must open in a new tab, the
# prose must be English, and the facts the install path depends on must stay.
#
#   NOTE: the model-pin regex below intentionally spells out "gpt-5"/"opus-4".
#   This file lives under tests/ (outside my/), so it does not trip the
#   acceptance grep `grep -rn 'gpt-5' my/ = 0` from Issue #98.

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
# 1: the six required top-level sections exist
# ------------------------------------------------------------------

@test "README has the six required top-level sections" {
  [ -f "${README}" ] || { printf 'README.md not found at %s\n' "${README}" >&2; return 1; }
  local missing=0 h
  for h in \
    '## 1. What This Is' \
    '## 2. Installation' \
    '## 3. How the Agent Teams Work' \
    '## 4. Model Policy' \
    '## 5. Testing' \
    '## 6. Key Commands'
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
#    (parses the README's own backtick tokens, so future additions are
#     guarded too — no hardcoded inventory to go stale)
# ------------------------------------------------------------------

@test "every c-bpm-* item referenced in README exists on disk" {
  local bad=0 tok
  # Every c-bpm token the README names, de-duplicated. A `.bats` suffix means
  # the reference is to a test file, not to the item itself.
  for tok in $(grep -oE 'c-bpm-(sk|cm|ag|rb)-[a-z0-9-]+(\.bats)?' "${README}" | sed 's/-*$//' | sort -u); do
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
        # A command may be a slash-command file, a root CLI script, or both.
        if [ ! -f "${REPO_ROOT}/my/commands/${tok}.md" ] && [ ! -f "${REPO_ROOT}/${tok}" ]; then
          printf 'README references command %s but neither my/commands/%s.md nor ./%s exists\n' "${tok}" "${tok}" "${tok}" >&2
          bad=1
        fi
        ;;
      c-bpm-ag-*)
        [ -f "${REPO_ROOT}/my/agents/${tok}.md" ] || {
          printf 'README references agent %s but my/agents/%s.md does not exist\n' "${tok}" "${tok}" >&2; bad=1; }
        ;;
      c-bpm-rb-*)
        [ -f "${REPO_ROOT}/my/runbooks/${tok}.md" ] || {
          printf 'README references runbook %s but my/runbooks/%s.md does not exist\n' "${tok}" "${tok}" >&2; bad=1; }
        ;;
    esac
  done
  return "${bad}"
}

@test "every root CLI referenced in README exists and is executable" {
  local bad=0 cli
  for cli in bcgasl install install-hooks sync; do
    if grep -qE "(^|[^a-z-])${cli}([^a-z-]|$)" "${README}"; then
      [ -x "${REPO_ROOT}/${cli}" ] || {
        printf 'README references ./%s but it is missing or not executable\n' "${cli}" >&2; bad=1; }
    fi
  done
  return "${bad}"
}

# ------------------------------------------------------------------
# 3: every documented flag exists in the script it is documented for
# ------------------------------------------------------------------

@test "every --flag documented in a README code fence exists in its script" {
  local bad=0
  while IFS= read -r line; do
    local owner="" tok base flag
    line="${line%%#*}"   # inline comments name tools they do not invoke
    # Owner = first token on the line whose basename names a repo-root script
    # (covers ./script, sudo ./script, and curl <url>/script | bash).
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

@test "README pins no model version (single-source model policy, #98)" {
  local hits
  hits="$(grep -nEi -- '(gpt-[0-9]|opus[- ][0-9]|sonnet[- ][0-9]|haiku[- ][0-9]|claude-[0-9]|gemini[- ][0-9])' "${README}" || true)"
  if [ -n "${hits}" ]; then
    printf 'README pins a model version (forbidden by #98 — point at c-bpm-sk-llm-selection instead):\n%s\n' "${hits}" >&2
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
    printf 'Markdown-style external link(s) outside code fences (must be <a href=... target="_blank">):\n%s\n' "${hits}" >&2
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

  # Hook install — both settings paths, with the amended "only if present" caveat (#65/#76).
  _fact 'the ~/.claude/settings.json path'                 -F -- '~/.claude/settings.json'
  _fact 'the ~/.config/claude/settings.json path'          -F -- '~/.config/claude/settings.json'
  _fact 'the "where they exist" caveat for settings files' -F -- 'where they exist'
  _fact 'the "skipped, not created" caveat'                -F -- 'skipped, not created'
  _fact 'the #65/#76 pointer for the settings-path gap'    -E -- '#65|#76'
  _fact 'the install-hooks step'                           -F -- 'install-hooks'

  # Update path (user requirement, 2026-07-25) — drift rationale is #114.
  _fact 'the "Updating an existing installation" subsection' -F -- '### Updating an existing installation'
  _fact 'the installed-copy drift pointer (#114)'            -F -- '#114'

  # Team operation.
  _fact 'DONE is human-only'                               -E -- 'DONE.*human|[Hh]uman.*DONE'
  _fact 'the Codex/Judge gate skill pointer'               -F -- 'c-bpm-sk-devils-advocate'
  _fact 'the teammate-lifecycle policy pointer (#120)'     -F -- '#120'

  # Model policy + testing honesty.
  _fact 'the model policy pointer'                         -F -- 'c-bpm-sk-llm-selection'
  _fact 'the known-red write-gate note (#100)'             -F -- '#100'
  _fact 'the E2E harness pointer (#122)'                   -F -- '#122'

  return "${bad}"
}

# ------------------------------------------------------------------
# 8: hook-system deep dive (Issue #150)
# ------------------------------------------------------------------

# Emit the body of the single ```mermaid block containing the given tag line.
mermaid_block_by_tag() { # <tag-name>
  awk -v tag="%% diagram: $1" '
    /^[[:space:]]*```mermaid/ { inb=1; buf=""; next }
    inb && /^[[:space:]]*```[[:space:]]*$/ { inb=0; if (index(buf, tag)) print buf; next }
    inb { buf = buf $0 "\n" }
  ' "${README}"
}

# Count mermaid blocks containing the given tag line.
mermaid_blocks_with_tag() { # <tag-name>
  awk -v tag="%% diagram: $1" '
    /^[[:space:]]*```mermaid/ { inb=1; buf=""; next }
    inb && /^[[:space:]]*```[[:space:]]*$/ { inb=0; if (index(buf, tag)) n++; next }
    inb { buf = buf $0 "\n" }
    END { print n+0 }
  ' "${README}"
}

# Assert one tagged diagram: unique tag, required type, required markers.
check_tagged_diagram() { # <tag> <type> <marker...>
  local tag="$1" type="$2"; shift 2
  local n block first m
  n="$(mermaid_blocks_with_tag "${tag}")"
  if [ "${n}" -ne 1 ]; then
    printf 'diagram tag "%s": expected exactly 1 mermaid block, found %s\n' "${tag}" "${n}" >&2
    return 1
  fi
  block="$(mermaid_block_by_tag "${tag}")"
  first="$(printf '%s\n' "${block}" | grep -vE '^[[:space:]]*(%%|$)' | head -1 | awk '{print $1}')"
  if [ "${first}" != "${type}" ]; then
    printf 'diagram "%s": first line type is "%s", expected "%s"\n' "${tag}" "${first}" "${type}" >&2
    return 1
  fi
  for m in "$@"; do
    if ! printf '%s\n' "${block}" | grep -qE -- "${m}"; then
      printf 'diagram "%s": required marker "%s" missing\n' "${tag}" "${m}" >&2
      return 1
    fi
  done
}

@test "README documents every HOOK_REGISTRY hook: name, PreToolUse event, all matchers (#150)" {
  local bad=0 row name matchers m
  while IFS='|' read -r name matchers _; do
    [ -n "${name}" ] || continue
    if ! grep -qF -- "${name}" "${README}"; then
      printf 'README does not name registered hook %s\n' "${name}" >&2; bad=1
    fi
    for m in ${matchers//,/ }; do
      if ! grep -qF -- "${m}" "${README}"; then
        printf 'README missing matcher %s of hook %s\n' "${m}" "${name}" >&2; bad=1
      fi
    done
  done < <(sed -n '/^HOOK_REGISTRY=(/,/^)/p' "${REPO_ROOT}/install-hooks" | grep -oE '"[^"]+"' | tr -d '"')
  grep -qF -- 'PreToolUse' "${README}" || { printf 'README missing the PreToolUse event name\n' >&2; bad=1; }
  return "${bad}"
}

@test "README states the hook I/O contract: stdin JSON, stdout decision, exit 0, fail-closed (#150)" {
  local bad=0 f
  for f in 'stdin' 'permission decision' 'exit 0' 'fail-closed'; do
    grep -qiF -- "${f}" "${README}" || { printf 'README missing hook-contract fact: %s\n' "${f}" >&2; bad=1; }
  done
  return "${bad}"
}

@test "README is honest about the inactive skill-activation-prompt source (#150, #151)" {
  grep -qF -- 'skill-activation-prompt' "${README}"
  grep -qiE 'skill-activation-prompt[^.]*\b(unregistered|inactive|not registered)|(unregistered|inactive)[^.]*skill-activation-prompt' "${README}"
  grep -qF -- '#151' "${README}"
}

@test "README carries >=4 mermaid diagrams, each opening with a valid type (#150)" {
  local count
  count="$(grep -cE '^[[:space:]]*```mermaid' "${README}")"
  if [ "${count}" -lt 4 ]; then
    printf 'expected >=4 mermaid blocks, found %s\n' "${count}" >&2
    return 1
  fi
  awk '
    /^[[:space:]]*```mermaid/ { inb=1; first=1; next }
    inb && /^[[:space:]]*```[[:space:]]*$/ { inb=0; next }
    inb && first {
      if ($0 ~ /^[[:space:]]*(%%|$)/) next
      if ($1 != "sequenceDiagram" && $1 != "flowchart" && $1 != "stateDiagram-v2" && $1 != "graph") {
        printf "invalid mermaid diagram type line: %s\n", $0 > "/dev/stderr"; bad=1
      }
      first=0
    }
    END { exit bad }
  ' "${README}"
}

@test "the four required diagrams exist as four distinct tagged blocks (#150)" {
  check_tagged_diagram 'issue-create-sequence' 'sequenceDiagram' 'issue-write-gate' 'deny' 'allow'
  check_tagged_diagram 'gate-decision'         'flowchart'       'issue-write-gate' 'milestone' 'bug' 'enhancement'
  check_tagged_diagram 'milestone-lifecycle'   'stateDiagram-v2' 'CANCELLED' 'DONE' 'test_approved|test-approved'
  check_tagged_diagram 'distribution'          'flowchart'       'settings\.json' 'c-bpm-cm-library-pull'
}

@test "README no longer claims only one hook ships (#150)" {
  ! grep -qiF -- 'one hook ships' "${README}"
}

@test "README is honest that the GitHub-Actions layer does not exist yet (#150)" {
  grep -qF -- '.github/workflows/' "${README}"
  grep -qF -- 'does not exist yet' "${README}"
}

@test "README testing section carries no stale known-red claim (#150)" {
  ! grep -qF -- 'expected to show exactly' "${README}"
  ! grep -qF -- 'Known red:' "${README}"
}
