# learn — 知识沉淀

## 1. Overview

将对话中的洞察沉淀为 `triggers.jsonl` 中的 `trigger` 条目。流程：collect → generate → conflict → confirm → write。宁少勿滥，质优于量。

## 2. Core Principles

1. **一次收集**。单次扫描得出最终 candidates，不做多轮过滤。
2. **质优于量**。能从代码直接看出的不写；只留非显性的隐性知识。
3. **写前确认**。用户见到每条原文，控制最终落盘。
4. **冲突不静默**。重复、矛盾、可合并重叠必须抛给用户决定。
5. **level 必须显式**。每条 trigger 不是 `project`（本仓库）就是 `user`（跨项目），无模糊默认。
6. **追问有限**。非法回复 → 兜底一次完整列表 → 再非法则 abort。

## 3. Definitions

| 术语 | 含义 |
|---|---|
| `trigger` | 一行 JSONL，8 字段：`tag, scope, summary, strict, ref, keywords, source, created/updated` |
| `tag` | `rule`（必须/禁止）、`insight`（决策/心智模型）、`trap`（bug/坑）；歧义优先级：`trap > rule > insight` |
| `scope` | 点分 keypath（`Auth.session`、`methodology.recall-design`），稳定可复用锚 |
| `strict` | `rule` 时为 `true/false`；`insight/trap` 必须为 `null` |
| `level` | `project` 或 `user`，决定文件位置 |
| `candidate` | 未落盘的 trigger 中间态 |

## 4. Rules

### 4.1 Input handling

- 字符串匹配一律 case-insensitive。
- `STOP:choose` 阻塞流程，用户必须从展示的选项里挑。
- 首次非法回复触发完整列表兜底；第二次非法则 `abort`。

### 4.2 Entry integrity

- 每条 candidate 产出合法 8 字段条目；禁止半条落盘。
- `rule` 要求 `strict ∈ {true, false}`；`insight/trap` 要求 `strict = null`。
- `summary` ≤ 80 字符，格式 `{结论} — {理由}`。
- scope 取值顺序：明确文件路径 → 模块/子系统名 → 反复出现的功能域 → 大范围边界 → `"project"`（兜底）。
- level 默认：scope 以 `methodology.*` 开头 → `user`；项目内标识 → `project`；歧义 → 问。

### 4.3 Candidate quality

任一条命中即丢弃：
- 无明确结论或规则；
- 描述一次性状态或孤立事实；
- 从代码表面直读即可，无额外 why/约束/上下文；
- 无可预见的复现或复用。

### 4.4 Conflict handling

| 关系 | 动作 |
|---|---|
| unrelated | 放行 |
| merge（互补） | 提议合并，`STOP:choose` |
| duplicate（结论相同） | 提议 skip 或 merge，`STOP:choose` |
| conflict（对立） | 必须抛出，`STOP:choose` 裁决 |

单凭语义相似度不拍板；同时权衡 scope、方向、tag、适用范围、时间先后。

### 4.5 User touchpoints

- `Collect` 后一次选择（选哪些 candidate 进入处理）。
- 任一 conflict 一次选择。
- `Write` 前一次确认。
- 其余步骤除非显式兜底，不得再追问。

## 5. Workflow

模型：`opus` 做扫描与判断（1、2）；`sonnet` 做机械工作（3、5）。

### 5.1 Step 1 — Collect

**Input**：`conversation`，可选 `"<claim>"`，入口 `/know learn`。
**Output**：`candidates[]`（≤ 5），每条带 `summary_draft` 与 `likely_tag`；无合格内容则为空。

```
1. 入口为 /know learn "<claim>"：
     → 单 candidate，跳过扫描。
2. 否则扫描会话，筛出同时通过 §4.3 四条质量检查的内容。
3. 拆分：一个结论 + 其直接理由 = 一条；两个独立事实 = 两条。
4. 池 > 5 时按以下排序取前 5：
     用户纠正 > 已收敛结论 > 可能复现 > 项目相关。
5. 展示：
     [learn] step: collect
     会话价值摘要：{theme}
     关键产出：
       - {output 1}
       - {output 2}
     检测到 {N} 条可持久化知识：
       1. [{likely_tag}] {summary_draft}
       2. ...
     持久化？[all / 编号 / skip]
6. 选择时 STOP:choose。
```

### 5.2 Step 2 — Generate

**Input**：被选中的 candidates。
**Output**：每条 candidate 落成 `{tag, scope, strict, summary, ref, keywords, level}`。

```
对每条被选 candidate：
  2a tag         trap > rule > insight；≥ 2 项同等合理 → 问用户。
  2b scope       按 §4.2；避免过深或过泛。
  2c strict      仅 rule 有值；insight/trap 必须 null。
  2d summary     "{结论} — {理由}"，≤ 80 字符；不合则改写至合格。
  2e ref         可选 docs 路径 / 代码锚 / URL；rule+strict=true 尽量给 ref。
  2f keywords    5–8 个 kebab-case；优先复用现有词汇（know-ctl keywords）。
  2g level       methodology.* → user；项目内 → project；歧义 → STOP:choose。
```

**Keyword 规则**：小写，`[a-z0-9-]`，长度 2–40；除非确属新概念，否则复用现有词汇。

### 5.3 Step 3 — Conflict

**Input**：已生成条目。
**Output**：已完成冲突解决的条目。

```
1. 对每条条目，用 scope keywords 跑 know-ctl search：
     bash "$KNOW_CTL" search "<kw1>|<kw2>"
2. 对每条候选匹配归类：unrelated | merge | duplicate | conflict。
3. 非 unrelated 即抛出：
     [conflict] Similar entry found:
       Existing: {summary}
       New:      {summary}
       Relation: {merge | duplicate | conflict}
       Choose:   A) Update existing  B) Keep both  C) Merge  D) Skip new
   STOP:choose 裁决。
```

### 5.4 Step 4 — Confirm

**Input**：已解决冲突的条目。
**Output**：可写入的最终列表；每条最多 3 轮编辑。

```
对每条条目：
  展示 tag / scope / strict / summary / ref / keywords / level。
  询问：confirm / edit <field>=<value> / skip / merge-with <existing>。
  第 3 轮编辑后强制 A) confirm current，B) cancel。
user-level 条目需二次确认，列出所有受影响 scope。
```

### 5.5 Step 5 — Write

**Input**：已确认条目。
**Output**：追加 triggers.jsonl 行 + `created` 事件。

```bash
TODAY=$(date +%Y-%m-%d)
bash "$KNOW_CTL" append --level {level} '{
  "tag":"{tag}","scope":"{scope}","summary":"{summary}",
  "strict":{strict_or_null},"ref":{ref_or_null},
  "keywords":{keywords_array_or_null},
  "source":"learn","created":"'"$TODAY"'","updated":"'"$TODAY"'"
}'
```

```
[persisted] {scope} :: {summary} ({level})
```

Decay 在 pipeline 入口跑一次（`know-ctl decay`）。

## 6. Examples

### 一次纠正落为 rule

```
user: "你忘了 webhook 必须先验签再解 body"
→ Collect：1 条 candidate，likely_tag=rule。
→ Generate：tag=rule, scope=Payment.webhook, strict=true,
   summary="webhook 必须先验签再解 body — 防注入",
   keywords=["webhook","signature-verification","security"], level=project。
→ Conflict：无匹配。
→ Confirm → Write。
```

### 方法论 insight 升到 user level

```
conversation：讨论 benchmark 双策略设计
→ Collect：1 条 candidate。
→ Generate：tag=insight, scope=methodology.benchmark,
   summary="benchmark = A 现状算法 + B 上界模拟 — 对照出天花板",
   level=user。
→ Conflict：无匹配。
→ Confirm → user level 二次确认 → Write。
```

### 通过合并解决冲突

```
Existing: "session 过期必须刷新 — 避免静默登出"
New:      "session 超时不要拒绝，必须刷新 — 提升留存"
→ Conflict 归类为 duplicate。
→ 用户选 C) Merge；Step 3 合并为单条；Step 5 更新。
```

## 7. Edge Cases

| 情形 | 行为 |
|---|---|
| 会话无合格内容 | `[learn] No high-value knowledge detected.` |
| `/know learn "<claim>"` claim 畸形 | 单 candidate，`likely_tag=insight`，照常继续。 |
| candidate > 5 | 按 §5.1 步骤 4 排序截断。 |
| 所选 candidate 全被质量预检丢弃 | 每条给 `[skipped]`，不 Write 直接退出。 |
| 编辑超过 3 轮 | 强制 confirm-current 或 cancel。 |
| `know-ctl append` 失败 | 抛错，不静默重试。 |
| user-level 写入未过二次确认 | 仅中止该条，其他条目继续。 |
