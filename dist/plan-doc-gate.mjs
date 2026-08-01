#!/usr/bin/env node
// plan-doc-gate.mjs — PreToolUse hook for BPMspaceUG#105
//
// Enforces #104 at RUNTIME: everything belongs in the GitHub Issue, so an
// agent must not author plan/doc side-car files (`~/.claude/plans/*.md`,
// scratchpad `prompt.md`, `plan.md`, `ISSUE_<n>_PLAN.md`, ...).
//
// HAND-MAINTAINED BUILD ARTIFACT. There is no build step in this repo; this
// file and my/hooks/plan-doc-gate.ts must be edited together. Parity is
// enforced by tests/bash/c-bpm-sk-plan-doc-gate.bats ("ts/dist parity").
//
// ── WHY PATH RULES AND NOT CONTENT HEURISTICS ────────────────────────────
//
// The sibling gate (issue-write-gate) burned four review rounds on exactly one
// failure mode: a shape/content heuristic that kept over-blocking ordinary
// work (`grep -c`, then `ssh -c`). Over-blocking is the dominant risk for a
// gate wired to Write/Edit, because a false positive there stops ALL repo
// work, not one command.
//
// So this gate decides on WHERE the file is and WHAT IT IS NAMED, full stop:
//   * it never reads the file, and never inspects tool_input.content /
//     new_string / old_string. A file is never blocked because its text
//     "looks like a plan";
//   * only .md/.markdown/.txt are even candidates, so code, tests, fixtures,
//     build artifacts, install scripts and every other repo write are allowed
//     by construction, before any rule runs;
//   * maintained docs (CLAUDE.md, agent.md, README.md, SKILL.md,
//     SHARED_TASK_NOTES.md, ...) are on an explicit allowlist;
//   * the deny set is a short, enumerated list of the side-car class named by
//     #104 — nothing inferred, nothing fuzzy.
//
// Consequence, stated plainly: a plan side-car under an unusual name (say
// `roadmap-v2.md`) passes. That is deliberate. This layer is the cheap runtime
// tripwire for the named class; the CI check from #104 remains the broad one.
//
// Contract (identical to issue-write-gate):
//   stdin:  JSON {tool_name, tool_input, cwd, ...}
//   stdout: JSON {hookSpecificOutput: {hookEventName, permissionDecision,
//                permissionDecisionReason}, ...legacy flat mirror}
//   exit:   ALWAYS 0 — including on an internal error, which emits `deny`
//           (fail-closed). #133: exiting non-zero with empty stdout delivers
//           NO decision to the harness, i.e. it fails OPEN. Never do that.
//
// Test mode env vars (used by tests/bash/c-bpm-sk-plan-doc-gate.bats):
//   PLAN_DOC_GATE_FORCE_ERROR=1   throws inside main() to prove fail-closed

import { readFileSync, existsSync } from 'fs';

// #155 sentinel: classify() returns this instead of null when the write is
// the sanctioned SPEC.md-paired PLAN.md deliverable (exact-name PLAN.md with
// sibling SPEC.md and a .git entry at a repo root), so the call site can
// emit an allow reason that names the exception.
const SPEC_DELIVERABLE = 'SPEC_DELIVERABLE_ALLOW';

// cwd of the tool call — needed only to resolve a relative PLAN.md path for
// the #155 sibling-existence checks. Set in main() before classify().
let CWD = '';

// Tools that write a file. Anything else is allowed untouched.
const WRITE_TOOLS = new Set([
  'Write', 'Edit', 'MultiEdit', 'NotebookEdit'
]);

// The ONLY extensions this gate considers. Everything else — .ts, .mjs, .sh,
// .json, .bats, extensionless scripts like `install-hooks` — is allowed
// before any classification runs.
const DOC_EXT = /\.(md|markdown|txt)$/i;

// Maintained docs, allowed by name wherever they live. `agent.md`/`agents.md`
// and `README.md` are explicitly here so #95-class docs work is never blocked;
// SHARED_TASK_NOTES.md is loaded by c-bpm-cm-openissues-team.md.
const MAINTAINED_DOCS = new Set([
  'claude.md', 'agent.md', 'agents.md', 'gemini.md', 'vibe.md', 'readme.md',
  'skill.md', 'changelog.md', 'contributing.md', 'license.md', 'security.md',
  'codeowners.md', 'shared_task_notes.md', 'issue_template.md', 'pr_template.md'
]);

// Directory segments whose contents are repo-maintained by definition: test
// trees and their fixtures, templates, vendored code, build output.
const ALLOW_SEGMENTS = new Set([
  'test', 'tests', '__tests__', 'fixtures', 'templates',
  'node_modules', '.git', 'dist', 'vendor'
]);

// Side-car stems named by #104 (exact match on the extension-stripped
// basename, lowercased).
const SIDECAR_STEMS = new Set([
  'plan', 'plans', 'prompt', 'prompts', 'scratch', 'scratchpad'
]);

// `implementation-plan.md`, `issue-105_plan.md`, ... — a stem that ENDS in a
// plan suffix. Anchored so `db_migration_playbook.md` does not match.
const PLAN_SUFFIX = /[-_](plan|plans)$/;

// `ISSUE_105_PLAN.md`, `issue-105-notes.md`, `issue105.md`. Digits are
// REQUIRED, so `ISSUE_TEMPLATE.md` is not a match.
const ISSUE_SIDECAR = /^issue[-_]?\d+/;

function emit(decision, reason = '') {
  process.stdout.write(JSON.stringify({
    // Authoritative shape per current Claude Code hook docs (#99).
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: decision,
      permissionDecisionReason: reason
    },
    // ponytail: legacy flat mirror, matching issue-write-gate. Older builds
    // read these top-level keys; without them the gate fails OPEN. Remove
    // when the sibling hook's mirror is removed — not before, not separately.
    permissionDecision: decision,
    permissionDecisionReason: reason
  }));
  process.exit(0);
}
const allow = (r = '') => emit('allow', r);
const deny  = (r) => emit('deny', `[plan-doc-gate] ${r}`);

function basename(p) {
  const i = p.lastIndexOf('/');
  return i < 0 ? p : p.slice(i + 1);
}

function segments(p) {
  return p.split('/').filter(Boolean);
}

function stem(name) {
  return name.replace(DOC_EXT, '').toLowerCase();
}

// Returns a deny reason, or null to allow. PATH IN, VERDICT OUT — no file is
// read, no tool_input content is consulted.
function classify(rawPath) {
  const path = rawPath.replace(/\\/g, '/');
  const name = basename(path);
  const lower = name.toLowerCase();

  if (!DOC_EXT.test(lower)) return null;              // not a doc file at all
  if (MAINTAINED_DOCS.has(lower)) return null;        // maintained doc

  const segs = segments(path);
  for (const s of segs.slice(0, -1)) {
    if (ALLOW_SEGMENTS.has(s.toLowerCase())) return null;
  }

  // A Claude plans directory — `~/.claude/plans/anything.md`. Named verbatim
  // by #104, so the whole directory is the side-car class regardless of stem.
  for (let i = 0; i + 1 < segs.length; i++) {
    if (segs[i].toLowerCase() === '.claude' && segs[i + 1].toLowerCase() === 'plans') {
      return `"${name}" is under a .claude/plans/ directory. Plans belong in the GitHub Issue body or a comment, not in a file (#104).`;
    }
  }

  // #155 spec-deliverable exception: `PLAN.md` (exact name) at a REPO ROOT
  // that pairs with `SPEC.md` is a mandated product deliverable of SPEC-driven
  // repos, not a run side-car. Three conditions, all in the same directory at
  // decision time: exact basename PLAN.md, a sibling SPEC.md, and a `.git`
  // entry (the repo-root marker). Runs after the .claude/plans check, so the
  // plans-dir denial wins even with a planted SPEC.md.
  if (name === 'PLAN.md') {
    const slash = path.lastIndexOf('/');
    let dir = slash < 0 ? '' : path.slice(0, slash + 1);
    if (!path.startsWith('/') && !/^[A-Za-z]:\//.test(path)) {
      dir = `${(CWD || '.').replace(/\\/g, '/')}/${dir}`;
    }
    if (existsSync(`${dir}SPEC.md`) && existsSync(`${dir}.git`)) {
      return SPEC_DELIVERABLE;
    }
  }

  const st = stem(lower);
  if (SIDECAR_STEMS.has(st) || PLAN_SUFFIX.test(st) || ISSUE_SIDECAR.test(st)) {
    return `"${name}" is an authored plan/doc side-car. Put the plan, progress, decisions and review notes in the GitHub Issue (body or comment) instead — no side-car files (#104).`;
  }

  return null;
}

function main() {
  if (process.env.PLAN_DOC_GATE_FORCE_ERROR === '1') {
    throw new Error('forced internal error (test seam)');
  }

  let raw = '';
  try { raw = readFileSync(0, 'utf8'); } catch {}
  let input;
  try { input = JSON.parse(raw); } catch {
    // Not an internal error: a payload we cannot parse carries no file path,
    // and this gate's class is defined by paths. Denying every write on
    // malformed input would halt all repo work. Matches issue-write-gate.
    return allow('hook input not parseable; passing through');
  }

  const tool = input.tool_name || '';
  if (!WRITE_TOOLS.has(tool)) return allow('non-write tool');

  const ti = input.tool_input || {};
  const target = ti.file_path ?? ti.notebook_path ?? ti.path;
  if (typeof target !== 'string' || !target) return allow('no file path in tool input');

  CWD = typeof input.cwd === 'string' ? input.cwd : '';
  const reason = classify(target);
  if (reason === SPEC_DELIVERABLE) {
    return allow('"PLAN.md" next to SPEC.md at a repo root — sanctioned spec deliverable, not a side-car (#155)');
  }
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
