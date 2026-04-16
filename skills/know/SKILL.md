---
name: know
description: Project knowledge compiler for AI agents — persist tacit knowledge and write structured documents.
---

# Know

5 pipelines: **learn** (persist knowledge), **write** (generate documents), **extract** (mine code), **review** (audit entries), **refine** (optimize skill text). Each loads its workflow file on demand.

2 always-on systems: **recall** (remind before code changes), **decay** (expire stale entries).

## Principles

**High-risk = conservative**: overwrite/delete knowledge, assign critical, recall block, rewrite documents, write unconfirmed as fact → require evidence + user confirmation.

**Low-risk = flexible**: candidate discovery, summary writing, scope inference, document drafts, recall ranking → use full model capability.

Semantic understanding recommends; explicit signals + user intent decide. Rules conflict with practicality → simpler flow wins.

---

## Input Normalization

### Direct entry

| Input | Pipeline | Workflow |
|-------|----------|----------|
| `/know learn` | Learn — scan conversation | `workflows/learn.md` |
| `/know learn "text"` | Learn — treat quoted text as claim | `workflows/learn.md` |
| `/know write` | Write — infer params from conversation | `workflows/write.md` |
| `/know write <hint>` | Write — hint assists inference | `workflows/write.md` |
| `/know extract` | Extract — mine code | `workflows/extract.md` |
| `/know review` | Review — audit all entries | `workflows/review.md` |
| `/know review <scope>` | Review — audit matching scope | `workflows/review.md` |
| `/know refine` | Refine — optimize skill text | `workflows/refine.md` |

### Auto-dispatch

`/know` or `/know {text}` → keyword match first, conversation scan fallback.

| Pipeline | Keywords |
|----------|----------|
| learn | 沉淀, 经验, 总结, 记住, save, persist, remember, 教训, lesson |
| write | prd, tech, roadmap, arch, capabilities, ui, 文档, doc, 写文档, ops, marketing, schema, decision |
| extract | 提取, extract, 扫描, scan, 挖掘, mine |
| review | review, 审查, 清理, 检查, audit, cleanup |
| refine | refine, polish, 优化, 润色, 上线版, prompt |

Case-insensitive substring match. First match wins.

**0 or ≥2 matches** → scan conversation → present findings → user chooses:
```
[route] Detected: {findings}
A) learn  B) write  C) extract  D) review  E) multi-select
```
Multi-select execution order: learn → extract → write → review.

---

## Recall

Goal: remind, not block. Help system, not enforcement.

### Trigger

Before code-changing operations (Edit, Write, Bash that modifies files).

**Skip when**: no index file, same scope already queried this session, read-only exploration.

### Pipeline

```
Scope Inference → Query → Rank → Select (max 3) → Act
```

**Scope inference** (from current file operation):

| Priority | Method |
|----------|--------|
| P1 | Current file path → module notation |
| P2 | Last 10 tool call paths, ≥2 occurrences wins |
| P3 | `"project"` fallback |

**Query**:
```bash
# [RUN]
bash "$KNOW_CTL" query "{scope}"
```

**Rank**: scope relevance → `active:defensive` > `active:directive` > `passive` → tier 1 before tier 2.

**Select**: max 3 entries. 0 relevant → show nothing, no output.

**Act**:

| Action | Condition | Threshold |
|--------|-----------|-----------|
| suggest | Default | Helpful, not high-risk |
| warn | Medium risk | Error if ignored |
| block | Critical violated, high confidence | Block benefit > interruption cost |

Uncertain → downgrade: block → warn → suggest.

**Output format**:
```
[recall] {summary}
Why: {one-line relevance to current operation}
Action: suggest | warn | block
```

**Record hit**: `bash "$KNOW_CTL" hit "{keyword}"`

---

## Decay

Runs once at learn pipeline entry. Skip if no index file.

```bash
# [RUN]
bash "$KNOW_CTL" decay
```

| Condition | Action |
|-----------|--------|
| tier=2 (memo) + hits=0 + age > 30d | Delete |
| tier=1 (critical) + hits=0 + age > 180d | Demote to memo |
| tier=1 (critical) + revs > 3 | Demote to memo (unstable) |

Output: `[decay] {N} deleted, {M} demoted` if any action taken. Silent if none.

---

## Storage

Directory name is always `.know/`. Never use `knowledge/`, `know/`, or any other variant.

```
.know/
├── index.jsonl              # One entry per line (JSONL)
├── entries/{tag}/{slug}.md  # Detail files (tier 1 only)
├── events.jsonl             # Append-only event log
├── metrics.json             # Aggregated counters
└── docs/                    # Structured documents
    ├── {type}.md            # Project single: roadmap, capabilities, ops, marketing
    ├── {type}/{topic}.md    # Project directory: arch, ui, schema, decision
    └── requirements/{req}/  # Requirement: prd.md, tech.md
```

### Entry Schema (12 fields)

```json
{"tag":"...","tier":1,"scope":"...","tm":"...","summary":"≤80ch","path":"entries/{tag}/{slug}.md|null","hits":0,"revs":0,"last_hit":null,"source":"learn|extract","created":"YYYY-MM-DD","updated":"YYYY-MM-DD"}
```

| Field | Values |
|-------|--------|
| tag | `rationale` (选型), `constraint` (约束), `pitfall` (踩坑), `concept` (概念), `reference` (外部集成) |
| tier | `1` = critical (缺失导致错误), `2` = memo (缺失浪费时间) |
| tm | `active:defensive` (warn/block), `active:directive` (suggest), `passive` (不主动) |
| summary | `{结论} — {原因}`, ≤80 chars, must contain searchable anchor words |

### Document Types (10 types)

| Type | Level | Path Pattern |
|------|-------|-------------|
| roadmap | 项目单文件 | `docs/roadmap.md` |
| capabilities | 项目单文件 | `docs/capabilities.md` |
| ops | 项目单文件 | `docs/ops.md` |
| marketing | 项目单文件 | `docs/marketing.md` |
| arch | 项目目录 | `docs/arch/{topic}.md` |
| ui | 项目目录 | `docs/ui/{topic}.md` |
| schema | 项目目录 | `docs/schema/{topic}.md` |
| decision | 项目目录 | `docs/decision/{topic}.md` |
| prd | 需求 | `docs/requirements/{req}/prd.md` |
| tech | 需求 | `docs/requirements/{req}/tech.md` |

Document hierarchy: `roadmap → prd → tech`. All other types are independent.

---

## Infrastructure

### Path Resolution

From `"Base directory for this skill: {path}"`, strip `skills/know/` to get project root.

```
KNOW_CTL     = {project_root}/scripts/know-ctl.sh
KNOW_DIR     = .know
INDEX_FILE   = .know/index.jsonl
ENTRIES_DIR  = .know/entries
DOCS_DIR     = .know/docs/
TEMPLATES_DIR = {project_root}/workflows/templates/
```

### Execution Control

| Marker | Behavior |
|--------|----------|
| `# [RUN]` | Execute with Bash tool |
| `[STOP:confirm]` | Pause until user confirms (ok/yes/continue/确认/好/可以) |
| `[STOP:choose]` | Pause until user picks option |

Flow markers never appear in user-facing output.

### Output Constraints

**Markers** — prefix every pipeline output:

| Marker | When |
|--------|------|
| `[route]` | Auto-dispatch result |
| `[learn]` | Learn pipeline status |
| `[persisted]` | Entry written to index |
| `[conflict]` | Duplicate/conflict/merge found |
| `[skipped]` | Claim filtered out |
| `[extract]` | Extract pipeline status |
| `[write]` | Write pipeline status |
| `[written]` | Document written to disk |
| `[progress]` | Parent document updated |
| `[recall]` | Knowledge recalled before edit |
| `[review]` | Review pipeline status |
| `[decay]` | Entries deleted or demoted |
| `[refine]` | Skill text optimized |
| `[error]` | Unrecoverable error |

**Style rules**:
- Include step name in pipelines: `[learn] step: detect`
- Match user's language for content
- No filler words, no hedging, no empty statements
- Numbers must be concrete: "3 files" not "several"
- Empty result is valid output: "No issues found" / "No entries"

---

## Defaults

| Situation | Behavior |
|-----------|----------|
| No `.know/` directory | Create on first write operation |
| No `index.jsonl` | Create on first append. Skip recall/review/decay silently |
| `/know write` with <3 messages | Warn insufficient context, ask user to specify content |
| `/know learn` with 0 signals | `[learn] No high-value knowledge detected.` |
| `/know review` with empty index | `[review] No entries to review.` |
| `/know extract` with 0 files | `[extract] No files detected. Provide path or glob.` |
| `/know` route finds nothing | `[route] No actionable findings.` Offer: review / extract |
| `know-ctl.sh` command fails | Show error verbatim. Ask: retry or skip |
| Workflow file missing | `[error] Workflow not found: {path}` |
