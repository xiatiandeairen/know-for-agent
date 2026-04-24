---
name: know
description: Project knowledge compiler for AI agents — persist tacit knowledge and write structured documents.
---

# Know

## 1. Overview

面向 AI agent 的项目知识编译器：沉淀隐性知识（triggers.jsonl）+ 生成结构化文档。

- **4 条 pipeline**（按需加载 workflow 文件）：`learn` 沉淀 / `write` 写文档 / `extract` 挖代码 / `review` 审查条目
- **2 个常驻系统**：`recall`（改动前提醒）/ `decay`（v7 no-op）
- **1 个报告**：`report`（知识库健康 6 段诊断）

## 2. Core Principles

1. **高风险保守**：覆盖/删除、critical 等级、block、重写文档、把未确认内容写为事实 → 必须证据 + 用户确认。
2. **低风险灵活**：候选发现、摘要、scope 推断、草稿、ranking → 用完整模型能力。
3. **语义理解给建议，显式信号 + 用户意图做决定**。
4. **规则与实用冲突 → 简单流程优先**。
5. **Recall 只提醒不阻断**：AI 看 tag + `⚠` 自行判断严格程度，无机械 block/warn/suggest 分层。
6. **level 二选一**：`project`（默认写入）/ `user`（跨项目）；读默认合并，`--level` 覆盖。
7. **数据置信**：数值必须标注来源（实测/估算/目标/无数据）。

## 3. Definitions

| 术语 | 含义 |
|---|---|
| entry | triggers.jsonl 一行记录，8 字段（见 §4.4） |
| tag | `rule`（约束）/ `insight`（决策/心智）/ `trap`（踩坑）；歧义时优先级 `trap > rule > insight` |
| scope | dot-separated keypath（`Auth.session`、`methodology.recall`），支持前缀匹配 |
| strict | `tag=rule` 时必填 bool：`true`=硬约束（违反即编译失败/数据损坏/安全事故），`false`=软推荐；其他 tag 必须 `null` |
| ref | 指向完整 context：docs 段 / 代码锚点 / URL / `null` |
| keywords | `string[]` 或 `null`；每项匹配 `^[a-z0-9-]+$`，长度 2-40；learn 时从 `know-ctl keywords` 词表优先选 5-8 个，recall 时选 3-5 做匹配；既有 trigger 可 null（向后兼容） |
| level | `project`（项目 git）/ `user`（跨项目，`$XDG_CONFIG_HOME/know/`） |
| pipeline | learn/write/extract/review，对应 workflow 文件 |
| PROJECT_ID | 项目绝对路径 `/` 换成 `-`（只作 event 字段，不作目录） |

## 4. Rules / Constraints

### 4.1 Session Init（首次加载执行一次）

```bash
# [RUN]
bash "$KNOW_CTL" stats --level project 2>/dev/null | grep -E '^Total:' | head -1
bash "$KNOW_CTL" stats --level user    2>/dev/null | grep -E '^Total:' | head -1
jq -sr 'sort_by(.updated) | last | .updated' "$PROJECT_TRIGGERS" 2>/dev/null
```

输出一行：`[know] [project] {N} entries | [user] {N} entries | last updated: {date}`。两份 triggers 都缺失或空 → 不输出。本会话不再重复。

### 4.2 Recall 触发条件

在任何会改文件的操作（`Edit` / `Write` / 写类 `Bash`）前执行。以下任一满足即跳过：
- 两份 triggers 文件都缺失
- 本会话已查过相同 scope
- 当前操作只读（`Read` / `Glob` / `Grep`）

### 4.3 存储布局（3 文件）

```
<project>/docs/triggers.jsonl           # project source（git-tracked）
$XDG_CONFIG_HOME/know/triggers.jsonl    # user source（~/.config/know/，用户 dotfiles 可选 git）
$XDG_DATA_HOME/know/events.jsonl        # runtime 事件（~/.local/share/know/，每行含 project_id + level）
```

`docs/` 同时托管文档：`{type}.md`（roadmap/capabilities/ops/marketing）、`{type}/{topic}.md`（arch/ui/schema/decision）、`requirements/{req}/prd.md + tech.md`。

legacy v6 数据（`$XDG_DATA_HOME/know/projects/{id}/` 和 `/user/`）由 `scripts/know-ctl.sh migrate-v7` 迁移，原文件不自动删除。

### 4.4 Entry Schema（8 字段 + 可选 keywords）

```json
{"tag":"rule|insight|trap","scope":"...","summary":"≤80ch","strict":true|false|null,"ref":"docs/x.md#a|src/f:42|https://...|null","keywords":["a","b"]|null,"source":"learn|extract","created":"YYYY-MM-DD","updated":"YYYY-MM-DD"}
```

| 字段 | 约束 |
|---|---|
| tag | 见 §3 |
| scope | dot-separated keypath；支持前缀匹配 |
| summary | `{结论} — {原因}`，≤80 字符，含可搜索锚词 |
| strict | `rule` 时 bool，其他 tag 必须 `null` |
| ref | docs 段 / 代码锚点 / URL / `null` |
| keywords | 见 §3 |
| source | `learn` / `extract` |
| created / updated | `YYYY-MM-DD` |

### 4.5 Event Schema（runtime）

```json
{"ts":"YYYY-MM-DD","project_id":"-Users-x-proj","level":"project|user","event":"created|updated|deleted|hit|recall_query","summary":"...","scope":"...","matched":N}
```

`scope` / `matched` 仅在 `event=recall_query` 存在。`level=user` 条目被命中时 `project_id` 仍记录（用于跨项目归因）。

### 4.6 文档类型（10 种）

| Type | 路径 |
|---|---|
| roadmap / capabilities / ops / marketing | `docs/{type}.md`（项目单文件） |
| arch / ui / schema / decision | `docs/{type}/{topic}.md`（项目目录） |
| prd / tech | `docs/requirements/{req}/{type}.md` |

层级：`roadmap → prd → tech`；其他独立。

### 4.7 路径解析（从 "Base directory for this skill: {path}" 去掉 `skills/know/` 得项目根）

```
KNOW_CTL          = {project_root}/scripts/know-ctl.sh
PROJECT_TRIGGERS  = $PROJECT_DIR/docs/triggers.jsonl
USER_TRIGGERS     = ${XDG_CONFIG_HOME:-~/.config}/know/triggers.jsonl
EVENTS_FILE       = ${XDG_DATA_HOME:-~/.local/share}/know/events.jsonl
DOCS_DIR          = $PROJECT_DIR/docs
TEMPLATES_DIR     = {project_root}/workflows/templates
PROJECT_ID        = pwd | sed 's|/|-|g'
```

### 4.8 执行控制标记（不出现在用户输出中）

| 标记 | 含义 |
|---|---|
| `# [RUN]` | Bash 工具执行 |
| `[STOP:confirm]` | 暂停待用户确认（ok/yes/continue/确认/好/可以） |
| `[STOP:choose]` | 暂停待用户选项 |

### 4.9 输出标记（每条 pipeline 输出前缀）

`[route]` / `[learn]` / `[persisted]` / `[conflict]` / `[skipped]` / `[extract]` / `[write]` / `[written]` / `[progress]` / `[recall]` / `[review]` / `[report]` / `[decay]` / `[error]`

**风格**：pipeline 输出带步骤名（`[learn] step: detect`）；匹配用户语言；无填充/含糊词；数值具体（"3 files" 不是 "several"）；空结果也是合法输出（"No issues found"）。

## 5. Workflow

### 5.1 输入归一化

**直接入口**：

| 输入 | pipeline | workflow |
|---|---|---|
| `/know learn` | Learn — 扫会话 | `workflows/learn.md` |
| `/know learn "text"` | Learn — 把 text 当 claim | `workflows/learn.md` |
| `/know write` | Write — 从会话推参数 | `workflows/write.md` |
| `/know write <hint>` | Write — hint 辅助推断 | `workflows/write.md` |
| `/know extract` | Extract — 挖代码 | `workflows/extract.md` |
| `/know review [scope]` | Review — 审查 | `workflows/review.md` |
| `/know report` | Report — 健康报告 | 内联，无 workflow |

**自动分派** `/know` 或 `/know {text}` → 关键词匹配优先，失败则扫会话。大小写不敏感子串匹配，首个命中胜出。

| pipeline | keywords |
|---|---|
| learn | 沉淀/经验/总结/记住/save/persist/remember/教训/lesson |
| write | prd/tech/roadmap/arch/capabilities/ui/文档/doc/写文档/ops/marketing/schema/decision |
| extract | 提取/extract/扫描/scan/挖掘/mine |
| review | review/审查/清理/检查/audit/cleanup |
| report | report/报告/健康/health/status/状态/概况 |

0 个或 ≥2 个命中 → 扫会话呈现发现让用户选：

```
[route] Detected: {findings}
A) learn  B) write  C) extract  D) review  E) multi-select
```

多选执行顺序：learn → extract → write → review。

### 5.2 Recall（4 步）

**Step 1 — 推断 context**

*Scope*：P1 当前文件路径 → 模块表示法 / P2 最近 10 次工具调用出现 ≥2 次的路径 / P3 fallback `"project"`。

*Keywords*：

```bash
# [RUN]
bash "$KNOW_CTL" keywords
```

从返回词表选 3-5 个匹配当前任务（文件类型 + 正在改的 feature + 会话上下文）。**禁止发明新词**，新词仅在 learn 时产生。

**Step 2 — 查询并记日志**

```bash
# [RUN]
bash "$KNOW_CTL" query "{scope}" --keywords "{k1},{k2},{k3}"
bash "$KNOW_CTL" recall-log "{scope}" "{matched_count}" \
  --keywords "{k1},{k2},{k3}" \
  --kw-hits "{total_kw_hits}" \
  --returned-scopes "{s1,s2,s3}"
```

返回 JSONL 已按 `_kw_hits` 降序、`_level=project` 先。`{total_kw_hits}` = 返回条目 `_kw_hits` 之和（空时 0）。必须记 `returned_scopes` 以便后续归因命中。

**Step 3 — 输出前 3 条**

空列表 → 不输出。`tag=rule && strict=true` 加 `⚠` 前缀。

```
[recall] [project] ⚠ {summary}
Why:  {一行相关性}
Ref:  {ref 或 —}
```

**Step 4 — 命中记录**

AI 在后续输出中**显式使用**某条 trigger 时立即发命中事件。判定显式：
- AI 回复按名引用该 trigger 的 summary/scope/ref
- AI 因某条具体 trigger 改变方案
- AI 基于该 trigger 调整或拒绝某步

**不计命中**：读了 recall 输出但没针对性行动；与某条 rule 无关地恰好一致。

```bash
# [RUN]
bash "$KNOW_CTL" hit "{summary-keyword}" --level {entry._level}
```

### 5.3 Learn Hint

三条件全满足时，本会话一次，追加在 recall 输出后（不单独打断）：本会话已触发过 recall + 用户消息 ≥5 条 + 本会话未触发过该提示。

```
[know] tip: this conversation has learnable insights — run /know learn before ending
```

### 5.4 Decay（v7 no-op）

```bash
# [RUN]
bash "$KNOW_CTL" decay
```

输出：`[decay] 已推延到下个 sprint（v7 schema 简化完成，衰减策略将在 v7.x 重做）`。

### 5.5 Report（/know report，内联）

**数据收集**：

```bash
# [RUN]
bash "$KNOW_CTL" metrics
bash "$KNOW_CTL" stats

# 近 7 天活动（当前项目）
jq -s --arg since "$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)" --arg pid "$PROJECT_ID" '[.[] | select(.ts >= $since and .project_id == $pid)]' "$EVENTS_FILE" 2>/dev/null | jq '{created:[.[]|select(.event=="created")]|length, hit:[.[]|select(.event=="hit")]|length, recall_query:[.[]|select(.event=="recall_query")]|length}'

# Top never-hit（当前项目）
TRIGGERS="$PROJECT_TRIGGERS"
jq -r '.summary' "$TRIGGERS" 2>/dev/null | while read -r s; do
  if ! jq -e --arg s "$s" --arg pid "$PROJECT_ID" 'select(.event=="hit" and .summary==$s and .project_id==$pid)' "$EVENTS_FILE" > /dev/null 2>&1; then
    echo "$s"
  fi
done | head -5

# 文档清单
find "$DOCS_DIR" -name "*.md" -not -path "*/milestones/*" | wc -l
```

**输出 6 段**（前缀 `[report]`）：

```
[report] know health report

--- 1. Overview ---
  Entries: {total} (rule:{n_rule}, insight:{n_insight}, trap:{n_trap})
  Strict:  {hard} hard + {soft} soft (rule only)
  Scopes:  {n} ({largest}: {n} entries)
  Last 7d: +{created} new, -{deleted} deleted

--- 2. Knowledge Value ---
  Hit rate: {hit}/{total} ({pct}%)
  Last hit: "{summary}"
  Never hit: {count} (top 3: ...)

--- 3. Recall ---
  Defensive:  {strict_hits}  (hits on rule+strict=true)
  Queries:    {rq_total} (hit {rq_hit}/{pct}%, empty {rq_empty}/{pct}%)
  Blind spots: {scopes never queried}

--- 4. Documents ---
  Types:   {covered}/{total} ({covered list})
  Files:   {count}
  Missing: {uncovered types}

--- 5. Trend (7d vs prior) ---
  New:      {recent} vs {prior}
  Hits:     {recent} vs {prior}
  Queries:  {recent} vs {prior}
  Direction: {growing/stable/declining} — {一行解读}

--- 6. Actions ---
  {priority}. {action}
```

**Action 规则**：

| 条件 | 优先级 | Action |
|---|---|---|
| hit rate < 10% | high | "{n} entries never hit — run /know review" |
| recall queries = 0 超过 7 天 | high | "recall not triggering — check SKILL.md recall section" |
| recall empty rate > 50% | medium | "recall matching too narrow — check scope rules" |
| 文档类型缺失但有对应数据 | medium | "missing {types} — run /know write" |
| 7 天无新 entry | low | "no recent knowledge — run /know learn or /know extract" |
| 全健康 | — | "all indicators healthy" |

## 6. Examples

**Recall 展示**

```
[recall] [project] ⚠ webhook 必须先验签再解 body — 防注入
Why:  当前改动涉及 src/payment/webhook.ts，属于 Payment.webhook scope
Ref:  docs/decision/payment.md#webhook-auth
```

**自动分派歧义**

```
user: /know 改进下 session 刷新
[route] Detected: 与 session 相关的讨论，候选多条
A) learn  B) write  C) extract  D) review  E) multi-select
```

**Session init 输出**

```
[know] [project] 42 entries | [user] 8 entries | last updated: 2026-04-20
```

## 7. Edge Cases

| 场景 | 行为 |
|---|---|
| 无 `$PROJECT_TRIGGERS` 文件 | 首次写入时创建 |
| 无 triggers 条目 | 静默跳过 recall / review |
| `/know write` 会话 <3 消息 | 警告上下文不足，让用户指定内容 |
| `/know learn` 无信号 | `[learn] No high-value knowledge detected.` |
| `/know review` 空索引 | `[review] No entries to review.` |
| `/know extract` 0 文件 | `[extract] No files detected. Provide path or glob.` |
| `/know` 路由无发现 | `[route] No actionable findings.` 提供 review / extract |
| `know-ctl.sh` 命令失败 | 原样显示错误，问 retry 或 skip |
| workflow 文件缺失 | `[error] Workflow not found: {path}` |
