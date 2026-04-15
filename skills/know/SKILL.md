---
name: know
description: Project knowledge compiler for AI agents — persist tacit knowledge and write structured documents.
---

# Know

`/know` routes to the right pipeline. `/know learn` persists knowledge. `/know write` generates documents. `/know extract` mines code. `/know review` audits entries.

## Core Principles

> **High-risk actions: conservative. Low-risk actions: flexible.**

High-risk (require evidence + user confirmation): overwrite/delete knowledge, assign critical, recall block, rewrite documents, write unconfirmed as fact.

Low-risk (use full model capability): candidate discovery, claim splitting, summary writing, scope inference, similarity retrieval, document drafts, recall ranking.

Semantic understanding can find candidates and recommend, but cannot alone decide: duplicate/conflict/merge classification, critical assignment, recall block, entry deletion. These require explicit signals + context + user intent.

When rules conflict with practicality → simpler flow, more helpful output, more natural interaction.

---

## Input Normalization

### Direct entry

| User Input | Action |
|------------|--------|
| `/know learn` | Learn — scan conversation → `workflows/learn.md` |
| `/know learn "text"` | Learn — treat quoted text as explicit claim |
| `/know write` | Write — infer params → `workflows/write.md` |
| `/know write <hint>` | Write — hint assists inference |
| `/know extract` | Extract — mine code → `workflows/extract.md` |
| `/know review` | Review — audit entries → `workflows/review.md` |
| `/know review <scope>` | Review — audit matching scope |

### Route (auto-dispatch)

`/know` or `/know {text}` → fast path keyword match first, fallback to conversation scan.

| Pipeline | Keywords |
|----------|----------|
| learn | 沉淀, 经验, 总结, 记住, save, persist, remember, 教训, lesson |
| write | prd, tech, roadmap, arch, 文档, doc, 写文档, ops, schema, decision |
| extract | 提取, extract, 扫描, scan, 挖掘, mine |
| review | review, 审查, 清理, 检查, audit, cleanup |
| refine | refine, polish, 优化, 润色, 上线版, prompt |

Case-insensitive substring match. First match wins. ≥2 matches or no match → full route: scan conversation → present findings → user chooses A) learn B) write C) extract D) review E) multi-select. Multi-select order: learn → extract → write → review.

---

## Recall

Recall is a help system, not an enforcement system. Goal: remind, not block.

**Trigger**: before code-changing operations (Edit, Write, Bash). Skip if no index, same scope already queried, or read-only exploration.

**Scope inference** (from current file operation, not conversation):

| Priority | Method |
|----------|--------|
| P1 | File path → module notation |
| P2 | Last 10 tool call paths, ≥2 occurrences wins |
| P3 | `"project"` |

```bash
# [RUN]
bash "$KNOW_CTL" query "{scope}"
```

**Rank**: scope relevance → `active:defensive` > `active:directive` > `passive` → highest tier first.

**Select**: max 3. Nothing relevant → show nothing.

**Act**:

| Action | When |
|--------|------|
| suggest | Default. Helpful, not high-risk |
| warn | Medium risk. May cause error if ignored |
| block | High-confidence critical violated. Block benefit > interruption cost |

Block sparingly. Uncertain → downgrade to warn.

```
[recall] {summary}
Why: {relevance}
Action: suggest | warn | block
```

On hit: `bash "$KNOW_CTL" hit "{keyword}"`

---

## Decay

Runs at learn entry. Skip if no index. Gentle, not aggressive.

```bash
# [RUN]
bash "$KNOW_CTL" decay
```

| Condition | Action |
|-----------|--------|
| memo + hits=0 + age > 30d | Delete |
| critical + hits=0 + age > 180d | Demote to memo |
| critical + revs > 3 | Demote to memo (unstable) |

`[decay] {N} deleted, {M} demoted` if any. Silent if none.

---

## Storage

```
.know/
├── index.jsonl          # One entry per line
├── entries/{tag}/       # Detail files (critical only)
└── docs/                # Structured documents
    ├── v{n}/            # Project-level versioned
    └── requirements/    # Requirement/feature level
```

### Schema (12 fields)

```json
{"tag":"...","tier":1,"scope":"...","tm":"...","summary":"≤80ch","path":"entries/{tag}/{slug}.md|null","hits":0,"revs":0,"last_hit":null,"source":"learn|extract","created":"YYYY-MM-DD","updated":"YYYY-MM-DD"}
```

**Quick reference** (full definitions in `workflows/learn.md`):

| Field | Values |
|-------|--------|
| tag | rationale (选型), constraint (约束), pitfall (踩坑), concept (概念), reference (外部集成) |
| tier | 1=critical (缺失导致错误), 2=memo (缺失浪费时间) |
| tm | defensive (warn/block), directive (suggest), passive (不主动) |
| summary | `{结论} — {原因}`, ≤80 chars, 含检索锚点词 |

---

## Infrastructure

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

### Execution control

- `# [RUN]` → execute with Bash tool
- `[STOP:confirm]` → pause until user confirms
- `[STOP:choose]` → pause until user picks option
- Flow markers never appear in user output

### Output markers

| Marker | When |
|--------|------|
| `[route]` | Route dispatch |
| `[learn]` | Learn status |
| `[persisted]` | Write complete |
| `[conflict]` | Duplicate/conflict/merge found |
| `[skipped]` | Filter DROP |
| `[extract]` | Extract status |
| `[write]` | Write pipeline status |
| `[written]` | Document written |
| `[index]` | CLAUDE.md updated |
| `[cascade]` | Downstream marked |
| `[progress]` | Parent updated |
| `[recall]` | Knowledge recall |
| `[review]` | Review status |
| `[decay]` | Decay action |
| `[refine]` | Skill refinement |
| `[error]` | Unrecoverable error |

Style: include step name in pipelines (`[learn] step: detect`). Match user's language. Professional, high density, no filler.

---

## Defaults

| Situation | Default |
|-----------|---------|
| No `.know/` | Create on first write |
| No `index.jsonl` | Create on first append. Skip recall/review silently |
| `/know write` <3 messages | Warn insufficient context |
| `/know learn` 0 signals | `[learn] No high-value knowledge detected.` |
| `/know review` empty index | `[review] No entries to review.` |
| `/know` route finds nothing | `[route] No actionable findings.` Offer: review / extract |
| `know-ctl.sh` fails | Show error verbatim, ask retry or skip |
