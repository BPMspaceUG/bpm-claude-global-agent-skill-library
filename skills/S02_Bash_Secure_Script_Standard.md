# Skill S02 – Bash Secure Script Standard

## Goal

Define a pattern for writing robust, maintainable and secure Bash scripts used for installation, updates and other automation tasks.

## When to Use

- Any time you create a new Bash script for automation.
- When refactoring an existing script to meet security and reliability requirements.

## Checklist

- [ ] Start your script with `#!/usr/bin/env bash`.
- [ ] Enable strict mode: `set -euo pipefail` and define a safe IFS.
- [ ] Define a `cleanup` function and trap it on `EXIT`, `INT` and `TERM`.
- [ ] Use `mktemp -d` for temporary files and ensure they are removed on exit.
- [ ] Quote all variable expansions and use braces `{}` to avoid globbing.
- [ ] Use functions to encapsulate logic and improve readability.
- [ ] Validate all inputs (arguments, environment variables, file paths).
- [ ] Provide usage/help output when invoked with `-h` or `--help`.
- [ ] Use consistent logging functions for info, warning and error messages.
- [ ] Ensure the script is idempotent: re‑running it does not cause errors or duplicate effects.

## Minimal Snippets

```
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

- The script terminates early on errors and logs meaningful messages.
- Temporary resources are cleaned up properly.
- Scripts can be run repeatedly without causing unintended side effects.

## Common Failure Modes

- Unquoted variables leading to word splitting or globbing.
- Failure to handle errors from external commands.
- Temporary files left behind, leading to clutter or security issues.