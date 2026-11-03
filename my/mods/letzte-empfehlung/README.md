# letzte-empfehlung

Claude Code mod: a pane on the right of the chat titled "Letzte Empfehlung".
It shows the last action line of an answer ("Robert, du bist dran: …" or
"Claude ist dran, …", skill `c-bpm-sk-next-step`) and keeps it across `/clear`
by reading the per-pane cache that the hook `c-bpm-hk-ask-matt-after-clear`
writes (`~/.cache/c-bpm-next-step/pane-<n>`), else its own store per directory.

The pane opens by itself when the terminal is at least 144 columns wide;
`/empfehlung` opens it at any width.

Loaded in every session through `CLAUDE_CODE_PLUGIN_DIRS` in the `env` block of
`~/.claude/settings.json`, pointing at this folder. Check: `claude plugin validate my/mods/letzte-empfehlung`.
