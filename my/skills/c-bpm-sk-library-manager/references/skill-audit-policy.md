# Skill Audit Policy — scorecard, principled splits, F3 Must-Stay Rule

Read when: auditing `c-bpm-sk-*` for cohesion, scoring a skill for well-formedness,
deciding whether two skills should be merged, or refactoring a SKILL.md into
`references/`.

Normative summaries live in `c-bpm-sk-library-manager/SKILL.md`. This file holds the
measurement detail. Governance: issues #54 (scorecard), #55 (principled splits),
#56 (F3 Must-Stay Rule); audit trail in #49.

---

## 1. Per-skill structural scorecard (#54)

Six binary dimensions, 0–6. **Threshold for 'well-formed': ≥ 5/6.**

| # | Dimension | Measure (binary) |
|---|---|---|
| 1 | Trigger discoverability | `description` contains the em-dash separator ` — ` and parses cleanly via the keyword extractor in `lib.sh` |
| 2 | Intent coverage | ≥ 3 distinct `intentPatterns` regexes |
| 3 | Tool boundary | `allowed-tools` declared **OR** `disable-model-invocation: true` |
| 4 | Argument awareness | `argument-hint` declared if `user-invocable: true` **AND** the body documents `$ARGUMENTS` |
| 5 | Token efficiency | SKILL.md ≤ 200 lines **OR** the skill uses `references/*.md` linked from the body |
| 6 | No content duplication | No paragraph > 3 lines repeated verbatim in another skill |

Scoring notes:

- Dimension 1 is falsifiable against the extractor, not against taste: a description
  without ` — ` silently loses every trigger keyword (the #52 defect class).
- Dimension 3 is an **either/or**, not a conjunction — a skill that is closed to the
  model (`disable-model-invocation: true`) has already bounded its blast radius.
- Dimension 5 is satisfied by *using* `references/`; it does not cap the reference
  files themselves.
- A skill scoring < 5/6 is not automatically wrong. It is automatically **explained**:
  record the failing dimension and the reason in the audit output.

## 2. Library-wide cohesion scorecard (#54)

| Metric | Definition |
|---|---|
| Description conformance % | share of `c-bpm-sk-*` whose description uses the em-dash structure |
| Frontmatter field-set consistency % | share sharing the modal field set (`name`, `description`, `enforcement`, `intentPatterns`, `user-invocable`) |
| Trigger collision count | number of `intentPattern` pairs that both match a prompt in the probe set |
| Library context budget | sum of frontmatter + description bytes across all skills |
| Lifecycle coverage % | share of domains that have a create → use → retire path |

Regression rule: a change that lowers any library-wide metric, or drops a skill below
5/6, must say so explicitly in its Issue before landing.

## 3. Principled splits — do not merge (#55)

These families **look** redundant to a surface-level audit and are not. Each was
checked for `intentPattern` overlap; each pair below has **zero** overlap on the probe
set. Evidence: #49 Rounds 5 and 6 (intentPattern shingle analysis).

| Family | Members | Split axis | Why merging breaks it |
|---|---|---|---|
| Grill family | `c-bpm-sk-grill-me`, `c-bpm-sk-grill-me-issue`, `c-bpm-sk-grill-claude-issue` | target × asker × output medium | `grill-me` questions a human about an unwritten idea; `grill-me-issue` edits an Issue body; `grill-claude-issue` reverses roles so the Judge asks and Claude answers. One skill cannot hold three different asker/target pairs without ambiguous routing. |
| Skill lifecycle pair | `c-bpm-sk-skill-creator`, `c-bpm-sk-skill-optimizer` | lifecycle stage (create → optimize) | The creator's decision flow **hands off** to the optimizer when a skill already exists. Merging removes the existence check that prevents duplicate skills. |
| Linux trio | `c-bpm-sk-linux-audit`, `c-bpm-sk-linux-admin`, `c-bpm-sk-linux-archive` | lifecycle stage (find → fix → preserve) | Audit files findings, admin mutates the host, archive snapshots config. Merging would put host mutation behind an audit trigger. |

**Rule:** an audit that proposes merging any pair above must first refute the split
axis in that row, in writing, in the Issue. "Looks redundant" is not a refutation.

## 4. F3 Must-Stay Rule — verification protocol (#56)

The normative Must-Stay / May-Move lists are in `c-bpm-sk-library-manager/SKILL.md`,
`c-bpm-sk-skill-creator/SKILL.md`, and `c-bpm-sk-skill-optimizer/SKILL.md`.

After any refactor that moves content out of a SKILL.md, verify all three:

1. The body still answers **"when do I invoke this?"** without reading any reference.
2. The body still answers **"what must I never do here?"** without reading any reference.
3. Removing the whole `references/` directory and re-running the skill on a smoke
   prompt still produces a **safe** — possibly lower-quality — output.

If any check fails, the moved content was Must-Stay content. Move it back.
