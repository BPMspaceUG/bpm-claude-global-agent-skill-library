---
model: opus
name: c-bpm-sk-idea-merge
description: "Cluster and merge ideas — cluster ideas, merge ideas, find duplicates, group similar issues, clean up ideas, deduplicate. Scans repos (Obsidian vaults, GitHub Issues) for clusterable ideas. User approves each action."
user-invocable: true
argument-hint: "[repo-path or owner/repo]"
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# c-bpm-sk-idea-merge

## Overview

Find clusters of related ideas or issues, suggest restructuring and merges, but
NEVER execute without explicit user approval per cluster.

**Philosophy:** Prefer restructuring (folders, tags, links) over content merging.
Organizing is always safer than combining.

**Primary target:** `BPMspaceUG/bpm-ideas` Obsidian vault.
Also works on any GitHub repo with open issues.

---

## Scan Modes

### Obsidian Vault Mode (local MD files)

**Detection:** Argument is a local path containing `.obsidian/` directory or `*.md` files.

**Scan procedure:**
1. `Glob **/*.md` to collect all markdown files
2. Read each file's frontmatter: `tags`, `status`, `org`, `related` fields
3. Extract all `[[wiki-links]]` from body content
4. Note folder location for each file

**Available signals:** title keyword overlap, tag overlap, wiki-link connections,
content key-phrase overlap, folder co-location.

**Threshold:** 2+ signals match to form a candidate cluster.

### GitHub Issues Mode (remote repo)

**Detection:** Argument is `owner/repo` format or current repo (detect via `gh repo view`).

**Auth check:** Run `gh auth status` first. Fail early with clear message if not authenticated.

**Scan procedure:**
```bash
gh api "repos/{owner}/{repo}/issues?state=open&per_page=100" \
  --jq '.[] | select(.pull_request == null) | {number, title, body, labels: [.labels[].name], milestone: .milestone.title}'
```

**Available signals:** title keyword overlap, label overlap, body keyword overlap,
referenced-repo grouping, milestone co-assignment.

**Threshold:** 2+ signals match to form a candidate cluster.

---

## Cluster Detection

Each signal is binary (match or no match). Score per pair of items:

| Signal | Obsidian | GitHub | Detection Method |
|--------|----------|--------|------------------|
| Title keyword overlap | yes | yes | Tokenize titles, remove stopwords, Jaccard > 0.3 |
| Tag/label overlap | yes | yes | 2+ shared tags or labels |
| Wiki-link connection | yes | no | Direct `[[link]]` between items or shared link targets |
| Content key-phrase overlap | yes | yes | Extract top-10 nouns/phrases, 3+ overlap |
| Folder co-location | yes | no | Same folder (e.g., both in `bpm/`) |
| Referenced-repo grouping | no | yes | Same repo/project mentioned in issue body |
| Milestone co-assignment | no | yes | Same milestone assigned |

**Clustering rules:**
- Items sharing 2+ signals (within their respective mode) form a cluster
- Rank clusters by total signal count (more signals = stronger relationship)
- One item may appear in multiple clusters — flag these overlaps to user

---

## Presentation Protocol

Present each cluster with full context. User decides per cluster.

**Format:**
```
### Cluster N (K signals: signal-a, signal-b, ...)
Items: item-1.md, item-2.md, item-3.md
Reason: <human-readable explanation of why these cluster>
Proposed action: <ACTION_TYPE> — <specific steps>
```

**Action types:**

| Action | When to propose | What it does |
|--------|----------------|--------------|
| `RESTRUCTURE` | Items belong together structurally | Move/reorganize files or folders, add links |
| `MERGE` | Items are clearly the same idea | Combine content into one item, archive others |
| `LINK` | Related but distinct ideas | Add cross-references without moving |
| `DUPLICATE` | One item is a subset of another | Close one, reference the other |

**User interaction:**
- Present ALL clusters before executing any
- User approves, rejects, or modifies EACH cluster individually
- User may change action type (e.g., downgrade MERGE to LINK)
- Proceed only with approved clusters

---

## Execution (after user approval per cluster)

### Step 1: Codex Gate

Before ANY mutations, invoke Codex for review:

```bash
codex exec --skip-git-repo-check \
  "Review these proposed changes for [repo]: [cluster summary with proposed actions]. \
   Are groupings warranted? Should any items be split instead? \
   Missing items that belong in a cluster?"
```

Post the Codex response to the user. Only execute if BOTH user AND Codex approve.

**Codex fallback chain:** codex → gemini → notify user (manual review required).

### Step 2: Dry-Run Diff

Show exactly what will change before executing. For each approved cluster:
- Files to create, move, or edit
- Content additions (wiki-links, frontmatter updates)
- Issues to close or label (GitHub mode)

### Step 3: Execute Mutations

**Obsidian vault mutations:**
- Create or edit MD files as needed
- Update `[[wiki-links]]` in affected files
- Move files to new folders (preserve git history with `git mv`)
- Update frontmatter `related:` fields
- Update all referrers: find files linking to moved/renamed items and fix their `[[wiki-links]]`

**GitHub issue mutations:**
```bash
# Close as duplicate
gh issue close {number} -c "Duplicate of #{target}" -R {owner}/{repo}

# Update issue body
gh issue edit {number} --body "..." -R {owner}/{repo}

# Add labels
gh issue edit {number} --add-label "{label}" -R {owner}/{repo}

# Add comment
gh issue comment {number} --body "..." -R {owner}/{repo}
```

---

## Rules

1. **Never auto-merge** without explicit user confirmation per cluster
2. **Never delete** files or issues — only archive (move to `_archive/` folder) or close with references
3. **Prefer restructuring** over merging — organizing is safer than combining
4. **Preserve all original content** — merged items keep full text with attribution
5. **Update all referrers** — outgoing `[[wiki-links]]` from affected files must be fixed in every file that references them
6. **Codex approval required** — no mutations without Codex review (fallback chain applies)
7. **Dry-run first** — always show the diff before executing
8. **Idempotent** — running the scan again after execution should show no new clusters for already-processed items
