// issue-write-gate.ts — TypeScript source for dist/issue-write-gate.mjs.
//
// PreToolUse hook for BPMspaceUG#68. Blocks GitHub issue creation when
// --milestone or a single bug|enhancement type label is missing.
// See dist/issue-write-gate.mjs for the runnable build artifact.
//
// Hook contract:
//   stdin:  JSON {tool_name, tool_input, cwd, ...}
//   stdout: JSON {permissionDecision: 'allow'|'deny', permissionDecisionReason}
//   exit:   always 0 (decision in stdout); non-zero is a hook bug
//
// Test mode env vars:
//   FIXTURE_MILESTONES         JSON {name: number} mocking gh api milestones
//   FIXTURE_REPO               "owner/repo" string skipping git resolution
//   FIXTURE_REPO_RESOLVE=fail  forces resolveRepo() → null

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

function emit(decision: 'allow' | 'deny', reason = ''): never {
  process.stdout.write(JSON.stringify({
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

function stripPrefixes(argv: string[]): string[] {
  let i = 0;
  while (i < argv.length) {
    const t = argv[i];
    if (t === 'command' || t === 'exec' || t === 'env') { i++; continue; }
    if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(t)) { i++; continue; }
    break;
  }
  return argv.slice(i);
}

function pushFlag(obj: FlagResult, key: string, val: string, multi: boolean): void {
  if (multi) {
    if (!Array.isArray(obj[key])) obj[key] = [];
    for (const part of val.split(',')) (obj[key] as string[]).push(part);
  } else {
    obj[key] = val;
  }
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
        pushFlag(result, key, tok.slice(short.length), spec.multi);
        matched = true; break;
      }
    }
    if (!matched) positional.push(tok);
  }
  result._positional = positional;
  return result;
}

function isGhApiIssueCreate(argv: string[]): boolean {
  const args = argv.slice(2);
  let method: string | null = null;
  let hasFields = false;
  let urlIsIssuesCreate = false;

  for (let i = 0; i < args.length; i++) {
    const t = args[i];
    if (t === '-X' || t === '--method') { method = (args[++i] || '').toUpperCase(); continue; }
    if (t.startsWith('--method=')) { method = t.slice(9).toUpperCase(); continue; }
    if (t.startsWith('-X') && t.length > 2 && !t.startsWith('-XX')) {
      method = t.slice(t.startsWith('-X=') ? 3 : 2).toUpperCase();
      continue;
    }
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

  if (!urlIsIssuesCreate) return false;
  if (method === 'POST') return true;
  if (method !== null) return false;
  return hasFields;
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

let milestoneCache: (MilestoneCatalog & { repo: string }) | null = null;

function getRepoMilestones(repo: string): MilestoneCatalog | null {
  if (process.env.FIXTURE_MILESTONES) {
    const map = JSON.parse(process.env.FIXTURE_MILESTONES) as Record<string, number>;
    const byNum = new Map<number, string>(); const byName = new Set<string>();
    for (const [name, num] of Object.entries(map)) {
      byNum.set(Number(num), name);
      byName.add(name);
    }
    return { byNum, byName };
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
      if (!line) continue;
      const [n, t] = line.split('\t');
      byNum.set(Number(n), t); byName.add(t);
    }
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
    return `cannot fetch milestones for repo ${repo} (gh api failed or timed out). Fail-closed.`;
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

function main(): never {
  let raw = '';
  try { raw = readFileSync(0, 'utf8'); } catch {}
  let input: HookInput;
  try { input = JSON.parse(raw); } catch {
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

  let argv: string[];
  try { argv = tokenise(cmd); } catch {
    if (/\bgh\s+(issue\s+create|api\b)/.test(cmd)) {
      return deny('command parse failed (unbalanced quotes?). Manual review required.');
    }
    return allow('non-parsable but not gh issue create');
  }

  const stripped = stripPrefixes(argv);
  if (stripped[0] !== 'gh') return allow('non-gh command');

  if (stripped[1] === 'issue' && stripped[2] === 'create') {
    const flags = extractFlags(stripped.slice(3), {
      '--milestone': { short: '-m', multi: false },
      '--label':     { short: '-l', multi: true  }
    });
    const repo = resolveRepo(cwd);
    const reason = validate(flags.milestone, flags.label, repo);
    return reason ? deny(reason) : allow();
  }

  if (stripped[1] === 'api' && isGhApiIssueCreate(stripped)) {
    const fields = extractGhApiFields(stripped);
    const repo = repoFromGhApiUrl(stripped) || resolveRepo(cwd);
    const reason = validate(fields.milestone, fields.labels, repo);
    return reason ? deny(reason) : allow();
  }

  return allow('non-issue gh subcommand');
}

main();
