---
name: my-bash-secure-script
description: Pattern for robust, maintainable, and secure Bash scripts. Use when creating new automation scripts, refactoring existing scripts, or reviewing scripts for security and reliability. Derived from S02.
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
