---
name: know
description: Project knowledge compiler for AI agents — persist tacit knowledge and write structured documents.
---

# Know

4 pipelines: **learn** (persist knowledge), **write** (generate documents), **extract** (mine code), **review** (audit entries). Each loads its workflow file on demand.

2 always-on systems: **recall** (remind before code changes), **decay** (expire stale entries).

1 report: **report** (knowledge base health — 6 section diagnostic).

## Session Init

On first load per session, run silently and output 1 line per non-empty level:

```bash
# [RUN]
bash "$KNOW_CTL" stats --level project 2>/dev/null | grep -E '^Total:' | head -1
bash "$KNOW_CTL" stats --level user 2>/dev/null | grep -E '^Total:' | head -1
```

Output: `[know] [project] {total} entries | [user] {total} entries | last updated: {date}`

Where `{date}` comes from project triggers:
```bash
jq -sr 'sort_by(.updated) | last | .updated' "$PROJECT_TRIGGERS" 2>/dev/null
```

No output if both triggers files missing or empty. Run once per session, do not repeat.

---

## Principles

**High-risk = conservative**: overwrite/delete knowledge, assign critical, recall block, rewrite documents, write unconfirmed as fact → require evidence + user confirmation.

**Low-risk = flexible**: candidate discovery, summary writing, scope inference, document drafts, recall ranking → use full model capability.

Semantic understanding recommends; explicit signals + user intent decide. Rules conflict with practicality → simpler flow wins.

---

## Definitions

| Term | Meaning |
|------|---------|
| entry | triggers.jsonl 中的一行记录，8 个字段（见 Entry Schema） |
| tag | 分类：`insight`（决策/心智模型）、`rule`（约束）、`trap`（踩坑）。选择优先级：trap > rule > insight |
| scope | dot-separated keypath（如 `Module.Class.method`），支持前缀匹配。概念域用 `methodology.*` 前缀 |
| strict | `tag=rule` 时强制的 bool：`true`=硬约束（违反导致编译失败/数据损坏/安全问题），`false`=软约束（推荐）。其他 tag 必须 `null` |
| ref | 指向完整 context 的引用：docs 段落 / 代码锚点 / URL / `null` |
| level | 存储作用域：`project`（项目 git，per-project）或 `user`（跨项目共享）。由 `--level` 参数控制；读类默认两 level 合并，写类默认 project |
| pipeline | 子命令对应的执行流程（learn/write/extract/review），由 workflow 文件定义 |

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
1. Both project and user triggers files missing
2. Same scope already queried this session
3. Current operation is Read/Glob/Grep (no Edit/Write/Bash write)

### Pipeline

```
Scope Inference → Query (both levels) → Rank → Select (max 3) → Act
```

**Scope inference** (from current file operation):

| Priority | Method |
|----------|--------|
| P1 | Current file path → module notation |
| P2 | Last 10 tool call paths, ≥2 occurrences wins |
| P3 | `"project"` fallback |

**Query** (default: both levels merged; each entry carries `_level` field):
```bash
# [RUN]
bash "$KNOW_CTL" query "{scope}"
```

**Record query** (immediately after Query, before Rank):
```bash
# [RUN]
bash "$KNOW_CTL" recall-log "{scope}" "{matched_count}"
```

**Rank**: scope exact > scope prefix → same scope layer prefer `_level=project` over `_level=user` (local wins on ties).

**Select**: max 3 entries. 0 relevant → show nothing, no output.

**Output format** — prefix level tag; `tag=rule && strict=true` 加 `⚠` 前缀；输出里补 ref（若非 null）：
```
[recall] [project] ⚠ {summary}
Why:  {one-line relevance to current operation}
Ref:  {ref or "—"}

[recall] [user] {summary}
Why:  {one-line relevance}
Ref:  {ref or "—"}
```

AI 自行根据 tag、strict、⚠ 判断处理强度（rule+strict=true 应严格遵守；insight/trap 参考）。不做机械 block/warn/suggest 分级。

**Record hit**: `bash "$KNOW_CTL" hit "{summary-keyword}" --level {entry._level}`

**Learn hint** (once per session, only when ≥5 user messages in conversation and not yet hinted):

```
[know] tip: this conversation has learnable insights — run /know learn before ending
```

Conditions: ≥5 user messages AND learn hint not yet shown this session AND recall was triggered (piggyback on recall, don't fire independently). Append after recall output, not as standalone interruption.

---

## Decay

**v7: no-op**（策略重做在下个 sprint）。命令保留可调用性；learn 管线入口仍调，但不会有删除/降级动作。

```bash
# [RUN]
bash "$KNOW_CTL" decay
```

Output: `[decay] 已推延到下个 sprint（v7 schema 简化完成，衰减策略将在 v7.x 重做）`。

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
# [RUN] recent activity (7 days, current project)
jq -s --arg since "$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)" --arg pid "$PROJECT_ID" '[.[] | select(.ts >= $since and .project_id == $pid)]' "$EVENTS_FILE" 2>/dev/null | jq '{created: [.[] | select(.event=="created")] | length, hit: [.[] | select(.event=="hit")] | length, recall_query: [.[] | select(.event=="recall_query")] | length}'
```

```bash
# [RUN] top never-hit entries (current project)
# "never-hit" = summary never appears as hit event for this project
TRIGGERS="$PROJECT_TRIGGERS"
jq -r '.summary' "$TRIGGERS" 2>/dev/null | while read -r s; do
  if ! jq -e --arg s "$s" --arg pid "$PROJECT_ID" 'select(.event=="hit" and .summary==$s and .project_id==$pid)' "$EVENTS_FILE" > /dev/null 2>&1; then
    echo "$s"
  fi
done | head -5
```

```bash
# [RUN] document inventory
find "$DOCS_DIR" -name "*.md" -not -path "*/milestones/*" | wc -l
```

### Output Format

Assemble into 6 sections. Use `[report]` marker.

```
[report] know health report

--- 1. Overview ---
  Entries:    {total} (rule: {n_rule}, insight: {n_insight}, trap: {n_trap})
  Strict:     {hard_count} hard + {soft_count} soft (rule only)
  Scopes:     {n} ({largest}: {n} entries)
  Last 7d:    +{created} new, -{deleted} deleted

--- 2. Knowledge Value ---
  Hit rate:   {hit_count}/{total} ({pct}%)
  Last hit:   "{summary}"
  Never hit:  {count} entries (top 3: ...)

--- 3. Recall ---
  Defensive:  {strict_hits}     (hits on rule+strict=true)
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

**Three JSONL files**, split by source vs runtime and by level:

```
<project>/docs/triggers.jsonl          # project source (git-tracked)
                                       # also hosts narrative docs:
                                       #   {type}.md (roadmap/capabilities/ops/marketing)
                                       #   {type}/{topic}.md (arch/ui/schema/decision)
                                       #   requirements/{req}/prd.md + tech.md

$XDG_CONFIG_HOME/know/triggers.jsonl   # user source (user's dotfiles git optional)
                                       # default: ~/.config/know/

$XDG_DATA_HOME/know/events.jsonl       # runtime: all events (project + user)
                                       # each event has project_id + level fields
                                       # default: ~/.local/share/know/
```

Legacy v6 data at `$XDG_DATA_HOME/know/projects/{id}/` and `/user/` is migrated via `bash scripts/know-ctl.sh migrate-v7`.

### Entry Schema (8 fields)

```json
{"tag":"rule|insight|trap","scope":"...","summary":"≤80ch","strict":true|false|null,"ref":"docs/x.md#a|src/f:42|https://...|null","source":"learn|extract","created":"YYYY-MM-DD","updated":"YYYY-MM-DD"}
```

| Field | Values |
|-------|--------|
| tag | `rule` (约束)、`insight` (决策/心智模型)、`trap` (踩坑)；选择优先级 trap > rule > insight |
| scope | dot-separated keypath；支持前缀匹配 |
| summary | `{结论} — {原因}`，≤80 chars，含可搜索锚词 |
| strict | `tag=rule` 时必填 bool：`true`=硬约束，`false`=软约束；其他 tag 必须 `null` |
| ref | 指向 context：docs 段 / 代码锚点 / URL / `null` |
| source | `learn` \| `extract` |
| created / updated | `YYYY-MM-DD` |

### Event Schema (runtime, `$XDG_DATA_HOME/know/events.jsonl`)

```json
{"ts":"YYYY-MM-DD","project_id":"-Users-x-proj","level":"project|user","event":"created|updated|deleted|hit|recall_query","summary":"...","scope":"...","matched":N}
```

`scope` and `matched` 仅在 `event=recall_query` 时存在。`project_id` 即便对 `level=user` 条目的 hit 也记录（表明"在哪个项目里命中"），用于跨项目分析。

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
KNOW_CTL          = {project_root}/scripts/know-ctl.sh
PROJECT_TRIGGERS  = $PROJECT_DIR/docs/triggers.jsonl
USER_TRIGGERS     = ${XDG_CONFIG_HOME:-~/.config}/know/triggers.jsonl
EVENTS_FILE       = ${XDG_DATA_HOME:-~/.local/share}/know/events.jsonl
DOCS_DIR          = $PROJECT_DIR/docs
TEMPLATES_DIR     = {project_root}/workflows/templates
PROJECT_ID        = pwd | sed 's|/|-|g'
```

**3 files** — source split from runtime by XDG semantics (CONFIG = user declarations, DATA = derived state).

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
| No `$PROJECT_TRIGGERS` file | Create on first write operation |
| No triggers entries | Skip recall/review silently |
| `/know write` with <3 messages | Warn insufficient context, ask user to specify content |
| `/know learn` with 0 signals | `[learn] No high-value knowledge detected.` |
| `/know review` with empty index | `[review] No entries to review.` |
| `/know extract` with 0 files | `[extract] No files detected. Provide path or glob.` |
| `/know` route finds nothing | `[route] No actionable findings.` Offer: review / extract |
| `know-ctl.sh` command fails | Show error verbatim. Ask: retry or skip |
| Workflow file missing | `[error] Workflow not found: {path}` |
