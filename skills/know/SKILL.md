---
name: know
description: Project knowledge compiler for AI agents — persist tacit knowledge and write structured documents.
---

# Know

`/know learn` persists knowledge. `/know write` generates structured documents. `/know review` audits existing entries.

## Overview

| Pipeline | Purpose | Output |
|----------|---------|--------|
| **Learn** | Persist tacit knowledge that code/git cannot express | `.knowledge/` entries |
| **Write** | Turn discussion results into versioned documents | `.know/docs/` documents |
| **Review** | Audit and maintain knowledge entries | Delete / Update / Keep |

## Core Principles

1. **Human gate** — all persistence requires user confirmation. No silent writes.
2. **Code-irreducible only** — if grep/git log answers it in 2 min, reject it.
3. **Token economy** — critical = detail file (≤220 tokens); memo = summary only.
4. **Single definition** — defined once in SKILL.md, referenced via `→ SKILL.md {section}`.
5. **Term anchoring** — one canonical name per concept (→ Definitions). Lifecycle: signal → claim → entry. No aliases.
6. **Explicit pause** — every user-input point marked `[STOP:confirm]` or `[STOP:choose]`. Unmarked pauses are bugs.
7. **Language mirroring** — output matches user's language. Internal docs stay English.

## Definitions

| Term | Meaning |
|------|---------|
| signal | Conversation pattern matching ≥1 keyword in signal table → triggers learn |
| claim | Knowledge unit extracted from conversation (Steps 2–4, pre-validation) |
| entry | Validated knowledge record written to `index.jsonl` (Step 5+) |
| tag | `rationale` \| `constraint` \| `pitfall` \| `concept` \| `reference` |
| tier | `critical` (tier 1, detail file) \| `memo` (tier 2, summary only) |
| scope | Dot-separated module keypath, prefix-matchable (e.g. `Auth.middleware`) |
| tm | Trigger mode: `passive` \| `active:defensive` \| `active:directive` |
| slug | File name identifier: `[a-z0-9-]`, max 50 chars, kebab-case |

## Input Normalization

| User Input | Normalized To |
|------------|---------------|
| `/know` | Show help: available commands (learn, write, review) |
| `/know learn` | Learn pipeline — scan full conversation |
| `/know learn "quoted text"` | Learn pipeline — treat quoted text as explicit claim |
| `/know write` | Write pipeline — infer all params from conversation |
| `/know write <hint>` | Write pipeline — hint assists type/name inference |
| `/know write prd` or `/know write 需求` | Write pipeline — hint = "prd" |
| "记住这个" / "save this" / "这个要记下来" | Treat as `/know learn` |
| "写个文档" / "write a doc" / "整理一下" | Treat as `/know write` |
| `/know review` | Review pipeline — audit all entries |
| `/know review <scope>` | Review pipeline — audit entries matching scope |
| "清理知识" / "review knowledge" / "检查经验" | Treat as `/know review` |
| `/know` + unrecognized argument | Show help with closest match suggestion |

## Default Behaviors

| Condition | Action |
|-----------|--------|
| No signals detected in conversation | Report: "No persistable knowledge detected in this conversation." |
| Conversation has <3 substantive messages | Warn insufficient context. Ask user to point to specific content. |
| Tag matches ≥2 tags equally | Show all 5 tags, ask user to choose |
| Scope unresolvable | Default to `"project"` |
| tm pattern matches none | Default to `passive` |
| Conflict detection returns 0 candidates | Skip Phase 2, proceed to confirm |
| `know-ctl.sh` missing or fails | Abort: `[error] know-ctl.sh not found or failed. Run setup first.` |
| Template file missing | Fallback: `# {Title}` / `## Overview` / `## Details` / `## Open Questions` |
| CLAUDE.md missing | Create with `## Know` → `### 文档索引` structure |
| Write type matches ≥2 equally | List matched types, ask user to choose |
| Write name unextractable | Ask user to provide name explicitly |

## Rules

### Execution Control

- `# [RUN]` → execute with Bash tool. Never describe the command instead of running it.
- `[STOP:confirm]` → pause until user confirms. `[STOP:choose]` → pause until user picks option.
- Confirm blocks must show content being confirmed. Choice blocks must list explicit options (A/B/C).
- Flow markers (`[STOP:*]`, step numbers) never appear in user output. Tag/tier/scope in `[learn]` confirmation blocks are user-reviewable content.
- Skip intent (继续/ok/go/好/可以 or equivalent) → accept current output, proceed. Discussion intent (question, objection, edit request) → stay at current step.

### Output Constraints

- Every user-facing output starts with exactly one `[marker]` from the marker table.
- Confirmation prompts end with exactly one of: `Confirm?` / `Correct?` / `Write?` / explicit option list.
- `[skipped]` blocks: max 2 lines (summary + reason).
- `[conflict]` blocks: max 6 lines (existing + new + 4 options).
- All field values in output use canonical names from Definitions.

### Output Markers

| Marker | Pipeline | When |
|--------|----------|------|
| `[suggest-learn]` | learn | Implicit signal batch proposal |
| `[learn]` | learn | Entry pending confirmation |
| `[persisted]` | learn | Write complete |
| `[conflict]` | learn | Duplicate/contradictory entry found |
| `[skipped]` | learn | Route interception DROP |
| `[write]` | write | Status / parameter confirmation / preview |
| `[written]` | write | Document write complete |
| `[index]` | write | CLAUDE.md index updated |
| `[cascade]` | write | Downstream docs marked for update after parent write |
| `[recall]` | recall | Knowledge entry applied to current operation |
| `[review]` | review | Entry audit status / action result |
| `[error]` | both | Unrecoverable error |

**Conflict block**:
```
[conflict] Similar entry found:
Existing: {summary}
New: {summary}
Choose: A) Update existing  B) Keep both  C) Merge  D) Skip new
```

**Skipped block**:
```
[skipped] {summary}
Reason: {drop reason}
```

### Path Constants

```
KNOWLEDGE_DIR  = .knowledge
INDEX_FILE     = .knowledge/index.jsonl
ENTRIES_DIR    = .knowledge/entries
DOCS_DIR       = .know/docs/
TEMPLATES_DIR  = workflows/templates/
KNOW_CTL       = scripts/know-ctl.sh
```

## Storage

### Architecture

```
.knowledge/
├── index.jsonl              # One entry per line, filter via jq
└── entries/                 # Detail files (critical only)
    ├── rationale/
    ├── constraint/
    ├── pitfall/
    ├── concept/
    └── reference/
```

### JSONL Schema (10 fields)

```json
{
  "tag": "rationale|constraint|pitfall|concept|reference",
  "tier": 1,
  "scope": "Module.Class.method",
  "tm": "passive|active:defensive|active:directive",
  "summary": "≤80 chars with retrieval anchors",
  "path": "entries/{tag}/{slug}.md|null",
  "hits": 0,
  "revs": 0,
  "created": "YYYY-MM-DD",
  "updated": "YYYY-MM-DD"
}
```

| Field | Filterable | Lifecycle |
|-------|:----------:|:---------:|
| tag, tier, scope, tm, summary | ✓ | |
| hits, revs, created, updated | | ✓ |

- Scope: string for single module, JSON array for cross-module (`["A","B"]`).
- Path: relative to `KNOWLEDGE_DIR`.

### Tier Rules

| Tier | Name | Detail File | Budget |
|------|------|:-----------:|--------|
| 1 | critical | required | ≤220 tokens |
| 2 | memo | none | summary only |

- **critical**: confirmed knowledge (test/reproduction/multi-source); missing it causes errors.
- **memo**: worth noting; missing it wastes time but won't cause errors.

### Summary Rules

- ≤80 characters; compress to fit, never truncate mid-word
- Must contain retrieval anchors (module names, API names, error patterns)
- Structure: `{conclusion} — {key reason}`

### Decay

```
memo     + hits=0 + age > 30d  → delete
critical + hits=0 + age > 180d → demote to memo
critical + revs > 3            → demote to memo (unstable)
```

### Decay Trigger

Run decay at `/know learn` Step 1 entry, before signal detection:

```bash
# [RUN]
bash "$KNOW_CTL" decay
```

- Output `[decay] {N} deleted, {M} demoted` if any action taken
- Silent if no entries affected
- Skip if `.knowledge/index.jsonl` does not exist

## Recall

Agent applies persisted knowledge to prevent repeated errors.

### When to Load

Before operating on code (Read, Edit, Write, Bash with code changes), query for matching entries:

```bash
# [RUN]
bash "$KNOW_CTL" query "{scope}"
```

**Scope inference** — derive from current operation, first match wins:

| Priority | Source | Method |
|----------|--------|--------|
| P1 | File being operated on | `src/{module}/` → `{module}`, nested → dot notation |
| P2 | Recent tool calls | Last 10 Read/Edit paths; module with ≥2 occurrences wins |
| P3 | Fallback | `"project"` |

**Skip conditions** — do not query when:
- No `.knowledge/index.jsonl` exists
- Same scope was already queried in this conversation
- Operation is read-only exploration (no code change intent)

### How to Apply

| tm | Behavior |
|----|----------|
| `active:defensive` | Check before acting. If current operation would violate the entry → block, show `[recall]`, suggest correct approach |
| `active:directive` | Check before acting. If entry is applicable to current operation → suggest, show `[recall]` |
| `passive` | Do not proactively check. Only show `[recall]` if about to make the same error described in the entry |

### On Hit

When an entry influences agent behavior:

1. Show: `[recall] {summary}`
2. Record:
```bash
# [RUN]
bash "$KNOW_CTL" hit "{summary keyword}"
```

### Rules

- Never show `[recall]` for entries that did not influence the current operation
- Max 3 `[recall]` per operation — if more match, show highest tier first, then `active:defensive` before others
- Do not re-show the same entry within a conversation unless context changed
- `[recall]` is informational — user does not need to confirm or respond

## Execution Pipelines

### Intent Routing

| Input | Dispatch |
|-------|----------|
| `/know learn` | → `workflows/learn.md` |
| AI detects signal | → `workflows/learn.md` (requires user consent) |
| `/know write` | → `workflows/write.md` |
| `/know write <hint>` | → `workflows/write.md` (hint assists inference) |
| `/know review` | → `workflows/review.md` |
| `/know review <scope>` | → `workflows/review.md` (scope filter) |

### Learn

```
1.Detect → 2.Extract → 3.Filter → 4.Assess → 5.Generate → 6.Conflict → 7.Confirm → 8.Write
                         ↓DROP      ↓DROP                    ↓conflict   ↓cancel
                         [skipped]  exit                     user decides exit
```

Full spec: `workflows/learn.md`

### Write

```
1.Trigger → 2.Infer → 3.Confirm → 4.Template → 5.Fill → 6.Preview → 7.Write → 8.Index
                       ↓edit       ↓missing      ↓<30%    ↓edit        ↓cascade
                       re-infer    fallback       warn     re-fill      [cascade] mark downstream

Step 2c: file exists → update mode (sections-only edit + changelog)
Step 8:  parent doc written → cascade mark direct children ⚠
         update mode → clear ⚠ from own index entry
```

Full spec: `workflows/write.md`

## Examples

### Learn — signal batch

```
[suggest-learn] Detected 2 high-value claims:
1. [constraint] Thresholds defined only in PressureLevel, no hardcoded numbers
2. [pitfall] DataEngine singleton leaks state across test targets
Persist? [all / select / skip]
```

### Learn — entry confirmation

```
[learn] Entry pending confirmation:

Tag: constraint | Tier: 1 | Scope: LoppyMetrics
Summary: Thresholds defined only in PressureLevel, no hardcoded numbers

--- entries/constraint/pressure-thresholds.md ---
# Thresholds defined only in PressureLevel
All pressure thresholds (35/55/75) are defined in the PressureLevel enum.
## Why
Scattered magic numbers caused inconsistent scoring in v1.
## How to check
grep for hardcoded 35/55/75 outside PressureLevel.

Confirm?
```

### Write — parameter confirmation

```
[write] Inferred from conversation:
Type: prd | Requirement: know-write | Parent: roadmap (v1/roadmap.md)
Correct?
```

### Write — index entry

```
- [know-write](.know/docs/requirements/know-write/prd.md) | 2026-04-10 ← roadmap
  - [tech](.know/docs/requirements/know-write/impl/tech.md) | 2026-04-10 ← prd
```
