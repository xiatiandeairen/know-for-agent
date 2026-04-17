---
name: know
description: Project knowledge compiler for AI agents — persist tacit knowledge and write structured documents.
---

# Know

4 pipelines: **learn** (persist knowledge), **write** (generate documents), **extract** (mine code), **review** (audit entries). Each loads its workflow file on demand.

2 always-on systems: **recall** (remind before code changes), **decay** (expire stale entries).

1 report: **report** (knowledge base health — 6 section diagnostic).

## Session Init

On first load per session, run silently and output 1 line:

```bash
# [RUN]
bash "$KNOW_CTL" stats 2>/dev/null | head -1
```

Output: `[know] {total} entries | last updated: {date}`

Where `{date}` comes from: `jq -sr 'sort_by(.updated) | last | .updated' "$KNOW_DIR/index.jsonl" 2>/dev/null`

No output if index file missing or empty (new project). Run once per session, do not repeat.

---

## Principles

**High-risk = conservative**: overwrite/delete knowledge, assign critical, recall block, rewrite documents, write unconfirmed as fact → require evidence + user confirmation.

**Low-risk = flexible**: candidate discovery, summary writing, scope inference, document drafts, recall ranking → use full model capability.

Semantic understanding recommends; explicit signals + user intent decide. Rules conflict with practicality → simpler flow wins.

---

## Definitions

| Term | Meaning |
|------|---------|
| entry | index.jsonl 中的一行记录，11 个字段（见 Entry Schema） |
| scope | dot-separated keypath（如 `Module.Class.method`），支持前缀匹配。概念域用 `methodology.*` 前缀 |
| pipeline | 子命令对应的执行流程（learn/write/extract/review），由 workflow 文件定义 |
| tier | entry 重要度：`1` = critical（不知道会产出编译失败或数据丢失/损坏的代码），`2` = memo（不知道会走弯路但最终能发现） |
| tm | trigger mode：`guard`（recall 时 warn/block）、`info`（recall 时 suggest） |

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
| `/know report` | Report — knowledge base health report | inline (no workflow file) |

### Auto-dispatch

`/know` or `/know {text}` → keyword match first, conversation scan fallback.

| Pipeline | Keywords |
|----------|----------|
| learn | 沉淀, 经验, 总结, 记住, save, persist, remember, 教训, lesson |
| write | prd, tech, roadmap, arch, capabilities, ui, 文档, doc, 写文档, ops, marketing, schema, decision |
| extract | 提取, extract, 扫描, scan, 挖掘, mine |
| review | review, 审查, 清理, 检查, audit, cleanup |
| report | report, 报告, 健康, health, status, 状态, 概况 |

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

**Skip when any**:
1. No index file exists
2. Same scope already queried this session
3. Current operation is Read/Glob/Grep (no Edit/Write/Bash write)

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

**Record query** (immediately after Query, before Rank):
```bash
# [RUN]
bash "$KNOW_CTL" recall-log "{scope}" "{matched_count}"
```

**Rank**: scope relevance → `guard` > `info` → tier 1 before tier 2.

**Select**: max 3 entries. 0 relevant → show nothing, no output.

**Act** (based on entry fields):

| Action | Condition |
|--------|-----------|
| suggest | `tm=info` |
| warn | `tm=guard` and `tier=2` |
| block | `tm=guard` and `tier=1` and scope exact match |

No exact match on `tier=1` + `guard` → downgrade to warn. No match at all → suggest.

**Output format**:
```
[recall] {summary}
Why: {one-line relevance to current operation}
Action: suggest | warn | block
```

**Record hit**: `bash "$KNOW_CTL" hit "{keyword}"`

**Learn hint** (once per session, only when ≥5 user messages in conversation and not yet hinted):

```
[know] tip: this conversation has learnable insights — run /know learn before ending
```

Conditions: ≥5 user messages AND learn hint not yet shown this session AND recall was triggered (piggyback on recall, don't fire independently). Append after recall output, not as standalone interruption.

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

Output: `[decay] {N} deleted, {M} demoted` if any action taken. Silent if none.

---

## Report

Triggered by `/know report`. No workflow file — runs inline commands and assembles output.

### Data Collection

```bash
# [RUN] collect all data in one pass
bash "$KNOW_CTL" metrics
bash "$KNOW_CTL" stats
```

Then gather additional data with inline commands:

```bash
# [RUN] recent activity (7 days)
jq -s --arg since "$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)" '[.[] | select(.ts >= $since)]' "$KNOW_DIR/events.jsonl" 2>/dev/null | jq '{created: [.[] | select(.event=="created")] | length, hit: [.[] | select(.event=="hit")] | length, decay: [.[] | select(.event=="decay_delete" or .event=="decay_demote")] | length, recall_query: [.[] | select(.event=="recall_query")] | length}'
```

```bash
# [RUN] top never-hit entries
jq -r 'select(.hits == 0) | "\(.scope) | \(.summary[0:60])"' "$KNOW_DIR/index.jsonl" | head -5
```

```bash
# [RUN] document inventory
find "$KNOW_DIR/docs" -name "*.md" -not -path "*/milestones/*" | wc -l
```

### Output Format

Assemble into 6 sections. Use `[report]` marker.

```
[report] know health report

--- 1. Overview ---
  Entries:    {total} (tier1: {n}, tier2: {n})
  Tags:       {tag1} {n}, {tag2} {n}, ...
  Scopes:     {n} ({largest}: {n} entries)
  Last 7d:    +{created} new, -{decayed} decayed, -{deleted} deleted

--- 2. Knowledge Value ---
  Hit rate:   {hit_count}/{total} ({pct}%)
  Last hit:   "{summary}" — {hits} hits
  Never hit:  {count} entries (top 3: ...)

--- 3. Recall ---
  Guards:     {guard_hits}
  Coverage:   {queried}/{total_scopes} ({pct}%)
  Queries:    {rq_total} (hit {rq_hit}/{pct}%, empty {rq_empty}/{pct}%)
  Blind spots: {scopes never queried}

--- 4. Documents ---
  Types:      {covered}/{total} ({list of covered types})
  Files:      {count}
  Missing:    {uncovered types}

--- 5. Trend (7d vs prior) ---
  New:        {recent} vs {prior}
  Hits:       {recent} vs {prior}
  Queries:    {recent} vs {prior}
  Direction:  {growing/stable/declining} — {one-line interpretation}

--- 6. Actions ---
  {priority}. {action description}
```

### Action Generation Rules

| Condition | Priority | Action |
|-----------|----------|--------|
| hit rate < 10% | high | "{n} entries never hit — run /know review" |
| recall queries = 0 for > 7 days | high | "recall not triggering — check SKILL.md recall section" |
| recall empty rate > 50% | medium | "recall matching too narrow — check scope rules" |
| uncovered doc types with existing data | medium | "missing {types} — run /know write" |
| no new entries in 7 days | low | "no recent knowledge — run /know learn or /know extract" |
| all healthy | — | "all indicators healthy" |

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

### Entry Schema (11 fields)

```json
{"tag":"...","tier":1,"scope":"...","tm":"...","summary":"≤80ch","path":"entries/{tag}/{slug}.md|null","hits":0,"revs":0,"source":"learn|extract","created":"YYYY-MM-DD","updated":"YYYY-MM-DD"}
```

| Field | Values |
|-------|--------|
| tag | `insight` (决策原因+心智模型), `rule` (约束), `trap` (踩坑) |
| tier | `1` = critical (不知道会产出编译失败或数据丢失/损坏的代码), `2` = memo (不知道会走弯路但最终能发现) |
| tm | `guard` (recall 时 warn/block), `info` (recall 时 suggest) |
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
| `[report]` | Health report output |
| `[decay]` | Entries deleted or demoted |
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
