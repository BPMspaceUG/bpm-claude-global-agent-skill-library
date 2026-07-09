---
model: opus
name: c-bpm-sk-bash-secure-script
description: "Secure Bash script — write bash script, shell script, automation script, bash best practices, set -euo pipefail. Robust, maintainable, and secure Bash patterns."
enforcement: block
intentPatterns: "secure bash script;;write (a )?bash script;;shell script (with|using) strict;;set -euo pipefail;;bash (best practice|automation)"
user-invocable: true
---

# Bash Secure Script

Define a pattern for writing robust, maintainable and secure Bash scripts used for installation, updates and other automation tasks.

## Checklist

- [ ] Shebang: `#!/usr/bin/env bash`
- [ ] Strict mode: `set -euo pipefail` and safe IFS
- [ ] `cleanup` function trapped on `EXIT`, `INT`, `TERM`
- [ ] `mktemp -d` for temporary files, cleaned up on exit
- [ ] Quote all variable expansions, use `${}`
- [ ] Functions to encapsulate logic
- [ ] Validate all inputs (arguments, environment variables, file paths)
- [ ] Usage/help on `-h` or `--help`
- [ ] Consistent logging functions (info, warning, error)
- [ ] Idempotent: re-running causes no errors or duplicates

## Template

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

cleanup() {
  rm -rf "${TMP_DIR:-}"
}
trap cleanup EXIT INT TERM

log() { printf '%s\n' "$@"; }

main() {
  # script logic goes here
  :
}

main "$@"
```

## Success Criteria

- Script terminates early on errors with meaningful messages
- Temporary resources are cleaned up
- Scripts can be run repeatedly without side effects

## Common Failure Modes

- Unquoted variables causing word splitting or globbing
- Failure to handle errors from external commands
- Temporary files left behind

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
