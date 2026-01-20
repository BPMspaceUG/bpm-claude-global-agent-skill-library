# BPMspace Claude Global Agents & Skills Library

This repository contains a collection of **agents**, **skills**, **runbooks** and **templates** designed for use with Claude Code CLI. These resources are intended to be installed globally on your development machine so that they can be reused across multiple projects.

## Contents

- `agents/` – role definitions describing responsibilities, inputs, outputs and guardrails for each agent.
- `skills/` – playbooks that standardise how to perform common tasks across technologies. Each skill includes a goal, checklist, minimal examples, success criteria and common failure modes.
- `runbooks/` – detailed operational guides for recurring processes such as releases, environment setup, database migrations and workflow versioning.
- `templates/` – issue and pull‑request templates to streamline collaboration.

## Installation

### One-time usage

Without n8n skills:
```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/sync | bash
```

With n8n skills:
```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/sync | bash -s -- --n8n
```

### Install bcgasl command (for repeated use)

Interactive (asks user/global):
```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/install | bash
```

User install (`~/.local/bin/bcgasl`):
```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/install | bash -s -- --user
```

Global install (`/usr/local/bin/bcgasl`, requires sudo):
```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/install | bash -s -- --global
```

Both user and global install:
```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/install | bash -s -- --all
```

### Usage

Install/update agents & skills:
```bash
bcgasl
```

With n8n skills:
```bash
bcgasl --n8n
```

Preview changes without applying:
```bash
bcgasl --dry-run
```

Show version:
```bash
bcgasl --version
```

The sync copies `agents/`, `skills/`, `runbooks/` and `templates/` to `~/.config/claude` or `~/.claude`. Use `--n8n` to also install [czlonkowski/n8n-skills](https://github.com/czlonkowski/n8n-skills).

## Usage

Once installed, you can reference these definitions in your prompts to Claude Code CLI. For example:

- *“Use the Bash secure script standard to implement the installer.”*
- *“As the Orchestrator, check the available MCP servers and provide an MCP Availability Handoff.”*

The Orchestrator agent is responsible for discovering which MCP servers are available in your session and publishing that information in its planning outputs. All other agents rely on this declaration and do not probe MCP servers on their own.

## External Skill Packs

The n8n skill pack is maintained in a separate repository. When the `--n8n` option is used, the `sync` script will clone the pack and copy its compiled skills into your global `skills/` directory. You can update the n8n skill pack by rerunning the `sync` script with `--n8n`.

## License

This library is provided under the MIT License. See the `LICENSE` file for details.