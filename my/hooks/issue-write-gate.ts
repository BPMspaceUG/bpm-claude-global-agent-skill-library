// issue-write-gate.ts — TypeScript source for dist/issue-write-gate.mjs.
//
// PreToolUse hook for BPMspaceUG#68. Blocks GitHub issue creation when
// --milestone or a single bug|enhancement type label is missing.
//
// NO BUILD STEP EXISTS in this repo. dist/issue-write-gate.mjs is the
// hand-maintained runnable artifact and is what Claude Code actually executes.
// Any change here MUST be mirrored there in the same commit; the bats suite
// ("ts/dist parity") pins both files by checksum and compares declarations.
//
// Hook contract:
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
// Test mode env vars:
//   FIXTURE_MILESTONES         JSON {name: number} mocking gh api milestones
//   FIXTURE_REPO               "owner/repo" string skipping git resolution
//   FIXTURE_REPO_RESOLVE=fail  forces resolveRepo() → null
//   ISSUE_WRITE_GATE_FORCE_ERROR=1  throws inside main() to prove fail-closed

import { readFileSync } from 'fs';
import { execFileSync } from 'child_process';

interface HookInput {
  tool_name?: string;
  tool_input?: Record<string, unknown>;
  cwd?: string;
}

interface FlagSpec {
  short?: string;
  multi: boolean;
}

interface FlagResult {
  [key: string]: string | string[] | undefined;
  _positional?: string[];
}

interface MilestoneCatalog {
  byNum: Map<number, string>;
  byName: Set<string>;
}

const LIFECYCLE: ReadonlySet<string> = new Set([
  'new', 'planned', 'plan-approved', 'test-designed', 'test-design-approved',
  'implemented', 'tested-success', 'tested-failed', 'test-approved',
  'reviewed', 'review-approved', 'investigating', 'resolved'
]);
// DONE deliberately excluded — human-only per c-bpm-sk-milestone-type.

const TYPE_LABELS: ReadonlySet<string> = new Set(['bug', 'enhancement']);

const MCP_CREATE_TOOLS: ReadonlySet<string> = new Set([
  'mcp__github__issue_write',
  'mcp__github__create_issue'
]);

// Shell operators that end one command and start another (#71): `true && gh
// issue create ...` must be gated, not waved through because argv[0] != gh.
const OPERATORS: ReadonlySet<string> = new Set(['&&', '||', ';', '|', '&']);

// Known shell runners (#71). NOT the trigger for unwrapping — that is
// shape-based, see decideSegment (#133). This set only picks the unwrap start
// point when a known runner sits mid-segment, carries `eval`'s join-the-rest
// semantics, and marks a payload as definitely-a-command for fail-closed
// tokenisation.
const SHELL_RUNNERS: ReadonlySet<string> = new Set(['bash', 'sh', 'zsh', 'dash', 'ksh', 'eval']);

const GH_COMMAND: ReadonlySet<string> = new Set(['gh']);

// #136: tools whose `-c` is NOT a command payload. `grep -c PATTERN` is a
// count, `sort -c` a check, `git -c k=v` a config override — re-gating their
// argument denied `grep -c "gh issue create" notes.txt`, i.e. the gate blocked
// anyone auditing this repo for that very pattern.
//
// This is a NARROW, name-based EXCEPTION to the shape-based unwrap, and it is
// deliberately the only name-based trust in the path: a name NOT on this list
// is still unwrapped and inspected, so unknown heads can never fail open (see
// decideSegment). Consulted only for the word that OWNS the flag (see
// shellPayloads), never for any word merely present in the segment — otherwise
// `mysh -c "gh issue create" grep` would disable its own unwrap.
const NON_SHELL_C_FLAG: ReadonlySet<string> = new Set([
  'grep', 'egrep', 'fgrep', 'rg', 'ag', 'ack', 'sort', 'uniq', 'awk',
  'tar', 'cpio', 'git', 'docker', 'podman', 'systemctl', 'cmake'
]);

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

function emit(decision: 'allow' | 'deny', reason = ''): never {
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
const allow = (r = ''): never => emit('allow', r);
const deny  = (r: string): never => emit('deny', `[issue-write-gate] ${r}`);

function tokenise(cmd: string): string[] {
  const out: string[] = [];
  let i = 0, cur = '', inSingle = false, inDouble = false, started = false;
  while (i < cmd.length) {
    const c = cmd[i];
    if (inSingle) {
      if (c === "'") { inSingle = false; i++; continue; }
      cur += c; i++; continue;
    }
    if (inDouble) {
      if (c === '"') { inDouble = false; i++; continue; }
      if (c === '\\' && i + 1 < cmd.length && '"\\$`'.includes(cmd[i + 1])) {
        cur += cmd[i + 1]; i += 2; continue;
      }
      cur += c; i++; continue;
    }
    if (c === "'") { inSingle = true; started = true; i++; continue; }
    if (c === '"') { inDouble = true; started = true; i++; continue; }
    if (c === '\\' && i + 1 < cmd.length) { cur += cmd[i + 1]; started = true; i += 2; continue; }
    if (/\s/.test(c)) {
      if (started) { out.push(cur); cur = ''; started = false; }
      i++; continue;
    }
    cur += c; started = true; i++;
  }
  if (inSingle || inDouble) throw new Error('unbalanced quotes');
  if (started) out.push(cur);
  return out;
}

// #70: `/usr/bin/gh issue create` is the same command as `gh issue create`.
function basename(tok: string): string {
  const i = tok.lastIndexOf('/');
  return i < 0 ? tok : tok.slice(i + 1);
}

function splitSegments(argv: string[]): string[][] {
  const segs: string[][] = [];
  let cur: string[] = [];
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
function findCommandIndex(seg: string[], names: ReadonlySet<string>): number {
  for (let i = 0; i < seg.length; i++) {
    if (names.has(basename(seg[i]))) return i;
  }
  return -1;
}

// Payloads handed to a shell runner, for recursive re-gating.
//
// #136: `owner` tracks the last non-flag word before the `-c` flag — the tool
// the flag actually belongs to. `sudo grep -c pat f` → grep, `mysh -c "cmd" x`
// → mysh. Only that word is checked against NON_SHELL_C_FLAG, so a trailing
// operand cannot be used to suppress the unwrap.
function shellPayloads(head: string, seg: string[]): string[] {
  if (head === 'eval') {
    const rest = seg.slice(1);
    return rest.length ? [rest.join(' ')] : [];
  }
  let owner = head;
  for (let i = 1; i < seg.length; i++) {
    const t = seg[i];
    if (t.startsWith('--')) continue;
    if (t.startsWith('-')) {
      if (!t.includes('c')) continue;
      if (NON_SHELL_C_FLAG.has(basename(owner))) return [];
      return i + 1 < seg.length ? [seg[i + 1]] : [];
    }
    owner = t;
  }
  return [];
}

function extractFlags(argv: string[], specs: Record<string, FlagSpec>): FlagResult {
  const result: FlagResult = {};
  const positional: string[] = [];
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
        if (i + 1 < argv.length) pushFlag(result, key, argv[++i], spec.multi);
        matched = true; break;
      }
      if (short && tok === short) {
        if (i + 1 < argv.length) pushFlag(result, key, argv[++i], spec.multi);
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

function pushFlag(obj: FlagResult, key: string, val: string, multi: boolean): void {
  if (multi) {
    if (!Array.isArray(obj[key])) obj[key] = [];
    for (const part of val.split(',')) (obj[key] as string[]).push(part);
  } else {
    obj[key] = val;
  }
}

// Bias (#72): a missed create is worse than a false positive. Explicit
// -X/--method wins; otherwise body fields on the issues collection mean CREATE.
// GET is inferred only from an explicit method or the absence of body fields.
function ghApiCreateKind(argv: string[]): 'none' | 'create' | 'opaque' {
  const args = argv.slice(2);
  let method: string | null = null;
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

function extractGhApiFields(argv: string[]): { milestone?: string; labels?: string[] } {
  const labels: string[] = [];
  let milestone: string | undefined;
  const args = argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    const t = args[i];
    let kv: string | null = null;
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
  const out: { milestone?: string; labels?: string[] } = {};
  if (milestone !== undefined) out.milestone = milestone;
  if (labels.length) out.labels = labels;
  return out;
}

function repoFromGhApiUrl(argv: string[]): string | null {
  for (const t of argv.slice(2)) {
    const m = t.match(/repos\/([^/]+)\/([^/]+?)\/issues/);
    if (m) return `${m[1]}/${m[2]}`;
  }
  return null;
}

function hasInterpolation(s: unknown): boolean {
  return typeof s === 'string' && /\$[A-Za-z_{(]/.test(s);
}

function resolveRepo(cwd: string): string | null {
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
function normaliseRepoFlag(val: unknown): string | null {
  if (typeof val !== 'string') return null;
  if (hasInterpolation(val)) return null;
  return /^[^/\s]+\/[^/\s]+$/.test(val) ? val : null;
}

let milestoneCache: (MilestoneCatalog & { repo: string }) | null = null;

// Returns null for "cannot verify" — NEVER an empty catalog, which validate()
// would read as "milestone not present" and could not distinguish from a
// successful lookup. Every unparseable input lands on null → deny (#133).
function getRepoMilestones(repo: string): MilestoneCatalog | null {
  if (process.env.FIXTURE_MILESTONES) {
    let map: Record<string, number>;
    // #133: was an unguarded JSON.parse — the single throw that crashed the
    // whole hook to exit 1 with empty stdout, i.e. fail-OPEN.
    try {
      map = JSON.parse(process.env.FIXTURE_MILESTONES) as Record<string, number>;
    } catch {
      return null;
    }
    if (!map || typeof map !== 'object') return null;
    const byNum = new Map<number, string>(); const byName = new Set<string>();
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
    const byNum = new Map<number, string>(); const byName = new Set<string>();
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

function validate(milestone: unknown, labels: unknown, repo: string | null): string | null {
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

  let title: string;
  const looksNumeric = (typeof milestone === 'number') || /^\d+$/.test(String(milestone));
  if (looksNumeric) {
    const t = ms.byNum.get(Number(milestone));
    if (!t) return `milestone number ${milestone} not found in repo ${repo}. Create it via c-bpm-sk-milestone-type Step 1 first.`;
    title = t;
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

  const types: string[] = [];
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

// #74: curl / python / any HTTP client POSTing to the GitHub issues API.
//
// SCOPE LIMIT, stated so it is not mistaken for full coverage: this is
// heuristic INLINE string inspection of the Bash command itself. It catches
// `curl ... api.github.com/repos/o/r/issues` and
// `python3 -c "...requests.post(...)"`. It does NOT and cannot catch issue
// creation inside a script FILE — `python3 create_issue.py`, `./release.sh` —
// because the hook never sees that file's contents. Script-file invocation is
// out of scope for this layer and belongs to the GitHub Actions layer
// (issues.opened), which catches anything created outside Claude Code.
// Tracked as issue #131 — do not "fix" it here; the recommendation there is to
// enforce server-side rather than grow more inline heuristics.
function checkHttpClient(cmd: string): string | null {
  const isGraphql = GH_GRAPHQL.test(cmd);
  const rest = cmd.match(GH_REST_ISSUES);
  if (!isGraphql && !rest) return null;
  if (!POST_HINT.test(cmd)) return null;      // read-only call

  if (isGraphql) {
    return GQL_CREATE.test(cmd)
      ? 'GraphQL createIssue mutation detected; milestone and type label cannot be validated here. Use `gh issue create --milestone <lifecycle> --label bug|enhancement`.'
      : null;
  }

  const repo = `${rest![1]}/${rest![2]}`;
  const ms = cmd.match(/["']milestone["']\s*:\s*"?([^",}\s]+)"?/);
  const block = cmd.match(/["']labels["']\s*:\s*\[([^\]]*)\]/);
  const labels = block
    ? [...block[1].matchAll(/["']([^"']+)["']/g)].map((m) => m[1])
    : undefined;
  return validate(ms ? ms[1] : undefined, labels, repo);
}

function decideGh(argv: string[], cwd: string): string | null {
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

function decideSegment(seg: string[], cwd: string, depth: number): string | null {
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
  // precisely: the argument of a `-c` flag is re-gated UNLESS the word owning
  // the flag is one of the few tools listed in NON_SHELL_C_FLAG. Every other
  // head — including every unknown one — is still unwrapped and inspected, so
  // this exception adds no fail-open path. Its cost is the opposite direction:
  // an unlisted tool whose `-c` argument literally contains an issue-create
  // command line is denied. That is the safe direction, and the deliberate one.
  const r = findCommandIndex(seg, SHELL_RUNNERS);
  const start = r >= 0 ? r : 0;
  for (const payload of shellPayloads(basename(seg[start]), seg.slice(start))) {
    // strict = known runner: its payload is definitely a command, so an
    // unparsable one fails closed. A shape-only unwrap falls back to SUSPECT so
    // `grep -c "it's" f` is not denied while `rbash -c "gh issue create 'x"` is.
    const reason = decideBash(payload, cwd, depth + 1, r >= 0);
    if (reason) return reason;
  }

  // Independent fallback: a `gh` word visible in this segment, however it got
  // there. Runs regardless of the runner scan, so neither path can mask the
  // other.
  const j = findCommandIndex(seg, GH_COMMAND);
  if (j < 0) return null;
  return decideGh(seg.slice(j), cwd);
}

function decideBash(cmd: string, cwd: string, depth: number, strict = false): string | null {
  if (depth > MAX_DEPTH) {
    return `nested shell wrappers exceed depth ${MAX_DEPTH}; command cannot be inspected. Fail-closed.`;
  }

  const http = checkHttpClient(cmd);
  if (http) return http;

  let argv: string[];
  try {
    argv = tokenise(cmd);
  } catch {
    // #71: a payload handed to a known shell runner that will not tokenise is
    // always fail-closed — it was already established as a wrapped command.
    if (strict) return 'wrapped command payload failed to parse (unbalanced quotes?). Fail-closed.';
    if (SUSPECT.test(cmd)) return 'command parse failed (unbalanced quotes?). Manual review required.';
    return null;
  }

  for (const seg of splitSegments(argv)) {
    const reason = decideSegment(seg, cwd, depth);
    if (reason) return reason;
  }
  return null;
}

function main(): never {
  if (process.env.ISSUE_WRITE_GATE_FORCE_ERROR === '1') {
    throw new Error('forced internal error (test seam)');
  }

  let raw = '';
  try { raw = readFileSync(0, 'utf8'); } catch {}
  let input: HookInput;
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
  const ti = (input.tool_input || {}) as Record<string, unknown>;
  const cwd = input.cwd || process.cwd();

  if (tool.startsWith('mcp__')) {
    if (!MCP_CREATE_TOOLS.has(tool)) return allow('non-create MCP tool');
    const method = String(ti.method || ti.action || '').toLowerCase();
    const isCreate = method === 'create' || (tool.endsWith('create_issue') && !method);
    if (!isCreate) return allow('MCP non-create method');
    const repo = (ti.owner && ti.repo) ? `${ti.owner}/${ti.repo}`
               : (typeof ti.repo === 'string' ? ti.repo : resolveRepo(cwd));
    const reason = validate(ti.milestone, ti.labels, repo);
    return reason ? deny(reason) : allow();
  }

  if (tool !== 'Bash') return allow('non-Bash, non-MCP tool');
  const cmd = String(ti.command || '');
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
