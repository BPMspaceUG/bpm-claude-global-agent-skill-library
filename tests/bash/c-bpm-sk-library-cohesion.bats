#!/usr/bin/env bats
#
# c-bpm-sk-library-cohesion.bats — guards for issues #50, #51, #52, #54, #55, #56,
#                                  #139, #140
# Run with: bats tests/bash/c-bpm-sk-library-cohesion.bats
#
# Purpose:
#   #52 The description of c-bpm-sk-skill-creator / c-bpm-sk-skill-optimizer must use
#       the library's em-dash convention. lib.sh only derives trigger keywords from a
#       description containing " — "; an outlier silently loses every trigger keyword.
#   #50 Skills whose ordinary-English triggers can carry the router all the way to a
#       high-impact mutation must declare `disable-model-invocation: true`. The set is
#       adjudicated (see the criterion at NO_AUTO_INVOKE_SKILLS below) — it is NOT
#       "everything destructive". Asserted in BOTH directions: present on exactly the
#       adjudicated set, absent everywhere else.
#   #51 Tech-specific skills must declare `paths` frontmatter so they only activate in
#       repos of that technology. Existence of `paths` is NOT enough: a glob such as
#       `**/*.sql` or `**/*.conf` fires in almost every repo, which is cosmetic
#       compliance rather than scoping. So `paths` is asserted three ways —
#       lexically (no non-selective pattern shape), negatively (the globs must not
#       fire on a generic unrelated repo fixture) and positively (they must fire on a
#       fixture of their own technology).
#   #54 The structural scorecard for c-bpm-sk-* audits is documented.
#   #55 The principled-split policy ("do not merge") is documented, and the
#       creator/optimizer pair links to it.
#   #56 The F3 Must-Stay Rule is adopted in skill-creator, skill-optimizer and
#       library-manager.
#  #139 The two authoring skills (skill-creator, skill-optimizer) must not TEACH a
#       frontmatter `model:` key while also forbidding it. They generate other skills,
#       so a recommendation here propagates a #121 violation into every skill built
#       from the template. The guard must pass the prohibition prose and fail the
#       recommendation — both name the key, only the polarity differs.
#  #140 The fenced YAML template EXAMPLES in those two skills must parse. The #52
#       parse test below reads each file's real frontmatter and is therefore
#       structurally blind to a broken sample block.
#
#   Every assertion below is exercised against a MUTATED fixture (property removed) to
#   prove the guard actually fails — a guard that passes either way is worthless.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
SKILLS_DIR="${REPO_ROOT}/my/skills"

CREATOR="${SKILLS_DIR}/c-bpm-sk-skill-creator/SKILL.md"
OPTIMIZER="${SKILLS_DIR}/c-bpm-sk-skill-optimizer/SKILL.md"
LIBMGR="${SKILLS_DIR}/c-bpm-sk-library-manager/SKILL.md"
AUDIT_POLICY="${SKILLS_DIR}/c-bpm-sk-library-manager/references/skill-audit-policy.md"

# --- #52: the two skills normalized to the em-dash convention -----------------
EMDASH_SKILLS=(
  c-bpm-sk-skill-creator
  c-bpm-sk-skill-optimizer
)

# --- #50: the no-auto-invoke set ---------------------------------------------
# DO NOT re-derive this list from the word "destructive". That reading was tried,
# collided head-on with #41 (already test-approved), and was adjudicated against on
# #138. The criterion is "common-trigger skills that can autonomously reach
# high-impact mutation" — all four facets must hold:
#
#   1. common-language trigger likelihood — the trigger phrases are ordinary English
#      ("cut a release", "audit this host") that the stock router can match on a
#      passing remark, with no explicit invocation from the user;
#   2. autonomous path to mutation — once fired it can reach the mutating step
#      without a fresh user checkpoint;
#   3. external / hard to reverse — the mutation lands outside the working tree:
#      live host state, a remote repo, a published tag or artefact;
#   4. blast radius — the damage is not confined to one reviewable file.
#
# A skill that merely *can* mutate does NOT qualify. Interactive, target-required
# workflows that stop and ask before acting (grill-me-issue, grill-claude-issue,
# idea-merge) are deliberately OUT: they need an issue/repo argument, they scan
# before they touch, and their worst case is extra comments. Likewise the audit and
# authoring skills (auditor, skill-creator, skill-optimizer) stay out — #41's demand
# to flag them was ruled overreach.
NO_AUTO_INVOKE_SKILLS=(
  c-bpm-sk-linux-admin          # apt / systemctl — mutates the live host
  c-bpm-sk-linux-archive        # clones a host repo, copies configs, commits, pushes
  c-bpm-sk-linux-audit          # opens Issues and can bootstrap repo + milestones
                                # before any user checkpoint
  c-bpm-sk-release-ops          # "cut a release" is ordinary English → tags,
                                # artefacts, deployment
)

# --- #51: the tech-specific set ----------------------------------------------
TECH_SKILLS=(
  c-bpm-sk-bash-secure-script
  c-bpm-sk-flightphp-pro
  c-bpm-sk-mariadb-migrations
  c-bpm-sk-n8n-reliability
  c-bpm-sk-php-crud-api-review
  c-bpm-sk-redis-keyspace
  c-bpm-sk-tls-http-headers
)

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# Print ONLY a file's YAML frontmatter. Strips a UTF-8 BOM and CRLF line endings
# first so a pin cannot be smuggled past the guard by encoding tricks; a file whose
# first line is not the `---` delimiter has no frontmatter and yields nothing.
_fm() {
  sed -e '1s/^\xEF\xBB\xBF//' -e 's/\r$//' "$1" \
    | awk 'NR==1 && $0 != "---" { exit } NR==1 { next } /^(---|\.\.\.)$/ { exit } { print }'
}

_has_disable_model_invocation() {
  _fm "$1" | grep -qE '^[[:space:]]*disable-model-invocation:[[:space:]]*true[[:space:]]*$'
}

_has_paths() {
  _fm "$1" | grep -qE '^[[:space:]]*paths:[[:space:]]*\[.*\][[:space:]]*$'
}

# Print one glob per line from a skill's `paths:` frontmatter list.
_paths_globs() {
  _fm "$1" | grep -E '^paths:' | grep -oE "'[^']+'" | tr -d "'"
}

# Selectivity checker (#51). Reads globs as argv, prints "glob<TAB>reason" for each
# pattern that cannot plausibly distinguish a repo of the technology from any repo
# that merely happens to contain a file of that shape. Silence == all selective.
#
# The three rejected shapes, each an actual Codex finding on the first #51 attempt:
#   1. extension-only wildcard over an extension shared by many technologies
#      (`**/*.sql`, `**/*.conf`) — every repo has a stray dump or config file;
#   2. a bare ubiquitous filename with no qualifying path segment
#      (`composer.json`, `**/api.php`) — present in whole ecosystems, not one tech;
#   3. a bare ubiquitous directory (`**/cache/**`, `**/bin/**`) — a generic layout
#      convention, not a technology marker.
# An extension NOT in the shared list (`.sh`, `.redis`, `.n8n.json`) is accepted as
# selective: that extension is produced by the technology itself, so the file being
# open IS the activation signal.
_selectivity_check() {
  python3 -c '
import re, sys
SHARED_EXT = {"sql","conf","cnf","json","php","js","jsx","ts","tsx","py","rb","go",
              "yml","yaml","xml","ini","toml","md","txt","env","html","css","log"}
UBIQUITOUS_FILE = {"composer.json","package.json","package-lock.json","api.php",
                   "index.php","config.php","settings.php","Makefile","Dockerfile",
                   "docker-compose.yml",".env","README.md","tsconfig.json"}
UBIQUITOUS_DIR = {"cache","tmp","temp","src","lib","libs","app","config","data",
                  "logs","log","public","www","bin","sbin","dist","build","vendor",
                  "node_modules","tests","test","scripts","etc","var","assets","docs"}

def why(p):
    core = p[3:] if p.startswith("**/") else p
    m = re.fullmatch(r"\*\.([A-Za-z0-9.]+)", core)
    if m and m.group(1).lower() in SHARED_EXT:
        return "extension-only glob over the shared extension .%s — fires in any repo holding one such file" % m.group(1)
    if core in UBIQUITOUS_FILE:
        return "bare ubiquitous filename %s with no qualifying path segment" % core
    m = re.fullmatch(r"([A-Za-z0-9_.-]+)/\*\*/?\*?", core)
    if m and m.group(1).lower() in UBIQUITOUS_DIR:
        return "bare ubiquitous directory %s/ — a generic layout convention, not a technology marker" % m.group(1)
    return None

for p in sys.argv[1:]:
    r = why(p)
    if r:
        print("%s\t%s" % (p, r))
' "$@"
}

# Build a throwaway repo tree from "relative/path" arguments (dirs implied).
_make_tree() {
  local root="$1"; shift
  local rel
  for rel in "$@"; do
    if [[ "${rel}" == */ ]]; then
      mkdir -p "${root}/${rel}"
    else
      mkdir -p "${root}/$(dirname "${rel}")"
      : > "${root}/${rel}"
    fi
  done
}

# Print the number of paths in ${root} matched by the globs given as argv.
_glob_hits() {
  local root="$1"; shift
  python3 -c '
import glob, sys
root = sys.argv[1]
hits = set()
for p in sys.argv[2:]:
    hits.update(glob.glob(p, root_dir=root, recursive=True))
for h in sorted(hits):
    print(h)
' "${root}" "$@"
}

# A generic repo that uses NONE of the technologies in TECH_SKILLS: a plain PHP/JS
# app with the incidental files the rejected globs used to latch onto.
GENERIC_REPO_FILES=(
  composer.json package.json README.md
  src/Controller/UserController.php
  public/index.php public/api.php
  db/dump.sql
  etc/supervisor.conf
  cache/twig/6a/tpl.php
  bin/console
  node_modules/.bin/eslint
  deploy.sh
)

# One file per technology that unambiguously identifies it — the positive control,
# so a glob cannot pass the negative fixture by being narrow to the point of dead.
#
# Deliberately a case statement, NOT `declare -A`: bats evaluates the preprocessed
# test file inside a function, which makes `declare` FUNCTION-LOCAL. An associative
# array declared here is simply gone by the time a @test body runs, and the lookup
# degrades to an arithmetic subscript ("c: unbound variable") instead of failing
# honestly. Plain assignments survive; `declare` does not.
_tech_fixture() {
  case "$1" in
    c-bpm-sk-bash-secure-script)  printf 'scripts/install.sh' ;;
    c-bpm-sk-flightphp-pro)       printf 'vendor/flightphp/core/flight/Flight.php' ;;
    c-bpm-sk-mariadb-migrations)  printf 'db/migrations/20260701_add_column.sql' ;;
    c-bpm-sk-n8n-reliability)     printf 'workflows/order-intake.n8n.json' ;;
    c-bpm-sk-php-crud-api-review) printf 'vendor/mevdschee/php-crud-api/api.php' ;;
    c-bpm-sk-redis-keyspace)      printf 'src/Cache/RedisClient.php' ;;
    c-bpm-sk-tls-http-headers)    printf 'etc/nginx/nginx.conf' ;;
    *)                            printf '' ;;
  esac
}

# `paths` on this skill is FILE-scoped, not repo-scoped: a shell script is in scope
# wherever it lives, so `**/*.sh` matching a generic repo's deploy.sh is correct
# behaviour, not a false fire. Every other tech skill claims REPO scoping.
FILE_SCOPED_SKILLS=(c-bpm-sk-bash-secure-script)

# The em-dash convention: description is a single-line double-quoted scalar whose
# value contains the " — " separator that lib.sh keys trigger extraction off.
_has_emdash_description() {
  _fm "$1" | grep -qE '^description: ".* — .*"$'
}

# Reimplements the keyword derivation in lib.sh (name parts >=3 chars, spaced name,
# full name, plus comma-separated trigger phrases from the description segment after
# " — " up to the first ". "), and prints the resulting keyword count.
_keyword_count() {
  _fm "$1" | python3 -c '
import re, sys
fm = sys.stdin.read()
name = re.search(r"^name:\s*(\S+)", fm, re.M).group(1)
m = re.search(r"^description:\s*\"(.*)\"\s*$", fm, re.M)
desc = m.group(1) if m else ""
short = name[len("c-bpm-sk-"):] if name.startswith("c-bpm-sk-") else name
kw = [p for p in short.split("-") if len(p) >= 3]
kw.append(short.replace("-", " "))
kw.append(name)
if " — " in desc:
    seg = desc.split(" — ", 1)[1].split(". ", 1)[0]
    kw += [p.strip() for p in seg.split(",") if p.strip()]
print(len(kw))
'
}

# --- #139 / #140: the authoring skills, whose templates are copied into new skills
AUTHORING_SKILLS=(
  c-bpm-sk-skill-creator
  c-bpm-sk-skill-optimizer
)

# #139 — template-content guard.
# Prints "file:line<TAB>reason<TAB>text" for every line of an authoring skill that
# TEACHES a frontmatter `model:` key. Silence == clean.
#
# The hard part is polarity, not detection. Both of these name the key:
#     | Does it need a specific model? | `model: opus` |     <- teaches it   (violation)
#     **No `model:` key, ever** (#121).                      <- forbids it   (must pass)
# A guard that greps for the token alone fires on the prohibition and would force
# deleting the very rule it exists to protect. So each hit is classified by the
# polarity of its own line, and only unforbidden references count.
#
# Two detection rules:
#   1. anywhere in the body — a reference to the KEY (`model`, `model:`, `model: x`)
#      on a line carrying no prohibition marker;
#   2. inside a fenced ```yaml block — a real YAML key line (`^  model: value`)
#      UNCONDITIONALLY. A key in a copy-paste template is a key whatever the
#      surrounding prose says; a YAML comment (`# never a model: key`) is not a key
#      line and is therefore untouched by this rule.
#
# NOT a hit: the English word "model" without the key shape — e.g. the neighbouring
# row "| `effort` | Override model effort level |" must stay legal.
_model_teaching_hits() {
  python3 - "$@" <<'PY'
import re, sys

KEY_REF = re.compile(r"`model`|(?<![\w-])model[ \t]*:")
PROHIBITION = re.compile(
    r"\b(no|never|not|without|forbid|forbids|forbidden|prohibit\w*|bans?|banned|"
    r"bypass\w*|disallow\w*|reject\w*|remove\w*|strip\w*|violat\w*)\b|#121",
    re.I)
FENCE_YAML = re.compile(r"^[ \t]*```[ \t]*ya?ml[ \t]*$", re.I)
FENCE_ANY = re.compile(r"^[ \t]*```")
YAML_KEY = re.compile(r"^[ \t]*model[ \t]*:[ \t]*\S")

hits = []
for path in sys.argv[1:]:
    in_yaml = False
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if in_yaml:
            if FENCE_ANY.match(line):
                in_yaml = False
                continue
            if YAML_KEY.match(line):
                hits.append((path, n, "model: key in a fenced YAML template block", line))
                continue
        elif FENCE_YAML.match(line):
            in_yaml = True
            continue
        if KEY_REF.search(line) and not PROHIBITION.search(line):
            hits.append((path, n, "teaches a model: key (no prohibition on this line)", line))
for p, n, why, text in hits:
    print("%s:%d\t%s\t%s" % (p, n, why, text.strip()))
PY
}

# #140 — fenced-YAML template guard.
# Parses each ```yaml block in the given files. The frontmatter parse test above is
# STRUCTURALLY BLIND to these: a template example is not the file's frontmatter, so
# an unparseable sample block ships happily and every skill copied from it is born
# with frontmatter YAML cannot read. Prints one error per broken block; silence == ok.
_fenced_yaml_errors() {
  python3 - "$@" <<'PY'
import re, sys, yaml
FENCE = re.compile(r"^[ \t]*```[ \t]*ya?ml[ \t]*\n(.*?)^[ \t]*```[ \t]*$", re.M | re.S | re.I)
for path in sys.argv[1:]:
    text = open(path, encoding="utf-8").read()
    for m in FENCE.finditer(text):
        block = m.group(1)
        line = text[:m.start(1)].count("\n") + 1
        try:
            docs = list(yaml.safe_load_all(block))
        except Exception as e:
            print("%s:%d\t%s: %s" % (path, line, type(e).__name__, str(e).splitlines()[0]))
            continue
        if not any(isinstance(d, dict) and d for d in docs):
            print("%s:%d\tblock parses but yields no mapping" % (path, line))
PY
}

# Number of fenced ```yaml blocks found — asserted non-zero so the extraction regex
# cannot silently stop matching and turn the guard above into a no-op.
_fenced_yaml_count() {
  python3 - "$1" <<'PY'
import re, sys
FENCE = re.compile(r"^[ \t]*```[ \t]*ya?ml[ \t]*\n(.*?)^[ \t]*```[ \t]*$", re.M | re.S | re.I)
print(len(FENCE.findall(open(sys.argv[1], encoding="utf-8").read())))
PY
}

# Re-break the #140 defect: un-escape the backslash INSIDE the fenced template block
# only, leaving the file's real frontmatter untouched. That asymmetry is the point of
# the mutation test — it reproduces exactly the state the old guard could not see.
_break_template_escape() {
  python3 - "$1" "$2" <<'PY'
import sys
src, dest = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
i = text.index("```yaml")
head, tail = text[:i], text[i:]
j = tail.index("\n```", 3)
block, rest = tail[:j], tail[j:]
broken = block.replace("2\\\\.0", "2\\.0")
if broken == block:
    sys.exit("fixture did not change: the template no longer contains the escape")
open(dest, "w", encoding="utf-8").write(head + broken + rest)
PY
}

# Parse ONLY a file's real frontmatter — the pre-existing #52 check, isolated here so
# a test can demonstrate what it does and does not see.
_frontmatter_parses() {
  python3 - "$1" <<'PY'
import sys, yaml
t = open(sys.argv[1], encoding="utf-8").read()
if not t.startswith("---\n"):
    sys.exit(1)
d = yaml.safe_load(t[4:t.index("\n---\n", 3) + 1])
sys.exit(0 if isinstance(d, dict) and d.get("description") else 1)
PY
}

# Copy a SKILL.md to a temp file with a frontmatter line removed, for mutation tests.
_fixture_without() {
  local src="$1" pattern="$2" dest="$3"
  grep -vE "${pattern}" "${src}" > "${dest}"
  ! diff -q "${src}" "${dest}" >/dev/null   # the mutation must have changed something
}

setup() {
  TMPD="$(mktemp -d)"
}

teardown() {
  rm -rf "${TMPD:-}"
}

# =============================================================================
# #52 — description convention
# =============================================================================

@test "[#52] skill-creator and skill-optimizer use the em-dash description convention" {
  local bad=()
  local s f
  for s in "${EMDASH_SKILLS[@]}"; do
    f="${SKILLS_DIR}/${s}/SKILL.md"
    [[ -f "${f}" ]] || { bad+=("${s}: SKILL.md missing"); continue; }
    _has_emdash_description "${f}" || bad+=("${s}: description is not a single-line \" … — … \" scalar")
  done
  if (( ${#bad[@]} )); then
    printf '#52 description convention violated:\n'; printf '  %s\n' "${bad[@]}"
    return 1
  fi
}

@test "[#52] both descriptions yield >= 8 lib.sh keywords (the 4-keyword outlier bug is fixed)" {
  local bad=()
  local s f n
  for s in "${EMDASH_SKILLS[@]}"; do
    f="${SKILLS_DIR}/${s}/SKILL.md"
    n="$(_keyword_count "${f}")"
    (( n >= 8 )) || bad+=("${s}: only ${n} keywords (need >= 8)")
  done
  if (( ${#bad[@]} )); then
    printf '#52 keyword regression:\n'; printf '  %s\n' "${bad[@]}"
    return 1
  fi
}

@test "[#52] every c-bpm-sk-* frontmatter is parseable YAML (a broken block loses the description entirely)" {
  python3 - "${SKILLS_DIR}" <<'PY'
import glob, os, sys, yaml
bad = []
for p in sorted(glob.glob(os.path.join(sys.argv[1], "c-bpm-sk-*", "SKILL.md"))):
    t = open(p, encoding="utf-8").read()
    if not t.startswith("---\n"):
        bad.append(f"{p}: no frontmatter"); continue
    try:
        d = yaml.safe_load(t[4:t.index("\n---\n", 3) + 1])
    except Exception as e:
        bad.append(f"{p}: {type(e).__name__}"); continue
    if not isinstance(d, dict) or not d.get("description"):
        bad.append(f"{p}: no description key")
if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
PY
}

@test "[#52] the guard fails when the em-dash is removed (mutation check)" {
  local mutated="${TMPD}/nodash.md"
  sed 's/ — / - /' "${CREATOR}" > "${mutated}"
  ! diff -q "${CREATOR}" "${mutated}" >/dev/null
  if _has_emdash_description "${mutated}"; then
    printf 'Guard is vacuous: it accepted a description with the em-dash removed.\n' >&2
    return 1
  fi
  local n; n="$(_keyword_count "${mutated}")"
  if (( n >= 8 )); then
    printf 'Keyword guard is vacuous: %s keywords without an em-dash.\n' "${n}" >&2
    return 1
  fi
}

# =============================================================================
# #50 — disable-model-invocation, asserted in BOTH directions
# =============================================================================

@test "[#50] every adjudicated no-auto-invoke skill declares disable-model-invocation: true" {
  local missing=()
  local s f
  for s in "${NO_AUTO_INVOKE_SKILLS[@]}"; do
    f="${SKILLS_DIR}/${s}/SKILL.md"
    [[ -f "${f}" ]] || { missing+=("${s}: SKILL.md missing"); continue; }
    _has_disable_model_invocation "${f}" || missing+=("${s}")
  done
  if (( ${#missing[@]} )); then
    printf '#50 adjudicated no-auto-invoke skills without disable-model-invocation: true:\n'
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

@test "[#50] no skill outside the adjudicated set declares disable-model-invocation (set is exact)" {
  local unexpected=()
  local d s
  for d in "${SKILLS_DIR}"/c-bpm-sk-*/; do
    s="$(basename "${d}")"
    [[ -f "${d}SKILL.md" ]] || continue
    case " ${NO_AUTO_INVOKE_SKILLS[*]} " in *" ${s} "*) continue ;; esac
    if _has_disable_model_invocation "${d}SKILL.md"; then
      unexpected+=("${s}")
    fi
  done
  if (( ${#unexpected[@]} )); then
    printf '#50 disable-model-invocation on a skill outside the adjudicated set.\n'
    printf 'The bar is all four facets of the criterion above (common-language trigger,\n'
    printf 'autonomous path to mutation, external/hard-to-reverse, wide blast radius) —\n'
    printf '"it can mutate things" is NOT sufficient. Either the skill clears that bar\n'
    printf '(add it to NO_AUTO_INVOKE_SKILLS with a justification) or remove the field:\n'
    printf '  %s\n' "${unexpected[@]}"
    return 1
  fi
}

@test "[#50] disable-model-invocation must sit in frontmatter, not prose (guard is not a plain grep)" {
  local body="${TMPD}/body-only.md"
  printf -- '---\nname: c-bpm-sk-x\n---\n\nNever set disable-model-invocation: true here.\n' > "${body}"
  # A naive whole-file grep would pass on this fixture...
  grep -q 'disable-model-invocation: true' "${body}"
  # ...the frontmatter-scoped guard must not.
  if _has_disable_model_invocation "${body}"; then
    printf 'Guard fired on a BODY mention — it must inspect frontmatter only.\n' >&2
    return 1
  fi
}

@test "[#50] the guard fails when the field is removed (mutation check)" {
  local s f mutated
  for s in "${NO_AUTO_INVOKE_SKILLS[@]}"; do
    f="${SKILLS_DIR}/${s}/SKILL.md"
    mutated="${TMPD}/$(basename "${s}").md"
    _fixture_without "${f}" '^disable-model-invocation:' "${mutated}"
    if _has_disable_model_invocation "${mutated}"; then
      printf 'Guard is vacuous for %s: it passed after the field was stripped.\n' "${s}" >&2
      return 1
    fi
  done
}

# =============================================================================
# #51 — paths frontmatter on tech-specific skills
# =============================================================================

@test "[#51] every tech-specific skill declares paths frontmatter" {
  local missing=()
  local s f
  for s in "${TECH_SKILLS[@]}"; do
    f="${SKILLS_DIR}/${s}/SKILL.md"
    [[ -f "${f}" ]] || { missing+=("${s}: SKILL.md missing"); continue; }
    _has_paths "${f}" || missing+=("${s}")
  done
  if (( ${#missing[@]} )); then
    printf '#51 tech-specific skills without paths frontmatter:\n'
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

@test "[#51] declared paths globs are non-empty and contain no bare repo-root wildcard" {
  local bad=()
  local s f line
  for s in "${TECH_SKILLS[@]}"; do
    f="${SKILLS_DIR}/${s}/SKILL.md"
    line="$(_fm "${f}" | grep -E '^paths:' || true)"
    [[ -n "${line}" ]] || { bad+=("${s}: no paths line"); continue; }
    # Codex constraint: no glob that matches every file in the repo.
    if grep -qE "'(\*|\*\*|\*\*/\*)'" <<<"${line}"; then
      bad+=("${s}: repo-root wildcard in ${line}")
    fi
  done
  if (( ${#bad[@]} )); then
    printf '#51 paths glob problems:\n'; printf '  %s\n' "${bad[@]}"
    return 1
  fi
}

@test "[#51] no declared paths glob is a non-selective (cosmetic) pattern" {
  local bad=() s f out
  for s in "${TECH_SKILLS[@]}"; do
    f="${SKILLS_DIR}/${s}/SKILL.md"
    mapfile -t globs < <(_paths_globs "${f}")
    (( ${#globs[@]} )) || { bad+=("${s}: paths declares no glob"); continue; }
    out="$(_selectivity_check "${globs[@]}")"
    [[ -z "${out}" ]] || bad+=("${s}: ${out//$'\n'/ | }")
  done
  if (( ${#bad[@]} )); then
    printf '#51 cosmetic paths globs — scoping is implied but does not exist:\n'
    printf '  %s\n' "${bad[@]}"
    return 1
  fi
}

@test "[#51] the selectivity guard rejects the pre-fix broad globs (regression proof)" {
  # The exact patterns Codex rejected. If any of these ever passes the checker, the
  # checker has been weakened and #51 can silently regress to cosmetic compliance.
  local p out
  for p in 'composer.json' '**/*.sql' '**/api.php' '**/cache/**' '**/*.conf' '**/bin/**'; do
    out="$(_selectivity_check "${p}")"
    if [[ -z "${out}" ]]; then
      printf 'Selectivity guard is vacuous: it accepted the rejected glob %s\n' "${p}" >&2
      return 1
    fi
  done
}

@test "[#51] no repo-scoped tech skill fires on a generic unrelated repo (behavioural)" {
  local generic="${TMPD}/generic"
  _make_tree "${generic}" "${GENERIC_REPO_FILES[@]}"
  local bad=() s f hits
  for s in "${TECH_SKILLS[@]}"; do
    case " ${FILE_SCOPED_SKILLS[*]} " in *" ${s} "*) continue ;; esac
    f="${SKILLS_DIR}/${s}/SKILL.md"
    mapfile -t globs < <(_paths_globs "${f}")
    hits="$(_glob_hits "${generic}" "${globs[@]}")"
    [[ -z "${hits}" ]] || bad+=("${s}: matched ${hits//$'\n'/, }")
  done
  if (( ${#bad[@]} )); then
    printf '#51 paths fired on a repo using none of these technologies:\n'
    printf '  %s\n' "${bad[@]}"
    return 1
  fi
}

@test "[#51] every tech skill fires on a fixture of its own technology" {
  local bad=() s f fx hits
  for s in "${TECH_SKILLS[@]}"; do
    f="${SKILLS_DIR}/${s}/SKILL.md"
    fx="$(_tech_fixture "${s}")"
    [[ -n "${fx}" ]] || { bad+=("${s}: no positive fixture declared"); continue; }
    _make_tree "${TMPD}/pos-${s}" "${fx}"
    mapfile -t globs < <(_paths_globs "${f}")
    hits="$(_glob_hits "${TMPD}/pos-${s}" "${globs[@]}")"
    [[ -n "${hits}" ]] || bad+=("${s}: no glob matched ${fx}")
  done
  if (( ${#bad[@]} )); then
    printf '#51 paths are narrow to the point of dead:\n'; printf '  %s\n' "${bad[@]}"
    return 1
  fi
}

@test "[#51] the guard fails when paths is removed (mutation check)" {
  local s f mutated
  for s in "${TECH_SKILLS[@]}"; do
    f="${SKILLS_DIR}/${s}/SKILL.md"
    mutated="${TMPD}/paths-$(basename "${s}").md"
    _fixture_without "${f}" '^paths:' "${mutated}"
    if _has_paths "${mutated}"; then
      printf 'Guard is vacuous for %s: it passed after paths was stripped.\n' "${s}" >&2
      return 1
    fi
  done
}

# =============================================================================
# #54 / #55 / #56 — the policy unit. Presence of the policy statements only:
# this unit is governance PROSE, so no behavioural assertions are invented for it.
# =============================================================================

@test "[#54] library-manager documents the structural scorecard and its threshold" {
  grep -qF "Structural Scorecard" "${LIBMGR}"
  grep -qF "5/6" "${LIBMGR}"
  grep -qF "Trigger discoverability" "${LIBMGR}"
  grep -qF "Intent coverage" "${LIBMGR}"
  grep -qF "Tool boundary" "${LIBMGR}"
  grep -qF "Argument awareness" "${LIBMGR}"
  grep -qF "Token efficiency" "${LIBMGR}"
  grep -qF "No content duplication" "${LIBMGR}"
}

@test "[#54] library-manager documents the library-wide cohesion metrics" {
  grep -qiF "description conformance" "${LIBMGR}"
  grep -qiF "trigger collision" "${LIBMGR}"
  grep -qiF "lifecycle coverage" "${LIBMGR}"
  grep -qiF "context budget" "${LIBMGR}"
}

@test "[#54/#55/#56] the audit-policy reference exists and carries all three policy sections" {
  [[ -f "${AUDIT_POLICY}" ]]
  grep -qF "structural scorecard" "${AUDIT_POLICY}"
  grep -qF "Principled splits" "${AUDIT_POLICY}"
  grep -qF "Must-Stay Rule" "${AUDIT_POLICY}"
  grep -qF "#54" "${AUDIT_POLICY}"
  grep -qF "#55" "${AUDIT_POLICY}"
  grep -qF "#56" "${AUDIT_POLICY}"
}

@test "[#55] library-manager documents the principled splits and names all three families" {
  grep -qF "Principled Splits (do not merge)" "${LIBMGR}"
  grep -qF "c-bpm-sk-grill-claude-issue" "${LIBMGR}"
  grep -qF "c-bpm-sk-skill-optimizer" "${LIBMGR}"
  grep -qF "c-bpm-sk-linux-archive" "${LIBMGR}"
  grep -qiF "looks redundant" "${LIBMGR}"
}

@test "[#55] skill-creator and skill-optimizer each carry a 'why we are not merged' footer" {
  grep -qF "not merged with \`c-bpm-sk-skill-optimizer\`" "${CREATOR}"
  grep -qF "not merged with \`c-bpm-sk-skill-creator\`" "${OPTIMIZER}"
  grep -qF "principled split" "${CREATOR}"
  grep -qF "principled split" "${OPTIMIZER}"
}

@test "[#56] the F3 Must-Stay Rule is adopted in all three skills" {
  local f missing=()
  for f in "${CREATOR}" "${OPTIMIZER}" "${LIBMGR}"; do
    grep -qF "Must-Stay Rule (F3)" "${f}" || missing+=("${f}: no 'Must-Stay Rule (F3)' section")
  done
  if (( ${#missing[@]} )); then
    printf '#56 not adopted:\n'; printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

@test "[#56] each Must-Stay adoption enumerates the protected items and the may-move set" {
  local f item missing=()
  for f in "${CREATOR}" "${OPTIMIZER}" "${LIBMGR}"; do
    for item in "Safety constraints" "phase gates" "Critical fallback chain" \
                "MVP scope exclusions" "Non-obvious defaults" "May move to"; do
      grep -qF "${item}" "${f}" || missing+=("$(basename "$(dirname "${f}")"): missing '${item}'")
    done
  done
  if (( ${#missing[@]} )); then
    printf '#56 incomplete Must-Stay list:\n'; printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

@test "[#56] the verification protocol is reachable from every adopting skill" {
  local f
  for f in "${CREATOR}" "${OPTIMIZER}" "${LIBMGR}"; do
    grep -qF "skill-audit-policy.md" "${f}"
  done
  grep -qF "when do I invoke this?" "${AUDIT_POLICY}"
  grep -qF "what must I never do here?" "${AUDIT_POLICY}"
}

@test "[#54/#55/#56] the policy guards fail when the policy text is removed (mutation check)" {
  local mutated="${TMPD}/libmgr-stripped.md"
  grep -vF "Must-Stay Rule (F3)" "${LIBMGR}" | grep -vF "Principled Splits (do not merge)" \
    | grep -vF "Structural Scorecard" > "${mutated}"
  ! diff -q "${LIBMGR}" "${mutated}" >/dev/null
  local leaked=()
  grep -qF "Must-Stay Rule (F3)" "${mutated}" && leaked+=("F3")
  grep -qF "Principled Splits (do not merge)" "${mutated}" && leaked+=("splits")
  grep -qF "Structural Scorecard" "${mutated}" && leaked+=("scorecard")
  if (( ${#leaked[@]} )); then
    printf 'Policy guard is vacuous — still matched after removal: %s\n' "${leaked[*]}" >&2
    return 1
  fi
}

# =============================================================================
# Cross-cutting: none of the edits above may introduce a model: pin (#121)
# =============================================================================

@test "[#121] no skill touched by #50/#51/#52 introduced a frontmatter model: key" {
  local s f hits=()
  # Includes the three skills the #138 adjudication REMOVED the flag from — they were
  # edited by this unit too, so they must stay under the #121 guard.
  for s in "${NO_AUTO_INVOKE_SKILLS[@]}" "${TECH_SKILLS[@]}" "${EMDASH_SKILLS[@]}" \
           c-bpm-sk-grill-me-issue c-bpm-sk-grill-claude-issue c-bpm-sk-idea-merge \
           c-bpm-sk-library-manager; do
    f="${SKILLS_DIR}/${s}/SKILL.md"
    [[ -f "${f}" ]] || continue
    if _fm "${f}" | grep -qE '^[[:space:]]*model:[[:space:]]*'; then
      hits+=("${s}")
    fi
  done
  if (( ${#hits[@]} )); then
    printf 'Frontmatter model: key introduced — forbidden by #121:\n'
    printf '  %s\n' "${hits[@]}"
    return 1
  fi
}

# =============================================================================
# #139 — the two authoring skills must not TEACH a model: key
#
# These are the skills that generate other skills, so a recommendation here does not
# stay here: it is copied into every skill authored from the template, propagating a
# #121 violation past the frontmatter guard above (which only inspects skills that
# already exist). Both files simultaneously taught `model:` in a decision table and
# forbade it in prose a few dozen lines later.
# =============================================================================

@test "[#139] neither authoring skill teaches a frontmatter model: key" {
  local s f out bad=()
  for s in "${AUTHORING_SKILLS[@]}"; do
    f="${SKILLS_DIR}/${s}/SKILL.md"
    [[ -f "${f}" ]] || { bad+=("${s}: SKILL.md missing"); continue; }
    out="$(_model_teaching_hits "${f}")"
    [[ -z "${out}" ]] || bad+=("${out}")
  done
  if (( ${#bad[@]} )); then
    printf '#139 an authoring skill recommends a model: key (forbidden by #121).\n'
    printf 'Remove the recommendation — do NOT remove the prohibition prose:\n'
    printf '  %s\n' "${bad[@]}"
    return 1
  fi
}

@test "[#139] the guard does NOT fire on prohibition prose (polarity, table and list forms)" {
  local ok="${TMPD}/prohibition-only.md"
  cat > "${ok}" <<'MD'
---
name: c-bpm-sk-x
description: "X — x."
---

**No `model:` key, ever** (#121). Model choice is single-source policy and lives as
prose in `c-bpm-sk-llm-selection`; a frontmatter `model:` key bypasses it.

| Field | Rule |
|-------|------|
| `model` | Never add this key — forbidden by #121 |
| `effort` | Override model effort level (e.g., `high` for thorough analysis) |

- Do not add a `model:` key to generated skills.
MD
  local out; out="$(_model_teaching_hits "${ok}")"
  if [[ -n "${out}" ]]; then
    printf 'Guard fired on prohibition prose — it cannot tell "add this" from "never add this".\n' >&2
    printf 'A guard this way round forces deletion of the rule it protects:\n%s\n' "${out}" >&2
    return 1
  fi
}

@test "[#139] the guard fires when a recommendation row is reintroduced (mutation check)" {
  # The exact rows removed for #139, put back one file at a time. The prohibition prose
  # stays in the file, so this also proves the guard classifies per line rather than
  # excusing a whole file that mentions #121 somewhere.
  local mutated out
  mutated="${TMPD}/creator-row.md"
  sed 's#^| Should it override effort level? .*#| Does it need a specific model? | `model: opus` or `model: sonnet` |\n&#' \
    "${CREATOR}" > "${mutated}"
  ! diff -q "${CREATOR}" "${mutated}" >/dev/null
  out="$(_model_teaching_hits "${mutated}")"
  if [[ -z "${out}" ]]; then
    printf 'Guard is vacuous: creator decision-table row `model: opus` was accepted.\n' >&2
    return 1
  fi

  mutated="${TMPD}/optimizer-row.md"
  sed 's#^| `effort` | Override model effort level.*#| `model` | Override model for specific skills (e.g., `opus` for complex tasks) |\n&#' \
    "${OPTIMIZER}" > "${mutated}"
  ! diff -q "${OPTIMIZER}" "${mutated}" >/dev/null
  out="$(_model_teaching_hits "${mutated}")"
  if [[ -z "${out}" ]]; then
    printf 'Guard is vacuous: optimizer feature-checklist row `model` was accepted.\n' >&2
    return 1
  fi
}

@test "[#139] the guard fires when model: is added to the fenced template frontmatter" {
  local mutated="${TMPD}/creator-template-model.md" out
  sed 's#^enforcement: block$#model: opus\n&#' "${CREATOR}" > "${mutated}"
  ! diff -q "${CREATOR}" "${mutated}" >/dev/null
  out="$(_model_teaching_hits "${mutated}")"
  if [[ -z "${out}" ]]; then
    printf 'Guard is vacuous: a model: key inside the copy-paste template was accepted.\n' >&2
    return 1
  fi
}

# =============================================================================
# #140 — the fenced YAML template examples must parse
#
# `intentPatterns: "... 2\.0 ..."` is invalid YAML: `\.` is not a recognised escape
# in a double-quoted scalar. It sat in the optimizer's template block, so every skill
# scaffolded from that template was born with frontmatter that does not load — and
# the #52 parse test above could not see it, because a fenced example is not
# frontmatter.
# =============================================================================

@test "[#140] every fenced YAML template example in the authoring skills parses" {
  local s f n out bad=()
  for s in "${AUTHORING_SKILLS[@]}"; do
    f="${SKILLS_DIR}/${s}/SKILL.md"
    [[ -f "${f}" ]] || { bad+=("${s}: SKILL.md missing"); continue; }
    n="$(_fenced_yaml_count "${f}")"
    (( n >= 1 )) || { bad+=("${s}: no fenced yaml block found — guard would be a no-op"); continue; }
    out="$(_fenced_yaml_errors "${f}")"
    [[ -z "${out}" ]] || bad+=("${out}")
  done
  if (( ${#bad[@]} )); then
    printf '#140 an authoring skill ships a template example that is not valid YAML.\n'
    printf 'Anyone copying it produces a skill whose frontmatter does not parse:\n'
    printf '  %s\n' "${bad[@]}"
    return 1
  fi
}

@test "[#140] the guard fires when the template escape is re-broken (mutation check)" {
  local mutated="${TMPD}/optimizer-broken-template.md" out
  _break_template_escape "${OPTIMIZER}" "${mutated}"
  ! diff -q "${OPTIMIZER}" "${mutated}" >/dev/null
  out="$(_fenced_yaml_errors "${mutated}")"
  if [[ -z "${out}" ]]; then
    printf 'Guard is vacuous: the unescaped-backslash template block was accepted.\n' >&2
    return 1
  fi
}

@test "[#140] the pre-existing frontmatter parse test is blind to a broken template block" {
  # Not a redundant assertion: it pins WHY a second guard is needed. The mutated file
  # has valid frontmatter and an invalid template example. If this ever starts failing,
  # the frontmatter test grew to cover fenced blocks and the two guards should be merged
  # rather than left to drift apart.
  local mutated="${TMPD}/blindness.md"
  _break_template_escape "${OPTIMIZER}" "${mutated}"
  if ! _frontmatter_parses "${mutated}"; then
    printf 'The frontmatter guard now sees the template defect — reconcile the two guards.\n' >&2
    return 1
  fi
  [[ -n "$(_fenced_yaml_errors "${mutated}")" ]]
}
