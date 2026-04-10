---
name: know
description: Project knowledge compiler for AI agents — persist high-value tacit knowledge and write structured documents to reduce exploration errors.
---

# Know

`/know learn` → persist knowledge. `/know write` → write structured documents.

Two capabilities, one entry point:
- **Learn**: correct the AI's mental model by recording tacit knowledge
- **Write**: turn conversation discussion results into structured documents in `docs/`

---

## Rules

- Bash commands marked `# [RUN]` must be executed with Bash tool, not described verbally.
- Wait for user at `[STOP:confirm]` (proceed only when user expresses confirmation intent) and `[STOP:choose]` (user picks one option).
- Questions that ask user to choose must always list explicit options (A/B/C). Never ask a choice question without options.
- Questions that ask user to confirm must always show the content being confirmed. Never ask "confirm?" without showing what to confirm.
- All internal markers (`[STOP:confirm]`, `[STOP:choose]`, step numbers, tier/tag/tm labels) must NEVER appear in user-facing output. Use natural language prompts instead.
- Match user's language. Chinese input → Chinese response. English input → English response. Internal docs (SKILL.md, workflows) stay in English.
- Users can skip confirmation points by expressing skip intent (go, ok, continue, 继续, 好, 可以, etc.). AI judges by intent, no specific keywords required. Skip intent → accept current output, move to next step. Discussion intent (question, objection, modification) → continue discussing.

### Output Blocks

Output blocks are user-facing formatted displays. Use `> [marker]` prefix:

| Marker | Semantics | When |
|--------|-----------|------|
| `> [suggest-learn]` | High-value knowledge detected, propose persistence | learn implicit signal |
| `> [learn]` | Entry pending confirmation | learn Step 7 |
| `> [persisted]` | Write complete confirmation | learn Step 8 |
| `> [conflict]` | Similar entry exists, user decision needed | learn Step 6 conflict |
| `> [skipped]` | Route interception, not persisted | learn Step 3 DROP |
| `> [write]` | Document write pipeline status | write steps |
| `> [written]` | Document write complete | write Step 8 |
| `> [index]` | Index update confirmation | write Step 9 |

**Conflict block format**:

```
> [conflict] Similar entry found:
>
> Existing: {existing summary}
> New: {new summary}
>
> Choose:
> A) Update existing entry
> B) Keep both
> C) Merge into one
> D) Skip new entry
```

**Skipped block format**:

```
> [skipped] {claim summary}
> Reason: {drop reason — e.g. derivable from code / belongs in CLAUDE.md / no conclusion}
```

### Path Constants

```
KNOWLEDGE_DIR=".knowledge"
INDEX_FILE=".knowledge/index.jsonl"
ENTRIES_DIR=".knowledge/entries"
DOCS_DIR=".know/docs/"
TEMPLATES_DIR="workflows/templates/"
KNOW_CTL="scripts/know-ctl.sh"
```

---

## Intent Routing [BRANCH]

| Input | Intent | Dispatch |
|-------|--------|----------|
| `/know learn` | Persist knowledge from conversation | → `workflows/learn.md` |
| AI detects signal | Propose persistence | → `workflows/learn.md` (requires user consent) |
| `/know write` | Write discussion result as structured document | → `workflows/write.md` |
| `/know write <hint>` | Write document with type/name hint | → `workflows/write.md` (hint assists inference) |

<HARD-GATE>
All writes must display content and receive user confirmation before persisting.
</HARD-GATE>

---

## Storage Architecture

```
.knowledge/
├── index.jsonl              # JSONL index — one entry per line, filter via jq
└── entries/                 # Markdown detail files
    ├── rationale/           #   Why this, not that
    ├── constraint/          #   What must not be done
    ├── pitfall/             #   Known traps with root cause
    ├── concept/             #   Core logic, algorithms, flows
    └── reference/           #   External tool integration guides
```

### JSONL Schema (10 fields)

```json
{
  "tag":      "rationale|constraint|pitfall|concept|reference",
  "tier":     1|2,
  "scope":    "Module.Class.method",
  "tm":       "passive|active:defensive|active:directive",
  "summary":  "≤80 chars, must contain retrieval anchor terms",
  "path":     "entries/{tag}/{slug}.md|null",
  "hits":     0,
  "revs":     0,
  "created":  "YYYY-MM-DD",
  "updated":  "YYYY-MM-DD"
}
```

**Scope field**: string for single scope, JSON array for cross-module (e.g. `["LoppyMetrics", "LoppyScoring"]`). In JSONL, arrays are serialized inline: `"scope":["A","B"]`.

| Field | Filter | Lifecycle |
|-------|--------|-----------|
| tag | ✓ | |
| tier | ✓ | |
| scope | ✓ | |
| tm | ✓ | |
| summary | ✓ (text match) | |
| path | | |
| hits | | ✓ |
| revs | | ✓ |
| created | | ✓ |
| updated | | ✓ |

### Scope Keypath

Dot-separated path supporting prefix match:

```
project                          → matches everything
LoppyMetrics                     → matches LoppyMetrics.*
LoppyMetrics.DataEngine          → matches LoppyMetrics.DataEngine.*
LoppyMetrics.DataEngine.refresh  → exact match
```

### Tier Rules

| Tier | Name | Token Budget | Detail File |
|------|------|-------------|-------------|
| 1 | critical | ≤ 220 tokens | required |
| 2 | memo | — | none (summary only) |

**Tier assignment criteria** (learn workflow):
- critical (tier 1): confirmed knowledge (verified via test, reproduction, or multi-source agreement); missing it would cause errors
- memo (tier 2): worth noting; missing it wastes time but unlikely to cause errors

**Summary rules**:
- ≤ 80 characters; if exceeds, compress to fit — never truncate mid-word
- Must contain retrieval anchor terms (module names, API names, error patterns)
- Structure: conclusion + key reason

### Decay Policy

```
memo (tier 2) + hits=0 + created > 30d      → delete
critical (tier 1) + hits=0 + created > 180d → demote to memo
revs > 3 + critical (tier 1)                → demote to memo (unstable)
```

---

## Pipelines

### Learn (mental model correction)

Record tacit high-value knowledge that code and git cannot express. Full spec: `workflows/learn.md`

```
Signal detection → Claim extraction → Route interception → 2-question tier assessment
→ Entry generation → Conflict detection (keyword pre-filter + LLM similarity)
→ Display and confirm → Write index.jsonl + entries/
```

### Write (document authoring)

Turn conversation results into structured, versioned documents. Full spec: `workflows/write.md`

```
Trigger → Infer parameters → Confirm parameters → Load template
→ Extract and fill → Preview and confirm → Write file
→ Update CLAUDE.md index → Done
```
