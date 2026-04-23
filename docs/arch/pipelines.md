# know 三大 Pipeline 总览

know 插件由三条核心 pipeline 组成：**write**（文档生成）、**learn**（知识沉淀）、**recall**（编辑前召回）。本文给出每条 pipeline 的目标、输入、输出、详细流程，便于整体把握。

---

## write

### 目标

把对话内容和 `triggers.jsonl` 里的知识组合成结构化 markdown 文档。支持 10 种类型跨三种布局（单文件 / 目录 / 需求），并把进度反馈给父文档。

### 输入 / 输出

| | 内容 |
|---|---|
| Input | `/know write [hint] [name_hint]`, conversation, `triggers` (project + user), 项目布局 |
| Output | `docs/**/*.md` 文件（create）或 section 级修改（update），可选父文档进度更新 |
| Path 规则 | 单文件 `docs/<type>.md` / 目录 `docs/<type>/<name>.md` / 需求 `docs/requirements/<name>/<type>.md` |

### 详细流程（10 步）

#### Step 1 — Parameter Inference

| Sub | 作用 | 关键决策 |
|---|---|---|
| 1a Type | 推断 10 种 type 之一 | hint 合法直用；否则对照 exemplar 做 inference check；失败则走 Q1→Q2 分层问询 |
| 1b Name | kebab-case slug | name_hint 规范化优先；否则从对话抽取；抽不到问用户 |
| 1c Mode | create / update | 文件存在 → STOP:choose (Update/Rename/Cancel)；roadmap 永远 update |
| 1d Parent | 上游文档路径 | prd→roadmap, tech→prd；缺失时显式处理，不默默跳过 |

Inference check 的判据：*"把完整对话替换成该 type 的 exemplar，新读者能否复现同一份写作意图？"* 只对 1 个 type yes → 推断成功；对某组 yes → 问 Q2；否则问 Q1+Q2。

#### Step 1.5 — Sufficiency Gate

**高风险类型** (`prd/tech/arch/schema/decision/ui`) 触发。加载 `templates/sufficiency-gate.md` 问题组，逐题用对话原话回答：

- 全 yes → `pass`
- 部分 → `degrade` (STOP:choose 补充 / 降级 / 取消)
- 全 no → `reject` 同上

#### Step 2 — Confirm [STOP:confirm]

展示 `{type, name, path, mode, parent}` 一次性确认。字段修改按依赖链 `type → name → mode → parent` 逐级重推。

#### Step 3 — Template

`cat workflows/templates/<type>.md`；缺失则 fallback 为最小骨架。

#### Step 4 — Fill

- **Create**：逐 section 收集对话 + 相关 triggers，按 `<!-- INCLUDE/EXCLUDE -->` 填充；证据不足标 `TBD`；歧义标 `Open question:`。
- **Update**：只重写对话涉及的 section，其他 byte-identical；`tech §3 关键决策` 只追加，`§4 迭代记录` 只前置插入不覆盖。
- **Triggers as evidence**：insight 按 summary 引用不复制；rule 必须遵守；trap 进 Open Questions。

#### Step 5 — Write [STOP:confirm]

预览（create 全文 / update diff）→ TBD > 3 个额外警告 → 用户确认 → 落盘。`create` 用 Write tool，`update` 用 Edit tool 逐 section。

#### Step 5.5 — Validate

`templates/<type>-checklist.md` 存在才跑。核心检查：结构 / 语言 / **数据置信度**（数字必须有源：实测 / 估算 / 目标 / 无数据；精确无源必 fail）/ 完整性 / 图表。最多 3 轮修复，第 4 轮仍不过 → force-through 标注未决数。

#### Step 6 — Progress Propagation

`tech` → PRD §4 方案任务表；`prd` → roadmap 里程碑表。其他类型 skip。Edit tool 只动进度字段。

### 关键硬规则

- 所有字符串 lowercase 后匹配
- 无效输入 → 1 次 full-list fallback → 仍无效 → `abort`（不猜）
- 撞名必 STOP:choose，不自动切 update
- 数字无来源必 fail，不允许编造
- Triggers 只引用不复制

### 测试 Fixtures (`tests/write/`)

| 文件 | Step | 条数 |
|---|---|---|
| type-inference.jsonl | 1a | 7 |
| name-inference.jsonl | 1b | 7 |
| mode-inference.jsonl | 1c | 5 |
| parent-inference.jsonl | 1d | 5 |
| sufficiency.jsonl | 1.5 | 5 |
| confirm.jsonl | 2 | 4 |
| fill.jsonl | 4 | 5 |
| write-op.jsonl | 5 | 5 |
| validate.jsonl | 5.5 | 5 |
| progress.jsonl | 6 | 4 |

---

## learn

### 目标

把对话中的 tacit knowledge 沉淀为 `triggers.jsonl` 里的 trigger。偏好"少而精"，拒绝代码表面就能读出的常识。

### 输入 / 输出

| | 内容 |
|---|---|
| Input | `/know learn` 或 `/know learn "<claim>"`, conversation, 现有 triggers (for conflict check) |
| Output | `docs/triggers.jsonl` 或 `$XDG_CONFIG_HOME/know/triggers.jsonl` 追加行 + `created` event |
| Entry schema | `tag` / `scope` / `summary` / `strict` / `ref` / `keywords` / `source` / `created` / `updated` |

### 详细流程（5 步 — 由原 9 步合并）

#### Step 1 — Collect

扫描对话，产出**已拆分、已去噪**的候选列表（≤ 5 条）。合并了原 Detect + Extract + Filter 三步。

**质量预检**（对每条自查）：
- 有明确结论或规则？
- 是否只是一次性状态？
- 能否从代码表面直接看出？
- 有"为什么/踩过坑/约束"价值？

**拆分规则**：一个结论 + 一个原因 = 1 条不拆；两个独立事实 = 拆成 2 条。

> 7 条以上按优先级截取：用户显式纠正 > 收敛结论 > 易再发生 > 项目相关。

STOP:choose `all / 编号 / skip`。

#### Step 2 — Generate

为每条 candidate 定 7 个字段：

| 字段 | 规则 |
|---|---|
| tag | 优先级 `trap > rule > insight`；≥2 等价 → 问用户 |
| scope | 显式文件路径 → 模块名 → 功能域 → 稳定边界 → `project` |
| strict | rule 必填 true/false；insight/trap 必须 null |
| summary | `{结论} — {原因}`, ≤80 字 |
| ref | rule+strict=true 建议配 ref，其他可选 |
| keywords | 5–8 个 kebab-case，优先复用 `know-ctl keywords` 词表 |
| level | methodology.* → user；项目专属 → project；模糊 → 问 |

#### Step 3 — Conflict

对每条 entry 跑 `know-ctl search`，分类 candidate matches：

| 关系 | 处理 |
|---|---|
| unrelated | 通过 |
| merge (互补) | STOP:choose 提议合并 |
| duplicate (同结论) | STOP:choose 合并或跳过 |
| conflict (相反) | 必须显式暴露给用户解决 |

#### Step 4 — Confirm [STOP:confirm]

逐条展示最终 entry，用户 `confirm / edit <field>=<value> / skip / merge-with <existing>`。

- 最多 3 轮编辑，超限强制 `confirm / cancel`
- **user-level entry 第二次确认**：列出受影响的 scope 名单

#### Step 5 — Write

```bash
bash "$KNOW_CTL" append --level <level> '<json>'
```

写入 triggers.jsonl + emit `created` event。Decay 入口跑一次（v7 是 no-op）。

### 关键硬规则

- 8 字段完整才 persist；rule + strict=null 或 insight + strict=true 必 reject
- summary 超长必须重写
- user-level 二次确认
- conflict 绝不静默
- 新 keywords 只在 learn 阶段产生；recall 阶段只复用

### 测试 Fixtures (`tests/learn/`)

| 文件 | Step | 条数 |
|---|---|---|
| collect.jsonl | 1 | 5 |
| generate.jsonl | 2 | 5 |
| conflict.jsonl | 3 | 5 |
| confirm.jsonl | 4 | 5 |
| write.jsonl | 5 | 4 |

### 与原版的差异

| 原步骤 | 命运 |
|---|---|
| Detect / Extract / Filter | 合并为 **Collect** |
| Challenge（5 题自审） | **删除**——其中 4 题已被 Collect 的质量预检覆盖，1 题（scope 精度）已在 Generate 里 |
| Level | **并入 Generate**（与其他字段一起定） |

9 步 → 5 步，语义完整保留。

---

## recall

### 目标

在代码修改前自动查询相关 triggers，提示 AI；记录事件供后续分析（采纳率 / 利用率等）。**提醒不阻断**。

### 输入 / 输出

| | 内容 |
|---|---|
| Input | 即将执行的工具调用（Edit / Write / Bash 改文件）、当前会话上下文 |
| Output | `[recall]` 输出到屏幕（max 3 条）、`recall_query` / `hit` events 写入 events.jsonl |

### 触发条件

- **触发**：`Edit` / `Write` / `Bash`（改文件类）前
- **跳过**：triggers 文件都不存在 / 同 scope 本 session 已查 / 读类工具（Read/Glob/Grep）

### 详细流程（4 步 — 由原 8 步合并）

#### Step 1 — Infer Context

推断 scope 和 keywords，一步完成。

**Scope 优先级**：

| 优先级 | 来源 |
|---|---|
| P1 | 当前文件路径 → module 记法 |
| P2 | 最近 10 次 tool call 路径中出现 ≥2 次的 |
| P3 | `project` fallback |

**Keywords**：跑 `know-ctl keywords` 拿动态词表，从中挑 3-5 个最相关的；**禁止自由生成新 keywords**。

#### Step 2 — Query & Log

```bash
bash "$KNOW_CTL" query "{scope}" --keywords "{k1,k2,k3}"
```

返回 JSONL，含 `_level` + `_kw_hits`，已按 kw_hits 降序 + project 优先排好。

立即记录事件（含 returned_scopes 以便采纳率归因）：

```bash
bash "$KNOW_CTL" recall-log "{scope}" "{matched}" \
  --keywords "{k1,k2,k3}" --kw-hits "{total}" \
  --returned-scopes "{s1,s2,s3}"
```

#### Step 3 — Present Top 3

取前 3 条；0 相关 → 静默。`tag=rule && strict=true` 加 `⚠` 前缀：

```
[recall] [project] ⚠ {summary}
Why:  {relevance}
Ref:  {ref or "—"}
```

AI 按 tag + ⚠ 自判严格度，无机械 block/warn/suggest 分级。

#### Step 4 — Hit on Adoption

**采纳的明确定义**（满足任一）：
- AI 回复里引用了该 trigger 的 summary / scope / ref
- AI 改变原计划，显式把该 trigger 作理由
- AI 拒绝或调整某步，显式引用该 trigger

**不算采纳**：
- 读了 recall 输出但没行动
- 行为恰好符合某规则但未引用它

```bash
bash "$KNOW_CTL" hit "{summary-keyword}" --level {entry._level}
```

### 关键硬规则

- 永远提醒不阻断（no block/warn/suggest 分级）
- 同 scope 本 session 不重复查
- 新 keywords 只在 learn 产生
- Hit 必须由**显式引用**触发，不允许"恰好对齐"就算采纳

### 测试 Fixtures (`tests/recall-pipeline/`)

| 文件 | Step | 条数 |
|---|---|---|
| infer-context.jsonl | 1 | 4 |
| query-log.jsonl | 2 | 3 |
| present.jsonl | 3 | 3 |
| hit.jsonl | 4 | 4 |

### 与原版的差异

| 原步骤 | 命运 |
|---|---|
| Scope Inference + Keywords Inference | 合并为 **Infer Context** |
| Query + Record Query + Rank | 合并为 **Query & Log**（Rank 本就由 know-ctl 内部做） |
| Select + Act | 合并为 **Present Top 3** |
| Hit (optional) | 升级为必要步骤 **Hit on Adoption**，定义明确的触发条件 |

8 步 → 4 步，功能完整，Hit 的触发规则显式化（解决 M3 采纳率数据为 0 的根因）。

---

## 三者关系

```
┌─────────┐                         ┌─────────┐
│  learn  │  写 trigger  ─────────→ │triggers │
└─────────┘                         │ .jsonl  │
                                    └────┬────┘
                                         │ 读
                                         ▼
                                    ┌─────────┐
                                    │ recall  │ ← 编辑前触发
                                    └────┬────┘
                                         │ 写 recall_query / hit
                                         ▼
                                    ┌──────────┐
                                    │ events   │
                                    │ .jsonl   │
                                    └──────────┘

┌─────────┐  读 triggers + 对话 → 填模板 → ┌─────────┐
│  write  │                                  │  docs/  │
└─────────┘                                  └─────────┘
```

**依赖方向**：
- learn 只写 triggers + events(created)
- write 读 triggers（不写）
- recall 读 triggers + 写 events(recall_query, hit)
- learn / write / recall 三者没有同步依赖，都是独立会话动作

**指标来源**：
- M1 自查率 / M2 污染率：`tests/recall/` 离线测
- M3 采纳率 / M4 利用率 / M5 深度分布：从 events.jsonl 派生（`know-ctl metrics`）
