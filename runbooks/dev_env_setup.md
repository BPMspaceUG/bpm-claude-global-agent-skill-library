# Development Environment Setup Runbook

Follow these steps to set up a development environment for projects using the global Claude agents and skills.

## Install Prerequisites

- **Git**: version control
- **PHP**: version 8.x with Composer
- **Node.js**: for front‑end and n8n development (optional)
- **MariaDB**: for database
- **Redis**: for caching and queues
- **n8n**: if building workflows (can run via Docker)
- **Bash**: a POSIX‑compliant shell (usually available by default)

## Clone the Repository

```bash
git clone <your-project-repo-url>
cd <your-project-directory>
```

If this is the global library itself, clone:

```bash
git clone https://github.com/BPMspaceUG/bpm-claude-global-agent-skill-library.git
```

## Install Global Agents & Skills

Run the sync script to copy the global agents and skills into your Claude configuration:

```bash
cd bpm-claude-global-agent-skill-library
./sync
# or with n8n skills
./sync --n8n
```

## Set Up PHP Dependencies

If the project uses PHP:

```bash
composer install
```

## Set Up Database

- Create a new MariaDB database and user.
- Run any pending migrations (see the migration playbook).
- Configure your `.env` file with database credentials.

## Set Up Redis

- Ensure Redis is running locally or reachable.
- Configure Redis credentials in `.env`.

## Start n8n (Optional)

- Run `docker-compose up n8n` or use the n8n desktop app.
- Import workflows via the UI or via CLI.

## Running Tests

Execute the test harness:

```bash
./scripts/test.sh
```

## References

- Skill S01 – Repo & Project Scaffold Standard
- Skill S04 – Config & Secrets Standard
- Skill S11 – Test Harness Standard