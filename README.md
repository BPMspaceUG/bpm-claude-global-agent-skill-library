# Claude Global Agents & Skills Library

This repository contains a collection of **agents**, **skills**, **runbooks** and **templates** designed for use with Claude Code CLI. These resources are intended to be installed globally on your development machine so that they can be reused across multiple projects.

## Contents

- `agents/` – role definitions describing responsibilities, inputs, outputs and guardrails for each agent.
- `skills/` – playbooks that standardise how to perform common tasks across technologies. Each skill includes a goal, checklist, minimal examples, success criteria and common failure modes.
- `runbooks/` – detailed operational guides for recurring processes such as releases, environment setup, database migrations and workflow versioning.
- `templates/` – issue and pull‑request templates to streamline collaboration.

## Installation

To install these agents and skills into your global Claude configuration, run the following script from this repository:

```bash
# install the library
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/sync | bash

# install the library with optional n8n skills
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/sync | bash -s -- --n8n
```

The script will detect whether Claude stores its configuration in `~/.config/claude` or `~/.claude` and copy the `agents/`, `skills/`, `runbooks/` and `templates/` directories into the appropriate place. Use the `--n8n` flag to download and install the [czlonkowski/n8n-skills](https://github.com/czlonkowski/n8n-skills) pack as well.

## Usage

Once installed, you can reference these definitions in your prompts to Claude Code CLI. For example:

- *“Use the Bash secure script standard to implement the installer.”*
- *“As the Orchestrator, check the available MCP servers and provide an MCP Availability Handoff.”*

The Orchestrator agent is responsible for discovering which MCP servers are available in your session and publishing that information in its planning outputs. All other agents rely on this declaration and do not probe MCP servers on their own.

## External Skill Packs

The n8n skill pack is maintained in a separate repository. When the `--n8n` option is used, the `sync` script will clone the pack and copy its compiled skills into your global `skills/` directory. You can update the n8n skill pack by rerunning the `sync` script with `--n8n`.

## License

This library is provided under the MIT License. See the `LICENSE` file for details.