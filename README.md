# Claude Global Agents & Skills Library

This repository contains a collection of **agents**, **skills**, **runbooks** and **templates** designed for use with Claude Code CLI. These resources are intended to be installed globally on your development machine so that they can be reused across multiple projects.

## Contents

- `agents/` – role definitions describing responsibilities, inputs, outputs and guardrails for each agent.
- `skills/` – playbooks that standardise how to perform common tasks across technologies. Each skill includes a goal, checklist, minimal examples, success criteria and common failure modes.
- `runbooks/` – detailed operational guides for recurring processes such as releases, environment setup, database migrations and workflow versioning.
- `templates/` – issue and pull‑request templates to streamline collaboration.

## Installation

### Install cgasl command

```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/install | bash
```

Choose:
- `[1]` User install → `~/.local/bin/cgasl`
- `[2]` Global install → `/usr/local/bin/cgasl` (requires sudo)

### Usage

```bash
cgasl         # Install/update agents & skills
cgasl --n8n   # Install/update with n8n skills
cgasl --help  # Show help
```

### Manual (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/sync | bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/sync | bash -s -- --n8n
```

The sync script detects Claude config location (`~/.config/claude` or `~/.claude`) and copies the `agents/`, `skills/`, `runbooks/` and `templates/` directories. Use `--n8n` to also install [czlonkowski/n8n-skills](https://github.com/czlonkowski/n8n-skills).

## Usage

Once installed, you can reference these definitions in your prompts to Claude Code CLI. For example:

- *“Use the Bash secure script standard to implement the installer.”*
- *“As the Orchestrator, check the available MCP servers and provide an MCP Availability Handoff.”*

The Orchestrator agent is responsible for discovering which MCP servers are available in your session and publishing that information in its planning outputs. All other agents rely on this declaration and do not probe MCP servers on their own.

## External Skill Packs

The n8n skill pack is maintained in a separate repository. When the `--n8n` option is used, the `sync` script will clone the pack and copy its compiled skills into your global `skills/` directory. You can update the n8n skill pack by rerunning the `sync` script with `--n8n`.

## License

This library is provided under the MIT License. See the `LICENSE` file for details.