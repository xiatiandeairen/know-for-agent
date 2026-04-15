---
name: know
description: Project knowledge compiler for AI agents — persist tacit knowledge and write structured documents.
---

# Know

`/know` routes to the right pipeline. `/know learn` persists knowledge. `/know write` generates documents. `/know extract` mines code. `/know review` audits entries.

## Overview

| Pipeline | Purpose | Output |
|----------|---------|--------|
| **Route** | Analyze conversation, dispatch to the right pipeline | → learn / write / extract / review |
| **Learn** | Persist tacit knowledge that code/git cannot express | `.know/` entries |
| **Write** | Turn discussion results into versioned documents | `.know/docs/` documents |
| **Extract** | Mine knowledge from project code/files | `.know/` entries |
| **Review** | Audit and maintain knowledge entries | Delete / Update / Keep |

## Definitions

| Term | Meaning |
|------|---------|
| signal | Conversation pattern matching ≥1 keyword → triggers learn |
| claim | Knowledge unit extracted from conversation (pre-validation) |
| entry | Validated record written to `index.jsonl` |
| tag | `rationale` \| `constraint` \| `pitfall` \| `concept` \| `reference` |
| tier | `critical` (tier 1, detail file) \| `memo` (tier 2, summary only) |
| scope | Dot-separated module keypath, prefix-matchable (e.g. `Auth.middleware`) |
| tm | Trigger mode: `passive` \| `active:defensive` \| `active:directive` |
| slug | `[a-z0-9-]`, max 50 chars, kebab-case |

## Input Normalization

### Direct entry (explicit sub-command)

| User Input | Action |
|------------|--------|
| `/know learn` | Learn pipeline — scan full conversation |
| `/know learn "quoted text"` | Learn pipeline — treat quoted text as explicit claim |
| `/know write` | Write pipeline — infer all params from conversation |
| `/know write <hint>` | Write pipeline — hint assists type/name inference |
| `/know extract` | Extract pipeline — mine code for knowledge |
| `/know review` | Review pipeline — audit all entries |
| `/know review <scope>` | Review pipeline — audit entries matching scope |

### Route entry (auto-dispatch)

| User Input | Action |
|------------|--------|
| `/know` | Route pipeline — scan conversation, present findings, user chooses |
| `/know {text}` | Route with fast path — keyword match first, fallback to scan |

### Fast path keywords

Fast path matches keywords in `{text}` and dispatches immediately without user confirmation.

| Pipeline | Keywords |
|----------|----------|
| learn | 沉淀, 经验, 总结, 记住, save, persist, remember, 教训, lesson |
| write | prd, tech, roadmap, arch, 文档, doc, 写文档, ops, schema, decision |
| extract | 提取, extract, 扫描, scan, 挖掘, mine |
| review | review, 审查, 清理, 检查, audit, cleanup |

**Match rule**: case-insensitive substring match against `{text}`. First match wins. No match → full route (scan + present).

**Conflict**: `{text}` matches keywords from ≥2 pipelines → full route (scan + present).

## Default Behaviors

| Situation | Default |
|-----------|---------|
| No `.know/` directory | Create on first write. No error. |
| No `index.jsonl` | Create on first append. Skip recall/review silently. |
| Conversation has <3 substantive messages when `/know write` | Warn insufficient context, ask user to point to specific content |
| `/know learn` finds 0 signals | Output `[learn] No high-value knowledge detected in this conversation.` |
| `/know review` with empty index | Output `[review] No entries to review.` |
| `/know` route scan finds nothing | Output `[know] No actionable findings in this conversation.` Offer: `A) review B) extract` |
| User gives skip intent (继续/ok/go/好/可以) | Accept current output, proceed to next step |
| User gives discussion intent (question/objection/edit) | Stay at current step, address feedback |
| Scope inference fails | Fallback to `"project"` |
| `know-ctl.sh` command fails | Show error verbatim (command + output), ask user to retry or skip |

## Rules

### Execution Control

- `# [RUN]` → execute with Bash tool. Never describe the command instead of running it.
- `[STOP:confirm]` → pause until user confirms. `[STOP:choose]` → pause until user picks option.
- Confirm blocks show content being confirmed. Choice blocks list explicit options (A/B/C).
- Flow markers (`[STOP:*]`, step numbers) never appear in user output.

### Output Constraints

- Every user-facing output starts with exactly one marker from the Output Markers table. After every `# [RUN]` execution, the next line of user-visible output must begin with a marker.
- Confirmation prompts end with exactly one of: `Confirm?` / `Correct?` / `Write?` / explicit option list.
- `[skipped]` blocks: max 2 lines (summary + reason).
- `[conflict]` blocks: max 6 lines (existing + new + 4 options).
- All field values use canonical names from Definitions.
- Match user's language. Internal docs stay English.

### Gate Notation

Every Step declares a gate using one of:

| Notation | Meaning |
|----------|---------|
| `Gate (always)` | Step always runs, cannot be skipped |
| `Gate (auto): {condition}` | AI evaluates condition, enters if true. Show condition + result to user |
| `Gate (user): {question}` | User decides. Show question with hint + default |

### Output Markers

| Marker | Pipeline | When |
|--------|----------|------|
| `[know]` | route | Conversation analysis / dispatch |
| `[learn]` | learn | Entry pending confirmation / summary |
| `[persisted]` | learn | Write complete |
| `[conflict]` | learn | Duplicate/contradictory entry found |
| `[skipped]` | learn, extract | Filter DROP |
| `[extract]` | extract | Code knowledge extraction status |
| `[write]` | write | Status / parameter confirmation / preview |
| `[written]` | write | Document write complete |
| `[index]` | write | CLAUDE.md index updated |
| `[cascade]` | write | Downstream docs marked for update |
| `[progress]` | write | Parent doc progress updated |
| `[recall]` | recall | Knowledge entry applied to current operation |
| `[review]` | review | Entry audit status / action result |
| `[error]` | all | Unrecoverable error |

### Path Constants

```
KNOW_DIR       = .know
INDEX_FILE     = .know/index.jsonl
ENTRIES_DIR    = .know/entries
DOCS_DIR       = .know/docs/
TEMPLATES_DIR  = workflows/templates/
```

### Script Paths

From "Base directory for this skill: {path}", strip `skills/know/` to get project root.

```
KNOW_CTL="{project_root}/scripts/know-ctl.sh"
```

All `# [RUN]` blocks use `bash "$KNOW_CTL"` with this resolved path. Template reads use `{project_root}/workflows/templates/{type}.md`.

## Storage

### Layout

```
.know/
├── index.jsonl              # One entry per line, filter via jq
├── entries/                 # Detail files (critical only)
│   ├── rationale/
│   ├── constraint/
│   ├── pitfall/
│   ├── concept/
│   └── reference/
└── docs/                    # Structured documents
    ├── v{n}/                # Project-level versioned
    └── requirements/        # Requirement/feature level
```

### JSONL Schema (11 fields)

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
  "last_hit": "YYYY-MM-DD|null",
  "created": "YYYY-MM-DD",
  "updated": "YYYY-MM-DD"
}
```

| Field | Filterable | Lifecycle |
|-------|:----------:|:---------:|
| tag, tier, scope, tm, summary | ✓ | |
| hits, revs, last_hit, created, updated | | ✓ |

- Scope: string for single module, JSON array for cross-module (`["A","B"]`).
- Path: relative to `KNOW_DIR`.

### Tier Rules

| Tier | Name | Detail File | Budget |
|------|------|:-----------:|--------|
| 1 | critical | required | ≤220 tokens |
| 2 | memo | none | summary only |

- **critical**: confirmed knowledge (test/reproduction/multi-source); missing it causes errors.
- **memo**: worth noting; missing it wastes time but won't cause errors.

### Summary Rules

- ≤80 characters; compress to fit, never truncate mid-word.
- Must contain retrieval anchors (module names, API names, error patterns).
- Structure: `{conclusion} — {key reason}`.

## Recall

Before operating on code (Read, Edit, Write, Bash with code changes), query for matching entries.

### Execution

```bash
# [RUN]
bash "$KNOW_CTL" query "{scope}"
```

**Scope inference** — derive from **current file operation** (not conversation context). First match wins:

| Priority | Source | Method |
|----------|--------|--------|
| P1 | File being operated on | `src/{module}/` → `{module}`, nested → dot notation |
| P2 | Recent tool calls | Last 10 Read/Edit paths; module with ≥2 occurrences wins |
| P3 | Fallback | `"project"` |

**Skip when**:
- No `.know/index.jsonl`
- Same scope already queried in this conversation
- Operation is read-only exploration (no code change intent)

### Application

| tm | Behavior |
|----|----------|
| `active:defensive` | Check before acting. If operation would violate → block, show `[recall]`, suggest correct approach |
| `active:directive` | Check before acting. If entry applies → suggest, show `[recall]` |
| `passive` | No proactive check. Show `[recall]` only if about to repeat the described error |

### On Hit

1. Show: `[recall] {summary}`
2. Record: `bash "$KNOW_CTL" hit "{summary keyword}"`

### Recall Limits

- Max 3 `[recall]` per operation — highest tier first, then `active:defensive` before others.
- Never show `[recall]` for entries that did not influence the current operation.
- Do not re-show the same entry within a conversation unless context changed.
- `[recall]` is informational — no user confirmation needed.

## Execution Pipeline

```
User input
  │
  ▼
[Input Normalization] → match against tables
  │
  ├─ /know learn ───→ Read workflows/learn.md → execute 8-step pipeline
  ├─ /know write ───→ Read workflows/write.md → execute 8-step pipeline
  ├─ /know extract ─→ Read workflows/extract.md → execute 6-step pipeline
  ├─ /know review ──→ Read workflows/review.md → execute 3-step pipeline
  └─ /know [text] ──→ Route (fast path → keyword match → dispatch)
                       (no match → scan conversation → present → user chooses)
```

### Route

```
/know [text]
  │
  ├─ [Fast Path] keyword match → dispatch immediately
  │
  └─ [Full Route] scan conversation → present findings → [STOP:choose]
       │
       ▼
     [know] 对话分析：
     - {N} 条可持久化知识 (learn)
     - {N} 个文档可整理 (write)
     - {N} 个文件可提取 (extract)
     
     A) learn  B) write  C) extract  D) review  E) 多选
       │
       ▼
     [Dispatch] → load corresponding workflow
     Multi-select → execute in order: learn → extract → write → review
```

### Learn Pipeline

```
1.Detect → 2.Extract → 3.Filter → 4.Assess → 5.Generate → 6.Conflict → 7.Confirm → 8.Write
                        ↓DROP      ↓DROP                    ↓conflict   ↓cancel
                        [skipped]  exit                     user decides exit
```

Full spec: `workflows/learn.md` (load on trigger)

### Write Pipeline

```
1.Trigger → 2.Infer → 3.Confirm → 4.Template → 5.Fill → 6.Preview → 7.Write → 8.Index
                       ↓edit       ↓missing      ↓<30%    ↓edit        ↓cascade+progress
                       re-infer    fallback       warn     re-fill      update parent docs
```

Full spec: `workflows/write.md` (load on trigger)

### Extract Pipeline

```
1.Scope → 2.Scan → 3.Extract → 4.Filter → 5.Confirm → 6.Write
                                 ↓DROP      ↓cancel
                                 [skipped]  exit
```

Full spec: `workflows/extract.md` (load on trigger)

### Review Pipeline

```
1.Load → 2.Display → 3.Process
          ↓empty      ↓per entry
          exit        A) Delete  B) Update  C) Keep
```

Full spec: `workflows/review.md` (load on trigger)
