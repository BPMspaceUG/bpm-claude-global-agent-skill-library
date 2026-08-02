#!/usr/bin/env bats
#
# c-bpm-sk-devils-advocate.bats - Issue #113 (+ #112, #117) acceptance suite
# Run with: bats tests/bash/c-bpm-sk-devils-advocate.bats
#
# Purpose:
#   Issue #113 centralises the Codex-as-Judge invocation into ONE skill,
#   c-bpm-sk-devils-advocate, and makes c-bpm-sk-llm-selection the single
#   source of model/ladder policy. This suite locks in:
#     1. Every enumerated call site had its direct `codex exec` invocation
#        REMOVED (not merely annotated) and delegates to the new skill.
#        Reference files are checked on RAW content (they carry no legitimate
#        stamped block); SKILL.md files must carry EXACTLY ONE stamped block,
#        so a kept invocation cannot be hidden inside a fake wrapper.
#     2. Forward drift-guard: only two files under my/skills/ may contain a
#        non-stamped `codex exec` at all — same anti-fake-stamp rules.
#     3. The new skill mandates a LIVE Issue fetch before invoking the Judge.
#     4. The new skill exists, is Codex-primary, and defers policy to
#        c-bpm-sk-llm-selection.
#     5. The OpenRouter key comes from user-level `~/.env`, never project-level.
#     6. No GLM / DeepSeek / Kimi / Fable numeric version pin under my/.
#     7. [#117] Both mandating files carry the network-enabled sandbox flags;
#        `danger-full-access` is not sanctioned anywhere.
#     8. [#121] No `model:` frontmatter key in any my/skills/*/SKILL.md OR
#        my/commands/*.md (single-source model policy — repo-wide sweep of the
#        31 carriers ratified in #113; c-bpm-sk-question-auditor carries no key
#        today and must stay key-free). Absolute: no "justified exception".
#     9. [#112] c-bpm-sk-llm-selection carries the new ladder and the
#        Producer/Judge role directive, and the stale bullets are gone.
#    10. [#118] my/commands/** obeys the same routing contract as my/skills/**:
#        zero non-stamped `codex exec`, delegation reference on every call site.
#    11. [#119] No c-bpm doc restates the stale Codex -> Gemini -> Claude ladder
#        (superseded by the OpenRouter tier in #113); the authority is named.
#
#   SCOPE NOTE: #118 (commands) and #121 (command-side model keys) landed here
#   in Tests 10 and 8. The user-level ~/.claude/CLAUDE.md itself is outside the
#   repo, so Test 11 guards the distributed wording, not that host file.
#
#   SELF-MATCH NOTE: this file lives under tests/, outside my/, and the one
#   repo-wide negative grep below excludes tests/ explicitly. The guard regexes
#   in this file therefore never match the suite itself.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

LLM_SELECTION_REL="my/skills/c-bpm-sk-llm-selection/SKILL.md"
DA_SKILL_REL="my/skills/c-bpm-sk-devils-advocate/SKILL.md"
LLM_SELECTION="${REPO_ROOT}/${LLM_SELECTION_REL}"
DA_SKILL="${REPO_ROOT}/${DA_SKILL_REL}"

# ------------------------------------------------------------------
# Enumerated call sites — binding rev-3 enumeration on Issue #113:
# 14 SKILL.md + 3 reference files = 17 files. Each MUST end up with zero
# `codex exec` AND a delegation reference to the new skill.
#
# The two lists are checked with different rules:
#   * SKILL.md  — the stamped issue-comms block legitimately contains a
#                 `codex exec` example, so it is stripped before counting;
#                 in exchange the file must carry EXACTLY ONE stamped block
#                 (a second, ad-hoc wrapper hiding a kept invocation fails).
#   * reference — no legitimate stamped block exists, so the RAW file must
#                 contain zero `codex exec` and zero stamp markers.
# ------------------------------------------------------------------
CALL_SITE_SKILLS=(
  "my/skills/c-bpm-sk-linux-admin/SKILL.md"
  "my/skills/c-bpm-sk-linux-audit/SKILL.md"
  "my/skills/c-bpm-sk-milestone-type/SKILL.md"
  "my/skills/c-bpm-sk-grill-claude-issue/SKILL.md"
  "my/skills/c-bpm-sk-grill-me/SKILL.md"
  "my/skills/c-bpm-sk-grill-me-issue/SKILL.md"
  "my/skills/c-bpm-sk-auditor/SKILL.md"
  "my/skills/c-bpm-sk-question-auditor/SKILL.md"
  "my/skills/c-bpm-sk-idea-merge/SKILL.md"
  "my/skills/c-bpm-sk-skill-creator/SKILL.md"
  "my/skills/c-bpm-sk-skill-optimizer/SKILL.md"
  "my/skills/c-bpm-sk-release-ops/SKILL.md"
  "my/skills/c-bpm-sk-repo-scaffold/SKILL.md"
  "my/skills/c-bpm-sk-linux-archive/SKILL.md"
)

CALL_SITE_REFERENCES=(
  "my/skills/c-bpm-sk-auditor/references/codex-prompts.md"
  "my/skills/c-bpm-sk-skill-optimizer/references/team-orchestration.md"
  "my/skills/c-bpm-sk-flightphp-pro/references/team-orchestration.md"
)

# ------------------------------------------------------------------
# Helper: print a file WITHOUT its stamped issue-comms block.
# The awk pattern mirrors extract_block() in issue-comms-anchor.bats
# (inverted) so both suites agree on the block boundaries. The master
# block itself contains a `codex exec` example, so stripping it is
# load-bearing for every codex-exec assertion below.
# ------------------------------------------------------------------
strip_stamped() {
  awk '
    /<!-- BEGIN issue-comms/ { p=1 }
    !p { print }
    /<!-- END issue-comms/   { p=0 }
  ' "$1"
}

# ------------------------------------------------------------------
# Helper: count `<!-- BEGIN issue-comms` markers in a file.
# Anti-fake-stamp guard: strip_stamped() hides everything between ANY
# BEGIN/END pair, so a kept `codex exec` could be smuggled past it inside
# an ad-hoc second wrapper. A stamped SKILL.md has exactly one marker;
# a reference file has none.
# ------------------------------------------------------------------
count_stamp_markers() {
  grep -c -- '<!-- BEGIN issue-comms' "$1" || true
}

# ------------------------------------------------------------------
# Helper: is the fetch-before-judging mandate stated as ONE coupled rule
# on ONE line? The `[^.]` classes keep the whole match inside a single
# sentence, so two unrelated sentences on adjacent lines cannot combine
# into a false positive. Both phrasing orders are accepted:
#   "Fetch the live Issue body and comments via gh api BEFORE invoking the Judge."
#   "BEFORE invoking the Judge, fetch the live Issue body and comments."
# ------------------------------------------------------------------
_coupled_fetch_mandate() {
  grep -qiE \
    -e '(fetch|read|pull|retrieve)[^.]{0,80}issue[^.]{0,80}before[^.]{0,40}(invok|judg|codex)' \
    -e 'before[^.]{0,40}(invok|judg|codex)[^.]{0,80}(fetch|read|pull|retrieve)[^.]{0,80}issue' \
    "$1"
}

# ------------------------------------------------------------------
# Helper: print ONLY a file's YAML frontmatter (the leading --- ... ---
# block), one line per key. Prints nothing when the file has none.
#
# [#121] The naive version (`NR==1 && $0=="---"`) was BYPASSABLE — it
# recognised frontmatter only when byte 1 of line 1 was a literal `-`,
# so all of these smuggled a `model:` pin straight past the guard:
#   * a UTF-8 BOM before the opening delimiter
#   * one or more blank/whitespace-only lines before it
#   * CRLF line endings (the trailing \r broke the exact `---` compare)
# ...and a `...` terminator (valid YAML end-of-document) was never
# recognised as the END of the block, so the whole BODY leaked into the
# comparison — a false-POSITIVE risk on prose in the other direction.
#
# Hardened rules:
#   * strip a UTF-8 BOM from line 1 (LC_ALL=C so substr is byte-wise;
#     under a UTF-8 locale awk's sprintf/substr are character-wise and
#     the 3-byte compare silently fails)
#   * strip a trailing \r from every line (CRLF tolerance)
#   * skip leading blank/whitespace-only lines before the delimiter
#   * accept `---` with surrounding whitespace as the opener; the FIRST
#     non-blank line that is not a delimiter means "no frontmatter"
#   * close on `---` OR `...` so the body can never leak in
# ------------------------------------------------------------------
_extract_frontmatter() {
  LC_ALL=C awk '
    BEGIN { bom = sprintf("%c%c%c", 239, 187, 191) }
    {
      line = $0
      if (NR == 1 && substr(line, 1, 3) == bom) line = substr(line, 4)
      sub(/\r$/, "", line)
    }
    !started {
      if (line ~ /^[[:space:]]*$/) next
      if (line ~ /^[[:space:]]*---[[:space:]]*$/) { started = 1; next }
      exit
    }
    { if (line ~ /^[[:space:]]*(---|\.\.\.)[[:space:]]*$/) exit; print line }
  ' "$1"
}

# ------------------------------------------------------------------
# Helper: does this file pin a model in its FRONTMATTER? Echoes the
# offending line(s); silent when clean. Single chokepoint so Test 8 and
# the Test 12 bypass fixtures exercise byte-identical logic.
# ------------------------------------------------------------------
_frontmatter_model_hit() {
  _extract_frontmatter "$1" | grep -nE '^[[:space:]]*model:[[:space:]]*' || true
}

# ------------------------------------------------------------------
# Helper: assert a file contains every needle (case-insensitive fixed
# string). Reports all missing needles. Missing file = clean failure.
# ------------------------------------------------------------------
_assert_needles() {
  local rel="$1"; shift
  local f="${REPO_ROOT}/${rel}"
  if [[ ! -f "${f}" ]]; then
    printf 'Required file not found: %s\n' "${rel}" >&2
    return 1
  fi
  local missing=()
  local needle
  for needle in "$@"; do
    if ! grep -qiF -- "${needle}" "${f}"; then
      missing+=("${needle}")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    printf 'Missing required content in %s:\n' "${rel}" >&2
    printf '  %s\n' "${missing[@]}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# Helper: assert a file does NOT contain any of the given fixed strings.
# ------------------------------------------------------------------
_assert_absent_needles() {
  local rel="$1"; shift
  local f="${REPO_ROOT}/${rel}"
  if [[ ! -f "${f}" ]]; then
    printf 'Required file not found: %s\n' "${rel}" >&2
    return 1
  fi
  local present=()
  local needle
  for needle in "$@"; do
    if grep -qiF -- "${needle}" "${f}"; then
      present+=("${needle}")
    fi
  done
  if (( ${#present[@]} > 0 )); then
    printf 'Stale wording still present in %s:\n' "${rel}" >&2
    printf '  %s\n' "${present[@]}" >&2
    return 1
  fi
}

# ==================================================================
# Test 1 - enumerated call sites: invocation REMOVED + delegation added
# ==================================================================

@test "all 17 enumerated call-site files have their direct 'codex exec' removed and delegate to c-bpm-sk-devils-advocate" {
  local offenders=()
  local rel f n m

  # --- 14 SKILL.md files: strip the ONE legitimate stamped block ---
  for rel in "${CALL_SITE_SKILLS[@]}"; do
    f="${REPO_ROOT}/${rel}"
    if [[ ! -f "${f}" ]]; then
      offenders+=("${rel}: file not found")
      continue
    fi
    # (a) exactly one stamped block — no ad-hoc wrapper to hide code in
    m="$(count_stamp_markers "${f}")"
    if (( m != 1 )); then
      offenders+=("${rel}: ${m} '<!-- BEGIN issue-comms' marker(s), expected exactly 1 (fake stamp block?)")
    fi
    # (b) no direct invocation left outside the stamped issue-comms block
    n="$(strip_stamped "${f}" | grep -c -- 'codex exec' || true)"
    if (( n > 0 )); then
      offenders+=("${rel}: ${n} non-stamped 'codex exec' occurrence(s) still present (must be 0)")
    fi
    # (c) delegation reference to the canonical Judge-invocation skill
    if ! grep -qF -- 'c-bpm-sk-devils-advocate' "${f}"; then
      offenders+=("${rel}: missing delegation reference to c-bpm-sk-devils-advocate")
    fi
  done

  # --- 3 reference files: RAW content, no stripping, no stamp markers ---
  for rel in "${CALL_SITE_REFERENCES[@]}"; do
    f="${REPO_ROOT}/${rel}"
    if [[ ! -f "${f}" ]]; then
      offenders+=("${rel}: file not found")
      continue
    fi
    n="$(grep -c -- 'codex exec' "${f}" || true)"
    if (( n > 0 )); then
      offenders+=("${rel}: ${n} raw 'codex exec' occurrence(s) still present (must be 0; reference files have no stamped block)")
    fi
    m="$(count_stamp_markers "${f}")"
    if (( m != 0 )); then
      offenders+=("${rel}: ${m} '<!-- BEGIN issue-comms' marker(s), expected 0 (reference files are not stamped)")
    fi
    if ! grep -qF -- 'c-bpm-sk-devils-advocate' "${f}"; then
      offenders+=("${rel}: missing delegation reference to c-bpm-sk-devils-advocate")
    fi
  done
  if (( ${#offenders[@]} > 0 )); then
    printf 'Issue #113 call-site routing incomplete (%d finding(s)):\n' "${#offenders[@]}" >&2
    printf '  %s\n' "${offenders[@]}" >&2
    return 1
  fi
}

# ==================================================================
# Test 2 - exclusivity / forward drift-guard across my/skills/
# ==================================================================

@test "only c-bpm-sk-llm-selection and c-bpm-sk-devils-advocate may contain a non-stamped 'codex exec' under my/skills/" {
  local offenders=()
  local f rel n m is_skill
  # my/commands/** is out of scope here (sequenced to #118).
  while IFS= read -r f; do
    rel="${f#${REPO_ROOT}/}"
    is_skill=0
    if [[ "${rel}" == my/skills/c-bpm-sk-*/SKILL.md ]]; then
      is_skill=1
    fi

    # Anti-fake-stamp guard applies to EVERY file, including the two
    # allowed invocation sites: SKILL.md carries exactly one stamped
    # block, any other .md carries none.
    m="$(count_stamp_markers "${f}")"
    if (( is_skill == 1 )); then
      (( m == 1 )) || offenders+=("${rel}: ${m} '<!-- BEGIN issue-comms' marker(s), expected exactly 1 (fake stamp block?)")
    else
      (( m == 0 )) || offenders+=("${rel}: ${m} '<!-- BEGIN issue-comms' marker(s), expected 0 (only SKILL.md is stamped)")
    fi

    # The two sanctioned invocation sites are exempt from the codex-exec
    # count (but not from the stamp-marker check above).
    if [[ "${rel}" == "${LLM_SELECTION_REL}" || "${rel}" == "${DA_SKILL_REL}" ]]; then
      continue
    fi

    if (( is_skill == 1 )); then
      n="$(strip_stamped "${f}" | grep -c -- 'codex exec' || true)"
      (( n == 0 )) || offenders+=("${rel}: ${n} non-stamped 'codex exec' occurrence(s)")
    else
      n="$(grep -c -- 'codex exec' "${f}" || true)"
      (( n == 0 )) || offenders+=("${rel}: ${n} raw 'codex exec' occurrence(s)")
    fi
  done < <(find "${REPO_ROOT}/my/skills" -type f -name '*.md' | sort)

  if (( ${#offenders[@]} > 0 )); then
    printf 'Codex invocation must live in exactly two files (%s, %s).\n' \
      "${LLM_SELECTION_REL}" "${DA_SKILL_REL}" >&2
    printf 'Unexpected invocation site(s):\n' >&2
    printf '  %s\n' "${offenders[@]}" >&2
    return 1
  fi
}

# ==================================================================
# Test 3 - the new skill mandates a LIVE Issue fetch before judging
# ==================================================================

@test "c-bpm-sk-devils-advocate mandates a live Issue fetch (body + comments) before invoking the Judge" {
  if [[ ! -f "${DA_SKILL}" ]]; then
    printf 'Skill not found: %s\n' "${DA_SKILL_REL}" >&2
    return 1
  fi

  # PRIMARY: the mandate must be stated as ONE coupled rule — fetch the
  # live Issue BEFORE the Judge/Codex is invoked — not as two unrelated
  # narrative fragments.
  if ! _coupled_fetch_mandate "${DA_SKILL}"; then
    printf 'No coupled fetch-before-judging mandate found in %s\n' "${DA_SKILL_REL}" >&2
    printf 'Expected ONE line (one sentence) stating: fetch/retrieve/read the Issue BEFORE invoking the Judge/Codex.\n' >&2
    return 1
  fi

  # SECONDARY: the mechanics and the failure behaviour.
  _assert_needles "${DA_SKILL_REL}" \
    "Live Issue Fetch" \
    "gh api repos/" \
    "/comments" \
    "before invoking the Judge" \
    "Judge unable"

  # The payload must be Issue-sourced, never an authored side-car .md.
  if ! grep -qiE 'never.{0,60}(authored|side.?car|hand.?written).{0,20}\.md' "${DA_SKILL}"; then
    printf 'Missing the "payload is Issue-sourced, never an authored .md" rule in %s\n' "${DA_SKILL_REL}" >&2
    return 1
  fi
  # A fabricated verdict is never acceptable when the fetch fails.
  if ! grep -qiE '(never|no|not).{0,120}fabricat' "${DA_SKILL}"; then
    printf 'Missing the "never a fabricated verdict" rule in %s\n' "${DA_SKILL_REL}" >&2
    return 1
  fi
}

# ==================================================================
# Test 4 - the skill exists, is Codex-primary, defers policy upstream
# ==================================================================

@test "c-bpm-sk-devils-advocate exists, is Codex-primary, and references c-bpm-sk-llm-selection" {
  if [[ ! -f "${DA_SKILL}" ]]; then
    printf 'Skill not found: %s\n' "${DA_SKILL_REL}" >&2
    return 1
  fi
  _assert_needles "${DA_SKILL_REL}" \
    "codex exec --skip-git-repo-check" \
    "Codex" \
    "primary" \
    "c-bpm-sk-llm-selection" \
    "cac pull --tool codex"
}

# ==================================================================
# Test 5 - OpenRouter key from user-level ~/.env, never project-level
# ==================================================================

@test "OpenRouter key is sourced from user-level ~/.env only, never project-level" {
  local rel
  for rel in "${LLM_SELECTION_REL}" "${DA_SKILL_REL}"; do
    _assert_needles "${rel}" "~/.env"
  done
  # The single source must state the never-project-level rule explicitly.
  if ! grep -qiE 'never.{0,40}project.?level' "${LLM_SELECTION}"; then
    printf 'Missing the "never project-level .env" rule in %s\n' "${LLM_SELECTION_REL}" >&2
    return 1
  fi
  # And neither file may point at a project-local .env path.
  local offenders=() f hits
  for rel in "${LLM_SELECTION_REL}" "${DA_SKILL_REL}"; do
    f="${REPO_ROOT}/${rel}"
    [[ -f "${f}" ]] || continue
    hits="$(grep -nE '(\./\.env|\$\{?PWD\}?/\.env)' "${f}" || true)"
    if [[ -n "${hits}" ]]; then
      offenders+=("${rel}: ${hits}")
    fi
  done
  if (( ${#offenders[@]} > 0 )); then
    printf 'Project-level .env reference found (key must come from ~/.env):\n' >&2
    printf '  %s\n' "${offenders[@]}" >&2
    return 1
  fi
}

# ==================================================================
# Test 6 - no GLM / DeepSeek / Kimi / Fable numeric version pin under my/
# ==================================================================

@test "no GLM / DeepSeek / Kimi / Fable numeric version pin anywhere under my/" {
  cd "${REPO_ROOT}"
  local bad
  # Slugs are resolved at invocation time via /api/v1/models; families are
  # named by role, never pinned numerically (single-source model policy, #98).
  bad="$(grep -rniE -- '(glm|deepseek|kimi|fable)[-_ ]?v?[0-9]' my/ || true)"
  if [[ -n "${bad}" ]]; then
    printf 'Hard-wired model version pin found under my/:\n%s\n' "${bad}" >&2
    return 1
  fi
}

# ==================================================================
# Test 7 - [#117] network-enabled sandbox flags; danger-full-access banned
# ==================================================================

@test "[#117] both mandating files carry the network-enabled sandbox flags and 'danger-full-access' is nowhere sanctioned" {
  local rel
  for rel in "${LLM_SELECTION_REL}" "${DA_SKILL_REL}"; do
    _assert_needles "${rel}" \
      "-s workspace-write" \
      "sandbox_workspace_write.network_access=true"
  done

  # The FULL canonical command must appear contiguously — tokens scattered
  # through prose do not prove the invocation actually carries them. Token
  # order is load-bearing: c-bpm-sk-codex-flag.bats requires a contiguous
  # `codex exec --skip-git-repo-check`, so the sandbox flags come AFTER it.
  local canonical='codex exec --skip-git-repo-check -s workspace-write -c sandbox_workspace_write.network_access=true'
  local offenders=() f
  for rel in "${LLM_SELECTION_REL}" "${DA_SKILL_REL}"; do
    f="${REPO_ROOT}/${rel}"
    if [[ ! -f "${f}" ]]; then
      offenders+=("${rel}: file not found")
      continue
    fi
    if ! grep -qF -- "${canonical}" "${f}"; then
      offenders+=("${rel}: missing contiguous canonical command '${canonical}'")
    fi
  done
  if (( ${#offenders[@]} > 0 )); then
    printf 'Canonical invocation token order broken:\n' >&2
    printf '  %s\n' "${offenders[@]}" >&2
    return 1
  fi

  # Repo-wide negative. tests/ is excluded so this suite does not match
  # its own guard string; .git and node_modules are noise. Lines that
  # FORBID the flag ("not sanctioned", "never", "forbidden", "banned") are
  # legitimate policy prose — the plan requires such a line in the skill —
  # so they are filtered out before failing.
  cd "${REPO_ROOT}"
  local bad
  bad="$(grep -rn --exclude-dir=.git --exclude-dir=tests --exclude-dir=node_modules \
    -- 'danger-full-access' . \
    | grep -viE 'not sanctioned|never|forbidden|banned' || true)"
  if [[ -n "${bad}" ]]; then
    printf 'danger-full-access is NOT sanctioned (workspace-write is the ceiling per #117):\n%s\n' "${bad}" >&2
    return 1
  fi
}

# ==================================================================
# Test 8 - [#121] no `model:` frontmatter key in ANY my/skills/*/SKILL.md
#          OR my/commands/*.md
#
# Codex rejected the "allow a justified exception with a comment" model
# (round 2, #121): a commented exception reopens the bypass. The rule is
# absolute — ZERO frontmatter `model:` keys on both sides. Model choice
# lives only as PROSE in c-bpm-sk-llm-selection (#98).
#
# Frontmatter only: prose and fenced YAML *templates* further down a body
# mention `model:` legitimately as documentation, so only the leading
# --- ... --- block is inspected.
# ==================================================================

@test "[#121] no 'model:' key in the frontmatter of any my/skills/*/SKILL.md or my/commands/*.md (single-source model policy)" {
  local offenders=()
  local f rel hit
  shopt -s nullglob
  local targets=( "${REPO_ROOT}"/my/skills/c-bpm-sk-*/SKILL.md "${REPO_ROOT}"/my/commands/c-bpm-cm-*.md )
  if (( ${#targets[@]} == 0 )); then
    printf 'No skill SKILL.md files found under my/skills/ — enumeration broken.\n' >&2
    return 1
  fi
  # Both halves must actually be enumerated — a glob that silently matched
  # nothing on one side would make this test vacuously green for that side.
  local n_skills n_commands
  n_skills="$(printf '%s\n' "${targets[@]}" | grep -c '/my/skills/' || true)"
  n_commands="$(printf '%s\n' "${targets[@]}" | grep -c '/my/commands/' || true)"
  if (( n_skills == 0 || n_commands == 0 )); then
    printf 'Enumeration broken: %d skill file(s), %d command file(s) — both must be > 0.\n' \
      "${n_skills}" "${n_commands}" >&2
    return 1
  fi
  for f in "${targets[@]}"; do
    rel="${f#${REPO_ROOT}/}"
    # Frontmatter only, via the hardened extractor (see _extract_frontmatter).
    # Template examples inside fenced code blocks further down the body are
    # NOT frontmatter and must never fire; a BOM / leading blank line / CRLF
    # must NOT hide a pin. Test 12 pins both halves of that contract.
    hit="$(_frontmatter_model_hit "${f}")"
    if [[ -n "${hit}" ]]; then
      offenders+=("${rel}: ${hit}")
    fi
  done
  if (( ${#offenders[@]} > 0 )); then
    printf 'Frontmatter model: key found — forbidden in EVERY my/skills SKILL.md (incl. %s) AND every my/commands/*.md.\n' "${LLM_SELECTION_REL}" >&2
    printf 'Model policy lives as PROSE in c-bpm-sk-llm-selection; no file pins a model in frontmatter:\n' >&2
    printf '  %s\n' "${offenders[@]}" >&2
    return 1
  fi
}

# ==================================================================
# Test 9 - [#112] llm-selection ladder + role-directive wording
# ==================================================================

@test "[#112] c-bpm-sk-llm-selection carries the new fallback ladder and the Producer/Judge role directive" {
  _assert_needles "${LLM_SELECTION_REL}" \
    "OPENROUTER_API_KEY" \
    "c-bpm-sk-devils-advocate"

  # Ladder: OpenRouter is the FIRST substitute-Judge tier after Codex.
  # Both the Unicode arrow and the ASCII variant are accepted.
  if ! grep -qiE 'Codex[[:space:]]*(→|->)[[:space:]]*OpenRouter' "${LLM_SELECTION}"; then
    printf 'Missing fallback-ladder wording "Codex -> OpenRouter" (→ or ->) in %s\n' "${LLM_SELECTION_REL}" >&2
    return 1
  fi

  # Role directive: Fable is the default Producer/teammate model.
  if ! grep -qiE 'fable.{0,80}(default|producer|teammate)' "${LLM_SELECTION}"; then
    printf 'Missing role directive "Fable = default Producer/teammate model" in %s\n' "${LLM_SELECTION_REL}" >&2
    return 1
  fi
  # Opus only where Fable is not a fit.
  if ! grep -qiE 'opus.{0,80}(not a fit|only where|only when)' "${LLM_SELECTION}"; then
    printf 'Missing role directive "Opus only where Fable is not a fit" in %s\n' "${LLM_SELECTION_REL}" >&2
    return 1
  fi
  # Codex remains the Judge.
  if ! grep -qiE 'codex.{0,60}judge' "${LLM_SELECTION}"; then
    printf 'Missing role directive "Codex remains the Judge" in %s\n' "${LLM_SELECTION_REL}" >&2
    return 1
  fi

  # Stale bullets that the role directive REPLACES must be gone.
  _assert_absent_needles "${LLM_SELECTION_REL}" \
    "always the newest Opus" \
    "for cross-model validation only" \
    "not yet adopted"
}

# ==================================================================
# Test 10 - [#118] command-side routing: same rules as my/skills/**
#
# The skills already delegate to c-bpm-sk-devils-advocate (Tests 1+2).
# #118 extends the identical contract to my/commands/**:
#   (a) exactly one stamped issue-comms block per command (anti-fake-stamp:
#       strip_stamped() hides anything between ANY BEGIN/END pair, so a
#       second ad-hoc wrapper could smuggle a kept invocation past it),
#   (b) ZERO non-stamped `codex exec` in ANY command — no exemptions;
#       unlike my/skills/**, no command is a sanctioned invocation site,
#   (c) every enumerated #118 call site carries a delegation reference.
#
# Commands with no review gate (library-pull/push/compare, openissues-list)
# are deliberately NOT in the delegation enumeration: adding the reference
# there would be a mechanical prose rewrite, not routing. Rule (b) still
# covers them, so they cannot acquire an invocation later without failing.
# ==================================================================

CALL_SITE_COMMANDS=(
  "my/commands/c-bpm-cm-openissues-team.md"
  "my/commands/c-bpm-cm-refactor-repo.md"
  "my/commands/c-bpm-cm-skill-creator.md"
  "my/commands/c-bpm-cm-skill-optimizer.md"
  "my/commands/c-bpm-cm-goal-issue.md"
)

@test "[#118] no my/commands/*.md contains a non-stamped 'codex exec', and every enumerated call site delegates to c-bpm-sk-devils-advocate" {
  local offenders=()
  local f rel n m

  # --- (a)+(b): drift-guard over EVERY command file ---
  shopt -s nullglob
  local all=( "${REPO_ROOT}"/my/commands/c-bpm-cm-*.md )
  if (( ${#all[@]} == 0 )); then
    printf 'No command files found under my/commands/ — enumeration broken.\n' >&2
    return 1
  fi
  for f in "${all[@]}"; do
    rel="${f#${REPO_ROOT}/}"
    m="$(count_stamp_markers "${f}")"
    if (( m != 1 )); then
      offenders+=("${rel}: ${m} '<!-- BEGIN issue-comms' marker(s), expected exactly 1 (fake stamp block?)")
    fi
    n="$(strip_stamped "${f}" | grep -c -- 'codex exec' || true)"
    if (( n > 0 )); then
      offenders+=("${rel}: ${n} non-stamped 'codex exec' occurrence(s) (must be 0 — route via c-bpm-sk-devils-advocate)")
    fi
  done

  # --- (c): delegation reference on the enumerated #118 call sites ---
  for rel in "${CALL_SITE_COMMANDS[@]}"; do
    f="${REPO_ROOT}/${rel}"
    if [[ ! -f "${f}" ]]; then
      offenders+=("${rel}: file not found")
      continue
    fi
    if ! grep -qF -- 'c-bpm-sk-devils-advocate' "${f}"; then
      offenders+=("${rel}: missing delegation reference to c-bpm-sk-devils-advocate")
    fi
  done

  if (( ${#offenders[@]} > 0 )); then
    printf 'Issue #118 command-side routing incomplete (%d finding(s)):\n' "${#offenders[@]}" >&2
    printf '  %s\n' "${offenders[@]}" >&2
    return 1
  fi
}

# ==================================================================
# Test 11 - [#119] distributed doc defers to c-bpm-sk-llm-selection
#           instead of hard-coding a fallback ladder.
#
# #113 added an OpenRouter tier, so any doc that restates a ladder goes
# stale the moment the policy moves again. The library's own distributed
# text must NAME the authority, never re-enumerate the tiers.
# The same wording is what ~/.claude/CLAUDE.md was rewritten to carry.
# ==================================================================

@test "[#119] no c-bpm doc hard-codes the stale 'Codex -> Gemini -> Claude' ladder; the authority is named instead" {
  cd "${REPO_ROOT}"
  local offenders=()

  # The stale two-hop ladder (Codex -> Gemini -> Claude) with NO OpenRouter
  # tier between them. `[^o]` on the separator keeps this from matching the
  # correct 4-tier ladder in c-bpm-sk-llm-selection / -devils-advocate.
  local bad
  bad="$(grep -rniE --include='*.md' \
    -- 'codex[^a-z]{1,4}(->|→|then)?[^a-z]{0,4}gemini[^a-z]{1,4}(->|→|then)?[^a-z]{0,4}claude' \
    my/ | grep -vi 'openrouter' || true)"
  if [[ -n "${bad}" ]]; then
    offenders+=("stale ladder without an OpenRouter tier:")
    while IFS= read -r line; do offenders+=("  ${line}"); done <<< "${bad}"
  fi

  # Positive: the two policy carriers must name llm-selection as the authority.
  local rel
  for rel in "${LLM_SELECTION_REL}" "${DA_SKILL_REL}"; do
    grep -qF -- 'OpenRouter' "${REPO_ROOT}/${rel}" \
      || offenders+=("${rel}: OpenRouter tier (#113) not mentioned")
  done

  if (( ${#offenders[@]} > 0 )); then
    printf 'Issue #119 ladder-drift guard failed:\n' >&2
    printf '%s\n' "${offenders[@]}" >&2
    return 1
  fi
}

# ==================================================================
# Test 12 - [#121] the frontmatter guard itself is not bypassable.
#
# Test 8 only proves the repo is clean TODAY under whatever logic the
# guard happens to have. This test proves the LOGIC: every fixture below
# is a real file fed to the real helper.
#
# The four "must DETECT" fixtures are exactly the shapes that slipped
# past the original `NR==1 && $0=="---"` guard — each one carries a
# `model:` pin and MUST be caught. The "must NOT fire" fixtures pin the
# other half of the contract: prose and fenced YAML templates that merely
# mention a model are legitimate documentation and must stay silent.
#
# Revert _extract_frontmatter to the naive version and the BOM, leading
# blank line and CRLF cases go green-when-they-should-be-red — which is
# the whole point of this test.
# ==================================================================

@test "[#121] frontmatter guard detects model: pins hidden by BOM / blank lines / CRLF, and stays silent on prose" {
  # No RETURN trap here: under bats it aborts the test process outright and
  # the case silently disappears from the run ("Executed 11 instead of 12").
  # Both verdicts are computed FIRST, the tmpdir is removed, and only then
  # are the assertions made — so cleanup happens on every path.
  local tmp
  tmp="$(mktemp -d)"

  # ---- MUST DETECT: a model: pin in frontmatter, however disguised ----
  # 1. UTF-8 BOM before the opening delimiter.
  printf '\xEF\xBB\xBF---\nname: x\nmodel: opus\n---\nbody\n'      > "${tmp}/bom.md"
  # 2. Leading blank lines before the opening delimiter.
  printf '\n\n---\nname: x\nmodel: opus\n---\nbody\n'              > "${tmp}/blank.md"
  # 3. CRLF line endings — the trailing \r broke the exact `---` compare.
  printf -- '---\r\nname: x\r\nmodel: opus\r\n---\r\nbody\r\n'     > "${tmp}/crlf.md"
  # 4. `...` YAML end-of-document terminator instead of `---`.
  printf -- '---\nname: x\nmodel: opus\n...\nbody\n'               > "${tmp}/dots.md"
  # 5. Indented key — YAML tolerates leading space, so the guard must too.
  printf -- '---\nname: x\n  model: opus\n---\nbody\n'             > "${tmp}/indent.md"

  local must_detect=(bom blank crlf dots indent)
  local missed=() name
  for name in "${must_detect[@]}"; do
    if [[ -z "$(_frontmatter_model_hit "${tmp}/${name}.md")" ]]; then
      missed+=("${name}.md: frontmatter 'model:' pin NOT detected — guard is bypassable")
    fi
  done

  # ---- MUST NOT FIRE: model mentioned in the BODY, not the frontmatter ----
  # 6. Fenced YAML template in the body (this is the real shape in
  #    c-bpm-sk-skill-creator / -skill-optimizer).
  printf -- '---\nname: x\n---\n\n```yaml\nmodel: opus   # example\n```\n' > "${tmp}/template.md"
  # 7. Prose that merely mentions the key.
  printf -- '---\nname: x\n---\n\nNever add a `model:` key.\nmodel: opus\n'  > "${tmp}/prose.md"
  # 8. No frontmatter at all — a body line must not be read as frontmatter.
  printf -- 'Some doc\nmodel: opus\n'                                        > "${tmp}/nofm.md"
  # 9. `...` terminator with the pin AFTER it — body, so not a violation.
  printf -- '---\nname: x\n...\nmodel: opus\n'                               > "${tmp}/after-dots.md"

  local must_be_silent=(template prose nofm after-dots)
  local false_fires=()
  for name in "${must_be_silent[@]}"; do
    if [[ -n "$(_frontmatter_model_hit "${tmp}/${name}.md")" ]]; then
      false_fires+=("${name}.md: guard fired on a BODY mention — it must inspect frontmatter only")
    fi
  done

  rm -rf "${tmp}"

  if (( ${#missed[@]} > 0 || ${#false_fires[@]} > 0 )); then
    printf 'Frontmatter guard contract broken:\n' >&2
    if (( ${#missed[@]} > 0 )); then
      printf '  BYPASS  %s\n' "${missed[@]}" >&2
    fi
    if (( ${#false_fires[@]} > 0 )); then
      printf '  FALSE+  %s\n' "${false_fires[@]}" >&2
    fi
    return 1
  fi
}

# ==================================================================
# #137 - the Critic: adversarial stance + graded verdict output contract
# ==================================================================

@test "[#137] devils-advocate documents the two concerns and the single Critic role" {
  grep -qF 'Critic' "${DA_SKILL}"
  grep -qiF 'stance' "${DA_SKILL}"
  grep -qiF 'verdict' "${DA_SKILL}"
}

@test "[#137] every verdict returns per-dimension scores, TOTAL and an explicit PASS/FAIL by reference to the canonical rubric" {
  grep -qiF 'per-dimension score' "${DA_SKILL}"
  grep -qF 'TOTAL' "${DA_SKILL}"
  grep -qF 'PASS' "${DA_SKILL}"
  grep -qF 'FAIL' "${DA_SKILL}"
  grep -qF 'canonical review rubric in `c-bpm-sk-llm-selection`' "${DA_SKILL}"
}

@test "[#137] the verdict tags each finding blocking vs residual-acceptable and names the incomplete-verdict rule" {
  grep -qF 'blocking' "${DA_SKILL}"
  grep -qF 'residual-acceptable' "${DA_SKILL}"
  grep -qiF 'incomplete verdict' "${DA_SKILL}"
}

@test "[#137] the #135 noise guard: per-finding evidence-verified requirement" {
  grep -qiF 'verified' "${DA_SKILL}"
  grep -qiF 'inferred' "${DA_SKILL}"
  grep -qF '#135' "${DA_SKILL}"
}

@test "[#137] single-source preserved: devils-advocate does not restate the numeric threshold" {
  ! grep -qF 'TOTAL >= 20' "${DA_SKILL}"
}
