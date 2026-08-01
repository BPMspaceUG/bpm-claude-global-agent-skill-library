---
name: c-bpm-sk-appsec-threatlite
description: "Security review checklist — threat model, appsec review, vulnerability check, file handling safety, auth review, compliance, remediation tracking. Lightweight security review with structured reporting."
enforcement: block
intentPatterns: "threat model;;security (review|checklist|audit);;appsec review;;vulnerability (check|scan)"
user-invocable: false
---

# AppSec & Threat Lite

Lightweight threat-model and checklist for application security, focusing on file handling safety and minimising common vulnerabilities.

## Checklist

- [ ] Identify assets (data, credentials, endpoints) and threats (unauthorised access, tampering)
- [ ] Validate all inputs; enforce strict types and ranges
- [ ] Sanitize filenames and paths to prevent directory traversal
- [ ] Check archives for zip-slip by verifying extraction paths
- [ ] Avoid sensitive files in publicly accessible directories
- [ ] Limit file uploads by size and type; scan for malware where possible
- [ ] Log security events (login attempts, permission changes) with timestamps
- [ ] Least privilege: scripts and processes run with minimal permissions
- [ ] Dependencies up to date and free from known vulnerabilities
- [ ] Review authentication and authorisation in backends and APIs
- [ ] Review `.env` and configuration files for secrets exposure
- [ ] Verify TLS and HTTP header configuration (see c-bpm-sk-tls-http-headers)
- [ ] Consider compliance requirements (GDPR, PCI) where applicable

## Snippets

```bash
# Zip-slip check
extract_safe() {
  local archive="$1"
  local dest="$2"
  mkdir -p "$dest"
  while read -r file; do
    case "$file" in
      */*) dest_path="$dest/${file}";;
      *) dest_path="$dest/$file";;
    esac
    if [[ "$dest_path" != "$dest"* ]]; then
      echo "Unsafe file detected: $file"; return 1;
    fi
    mkdir -p "$(dirname "$dest_path")"
    unzip -p "$archive" "$file" > "$dest_path"
  done < <(zipinfo -1 "$archive")
}
```

## Success Criteria

- Threats identified and documented before implementation
- File operations protected against traversal and zip-slip
- Least privilege consistently applied
- Security controls included in application design

## Remediation Report

Structure security findings as:

| Field | Content |
|-------|---------|
| Finding | Description of the vulnerability |
| Severity | Critical / High / Medium / Low |
| File/Component | Affected file paths or workflow names |
| Recommended Action | Specific fix with best practice reference |
| Status | Open / In Progress / Resolved |

Track findings to closure — document vulnerabilities, assign to implementers, do not fix silently.

## Common Failure Modes

- Missing or superficial threat assessments
- Extracting archives without verifying file paths
- Running scripts as root when not necessary
- Ignoring dependency vulnerabilities

## Findings → Issues

Every finding this skill surfaces — bug, optimization, gap, decision-needed,
even a maybe-not-OK hunch — is filed as a GitHub Issue **immediately**, one
issue per discrete finding, at the moment it is found. Never ask first;
over-filing is fine, asking is not. Dedup before filing: search open issues
and skip only on a genuine match (note "already tracked: #N"). Every created
issue gets milestone `new` and exactly one type label — `bug` or
`enhancement` (lowercase) — at creation; issue-write-gate enforces both
mechanically. The user decides afterwards which issues are kept or worked on.

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
