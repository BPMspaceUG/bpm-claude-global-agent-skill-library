#!/usr/bin/env node
// issue-write-gate.mjs — PreToolUse hook for BPMspaceUG#68
//
// Blocks GitHub issue creation when --milestone or a single bug|enhancement
// type label is missing. Gates: Bash (`gh issue create`, `gh api ... POST
// .../issues`, curl/python HTTP clients hitting the GitHub issues API) and
// MCP (`mcp__github__issue_write` create, `mcp__github__create_issue`).
//
// HAND-MAINTAINED BUILD ARTIFACT. There is no build step in this repo; this
// file and my/hooks/issue-write-gate.ts must be edited together. Parity is
// enforced by tests/bash/c-bpm-sk-issue-write-gate.bats ("ts/dist parity").
//
// Contract:
//   stdin:  JSON {tool_name, tool_input, cwd, ...}
//   stdout: JSON {hookSpecificOutput: {hookEventName, permissionDecision,
//                permissionDecisionReason}, ...legacy flat mirror}
//   exit:   ALWAYS 0 — including on an internal error, which emits `deny`
//           (fail-closed). #133: exiting non-zero with empty stdout delivers
//           NO decision to the harness, i.e. it fails OPEN, and it fails open
//           exactly when the environment is already degraded (expired auth,
//           rate limit, DNS failure, gh missing, login-shell banners on the
//           same stream per #94/#130). Never do that.
//
// ── ACCEPTED RESIDUAL BYPASS SURFACE (#71 action item 3) ─────────────────
// This layer inspects the argv it is handed. Any indirection that hides the
// create from that argv is a KNOWN, ACCEPTED limit, not a bug to chase here —
// chasing it means interpreting arbitrary embedded languages, which this hook
// deliberately does not do (that is how the sibling shape heuristic burned
// four review rounds). Enumerated so the boundary is explicit:
//   * subshell / command substitution — `$(...)`, backticks producing the
//     create at runtime;
//   * base64 / other decode-then-exec — `echo <b64> | base64 -d | sh`;
//   * here-strings / here-docs feeding a shell — `sh <<<"gh issue create ..."`,
//     `sh <<EOF … EOF`. #156 made this EXPLICIT rather than accidental: heredoc
//     bodies are now OPAQUE DATA by design (that is what stops a body full of
//     apostrophes from breaking the parse), so a body handed to a shell is not
//     inspected. It used to "deny" only as a side effect of the body breaking
//     tokenisation — an accident, not enforcement. Pinned by fixtures 103/113.
//   * URL or command assembled at runtime from pieces (see the inline-HTTP
//     note below for the same limit on the curl/python path).
// The backstop for ALL of these is the server-side GitHub Actions layer on
// issues.opened (#42/#131), which sees every issue however it was created.
// Widen the inspected argv shapes with care; never add a decode/eval emulator.
//
// Test mode env vars (used by tests/bash/c-bpm-sk-issue-write-gate.bats):
//   FIXTURE_MILESTONES      JSON object {name: number} mocking gh api milestones
//   FIXTURE_REPO            "owner/repo" string skipping git resolution
//   FIXTURE_REPO_RESOLVE=fail  forces repo resolution to return null
//   ISSUE_WRITE_GATE_FORCE_ERROR=1  throws inside main() to prove fail-closed

import { readFileSync } from 'fs';
import { execFileSync } from 'child_process';

const LIFECYCLE = new Set([
  'new', 'planned', 'plan-approved', 'test-designed', 'test-design-approved',
  'implemented', 'tested-success', 'tested-failed', 'test-approved',
  'reviewed', 'review-approved', 'investigating', 'resolved'
]);
// DONE deliberately excluded — human-only per c-bpm-sk-milestone-type.

const TYPE_LABELS = new Set(['bug', 'enhancement']);

const MCP_CREATE_TOOLS = new Set([
  'mcp__github__issue_write',
  'mcp__github__create_issue'
]);

// Shell operators that end one command and start another (#71): `true && gh
// issue create ...` must be gated, not waved through because argv[0] != gh.
const OPERATORS = new Set(['&&', '||', ';', '|', '&']);

// Known shell runners (#71). NOT the trigger for unwrapping — that is
// shape-based, see decideSegment (#133). This set only picks the unwrap start
// point when a known runner sits mid-segment, carries `eval`'s join-the-rest
// semantics, and marks a payload as definitely-a-command for fail-closed
// tokenisation.
const SHELL_RUNNERS = new Set(['bash', 'sh', 'zsh', 'dash', 'ksh', 'eval']);

const GH_COMMAND = new Set(['gh']);

// #136: tools whose `-c` takes an OPERAND, not a command. `grep -c PATTERN` is
// a count, `sort -c` a check, `ssh -c CIPHER` a cipher name, `git -c k=v` a
// config override — re-gating their argument denied `grep -c "gh issue create"
// notes.txt` and `ssh -c 'gh issue create --title x' host`, i.e. the gate
// blocked anyone auditing this repo for that very pattern.
//
// This list is HALF of the discriminator, never the whole of it — see
// shellPayloads for how it combines with the positional rules, and why neither
// signal is allowed to decide alone. Consulted only for the word that OWNS the
// flag, never for any word merely present in the segment — otherwise
// `mysh -c "gh issue create" grep` would disable its own unwrap.
const C_OPERAND_TOOLS = new Set([
  'grep', 'egrep', 'fgrep', 'rg', 'ag', 'ack', 'sort', 'uniq', 'awk',
  'tar', 'cpio', 'git', 'docker', 'podman', 'systemctl', 'cmake',
  'ssh', 'scp', 'sftp'
]);

// #136: HTTP clients whose argv can carry a create. Used to bind a POST flag to
// a URL inside ONE invocation — see curlPostsToIssues.
const HTTP_CLIENTS = new Set(['curl', 'wget', 'http', 'https', 'httpie', 'xh']);

// Max recursion through nested shell runners before failing closed (#71).
const MAX_DEPTH = 5;

// Top-level tokenise failure denies only when the command looks like an issue
// write. Inner payloads always fail closed — see decideBash().
const SUSPECT = /\bgh\s+(issue\s+create|api\b)|api\.github\.com/;

// GitHub REST issues collection endpoint (create target). The lookahead rejects
// .../issues/123 and .../issues/comments — those are not creates.
const GH_REST_ISSUES = /api\.github\.com\/repos\/([^/\s'"?]+)\/([^/\s'"?]+)\/issues(?![/\w])/;
const GH_GRAPHQL = /api\.github\.com\/graphql/;
const POST_HINT = /-X\s*POST|--request\s+POST|--data|--json|\s-d\s|requests\.post|session\.post|\.post\(|http\.client|urlopen|method\s*[:=]\s*['"]POST['"]/i;
const GQL_CREATE = /createIssue|create_issue/i;

// ── Output helpers ────────────────────────────────────────────────────────

function emit(decision, reason = '') {
  process.stdout.write(JSON.stringify({
    // Authoritative shape per current Claude Code hook docs (#99).
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: decision,
      permissionDecisionReason: reason
    },
    // ponytail: legacy flat mirror, one transition release only. Older builds
    // read these top-level keys; without them the gate would silently fail
    // OPEN. Remove once the minimum supported Claude Code build is confirmed
    // to read hookSpecificOutput.
    permissionDecision: decision,
    permissionDecisionReason: reason
  }));
  process.exit(0);
}
const allow = (r = '') => emit('allow', r);
const deny  = (r)      => emit('deny',  `[issue-write-gate] ${r}`);

// ── Argv tokeniser ────────────────────────────────────────────────────────

// A heredoc introducer: `<<EOF`, `<<-EOF`, `<< 'EOF'`, `<<"EOF"`, `<<\EOF`.
// The bare form deliberately stops at any shell metacharacter so that
// `$((1<<2))` yields the (nonexistent) delimiter `2` instead of swallowing the
// rest of the command — see skipHeredocBodies for why that fails CLOSED.
const HEREDOC_START = /^<<(-?)\s*(?:'([^']*)'|"([^"]*)"|((?:\\.|[^\s;&|<>()'"])+))/;

// #156: the tokeniser used to split on WHITESPACE ONLY, so it modelled neither
// command separators nor heredocs. Three consequences, all fixed here rather
// than in a pre-split, because the root cause is this function:
//   (a) FALSE POSITIVE — two compliant creates separated by a newline or `;`
//       landed in ONE segment, so extractFlags accumulated `--label` across
//       both and reported "got 2 type labels" for two one-label commands;
//   (b) FALSE POSITIVE — a heredoc body was tokenised as shell, so one
//       apostrophe in prose opened a quote that never closed → throw →
//       "command parse failed"; the body is DATA and is now skipped;
//   (c) FAIL-OPEN — `echo x|gh issue create`, `true&&gh issue create` and
//       `true;gh issue create` all ALLOWED, because without operator splitting
//       the create's command word was `x|gh` / `true&&gh` / `true;gh`, whose
//       basename is not `gh`. Closed by (e) below; fixtures 106-108.
// The quote state machine below stays FIRST and unchanged — it is the only
// throw site, and keeping it ahead of everything else is what keeps a quoted
// newline, `;`, `|` or `<<` inert (fixture 88).
function tokenise(cmd) {
  const out = [];
  const pending = [];
  let i = 0, cur = '', inSingle = false, inDouble = false, started = false, quoteAt = -1;
  const flush = () => { if (started) { out.push(cur); cur = ''; started = false; } };
  while (i < cmd.length) {
    const c = cmd[i];
    if (inSingle) {
      if (c === "'") { inSingle = false; i++; continue; }
      cur += c; i++; continue;
    }
    if (inDouble) {
      if (c === '"') { inDouble = false; i++; continue; }
      if (c === '\\' && i + 1 < cmd.length && '"\\$`'.includes(cmd[i+1])) {
        cur += cmd[i+1]; i += 2; continue;
      }
      cur += c; i++; continue;
    }
    if (c === "'") { inSingle = true; started = true; quoteAt = i; i++; continue; }
    if (c === '"') { inDouble = true; started = true; quoteAt = i; i++; continue; }
    // (a) line continuation — `\<newline>` is removed by the shell, so it must
    // not become a token boundary NOR a literal newline.
    if (c === '\\' && cmd[i + 1] === '\n') { i += 2; continue; }
    if (c === '\\' && i + 1 < cmd.length) { cur += cmd[i+1]; started = true; i += 2; continue; }
    // (b) here-STRING: `<<<word` is data on stdin, not a heredoc. Checked first
    // so the `<<` branch cannot claim the third `<` as a delimiter.
    if (c === '<' && cmd.startsWith('<<<', i)) { flush(); i += 3; continue; }
    // (c) heredoc introducer: remember the delimiter, emit no redirect token.
    if (c === '<' && cmd.startsWith('<<', i)) {
      const m = HEREDOC_START.exec(cmd.slice(i));
      if (m) {
        flush();
        const delim = m[2] !== undefined ? m[2]
                    : m[3] !== undefined ? m[3]
                    : m[4].replace(/\\(.)/g, '$1');
        pending.push({ delim, strip: m[1] === '-' });
        i += m[0].length; continue;
      }
    }
    // (d) newline ends a command like `;` does — and is where any pending
    // heredoc BODY starts, which is data and never shell.
    if (c === '\n') { flush(); out.push(';'); i = skipHeredocBodies(cmd, i + 1, pending); continue; }
    // (e) unwhitespaced operators become their own tokens; splitSegments
    // already keys on exactly these.
    if (c === '&' || c === '|' || c === ';') {
      flush();
      const two = cmd.slice(i, i + 2);
      if (two === '&&' || two === '||') { out.push(two); i += 2; continue; }
      out.push(c); i++; continue;
    }
    if (/\s/.test(c)) { flush(); i++; continue; }
    cur += c; started = true; i++;
  }
  // (f) name the construct: decideBash surfaces this message, so a denial says
  // WHAT failed to parse instead of guessing "unbalanced quotes?".
  if (inSingle || inDouble) {
    throw new Error(`unterminated ${inSingle ? 'single' : 'double'} quote at offset ${quoteAt}`);
  }
  flush();
  return out;
}

// Skip the bodies of the heredocs opened on the line that just ended. `i` is the
// first character of the first body; the return value is where shell parsing
// resumes.
//
// FAIL-CLOSED HINGE (#156): the body is skipped ONLY when its terminator is
// actually found. If it is not, this returns the position it was given —
// unadvanced — and the "body" is tokenised as ordinary shell. That asymmetry is
// what makes a FALSE heredoc harmless: `echo $((1<<2))` registers the delimiter
// `2`, no line `2` follows, nothing is skipped, and a create further down stays
// visible and is denied (fixture 101). Skipping on a found terminator is safe
// because that text is a body the shell hands to a program as data, never
// executes — with the one enumerated exception of a body fed to a SHELL, which
// is the accepted residual bypass documented in the header (fixtures 103/113).
function skipHeredocBodies(cmd, i, pending) {
  let pos = i;
  for (const h of pending) {
    let found = false;
    while (pos < cmd.length) {
      const nl = cmd.indexOf('\n', pos);
      const end = nl < 0 ? cmd.length : nl;
      let line = cmd.slice(pos, end);
      if (h.strip) line = line.replace(/^\t+/, '');   // `<<-` strips leading tabs
      pos = nl < 0 ? end : end + 1;
      if (line.trimEnd() === h.delim) { found = true; break; }
    }
    if (!found) { pending.length = 0; return i; }
  }
  pending.length = 0;
  return pos;
}

// ── Command-word helpers ──────────────────────────────────────────────────

// #70: `/usr/bin/gh issue create` is the same command as `gh issue create`.
function basename(tok) {
  const i = tok.lastIndexOf('/');
  return i < 0 ? tok : tok.slice(i + 1);
}

function splitSegments(argv) {
  const segs = [];
  let cur = [];
  for (const tok of argv) {
    if (OPERATORS.has(tok)) { segs.push(cur); cur = []; continue; }
    cur.push(tok);
  }
  segs.push(cur);
  return segs;
}

// #71: replaces the old prefix-stripping whitelist (command|exec|env). Any
// wrapper chain — sudo -u X, timeout 30, nohup, stdbuf -oL, env FOO=1,
// /usr/bin/env — is handled generically by locating the command word itself
// ANYWHERE in the segment, so no wrapper needs to be enumerated. Checking only
// the segment head let `sudo bash -lc "gh issue create"` through, because the
// head was `sudo` and the `gh` was inside a quoted payload.
//
// GUARANTEE, precisely (#133): this finds a name from `names` wherever it sits,
// so no wrapper needs enumerating. It does NOT make unknown names safe — a name
// absent from `names` is simply not found. That is why the payload unwrap in
// decideSegment triggers on shape rather than on this lookup.
function findCommandIndex(seg, names) {
  for (let i = 0; i < seg.length; i++) {
    if (names.has(basename(seg[i]))) return i;
  }
  return -1;
}

// Payloads handed to a shell runner, for recursive re-gating. Each entry is
// {payload, strict} — #136; `strict` drives fail-closed parsing.
//
// #136 — HOW THE TWO SIGNALS COMBINE. Neither decides alone, because each one
// alone was demonstrably wrong:
//
//   OWNERSHIP (primary). `owner` is the last non-flag word before the `-c`
//   flag — the tool the flag actually belongs to. `sudo grep -c pat f` → grep,
//   `mysh -c "cmd" x` → mysh. Only that word is matched against
//   C_OPERAND_TOOLS, so a trailing operand cannot be used to suppress the
//   unwrap. Ownership is what makes `sort -c "gh issue create --title x"` and
//   `ssh -c CIPHER host` allow: the flag demonstrably belongs to a tool that
//   consumes an operand there. But a NAME LIST alone was rejected twice, and
//   correctly: a list that decides WHAT TO INSPECT fails open on every name
//   nobody listed. So it does NOT decide inspection here — an owner that is not
//   on the list is still unwrapped and inspected. The list can only ever
//   SUPPRESS inspection for a positively-recognised operand consumer, which is
//   the safe direction; unknown owners keep failing closed.
//
//   POSITION (secondary). A terminal `-c` argument is not unique to shells —
//   `sort -c "gh issue create --title x"` has the exact shape of
//   `mysh -c "gh issue create --title x"` — so position cannot decide
//   inspection either. What it CAN decide is confidence, i.e. whether an
//   unrecognised owner's payload is treated as definitely-a-command and
//   therefore parsed fail-closed (`strict`). Three shapes say "shell":
//     - the owner is a known shell runner (`bash -c`, `busybox sh -c`);
//     - the flag is a BUNDLE — `-lc`, `-ic`, `-euc`. Stacking `c` with other
//       single letters is a shell spelling; an operand-taking tool does not
//       spell its option that way;
//     - an operand FOLLOWS the payload — the `sh -c CMD $0 $1...` shape.
//   Hence `mysh -c "it's fine"` stays allowed (unparseable, not obviously a
//   command, SUSPECT decides) while `mysh -c "it's fine" arg0` denies: the
//   trailing operand is the shell shape, so an unparseable payload fails
//   closed. Same owner, same flag, decided by position alone.
//
//   RESIDUAL, stated generally so it is not mistaken for a short list of known
//   shapes: ANY tool that takes an operand after `-c` and is NOT in
//   C_OPERAND_TOOLS has that operand re-gated as if it were a command, so it is
//   DENIED whenever the operand text itself looks like an issue-create. `grep`,
//   `sort` and `ssh` are listed because they were hit in practice; every
//   unlisted consumer — `gcc -c "gh issue create --title x" file.c` is one, and
//   there are others nobody has enumerated — is a false positive of exactly
//   this kind. That is the DESIGNED cost, not an oversight: the list may only
//   ever suppress inspection, never enable it, so growing it on demand trades a
//   visible, self-correcting annoyance for a silent fail-open. Do not "fix" a
//   report of this shape by appending the tool; only add a name when that tool
//   is genuinely a `-c` operand consumer AND the false positive is real.
function shellPayloads(head, seg) {
  if (basename(head) === 'eval') {
    const rest = seg.slice(1);
    return rest.length ? [{ payload: rest.join(' '), strict: true }] : [];
  }
  let owner = head;
  for (let i = 1; i < seg.length; i++) {
    const t = seg[i];
    if (t.startsWith('--')) continue;
    if (t.startsWith('-')) {
      if (!t.includes('c')) continue;
      if (C_OPERAND_TOOLS.has(basename(owner))) return [];
      if (i + 1 >= seg.length) return [];
      const strict = SHELL_RUNNERS.has(basename(owner))   // known shell
        || t.replace(/^-+/, '').length > 1                // bundled -lc/-ic
        || i + 2 < seg.length;                            // trailing $0 operand
      return [{ payload: seg[i + 1], strict }];
    }
    owner = t;
  }
  return [];
}

// ── Generic flag extraction (long, short, equals, repeated, comma-split) ──

function extractFlags(argv, specs) {
  const result = {};
  let positional = [];
  let endOfOpts = false;
  for (let i = 0; i < argv.length; i++) {
    const tok = argv[i];
    if (endOfOpts) { positional.push(tok); continue; }
    if (tok === '--') { endOfOpts = true; continue; }
    let matched = false;
    for (const [longFlag, spec] of Object.entries(specs)) {
      const short = spec.short;
      const key = longFlag.replace(/^--/, '');
      if (tok.startsWith(longFlag + '=')) {
        pushFlag(result, key, tok.slice(longFlag.length + 1), spec.multi);
        matched = true; break;
      }
      if (tok === longFlag) {
        if (i + 1 < argv.length) { pushFlag(result, key, argv[++i], spec.multi); }
        matched = true; break;
      }
      if (short && tok === short) {
        if (i + 1 < argv.length) { pushFlag(result, key, argv[++i], spec.multi); }
        matched = true; break;
      }
      if (short && tok.startsWith(short) && tok.length > short.length && !tok.startsWith('--')) {
        // #73: `-l=bug` / `-m=new` — drop the separator, else the value parses
        // as the literal "=bug" and a compliant command is wrongly denied.
        pushFlag(result, key, tok.slice(short.length).replace(/^=/, ''), spec.multi);
        matched = true; break;
      }
    }
    if (!matched) positional.push(tok);
  }
  result._positional = positional;
  return result;
}

function pushFlag(obj, key, val, multi) {
  if (multi) {
    obj[key] = obj[key] || [];
    for (const part of val.split(',')) obj[key].push(part);
  } else {
    obj[key] = val;
  }
}

// ── gh api detection ──────────────────────────────────────────────────────

// Bias (#72): a missed create is worse than a false positive. Explicit
// -X/--method wins; otherwise body fields on the issues collection mean CREATE.
// GET is inferred only from an explicit method or the absence of body fields.
function ghApiCreateKind(argv) {
  const args = argv.slice(2);
  let method = null;
  let hasFields = false;
  let hasInput = false;
  let urlIsIssuesCreate = false;

  for (let i = 0; i < args.length; i++) {
    const t = args[i];
    if (t === '-X' || t === '--method') { method = (args[++i] || '').toUpperCase(); continue; }
    if (t.startsWith('--method=')) { method = t.slice(9).toUpperCase(); continue; }
    if (t.startsWith('-X') && t.length > 2 && !t.startsWith('-XX')) {
      method = t.slice(t.startsWith('-X=') ? 3 : 2).toUpperCase();
      continue;
    }
    if (t === '--input') { hasInput = true; i++; continue; }
    if (t.startsWith('--input=')) { hasInput = true; continue; }
    if (t === '-f' || t === '-F' || t === '--field' || t === '--raw-field') { hasFields = true; i++; continue; }
    if (t.startsWith('--field=') || t.startsWith('--raw-field=')) { hasFields = true; continue; }
    if ((t.startsWith('-f') || t.startsWith('-F')) && t.length > 2) { hasFields = true; continue; }
    if (!t.startsWith('-')) {
      if (/repos\/[^/]+\/[^/]+\/issues(?:$|\?|\/?(?!\d))/.test(t) &&
          !/repos\/[^/]+\/[^/]+\/issues\/\d+/.test(t)) {
        urlIsIssuesCreate = true;
      }
    }
  }

  if (!urlIsIssuesCreate) return 'none';
  if (method !== null) return method === 'POST' ? (hasInput ? 'opaque' : 'create') : 'none';
  if (hasInput) return 'opaque';               // body in a file/stdin — cannot inspect
  return hasFields ? 'create' : 'none';        // default-POST inferred when fields present
}

function extractGhApiFields(argv) {
  const labels = [];
  let milestone;
  const args = argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    const t = args[i];
    let kv = null;
    if (t === '-f' || t === '-F' || t === '--field' || t === '--raw-field') {
      kv = args[++i] || '';
    } else if (t.startsWith('--field=')) kv = t.slice(8);
    else if (t.startsWith('--raw-field=')) kv = t.slice(12);
    else if ((t.startsWith('-f') || t.startsWith('-F')) && t.length > 2) kv = t.slice(2);
    if (kv === null) continue;
    const eq = kv.indexOf('=');
    if (eq < 0) continue;
    const k = kv.slice(0, eq);
    const v = kv.slice(eq + 1);
    if (k === 'milestone') milestone = v;
    else if (k === 'labels[]' || k === 'labels') labels.push(v);
  }
  const out = {};
  if (milestone !== undefined) out.milestone = milestone;
  if (labels.length) out.labels = labels;
  return out;
}

function repoFromGhApiUrl(argv) {
  for (const t of argv.slice(2)) {
    const m = t.match(/repos\/([^/]+)\/([^/]+?)\/issues/);
    if (m) return `${m[1]}/${m[2]}`;
  }
  return null;
}

// ── Variable interpolation guard ──────────────────────────────────────────

function hasInterpolation(s) {
  return typeof s === 'string' && /\$[A-Za-z_{(]/.test(s);
}

// ── Repo resolution ───────────────────────────────────────────────────────

function resolveRepo(cwd) {
  if (process.env.FIXTURE_REPO_RESOLVE === 'fail') return null;
  if (process.env.FIXTURE_REPO) return process.env.FIXTURE_REPO;
  try {
    const url = execFileSync('git', ['-C', cwd || '.', 'config', '--get', 'remote.origin.url'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
      timeout: 2000
    }).trim();
    const m = url.match(/[:/]([^/:]+)\/([^/]+?)(?:\.git)?$/);
    return m ? `${m[1]}/${m[2]}` : null;
  } catch {
    return null;
  }
}

// #69: an explicit --repo/-R overrides git resolution, so a compliant command
// run outside a git checkout is no longer a false positive.
function normaliseRepoFlag(val) {
  if (typeof val !== 'string') return null;
  if (hasInterpolation(val)) return null;
  return /^[^/\s]+\/[^/\s]+$/.test(val) ? val : null;
}

// ── Repo milestone catalog (cached per process) ───────────────────────────

let milestoneCache = null;

// Returns null for "cannot verify" — NEVER an empty catalog, which validate()
// would read as "milestone not present" and could not distinguish from a
// successful lookup. Every unparseable input lands on null → deny (#133).
function getRepoMilestones(repo) {
  if (process.env.FIXTURE_MILESTONES) {
    let map;
    // #133: was an unguarded JSON.parse — the single throw that crashed the
    // whole hook to exit 1 with empty stdout, i.e. fail-OPEN.
    try {
      map = JSON.parse(process.env.FIXTURE_MILESTONES);
    } catch {
      return null;
    }
    if (!map || typeof map !== 'object') return null;
    const byNum = new Map(); const byName = new Set();
    for (const [name, num] of Object.entries(map)) {
      byNum.set(Number(num), name);
      byName.add(name);
    }
    return byName.size ? { byNum, byName } : null;
  }
  if (milestoneCache && milestoneCache.repo === repo) return milestoneCache;
  try {
    const out = execFileSync('gh', [
      'api', `repos/${repo}/milestones?per_page=100&state=all`,
      '--jq', '.[] | "\\(.number)\t\\(.title)"'
    ], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
      timeout: 3000
    });
    const byNum = new Map(); const byName = new Set();
    for (const line of out.split('\n')) {
      // #133: `gh` is not guaranteed to hand back clean `number<TAB>title`
      // lines. A login shell prepends keychain/curl banners to the same stream
      // (#94/#130), and a different gh build can reshape the output entirely.
      // Skip anything that is not a well-formed record instead of admitting
      // `NaN → undefined` entries into the catalog.
      const tab = line.indexOf('\t');
      if (tab < 0) continue;
      const n = Number(line.slice(0, tab));
      const t = line.slice(tab + 1);
      if (!Number.isFinite(n) || !t) continue;
      byNum.set(n, t); byName.add(t);
    }
    // Nothing parseable = we did NOT learn the repo's milestones. Returning an
    // empty catalog here would read downstream as "milestone does not exist",
    // which is a guess; null means "cannot verify" and denies.
    if (!byName.size) return null;
    milestoneCache = { repo, byNum, byName };
    return milestoneCache;
  } catch {
    return null;
  }
}

// ── Validation ────────────────────────────────────────────────────────────

function validate(milestone, labels, repo) {
  if (milestone === null || milestone === undefined || milestone === '') {
    return 'missing --milestone (or milestone field). Every issue requires a lifecycle milestone (new, planned, plan-approved, ...). DONE is human-only.';
  }
  if (typeof milestone === 'string' && hasInterpolation(milestone)) {
    return 'shell interpolation detected in --milestone value. Use a literal name (e.g., --milestone new), not $VAR or $(...).';
  }
  if (typeof milestone === 'string' && milestone.toUpperCase() === 'DONE') {
    return 'DONE is human-only and cannot be set at issue creation (per c-bpm-sk-milestone-type).';
  }

  if (!repo) {
    return 'cannot resolve owner/repo for milestone validation. Run inside a git repo with a github remote, or pass --repo explicitly.';
  }

  const ms = getRepoMilestones(repo);
  if (!ms) {
    return `cannot fetch or parse milestones for repo ${repo} (gh api failed, timed out, or returned unusable output). Fail-closed.`;
  }

  let title;
  const looksNumeric = (typeof milestone === 'number') || /^\d+$/.test(String(milestone));
  if (looksNumeric) {
    title = ms.byNum.get(Number(milestone));
    if (!title) return `milestone number ${milestone} not found in repo ${repo}. Create it via c-bpm-sk-milestone-type Step 1 first.`;
  } else {
    title = String(milestone);
  }

  if (!LIFECYCLE.has(title)) {
    return `milestone "${title}" is not in the c-bpm-sk-milestone-type lifecycle. Allowed: ${[...LIFECYCLE].join(', ')}.`;
  }
  if (!ms.byName.has(title)) {
    return `milestone "${title}" is not present in repo ${repo}. Create it via c-bpm-sk-milestone-type Step 1 first.`;
  }

  if (!Array.isArray(labels) || labels.length === 0) {
    return 'missing type label. Every issue requires exactly one of: bug, enhancement (lowercase).';
  }

  const types = [];
  for (const lab of labels) {
    if (typeof lab !== 'string') continue;
    if (hasInterpolation(lab)) {
      return 'shell interpolation detected in --label value.';
    }
    if (TYPE_LABELS.has(lab)) {
      types.push(lab);
    } else if (lab.toLowerCase() === 'bug' || lab.toLowerCase() === 'enhancement') {
      return `label "${lab}" must be lowercase. Use "${lab.toLowerCase()}".`;
    }
  }
  if (types.length === 0) {
    return 'no type label found among supplied labels. Every issue requires exactly one of: bug, enhancement (lowercase).';
  }
  if (types.length > 1) {
    return `exactly one type label allowed; got ${types.length}: ${types.join(', ')}.`;
  }

  return null;
}

// ── Raw HTTP client path (#74: curl / python / any client) ────────────────

// SCOPE LIMIT (#74), stated so it is not mistaken for full coverage: this is
// heuristic INLINE string inspection of the Bash command itself. It catches
// `curl ... api.github.com/repos/o/r/issues` and
// `python3 -c "...requests.post(...)"`. It does NOT and cannot catch issue
// creation inside a script FILE — `python3 create_issue.py`, `./release.sh` —
// because the hook never sees that file's contents. Script-file invocation is
// out of scope for this layer BY RULING (#131): the hook cannot read a
// subprocess's file, and must NOT grow deny-on-suspicion heuristics that would
// block ordinary script runs (that option was weighed and rejected on #131).
// The layer that WOULD catch it is the `issues.opened` GitHub Action — but that
// Action is NOT YET IMPLEMENTED (tracked in #42). Until #42 lands, script-file
// issue creation from inside Claude Code is UNENFORCED; that is an accepted,
// documented residual, not a covered case. Do not "fix" it here. Fixture 114
// pins the allow so a future over-eager heuristic that starts denying script
// files fails a test instead of silently shipping the false-positive class.
//
// #136: the POST indicator and the URL must be SYNTACTICALLY CONNECTED — bound
// inside one invocation — not merely co-occurring somewhere in the string. The
// old whole-string test denied
//   python3 -c "print('requests.post'); print('https://api.github.com/repos/o/r/issues')"
// because both tokens appeared, each inside its own print().

// A curl/wget argv token that carries a request BODY or names POST explicitly.
// `next` is the following token, for the separated `-X POST` form.
function isPostFlag(tok, next) {
  if (/^(?:-d|--data|--data-raw|--data-binary|--data-urlencode|--json|-F|--form|-T|--upload-file|--post-data|--post-file)$/.test(tok)) return true;
  if (/^(?:--data|--data-raw|--data-binary|--data-urlencode|--json|--form|--upload-file|--post-data|--post-file)=/.test(tok)) return true;
  if (/^-d./.test(tok)) return true;                       // -d'{"a":1}' → -d{"a":1}
  if (tok === '-X' || tok === '--request' || tok === '--method') {
    return (next || '').toUpperCase() === 'POST';
  }
  if (/^(?:-X|--request=|--method=)/.test(tok)) return /post/i.test(tok);
  // #136 delta: the httpie family (`http`, `httpie`, `xh`) names the method as a
  // bare positional verb — `xh POST <url> title=x` — not as a flag.
  if (tok === 'POST') return true;
  return false;
}

// The URL and the POST flag must sit in the SAME client invocation. Segment
// scoping means `curl .../issues | grep -d` cannot fake a create, and
// `echo -d && curl .../issues` cannot either.
function curlPostsToIssues(cmd) {
  let argv;
  try { argv = tokenise(cmd); } catch { return false; }
  for (const seg of splitSegments(argv)) {
    const i = findCommandIndex(seg, HTTP_CLIENTS);
    if (i < 0) continue;
    const args = seg.slice(i + 1);
    if (!args.some((t) => GH_REST_ISSUES.test(t))) continue;
    if (args.some((t, k) => isPostFlag(t, args[k + 1]))) return true;
  }
  return false;
}

// Posting call sites in INLINE code (`python3 -c "..."`, `node -e "..."`).
//
// #136: detection is a CALL-SHAPED TEXTUAL MATCH, not a semantic one. This
// hook does not parse the embedded language, so it cannot tell executable code
// from a string literal or a comment. Both directions of that are KNOWN and
// ACCEPTED — the earlier claim here, that a URL "printed, logged or assembled
// in a comment is not a create", was simply false and is retracted:
//
//   FALSE POSITIVE — a call-shaped MENTION is denied. Both of these merely
//   quote a create and both are DENIED today:
//     python3 -c "print(\"requests.post('https://api.github.com/repos/o/r/issues', data='x')\")"
//     python3 -c "# requests.post('https://api.github.com/repos/o/r/issues', data='x')\nprint('ok')"
//   What is NOT matched is a bare token with no call shape, e.g.
//   `python3 -c "print('requests.post')"` — quoting the NAME is fine, quoting a
//   whole call is not.
//
//   FALSE NEGATIVE — the URL has to appear LITERALLY in the TEXT OF THAT
//   ARGUMENT LIST, so any indirection that removes it evades the check.
//   Illustrative, not exhaustive:
//     - bound to a name first: `u = "https://api.github.com/repos/o/r/issues";
//       requests.post(u, json=...)`;
//     - returned by a helper: `requests.post(build_url(), json=...)`;
//     - assembled from pieces: `requests.post(BASE + "/repos/o/r/issues", ...)`.
//   All were denied by the old co-occurrence rule and are NOT caught now.
//
// Closing either direction means interpreting the embedded language, which this
// hook does not and should not do. So where the check CAN fire it is
// deliberately biased toward DENYING ON DOUBT, consistent with this file's
// fail-closed posture, and the price is false positives on commands that quote
// code; where indirection hides the URL it cannot fire at all, and the backstop
// is the same as for the script-FILE limit above — the server-side GitHub
// Actions layer on issues.opened (#131), which sees every issue however it was
// created. Fixtures 87/88 pin the two false positives above so a future change
// to this behaviour surfaces at review instead of passing unnoticed.
//
// What IS guaranteed: the literal is found wherever it sits inside the call's
// own parentheses, however deeply nested in sub-calls (see argsOf).
const INLINE_POST_CALL = /\b(?:[\w.]*\.post|urlopen|Request|fetch|request)\s*\(/g;

// Bound on the matching-paren scan below. Long enough for any real inline
// script a hook sees, short enough that a pathological input cannot make the
// scan the slow part of the hook. Exceeding it is not "give up and allow" —
// see the caller.
const MAX_ARG_SCAN = 8192;

// Text between the paren at `open` and its MATCHING close, or null if that
// close is not within MAX_ARG_SCAN characters.
//
// #136: this used to be `cmd.indexOf(')', open)` — the FIRST close paren, not
// the matching one — which truncated the argument text at the first nested
// call and lost everything after it. `fetch(new URL('…/issues'), {method:
// 'POST'})` yielded `new URL('…/issues'` , so the corroborating `method:` fell
// outside and the create was ALLOWED. Depth counting fixes that; string
// literals are skipped so a `)` inside `'…'`, `"…"` or a backtick template
// cannot close the call early.
function argsOf(cmd, open) {
  let depth = 1;
  let quote = '';
  const end = Math.min(cmd.length, open + MAX_ARG_SCAN);
  for (let i = open; i < end; i++) {
    const ch = cmd[i];
    if (ch === '\\') { i++; continue; }               // escaped char, in or out of a string
    if (quote) { if (ch === quote) quote = ''; continue; }
    if (ch === '"' || ch === "'" || ch === '`') { quote = ch; continue; }
    if (ch === '(') depth++;
    else if (ch === ')' && --depth === 0) return cmd.slice(open, i);
  }
  return null;
}

function inlinePostsToIssues(cmd) {
  INLINE_POST_CALL.lastIndex = 0;
  let m;
  while ((m = INLINE_POST_CALL.exec(cmd)) !== null) {
    const open = m.index + m[0].length;
    const argsText = argsOf(cmd, open);
    // Fail closed, like the rest of this file: a posting call whose argument
    // list is unterminated or longer than the scan bound cannot be inspected,
    // and the caller has already established that an issues URL is present in
    // the command. Unparseable + a create URL = deny, not allow.
    if (argsText === null) return true;
    if (!GH_REST_ISSUES.test(argsText)) continue;
    // urlopen()/Request()/fetch()/request() are ALSO the read path; only a body
    // or an explicit method riding in the same call makes one a create.
    // `.post(` needs no such corroboration — the verb is the method.
    if (!/\.post$/.test(m[0].replace(/\s*\($/, ''))) {
      if (!/\b(?:data|body|method)\s*[=:]/i.test(argsText)) continue;
    }
    return true;
  }
  return false;
}

function checkHttpClient(cmd) {
  // #156: this path deliberately still reads the RAW command text, heredoc
  // bodies included — `curl … -d @- <<EOF {json} EOF` carries its milestone and
  // labels in that body, and the body is exactly what has to be validated here.
  // #136 RESIDUAL: the GraphQL branch below still tests POST_HINT and
  // GQL_CREATE against the WHOLE command string. The false-positive class fixed
  // for the REST path — an unrelated POST word and an unrelated URL merely
  // CO-OCCURRING, with no syntactic connection — therefore survives here:
  // `echo https://api.github.com/graphql --data 'createIssue'` still denies.
  // Not fixed in this change; tracked in #160.
  if (GH_GRAPHQL.test(cmd)) {
    if (!POST_HINT.test(cmd)) return null;    // read-only call
    return GQL_CREATE.test(cmd)
      ? 'GraphQL createIssue mutation detected; milestone and type label cannot be validated here. Use `gh issue create --milestone <lifecycle> --label bug|enhancement`.'
      : null;
  }

  const rest = cmd.match(GH_REST_ISSUES);
  if (!rest) return null;
  if (!curlPostsToIssues(cmd) && !inlinePostsToIssues(cmd)) return null;

  const repo = `${rest[1]}/${rest[2]}`;
  const ms = cmd.match(/["']milestone["']\s*:\s*"?([^",}\s]+)"?/);
  const block = cmd.match(/["']labels["']\s*:\s*\[([^\]]*)\]/);
  const labels = block
    ? [...block[1].matchAll(/["']([^"']+)["']/g)].map((m) => m[1])
    : undefined;
  return validate(ms ? ms[1] : undefined, labels, repo);
}

// ── Bash decision (recursive) ─────────────────────────────────────────────

function decideGh(argv, cwd) {
  if (argv[1] === 'issue' && argv[2] === 'create') {
    const flags = extractFlags(argv.slice(3), {
      '--milestone': { short: '-m', multi: false },
      '--label':     { short: '-l', multi: true  },
      '--repo':      { short: '-R', multi: false }
    });
    const repo = normaliseRepoFlag(flags.repo) || resolveRepo(cwd);
    return validate(flags.milestone, flags.label, repo);
  }

  if (argv[1] === 'api') {
    if (argv.slice(2).some((t) => t === 'graphql') && GQL_CREATE.test(argv.join(' '))) {
      return 'GraphQL createIssue mutation detected; milestone and type label cannot be validated here. Use `gh issue create --milestone <lifecycle> --label bug|enhancement`.';
    }
    const kind = ghApiCreateKind(argv);
    if (kind === 'opaque') {
      return 'gh api issue create with --input (body from file/stdin) cannot be inspected for milestone and type label. Fail-closed — use `gh issue create` or inline -f fields.';
    }
    if (kind === 'create') {
      const fields = extractGhApiFields(argv);
      const repo = repoFromGhApiUrl(argv) || resolveRepo(cwd);
      return validate(fields.milestone, fields.labels, repo);
    }
  }

  return null;
}

function decideSegment(seg, cwd, depth) {
  if (!seg.length) return null;

  // #71: a shell runner can sit behind any wrapper chain — `sudo bash -lc
  // "..."`, `env bash -lc "..."`, `sudo env bash -lc "..."`. Scanning the whole
  // segment instead of only seg[0] makes wrapper-stripping and runner-detection
  // compose without enumerating wrappers.
  //
  // #133: the unwrap used to fire only when a KNOWN shell name was found, which
  // failed open on every unknown one — `rbash`, `/opt/bin/mysh`, any shell
  // shipped tomorrow. An allowlist deciding WHAT TO INSPECT is the wrong shape
  // for a fail-closed gate, so the trigger is now SHAPE: any segment carrying a
  // `-c`/`-lc`/`-ic`-style flag with a payload gets that payload re-gated,
  // whatever the head is called.
  //
  // #136: the earlier claim here — that a non-shell `-c` consumer merely costs
  // "one redundant inspection ... which finds no issue-create" — was FALSE. It
  // held only while the argument contained no issue-create text: `grep -c "gh
  // issue create" notes.txt` was re-gated as if it were an invocation and
  // DENIED, so the gate blocked auditing itself. What the code guarantees now,
  // precisely: the argument of a `-c` flag is re-gated UNLESS the word OWNING
  // the flag is a positively-recognised operand consumer (C_OPERAND_TOOLS).
  // Every other owner — including every unknown one — is still unwrapped and
  // inspected, so the name list adds no fail-open path; positional shape then
  // decides how strictly the unwrapped payload is parsed. See shellPayloads for
  // why neither signal is allowed to decide alone. The residual cost runs in
  // the safe direction: an UNRECOGNISED tool whose `-c` argument literally
  // contains an issue-create command line is denied.
  const r = findCommandIndex(seg, SHELL_RUNNERS);
  const start = r >= 0 ? r : 0;
  for (const p of shellPayloads(basename(seg[start]), seg.slice(start))) {
    // strict: the payload is definitely a command, so an unparsable one fails
    // closed. Otherwise SUSPECT decides, so `grep -c "it's" f` is not denied
    // while `rbash -c "gh issue create 'x"` is.
    const reason = decideBash(p.payload, cwd, depth + 1, p.strict);
    if (reason) return reason;
  }

  // Independent fallback: a `gh` word visible in this segment, however it got
  // there. Runs regardless of the runner scan, so neither path can mask the
  // other.
  //
  // #156: EVERY gh invocation in the segment is evaluated on its OWN argv, not
  // just the first one found. The tokeniser already puts separated creates in
  // separate segments, so this is belt-and-braces — but it is what the issue
  // literally asks for, and it removes the last way two invocations' flags can
  // be pooled into one `validate()` call ("got 2 type labels" for two
  // one-label commands). Each slice ends where the next invocation starts.
  const hits = [];
  for (let j = 0; j < seg.length; j++) {
    const next = seg[j + 1];
    if (GH_COMMAND.has(basename(seg[j])) && (next === 'issue' || next === 'api')) hits.push(j);
  }
  for (let k = 0; k < hits.length; k++) {
    const reason = decideGh(seg.slice(hits[k], hits[k + 1]), cwd);
    if (reason) return reason;
  }
  return null;
}

function decideBash(cmd, cwd, depth, strict = false) {
  if (depth > MAX_DEPTH) {
    return `nested shell wrappers exceed depth ${MAX_DEPTH}; command cannot be inspected. Fail-closed.`;
  }

  const http = checkHttpClient(cmd);
  if (http) return http;

  let argv;
  try {
    argv = tokenise(cmd);
  } catch (err) {
    // #156: name the construct that failed instead of guessing "unbalanced
    // quotes?" — tokenise() reports which quote and at what offset. The strict
    // branch keeps the verbatim "Fail-closed." sentence it always had.
    const why = err instanceof Error ? err.message : String(err);
    // #71: a payload handed to a known shell runner that will not tokenise is
    // always fail-closed — it was already established as a wrapped command.
    if (strict) return `wrapped command payload failed to parse (${why}). Fail-closed.`;
    if (SUSPECT.test(cmd)) return `command parse failed (${why}). Manual review required.`;
    return null;
  }

  for (const seg of splitSegments(argv)) {
    const reason = decideSegment(seg, cwd, depth);
    if (reason) return reason;
  }
  return null;
}

// ── Main entry ────────────────────────────────────────────────────────────

function main() {
  if (process.env.ISSUE_WRITE_GATE_FORCE_ERROR === '1') {
    throw new Error('forced internal error (test seam)');
  }

  let raw = '';
  try { raw = readFileSync(0, 'utf8'); } catch {}
  let input;
  try { input = JSON.parse(raw); } catch {
    // NOT an internal error, and deliberately NOT a deny: a payload the harness
    // itself failed to hand over carries no tool_name and no command, so there
    // is nothing to classify. Denying it would block every tool call the gate
    // is not even interested in. Distinct from a throw inside evaluation below,
    // which means we HAD something to judge and could not — that denies.
    // Same split as plan-doc-gate, approved for both (#133).
    return allow('hook input not parseable; passing through');
  }

  const tool = input.tool_name || '';
  const ti   = input.tool_input || {};
  const cwd  = input.cwd || process.cwd();

  // (a) MCP path
  if (tool.startsWith('mcp__')) {
    if (!MCP_CREATE_TOOLS.has(tool)) return allow('non-create MCP tool');
    const method = ((ti.method || ti.action || '') + '').toLowerCase();
    const isCreate = method === 'create' || (tool.endsWith('create_issue') && !method);
    if (!isCreate) return allow('MCP non-create method');
    const repo = (ti.owner && ti.repo) ? `${ti.owner}/${ti.repo}`
               : (ti.repo || resolveRepo(cwd));
    const reason = validate(ti.milestone, ti.labels, repo);
    return reason ? deny(reason) : allow();
  }

  // (b) Bash path
  if (tool !== 'Bash') return allow('non-Bash, non-MCP tool');
  const cmd = (ti.command || '').toString();
  if (!cmd) return allow('empty command');

  const reason = decideBash(cmd, cwd, 0);
  return reason ? deny(reason) : allow();
}

// Fail-closed wrapper (#133). Any throw still delivers a valid deny decision
// on stdout and exits 0; a non-zero exit with empty stdout would fail OPEN.
try {
  main();
} catch (err) {
  const msg = err instanceof Error ? err.message : String(err);
  deny(`internal error, failing closed: ${msg}`);
}
