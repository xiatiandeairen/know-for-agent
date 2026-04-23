# know 三大 Pipeline 细则

> 临时总览文档，便于校准每条 pipeline 每个 step 的细节。
> 最终正式版见 `workflows/write.md` · `workflows/learn.md` · `skills/know/SKILL.md`。

know 由三条核心 pipeline 组成：
- **write** — 从对话生成结构化文档（10 类 × 3 种布局）
- **learn** — 把对话中的 tacit knowledge 沉淀为 triggers
- **recall** — 代码修改前查询相关 triggers 提示 AI

三者独立触发，靠 triggers.jsonl + events.jsonl 间接协作。

---

# PIPELINE 1 — write

## 1.1 目标

把 **对话内容** 和 **已积累的 triggers** 组合成结构化 markdown 文档：选好类型 → 选好路径 → 选好填充策略 → 预览 → 落盘 → 校验 → 进度反馈。

**核心价值**：让文档不是重头写，而是"从讨论中沉淀"；让文档结构被模板锁死，内容真实性被 checklist 保底。

## 1.2 输入

| 字段 | 来源 | 必需 | 说明 |
|---|---|---|---|
| `hint` | CLI: `/know write <hint>` | 否 | 用户明示的 type 名；合法 → 跳过类型推断 |
| `name_hint` | CLI: `/know write <hint> <name>` | 否 | 用户明示的 slug；合法 → 跳过名称推断 |
| `conversation` | 当前会话 | 是 | 对话全文，filter 用于 type/name/sufficiency 推断 + fill 的内容来源 |
| `triggers` | `docs/triggers.jsonl` + `$XDG_CONFIG_HOME/know/triggers.jsonl` | 否 | 两 level 读合并，作 Fill 的补充素材 |
| `project_layout` | `git ls-files` + 文件系统 | 是 | 检测文件是否已存在、父文档是否在 |

## 1.3 输出

| 产物 | 目的 |
|---|---|
| `docs/**/*.md` | 文档文件（create 新建 / update 按 section 修改） |
| 父文档进度字段 | tech → PRD §4 任务表 / prd → roadmap 里程碑表 |
| `[written]` / `[progress]` 输出 | 屏幕反馈给用户 |

**不输出**：events.jsonl 事件（write 与 learn/recall 事件体系无交集）。

## 1.4 路径规则

| Type 类型 | 布局 | 路径模板 | 示例 |
|---|---|---|---|
| roadmap | 单文件 | `docs/<type>.md` | `docs/roadmap.md` |
| capabilities | 单文件 | `docs/<type>.md` | `docs/capabilities.md` |
| ops | 单文件 | `docs/<type>.md` | `docs/ops.md` |
| marketing | 单文件 | `docs/<type>.md` | `docs/marketing.md` |
| arch | 目录 | `docs/<type>/<name>.md` | `docs/arch/recall.md` |
| ui | 目录 | `docs/<type>/<name>.md` | `docs/ui/login-page.md` |
| schema | 目录 | `docs/<type>/<name>.md` | `docs/schema/know-ctl.md` |
| decision | 目录 | `docs/<type>/<name>.md` | `docs/decision/storage-format.md` |
| prd | 需求 | `docs/requirements/<name>/prd.md` | `docs/requirements/upload-flow/prd.md` |
| tech | 需求 | `docs/requirements/<name>/tech.md` | `docs/requirements/upload-flow/tech.md` |

**层级**：`roadmap → prd → tech`。其他类型独立，无父子关系。

**版本化**：所有文档单文件 + git 历史。roadmap 的多版本以 `### v{n}` section 存在 `## 2. 版本规划` 下，新版本 = `mode=update`，不是 create。

## 1.5 详细流程（10 步）

### Step 1a — Type Inference（类型推断）

**Signature**
- Input: `hint`, `conversation`, `user_replies[]`
- Output: `type ∈ 10 类` 或 `abort`
- 测试: `tests/write/type-inference.jsonl` (7 条)

**Decision procedure**

```
1. hint 合法（lowercase 后 ∈ 10 类）                 → accept and return.
2. 否则对 conversation 跑 inference check：
   2a. 仅某 1 type 通过                              → return that type.
   2b. 仅某组（A/B/C 之一）通过                      → ask Q2 for that group.
   2c. 无 type 通过 或 跨组通过                       → ask Q1, then Q2.
3. 用户回答不合法（非 A-D 字母、非 type 名、或"不知道"类模糊词）：
   → 列全 10 类让用户选
   → 再不合法 → abort.
```

**Inference check 判据**

对每个 type 问自己：

> **"如果把完整对话替换成该 type 的 exemplar，新读者是否还能复现同一份写作意图？"**

- yes for exactly 1 type → 2a
- yes for all types within 1 group → 2b
- 都 no 或跨组都 yes → 2c

**Type catalog (exemplars)** — AI 用作语义锚点

| Type | Exemplar |
|---|---|
| roadmap | "v1 交付 A/B/C；v2 扩展 D；Q2 发布" |
| prd | "用户可上传 pdf；上传成功率目标 95%" |
| tech | "采用 SQLite 存储；启用 WAL 模式；按 project_id 分表" |
| arch | "recall 模块由 scope 推断、query、rank 三段构成" |
| decision | "选用 JSONL 而非 SQLite，因其 diff 友好" |
| schema | "POST /api/v2/users 请求体含 name、email" |
| capabilities | "系统支持文件上传、OCR、全文检索" |
| ui | "点击按钮触发弹窗；表单分三段" |
| ops | "发布后收集反馈；两周一次迭代" |
| marketing | "通过博客、Twitter、官网 landing 多渠道推广" |

**Q1（3 选 1，大组分流）**

```
你要写哪类文档？
  A) 计划 / 需求         (roadmap, prd)
  B) 技术方案            (tech, arch, decision, schema)
  C) 产品 / 运营介绍     (capabilities, ui, ops, marketing)
```

**Q2 按组分支**

| Branch | Options |
|---|---|
| Q2-A | A) 项目总计划/版本规划 → `roadmap` · B) 单需求用户故事/验收标准 → `prd` |
| Q2-B | A) 实现细节/数据流 → `tech` · B) 系统架构/模块分解 → `arch` · C) 决策记录 → `decision` · D) 接口/数据结构 → `schema` |
| Q2-C | A) 对外功能清单 → `capabilities` · B) 界面/交互 → `ui` · C) 运营流程 → `ops` · D) 推广方案 → `marketing` |

**答案解析**
- 合法：字母（A/B/C/D）或显式 type 名
- 直接给 type 名 → 短路未问的 Q2
- 其他（`其他`、`都不是`、不在 catalog 的名词）→ invalid

**Hard rules**
- 所有 string 输入 lowercase 后匹配
- 合法 hint → 立即采用，不再询问
- invalid reply → 1 次 10 类 fallback prompt；第 2 次 invalid → `abort`（禁止 guess）
- Q1/Q2 选项必须完整展示，不得缩写
- 2a 推断必须能用"exemplar 替换对话"思想实验通过，否则降级

**示例**

| 对话片段 | 最接近 exemplar | 判决 |
|---|---|---|
| "recall 用 SQLite, WAL 模式, 按 project_id 分表" | tech exemplar 几乎 1:1 | 2a → `tech` |
| "聊了方案，但没定画架构还是记录选型" | B 组 arch / decision 都对 | 2b → 问 Q2-B |
| "零散想法，涉及版本规划、UI、上线节奏" | 跨 A/C 组 | 2c → 问 Q1 |

---

### Step 1b — Name Inference（名称推断）

**Signature**
- Input: `type`, `conversation`, `name_hint`, `user_replies[]`
- Output: `name` (kebab-case) 或 `null` 或 `abort`
- 测试: `tests/write/name-inference.jsonl` (7 条)

**是否需要 name 取决于 type**

| Type | 需要 name？ |
|---|---|
| roadmap / capabilities / ops / marketing | ❌ |
| arch / ui / schema / decision | ✅ topic slug |
| prd / tech | ✅ req slug |

**Decision procedure**

```
1. type 不需要 name                                   → return null.
2. name_hint 提供                                     → normalize, return.
3. 否则从 conversation 推断 slug：
   3a. 明确 topic/req 短语（如 "recall pipeline"）     → normalize, return.
   3b. 无明确短语                                      → ask user.
4. 回答无效 → 再问 1 次；仍无效 → abort.
```

**Kebab-case 规范化**
1. lowercase
2. `空格 / _ / . / /` → `-`
3. 剔除 `[a-z0-9-]` 外字符
4. 合并重复 `-`，去首尾 `-`
5. 规范化后为空 → invalid

**Invalid reply 定义**
规范化后为空，或 lowercase 匹配：`不知道` / `随便` / `skip` / `idk` / `-`

**Hard rules**
- `null` 仅在 type 不需 name 时返回
- `name_hint` 规范化后直采用，不追问
- 3a 推断必须是**显式名词短语**（如 `recall pipeline` / `cache layer`），不得从无关提及构造
- invalid reply 触发 1 次 fallback；第 2 次 invalid → abort

---

### Step 1c — Mode Inference（模式推断）

**Signature**
- Input: `type`, `name`, 已解析 `path`
- Output: `mode ∈ {create, update}` 或 `abort`
- 测试: `tests/write/mode-inference.jsonl` (5 条)

**Decision procedure**

```
1. 文件不存在                                         → mode = create.
2. type = roadmap (始终是单文件)                      → mode = update（新版本 = 新 section）.
3. 文件存在（其他类型）→ [STOP:choose]:
     A) 更新已有文件                                   → mode = update.
     B) 换个 name                                      → 重回 Step 1b.
     C) 取消                                           → abort.
```

**Hard rules**
- 永不静默覆盖已有文件；rule 3 强制触发
- roadmap 的"新版本" = update，不是 create（它的 file 是所有版本的 single source）

---

### Step 1d — Parent Inference（父级推断）

**Signature**
- Input: `type`, `name`, 项目布局
- Output: `parent_path` 或 `null`
- 测试: `tests/write/parent-inference.jsonl` (5 条)

**父级映射**

| Type | Parent | 路径 |
|---|---|---|
| prd | roadmap | `docs/roadmap.md` |
| tech | prd | `docs/requirements/<name>/prd.md` |
| 其他 | none | — |

**Decision procedure**

```
1. Type 无 parent                                     → return null.
2. Parent 文件存在                                    → return 其路径.
3. type=prd 且 roadmap 缺失                           → 继续，但标注 absence.
4. type=tech 且 prd 缺失 → [STOP:choose]:
     A) 不带 parent 继续                                → return null.
     B) 先建 PRD                                       → 重定向到 /know write prd.
5. type=prd 且里程碑归属模糊                          → 问用户里程碑编号.
```

**Hard rules**
- parent 缺失永远不静默；rules 3–5 让缺席显式化
- 此处不产出 `abort`，用户的重定向选择由下游处理

---

### Step 1.5 — Sufficiency Gate（充分性门禁）

**Signature**
- Input: `type`, `conversation`
- Output: `verdict ∈ {pass, degrade, reject}` + 未满足问题列表
- Gate: 仅 `type ∈ {prd, tech, arch, schema, decision, ui}` 触发；其他类型直接 pass
- 测试: `tests/write/sufficiency.jsonl` (5 条)

**Decision procedure**

```
1. type 不是高风险                                   → verdict = pass.
2. 加载 templates/sufficiency-gate.md 对应 type 的问题组，逐题用对话原话回答：
3. 全 yes                                            → verdict = pass.
4. 有 yes 有 no                                      → verdict = degrade.
5. 全 no                                             → verdict = reject.
```

**Output format**

```
[write] Sufficiency check: {type}
  ✅ Q1: {question} — {supporting quote}
  ❌ Q2: {question} — {what is missing}
  ...
Verdict: {pass | degrade | reject}
```

`degrade` 或 `reject` → STOP:choose

- A) 补充对话 → 重跑本 step
- B) 降级为 {推荐 type} → 重回 Step 1（带新 type）
- C) 取消 → abort

**Hard rules**
- 每题必须用对话原话回答或明确说 "not present"，不得用推理或猜测
- 降级目标固定为该 type 的最低风险邻居（如 `tech → decision`, `prd → capabilities`）
- 用户选 B → 必须重回 Step 1 重新推 name / mode / parent

---

### Step 2 — Confirm [STOP:confirm]

**Signature**
- Input: Step 1 产出的 `{type, name, mode, path, parent}`
- Output: 用户确认后的参数，或跳回某个 step

**Display format**

```
[write] Inferred from conversation
  Type:   {type}
  Name:   {name or "—"}
  Path:   {resolved path}
  Mode:   {create | update}
  Parent: {parent or "none"}
Correct? (yes / change <field>=<value>)
```

**Decision procedure**

```
1. 用户确认                          → 进 Step 3.
2. 改 type                           → 重回 Step 1a；name/mode/parent 全重推.
3. 改 name                           → 重回 Step 1c；mode/parent 跟进.
4. 改 mode 或 path                   → 直接采用，无需重推.
5. Step 1 有多候选                   → [STOP:choose] `1 | 2 | both`；both → Steps 3-6 逐个跑.
```

**依赖链**：`type → name → mode → parent`。改上游字段触发下游重推。

**Hard rules**
- 不得跳过此 step，即使推断高置信
- 字段编辑只重推下游字段，不做全量重推

---

### Step 3 — Template Loading

**Signature**
- Input: `type`
- Output: 模板文本（含 section headers 和 INCLUDE/EXCLUDE 注释）

```bash
cat "{project_root}/workflows/templates/{type}.md"
```

**Fallback**：模板文件不存在 → 合成最小骨架

```markdown
# {Title}
## Overview
## Details
## Open Questions
```

**Hard rules**
- 模板文件是文档结构的 single source of truth；本 step 永不修改它
- fallback 骨架仅在模板**真正缺失**时使用；不得替代"看起来不完整"的已有模板

---

### Step 4 — Fill（填充）

**Signature**
- Input: `template`, `conversation`, `triggers` (project + user), `existing_doc`（update 才有）
- Output: 完整填充的 markdown
- 测试: `tests/write/fill.jsonl` (5 条)

#### Create mode

```
1. 加载两 level triggers (docs/triggers.jsonl + $XDG_CONFIG_HOME/know/triggers.jsonl).
2. 逐 template section：
     2a. 收集对话相关引语 + 匹配 trigger.
     2b. 遵守 section 的 <!-- INCLUDE / EXCLUDE --> 指引.
     2c. 产出结构化散文；代码/表格从原文逐字引用.
     2d. 证据不足 → 写 "TBD — {缺什么}".
3. 歧义前缀 "Open question:".
4. 交叉引用用项目根相对路径；内容语言跟用户.
5. 应用 progress 字段表（见下）再 handoff.
```

**Triggers as evidence（核心补缺口）**

| Tag | 用法 |
|---|---|
| `insight` | 参考素材；按 summary 引用，不复制 |
| `rule` | 同 scope 章节必须遵守（如 PRD 不得违反"auth 必须验签"的 rule） |
| `trap` | 进 `Open Questions` 或相关"风险"子节 |

#### Progress 字段（Create 模式自动填）

| Type | 字段 | 规则 |
|---|---|---|
| roadmap | 里程碑.进度 | 统计链接到该里程碑的 PRD。格式 `完成数/总数` |
| roadmap | 里程碑.需求 | 链接每条 PRD；空则 `—` |
| roadmap | 里程碑编号 | 每版本从 M1 重新开始 |
| prd | §4 方案.任务表 | 每条 tech doc 一行；进度 = `完成数/总数` |
| tech | §4 迭代记录 | 种初始条目，含当日日期 + sprint 摘要 |

#### Update mode

```
1. 读现有文档全文.
2. 列出对话涉及的每个 section.
3. 仅重新生成涉及的 section，用 create-mode 的质量规则.
4. 未涉及的 section 保持 byte-identical.
5. 模板里新增但文档里缺失的 section → 加上，内容或 TBD.
6. 仅在涉及的 section 内修补断链相对路径.
7. 无 section 被讨论 → [STOP:choose] A) 加新 section B) 取消.
```

**Update 规则 by type**

| Type | Section | 规则 |
|---|---|---|
| tech | §2 方案 | 随理解深化覆盖 |
| tech | §3 关键决策 | 追加新行；绝不重写 |
| tech | §4 迭代记录 | 前置今天条目；绝不覆盖历史 |

**H1 标题规则**

| Scope | Title |
|---|---|
| Project single | `{项目名} {文档类型}` |
| Project directory | `{主题名} {文档类型}` |
| Requirement (prd) | `{用户入口}` |
| Requirement (tech) | `{需求名} 技术方案` |

**Hard rules**
- 禁止编造；证据缺失必须产出 TBD 或 Open question
- Create 模式：每个模板 section 恰好写一次
- Update 模式：只动对话涉及的 section
- Triggers 只引用不复制

---

### Step 5 — Write [STOP:confirm]（预览+落盘）

**Signature**
- Input: 填完的文档、解析路径、mode
- Output: 落盘文件；用户编辑可回 preview
- 测试: `tests/write/write-op.jsonl` (5 条)

#### Preview

**Create 模式** —— 显示全文

```
[write] Preview: {path}

{full document content}

Write? (yes / edit <section> / no)
```

**Update 模式** —— 仅显示涉及 section 的 diff

```
[write] Update preview: {path}

## {Section}
- {old}
+ {new}

Write? (yes / edit <section> / no)
```

#### TBD 阈值

填完的文档有 > 3 个 section 是 `TBD` → 在确认之前插入：

```
[write] {n} sections marked TBD: {list}. Still write?
```

用户必须再确认一次才继续；对该 section 进行编辑会自动从 TBD list 移除。

#### 落盘

```bash
mkdir -p "$(dirname "{resolved_path}")"
```

- `create` → Write tool
- `update` → Edit tool 逐 section；tech 文档额外在 `§4 迭代记录` 前置插入条目

```
[written] {path}
[written] {path} (updated {n} sections)
```

**Hard rules**
- 预览强制，不得静默落盘
- "Create 撞已有文件" 在 Step 1c 已处理，Step 5 到此 mode 已确定
- 用户 `edit <section>` 循环 preview，直到 `yes` 或 `no`（取消）

---

### Step 5.5 — Validate（校验）

**Signature**
- Input: 落盘文档路径、`type`
- Output: `pass` / `fail` / `force-through` + 违规列表；最多 3 轮修复
- Gate: 仅 `templates/{type}-checklist.md` 存在才跑；否则 skip
- 测试: `tests/write/validate.jsonl` (5 条)

**Procedure**

```bash
cat "{project_root}/workflows/templates/{type}-checklist.md"
```

```
对每项 check 验证文档符合：
  1. Structure    — 必需 section/field 存在，无多余.
  2. Language     — field 符合其语言约束（✅/❌ 模式）.
  3. Data         — 每个数值都有 source（见下）.
  4. Completeness — 非可选 field 是真内容，非占位.
  5. Diagrams     — 若 checklist 引用 diagram-checklist.md，加跑.

违规 → 列出、修、回 Step 5 重预览.
最多 3 轮；第 4 轮输出当前版本 + 标 "[validate] forced through, {n} checks unresolved".
```

**Data confidence 铁律**（核心防编造）

每个数值必须 cite 来源：

| Source | 输出形式 |
|---|---|
| 实测 | 值 + 引用 |
| 估算 | 值 + `估算` + 依据 |
| 目标 | 值 + `目标值，待验证` |
| 无数据 | `无数据（{reason}）` |

精确数字无 source → **必 fail**，无例外。

**Output**

```
[validate] {type} checklist: {passed}/{total} passed
  ✅ {check}
  ❌ {check} — {violation}
```

**Hard rules**
- checklist 缺失 = skip，不是"0 项都通过"
- 3 轮修复上限防死循环；到限强制输出 + 标未决数
- Data confidence 不容商量：编造的数字即使其他 check 全过也 fail

---

### Step 6 — Progress Propagation（进度反馈）

**Signature**
- Input: 已落盘文档的 `type` + `path`
- Output: 父文档被 Edit；或 silent skip
- 测试: `tests/write/progress.jsonl` (4 条)

**更新规则**

| 已写 type | Parent | 字段 |
|---|---|---|
| tech | parent PRD | `§4 方案` 任务表 progress 列 |
| prd | roadmap | 里程碑表 `完成PRD数/总PRD数` |
| 其他 | — | skip |

**Decision procedure**

```
1. 该 type 无 parent                                  → skip silently.
2. Parent 文件不存在                                  → skip silently.
3. Parent 存在 → Edit tool 只更新 progress 字段.
```

**Hard rules**
- 只改 progress 字段，不动相邻内容
- silent skip 是唯一的非更新合法结果；永远不在此 step 创建 parent —— 创建 parent 是 Step 1d 的职责

---

## 1.6 write 关键硬规则总汇

1. 所有字符串 lowercase 后匹配
2. 无效输入 → 1 次 full-list fallback → 仍无效 → `abort`（不猜）
3. 撞名必 STOP:choose，不自动切 update
4. Create 模式每 section 填一次；Update 模式只动涉及 section
5. 数字无来源必 fail
6. Triggers 只引用不复制
7. Validate 最多 3 轮修复，超限 force-through
8. 父文档不存在在本文档流程里永远不创建

## 1.7 write 测试 Fixtures

| 文件 | Step | 条数 | 关键场景 |
|---|---|---|---|
| `tests/write/type-inference.jsonl` | 1a | 7 | hint 合法/非法/大小写、全猜、部分猜、全问、无效重问、abort |
| `tests/write/name-inference.jsonl` | 1b | 7 | 不需 name、hint 直用、hint 规范化、对话推断、无猜问用户、重问、abort |
| `tests/write/mode-inference.jsonl` | 1c | 5 | 不存在→create、存在 Update、存在 Rename、存在 Cancel、roadmap update |
| `tests/write/parent-inference.jsonl` | 1d | 5 | 无 parent、prd+roadmap、prd 无 roadmap、tech 无 prd 继续/重定向 |
| `tests/write/sufficiency.jsonl` | 1.5 | 5 | 非高风险跳过、全 yes、部分 degrade、全 no reject、cancel |
| `tests/write/confirm.jsonl` | 2 | 4 | 直确认、改 type、改 name、both types |
| `tests/write/fill.jsonl` | 4 | 5 | create 全满、create 部分 TBD、update 只动涉及、triggers 引用、update 无 overlap |
| `tests/write/write-op.jsonl` | 5 | 5 | create 确认、TBD 阈值、edit 循环、cancel、update diff |
| `tests/write/validate.jsonl` | 5.5 | 5 | 无 checklist skip、pass、数据编造 fail、修复内、force-through |
| `tests/write/progress.jsonl` | 6 | 4 | 无 parent、tech→prd、prd→roadmap、parent 缺失 |

共 **52 条**。

## 1.8 write 常见 edge case

| 场景 | 行为 |
|---|---|
| hint 匹配 catalog 外的名字（如 `runbook`）| 视为 null，走推断路径 |
| 连续两次无效 reply | 终止 step 并 `abort` |
| Create 目标文件已存在 | Step 1c STOP:choose Update/Rename/Cancel |
| tech 无 parent PRD | Step 1d STOP:choose 继续/先建 PRD |
| Sufficiency reject 后选 B 降级 | 重回 Step 1，全部重推 |
| Preview 有 ≥ 4 个 TBD | 警告并要求再次确认 |
| Validator 3 轮仍有违规 | force-through + 显示未决数 |
| Parent 存在但 Edit 失败（权限/语法） | 输出 `[progress] skip: {reason}` 并继续 |

---

# PIPELINE 2 — learn

## 2.1 目标

把**会话中的 tacit knowledge**沉淀为 **`triggers.jsonl` 里的 trigger 条目**。原则：**宁缺勿滥**——只沉淀代码表面看不出来的"为什么"、"踩过的坑"、"必须遵守的约束"。

**核心价值**：AI 的阶段性理解（决策/原因/踩坑/规则）不应随 session 结束消失；沉淀后由 recall 在未来编辑时自动召回。

## 2.2 输入

| 字段 | 来源 | 必需 |
|---|---|---|
| `conversation` | 当前会话 | 是（`/know learn` 扫全对话） |
| `claim` | CLI: `/know learn "<claim>"` | 否（传了就当单一 candidate，跳过扫描） |
| 现有 triggers | `docs/triggers.jsonl` + user triggers | 是（conflict 查重用） |
| 现有 keywords 词表 | `know-ctl keywords` | 是（keywords 字段优先复用） |

## 2.3 输出

| 产物 | 目的 |
|---|---|
| 追加到 `docs/triggers.jsonl` 或 `$XDG_CONFIG_HOME/know/triggers.jsonl` 的行 | 本体数据 |
| `created` event | events.jsonl，供 recall 后续 adoption 归因 |
| 屏幕 `[persisted]` / `[skipped]` / `[conflict]` 输出 | 用户反馈 |

## 2.4 Entry Schema（8 字段）

```jsonc
{
  "tag":     "rule | insight | trap",       // 3 选 1
  "scope":   "Auth.session",                // dot-separated keypath
  "summary": "session 过期必须刷新 — 避免静默登出",  // ≤80 chars, "{结论} — {原因}"
  "strict":  true | false | null,            // rule=true/false; insight/trap=null
  "ref":     "docs/decision/auth.md#refresh" | null,  // 可空
  "keywords": ["authentication","session-refresh"],   // 5-8 个 kebab-case
  "source":  "learn",                        // 枚举 learn | extract
  "created": "2026-04-23",
  "updated": "2026-04-23"
}
```

**Level**（不在 JSON 里，靠文件位置表达）：
- `project` → 写入 `docs/triggers.jsonl`（项目级，git 跟踪）
- `user` → 写入 `$XDG_CONFIG_HOME/know/triggers.jsonl`（跨项目方法论）

## 2.5 详细流程（5 步 — 原 9 步合并）

### Step 1 — Collect（收集）

**Signature**
- Input: `conversation`, optional `claim`
- Output: `candidates[]`（≤ 5），含 `summary_draft` + `likely_tag`；无可沉淀 → `[]`
- 测试: `tests/learn/collect.jsonl` (5 条)

原本是 Detect/Extract/Filter 三步，合并为一步：**扫描 + 拆分 + 去噪 一次完成**。

**Procedure**

```
1. 如果是 /know learn "<claim>"：
   → 单一 candidate，跳过扫描.
2. 否则扫 conversation，产出通过质量预检（§2.7）的候选.
3. 拆分：一个结论+直接原因=1 条（不拆）；两个独立事实=2 条；不确定不拆.
4. 如果超 5 条，按优先级截取：
     user-corrected > converged conclusion > likely to recur > project-relevant.
5. 展示候选：
     [learn] step: collect
     会话价值摘要：{theme}
     关键产出：
       - {output 1}
       - {output 2}
     检测到 {N} 条可持久化知识：
       1. [{likely_tag}] {summary_draft}
       2. ...
     持久化？[all / 编号 / skip]
6. STOP:choose.
```

**Signal types**（帮 AI 扫描时分类用）

| Signal | 典型语言 | Likely tag |
|---|---|---|
| 用户纠错 | "don't / not X use Y / wrong / should be / 必须 / 不能" | rule / insight |
| 技术选型 | "chose / decided / instead of / tradeoff / 选了 / 决定用" | insight |
| 根因 | "root cause / caused by / turns out / 根因 / 问题是" | trap |
| 业务逻辑 | "the flow is / algorithm / works by / 机制是 / 流程是" | insight |
| 硬约束 | "must not / forbidden / never / always / 千万别" | rule |
| 外部集成 | "API / endpoint / SDK / webhook / 第三方接口" | insight |

### Step 2 — Generate（字段化）

**Signature**
- Input: 已选的 candidates
- Output: 每条 candidate 变成含 7 字段的正式 entry（`tag/scope/strict/summary/ref/keywords/level`）
- 测试: `tests/learn/generate.jsonl` (5 条)

**子步序（每条 candidate 按序走）**

#### 2a — Tag（标签）

**优先级**：`trap > rule > insight`（解决多标签冲突）

| 模式 | Tag |
|---|---|
| 有"历史犯错"的根因（踩过且易再踩） | **trap** |
| 明确约束（必须/禁止做 X，含外部 API 约束） | **rule** |
| 选型/比较（chose X over Y） | insight |
| 禁止（must not / forbidden / always） | rule |
| 外部 API/SDK 硬约束（header required, version pinned） | rule（防错优先于解释） |
| Bug/error/root-cause 发现 | trap |
| Flow/algorithm/architecture/business-rule | insight |

≥2 等价 → STOP:choose 问用户。

#### 2b — Scope

**生成优先级**：explicit 文件路径 → 模块/子系统名 → 反复出现的功能域 → 广稳定边界 → `"project"`（最后手段）。

**示例**：
- ✓ `Auth.session`、`Payment.webhook`、`Search.reranker`、`Infra.queue.worker`
- ✗ `src.app.services.payment.handlers.webhook.verify.signature.v2`（过深）
- ✗ `misc`、`unknown`（过泛）

#### 2c — Strict（仅 rule 适用）

| 条件 | strict |
|---|---|
| 违反会导致编译失败 / 数据损坏 / 安全漏洞 / 外部 API 硬要求 | `true` |
| 推荐实践 / 风格约定 / 建议性规则 | `false` |

tag=insight/trap → strict **必须** null。

#### 2d — Summary

**格式**：`{结论} — {原因/上下文}`，**≤80 字符**。

**要求**：简洁、可读、真信息密度，不空标题。

**超长处理**：去修饰 → 只留核心结论 → 仍超 → 拆成两条 entry。

#### 2e — Ref（可选）

指向 entry 的完整 context：
- `"docs/decision/xxx.md#anchor"` — 项目文档段落
- `"src/auth/session.ts:42"` — 代码锚点
- `"https://..."` — 外部链接
- `null` — summary 已够

**推荐场景**：`tag=rule && strict=true` 最好有 ref；summary ≥60 字往往值得配 doc 段。

#### 2f — Keywords

**Hard rule**（`know-ctl` 校验）：
- 每个 keyword 字符只允许 `[a-z0-9-]`
- 长度 2-40
- ✓ `webhook` / `signature-verification` / `api-v2` / `jwt` / `pii-protection`
- ✗ `Webhook`（大写）/ `web_hook`（下划线）/ `签名`（中文）/ `api design`（空格）

**Soft convention**：优先复用现有词表

```bash
bash "$KNOW_CTL" keywords
```

示例输出：
```
authentication (8)
webhooks (5)
signature-verification (3)
idempotency (4)
```

为 trigger 选 5-8 个：
- **优先从词表复用**（一致性 > 个人偏好）
- 新词直接加入（会自然扩展词表）

#### 2g — Level

| Signal（在 scope 或 summary 里） | 建议 level |
|---|---|
| Scope 以 `methodology.*` 开头 | user |
| Summary 是领域无关（通用工程教训，无项目特有标识） | user |
| Scope 命名项目局部模块（如 `Auth.session`、`Search.reranker`） | project |
| 引用项目特有文件/类/配置 | project |

模糊 → STOP:choose 问用户。

### Step 3 — Conflict（冲突处理）

**Signature**
- Input: 生成好的 entries
- Output: 冲突解决后的 entries
- 测试: `tests/learn/conflict.jsonl` (5 条)

**Procedure**

```
对每个 entry：
1. know-ctl search 抓候选匹配：
     bash "$KNOW_CTL" search "<kw1>|<kw2>"
2. 对每个 candidate match 分类：unrelated | merge | duplicate | conflict.
3. 任何非 unrelated → [STOP:choose]:
     [conflict] Similar entry found:
       Existing: {summary}
       New:      {summary}
       Relation: {merge | duplicate | conflict}
       Choose:   A) Update existing  B) Keep both  C) Merge  D) Skip new
```

**分类依据**

| Relation | 判据 |
|---|---|
| duplicate | 同结论，不同措辞 → 建议 merge 或 skip |
| conflict | 互斥结论 → 必须展示，用户决定 |
| merge | 互补（同话题，不同角度）→ 建议 merge |
| unrelated | 通过 |

语义相似度能找候选，但最终分类还须考虑：scope / 结论方向 / tag / 适用范围 / 时间顺序。

### Step 4 — Confirm [STOP:confirm]

**Signature**
- Input: 解决冲突后的 entries
- Output: 最终待写 list；每条最多 3 轮编辑
- 测试: `tests/learn/confirm.jsonl` (5 条)

**Procedure**

```
对每条 entry：
  展示 tag / scope / strict / summary / ref / keywords / level.
  问：confirm / edit <field>=<value> / skip / merge-with <existing>.
  3 轮编辑后，强制 A) 确认当前, B) 取消.

User-level entry 需要二次确认（列出所有受影响 scope）.
```

**User-level 二次确认示例**

```
[learn] 即将写入 user 级，跨所有项目生效。确认以下 {M} 条？
  1. [insight] methodology.benchmark — benchmark 双策略 …
  2. [rule]    methodology.upgrade  — 算法升级前先建观测 …
回复 "y" 确认；或 "1:project, 3:project" 降回 project；或 "cancel" 撤销.
```

### Step 5 — Write（落盘）

**Signature**
- Input: 确认后的 entries
- Output: 追加行到 triggers.jsonl + `created` event
- 测试: `tests/learn/write.jsonl` (4 条)

```bash
TODAY=$(date +%Y-%m-%d)
bash "$KNOW_CTL" append --level <level> '{
  "tag":"<tag>","scope":"<scope>","summary":"<summary>",
  "strict":<strict_or_null>,"ref":<ref_or_null>,
  "keywords":<keywords_array_or_null>,
  "source":"learn","created":"'"$TODAY"'","updated":"'"$TODAY"'"
}'
```

输出：

```
[persisted] <scope> :: <summary> (<level>)
```

**Decay**：pipeline 入口跑一次（`know-ctl decay`，v7 中是 no-op，保留作 hook）。

## 2.6 原 9 步如何合并

| 原步骤 | 命运 | 理由 |
|---|---|---|
| 1 Detect | → 并入 **Collect** | 与 Extract/Filter 三步本质同事（扫 + 拆 + 去噪） |
| 2 Extract | → 并入 **Collect** | 拆分规则简单，不需独立一步 |
| 3 Filter | → 并入 **Collect** | 质量预检在扫描时顺便做，不需二次 pass |
| 4 Generate | → **Generate** | 保留，重要 |
| 5 Conflict | → **Conflict** | 保留，核心 |
| 6 Challenge（5 题自审）| **删除** | 5 题中 4 题已被 Collect 质量预检覆盖，1 题（scope 精度）已在 Generate 里 |
| 7 Level | → 并入 **Generate 2g** | 本质是 entry 的一个字段，应和其他字段一起定 |
| 8 Confirm | → **Confirm** | 保留，唯一用户触点 |
| 9 Write | → **Write** | 保留 |

9 步 → 5 步，语义完整保留。

## 2.7 质量预检（Collect 内做的 4 问）

对每条 candidate 自查，任一回答 yes → drop：

1. 无明确结论或规则？
2. 是一次性/短期状态？
3. 能否从代码表面直接看出？
4. 没有"为什么/踩过坑/约束"的长期价值？

**Keep（即便单文件）**：
- 结论非显而易见
- 原因不从表面代码直接看出
- 易再次踩坑
- 涉及业务边界、外部系统、时序、顺序
- 清晰的"我们为什么这么做"价值
- 项目特有决策或规则

## 2.8 learn 关键硬规则

1. 8 字段完整才 persist；partial write 禁止
2. rule 必须 strict ∈ {true, false}；insight/trap 必须 strict = null
3. summary ≤ 80 字符，超长必重写
4. level=user 要二次确认
5. conflict 绝不静默，必须展示让用户选
6. 新 keywords 只在 learn 产生；recall 只复用
7. invalid reply → 1 次 fallback → 仍 invalid → abort

## 2.9 learn 测试 Fixtures

| 文件 | Step | 条数 | 关键场景 |
|---|---|---|---|
| `tests/learn/collect.jsonl` | 1 | 5 | 无信号、claim 模式、单纠错、7→5 截取、表面代码 drop |
| `tests/learn/generate.jsonl` | 2 | 5 | rule+strict=true、insight+strict=null、trap、超 80 重写、methodology→user |
| `tests/learn/conflict.jsonl` | 3 | 5 | 无冲突、duplicate、merge、conflict keep-both、skip |
| `tests/learn/confirm.jsonl` | 4 | 5 | 直确认、edit+confirm、skip、3 轮强制、user-level 二次确认 |
| `tests/learn/write.jsonl` | 5 | 4 | project 写、user 写、schema 违规、空 list |

共 **24 条**。

## 2.10 learn 常见 edge case

| 场景 | 行为 |
|---|---|
| 会话无可沉淀内容 | `[learn] No high-value knowledge detected.` |
| `/know learn "<claim>"` 的 claim 畸形 | 单 candidate with `likely_tag=insight`，正常继续 |
| >5 candidates | 按优先级截取，丢弃其余 |
| 所有 candidate 被质量预检 drop | 逐条输出 `[skipped]`，pipeline 退出 |
| 用户编辑超 3 轮 | 强制 A) 确认当前 B) 取消 |
| `know-ctl append` 失败 | 报错显式化，不静默重试 |
| user-level 未过二次确认 | 只 abort 那条，其他继续 |

---

# PIPELINE 3 — recall

## 3.1 目标

在 **代码修改前**自动查询相关 triggers 并提示 AI。**提醒不阻断**，让 AI 自己决定怎么用。同时记录事件（recall_query、hit），供离线和实时指标分析。

**核心价值**：
- 沉淀的 triggers 不被动等待，主动在相关场景暴露
- 记录事件供 M3 采纳率、M4 利用率、M5 深度分布等指标派生

## 3.2 输入

| 字段 | 来源 | 必需 |
|---|---|---|
| 即将执行的工具调用 | Edit / Write / Bash (改文件) | 是（判 trigger 与否） |
| 当前文件路径 | 工具参数 | 否（scope 推断 P1） |
| 最近 tool call 历史 | session 上下文 | 否（scope 推断 P2） |
| 当前 task 上下文 | 对话 | 是（keywords 推断用） |
| Triggers | `docs/triggers.jsonl` + user triggers | 是 |
| Keywords 词表 | `know-ctl keywords` | 是（keywords 必须来自词表） |

## 3.3 输出

| 产物 | 目的 |
|---|---|
| 屏幕 `[recall]` 输出（max 3 条） | 提示 AI |
| `recall_query` event → events.jsonl | 查询归档 + M3/M4/M5 数据源 |
| `hit` event → events.jsonl | 采纳归档 + M3 分子数据源 |

## 3.4 触发规则

**触发**：即将执行 `Edit` / `Write` / `Bash`（改文件类）

**跳过 when any**：
- project 和 user triggers 文件**都**不存在
- 同 scope 本 session 已查过
- 只读工具（`Read` / `Glob` / `Grep`）

## 3.5 详细流程（4 步 — 原 8 步合并）

### Step 1 — Infer Context（推断上下文）

**Signature**
- Input: 当前工具调用的参数、对话、最近 tool call 历史
- Output: `scope` + `keywords[]`（3-5 个）
- 测试: `tests/recall-pipeline/infer-context.jsonl` (4 条)

推断 scope + keywords 一步完成（原 Scope Inference + Keywords Inference 合并）。

#### Scope 推断（3 级优先级）

| 优先级 | 来源 |
|---|---|
| **P1** | 当前文件路径 → module 记法 |
| **P2** | 最近 10 次 tool call 的路径中出现 ≥2 次的 |
| **P3** | `"project"` fallback |

P1 示例：`src/auth/session.ts` → `Auth.session`
P2 示例：最近连改 `src/payment/a.ts`、`src/payment/b.ts`、`src/payment/c.ts` → 虽然当前编辑的是 `build.sh`，scope 仍推 `Payment`

#### Keywords 推断

```bash
bash "$KNOW_CTL" keywords
```

输出带频次的动态词表：
```
authentication (8)
webhooks (5)
signature-verification (3)
...
```

**AI 从词表挑 3-5 个**，根据：
- 当前 file 类型（`.ts` / `.sh` / `.md`）
- 正在改的功能
- 对话 task context

**硬规则**：只从词表选；**禁止自由生成新词**（新词只在 learn 产生）。

### Step 2 — Query & Log（查询 + 记录）

**Signature**
- Input: `scope`, `keywords`
- Output: 返回的 entries 列表（JSONL，已排序）+ `recall_query` event
- 测试: `tests/recall-pipeline/query-log.jsonl` (3 条)

原 Query + Record Query + Rank 三步合并。Rank 本就由 `know-ctl query` 内部做（无需独立 AI step）。

#### Query

```bash
bash "$KNOW_CTL" query "{scope}" --keywords "{k1},{k2},{k3}"
```

**返回 JSONL**：每行一个 entry，含：
- 原 8 字段
- `_level`（project / user）
- `_kw_hits`（keywords 命中数）

**排序**：`_kw_hits` 降序；平手内 `_level=project` 优先（know-ctl 已自动做）。

#### Log

```bash
bash "$KNOW_CTL" recall-log "{scope}" "{matched}" \
  --keywords "{k1},{k2},{k3}" \
  --kw-hits "{total_kw_hits}" \
  --returned-scopes "{s1,s2,s3}"
```

**参数**：
- `matched` = 返回的 entry 条数
- `total_kw_hits` = 所有返回 entry 的 `_kw_hits` 累加
- `returned_scopes` = 前 N 条的 scope 列表（**M3 采纳率归因必需**）

### Step 3 — Present Top 3（呈现）

**Signature**
- Input: 查询返回的 entries
- Output: 屏幕输出（max 3 条）
- 测试: `tests/recall-pipeline/present.jsonl` (3 条)

原 Select + Act 合并。

```
取 _kw_hits 降序前 3 条.
0 相关 → 静默不输出.
tag=rule && strict=true → 加 ⚠ 前缀.
```

**输出格式**：

```
[recall] [project] ⚠ {summary}
Why:  {one-line relevance to current operation}
Ref:  {ref or "—"}

[recall] [user] {summary}
Why:  {one-line relevance}
Ref:  {ref or "—"}
```

**处理强度**：AI 按 tag + ⚠ 自判，不做机械 block/warn/suggest 分级：
- `rule + strict=true + ⚠` → 严格遵守
- `rule + strict=false` → 遵守但允许权衡
- `insight / trap` → 参考

### Step 4 — Hit on Adoption（采纳记录）

**Signature**
- Input: AI 对 recall 输出的后续行为
- Output: 可能的 `hit` event
- 测试: `tests/recall-pipeline/hit.jsonl` (4 条)

**这一步是 M3 采纳率数据的唯一来源**。原 "(Optional) Hit" 语义模糊导致实际从不触发（M3 永远 0）；现在把触发条件显式化。

#### 采纳的明确定义

满足**任一**即算采纳：

1. **AI 回复里引用了该 trigger** 的 summary、scope、或 ref
2. **AI 改变原计划** 并显式把该 trigger 作为理由
3. **AI 拒绝或调整某步** 并显式引用该 trigger

#### 不算采纳

- 读了 recall 输出但没行动
- 行为恰好符合某规则但未引用它（"顺势对齐"）

#### 触发

```bash
bash "$KNOW_CTL" hit "{summary-keyword}" --level {entry._level}
```

会 emit `hit` event，含 `scope` 字段（从 trigger 自动回填）。后续 M3 计算时关联 `recall_query.returned_scopes` 判定"这次查询被采纳"。

## 3.6 原 8 步如何合并

| 原步骤 | 命运 | 理由 |
|---|---|---|
| 1 Scope Inference | → 并入 **Infer Context** | 和 Keywords 是同一认知 |
| 2 Keywords Inference | → 并入 **Infer Context** | 同上 |
| 3 Query | → 并入 **Query & Log** | CLI 调用 |
| 4 Record Query | → 并入 **Query & Log** | 同一次 CLI 调用序列 |
| 5 Rank | **删除** | 本就由 know-ctl 内部做，非 AI step |
| 6 Select | → 并入 **Present Top 3** | 和 Act 是同一动作 |
| 7 Act | → 并入 **Present Top 3** | 渲染输出 |
| 8 Hit (optional) | **升级为必要 Step 4** | 采纳条件显式化，解决 M3=0 问题 |

8 步 → 4 步，功能完整；Hit 触发规则显式化。

## 3.7 Learn hint（附加能力）

**触发条件**（全部满足）：
- recall 本 session 已触发过
- 用户本 session 已发送 ≥ 5 条消息
- 本 session 还没提示过

**输出**（追加在 recall 输出后，不单独中断）：

```
[know] tip: this conversation has learnable insights — run /know learn before ending
```

**每 session 最多 1 次**。

## 3.8 recall 关键硬规则

1. 永远提醒不阻断（无 block/warn/suggest 分级）
2. 同 scope 本 session 不重复查（防打扰）
3. 新 keywords 只在 learn 阶段产生；recall 阶段只从词表选
4. Hit 必须由**显式引用**触发，不允许"顺势对齐"就算采纳
5. 查询 scope 不在 triggers 里 ≠ 无结果；scope 支持双向前缀匹配
6. 黑盒调用 `know-ctl` CLI；不绕过读 triggers.jsonl
7. recall 失败不阻塞主流程

## 3.9 recall 测试 Fixtures

| 文件 | Step | 条数 | 关键场景 |
|---|---|---|---|
| `tests/recall-pipeline/infer-context.jsonl` | 1 | 4 | 文件路径→scope、历史→scope P2、fallback、keywords 来自词表 |
| `tests/recall-pipeline/query-log.jsonl` | 2 | 3 | 有结果 log、空结果 log、同 scope 跳过 |
| `tests/recall-pipeline/present.jsonl` | 3 | 3 | top 3 渲染+⚠、空静默、>3 截断 |
| `tests/recall-pipeline/hit.jsonl` | 4 | 4 | 引用 summary 触发、引用 scope 触发、顺势对齐不触发、只读不触发 |

共 **14 条**。

## 3.10 recall 指标派生

recall 产生的事件供以下指标派生（`know-ctl metrics`）：

| 指标 | 定义 | 数据来源 |
|---|---|---|
| **M3 采纳率** | recall_query（matched>0）中 1h 内有 hit.scope ∈ returned_scopes 的比例 | recall_query.returned_scopes + hit.scope |
| **M4 利用率** | 30 天内 returned_scopes 的 union / 总 trigger scope 数 | recall_query.returned_scopes |
| **M5 深度分布** | recall_query.matched 的 median / mean / bucket | recall_query.matched |
| **死 trigger 名单** | 30 天未进任何 returned_scopes 的 trigger | recall_query.returned_scopes + triggers.jsonl |

## 3.11 recall 常见 edge case

| 场景 | 行为 |
|---|---|
| triggers 文件都不存在 | 静默 skip |
| 同 scope 本 session 已查过 | 静默 skip（防打扰） |
| 当前操作是 Read/Glob/Grep | skip |
| query 返回 0 条 | 不输出，但 recall_query event 仍记（matched=0） |
| 词表空（`know-ctl keywords` 无输出） | AI 按 task context 挑 1-3 个合理词试查 |
| AI 引用 scope 但不采纳具体内容 | 不触发 hit |
| Bash 修改文件（如 `> file.txt`） | 按 Edit/Write 一样触发 recall |
| `know-ctl` 执行失败 | 错误提示 + 跳过本次 recall，不阻塞主流程 |

---

# 三者关系图

```
                       ┌─────────┐
                       │  learn  │
                       └────┬────┘
                            │ 写 trigger
                            ▼
                       ┌──────────────┐
                       │ triggers.jsonl│◄──── 读 ──── write (Fill 用作 evidence)
                       │ (project+user)│
                       └──────┬───────┘
                              │ 读
                              ▼
                         ┌─────────┐
                         │ recall  │ ← Edit/Write/Bash 前触发
                         └────┬────┘
                              │ 写 recall_query / hit
                              ▼
                       ┌──────────────┐
                       │ events.jsonl │ ──── metrics / report-recall 派生 M3/M4/M5
                       └──────────────┘
```

## 依赖方向

- **learn**：只写 triggers + events(created)
- **write**：读 triggers（作 Fill 素材），不写 events
- **recall**：读 triggers，写 events(recall_query, hit)
- 三者**没有同步依赖**，均为独立会话动作

## 数据生命周期

```
learn (create)         →  trigger                 ↑
                              ↓                    │
                      write (read as evidence)    │
                              ↓                    │
                      recall (surface in edit) ←──┘
                              ↓
                      hit (adopted) → M3 data
```

## 事件归属

| Event | 产生者 | 消费者 |
|---|---|---|
| `created` / `updated` / `deleted` | learn / manual CLI | history / metrics |
| `hit` | recall Step 4 | M3 采纳率 |
| `recall_query` | recall Step 2 | M3/M4/M5/死名单 |
| `decay_delete` / `decay_demote` | decay（v7 no-op） | history |

## 指标来源

| 指标 | 来源 | 消费 |
|---|---|---|
| **M1 自查率** | `tests/recall/` 离线测 | trigger scope/keywords 质量 |
| **M2 污染率** | `tests/recall/` 离线测 | trigger scope 范围 |
| **M3 采纳率** | events.jsonl | recall 推荐质量 |
| **M4 利用率** | events.jsonl | 知识库活性 |
| **M5 深度分布** | events.jsonl | scope 粒度诊断 |
| **死 trigger 名单** | events.jsonl + triggers.jsonl | review 清理指引 |
