# know 三大 Pipeline 细则（逐 step 版）

> 临时总览文档。每条 pipeline 每个 step 按：目标 / 输入 / 输出 / 触发 / 执行过程 / 用户交互 / 硬规则 / 成功示例 / 失败示例 / 测试 展开。
> 最终正式 spec 以 `workflows/write.md` · `workflows/learn.md` · `skills/know/SKILL.md` 为准。

know 由三条核心 pipeline 组成：
- **write** — 从对话生成结构化文档
- **learn** — 把对话中的 tacit knowledge 沉淀为 triggers
- **recall** — 代码修改前查询相关 triggers 提示 AI

三者独立触发，通过 `triggers.jsonl` + `events.jsonl` 间接协作。

---

# 通用约定（全三条 pipeline 共享）

## 控制流标记

| 标记 | 含义 |
|---|---|
| `STOP:confirm` | 阻塞等待用户答 yes/no（或等价表达） |
| `STOP:choose` | 阻塞等待用户从给出的选项中挑一个 |
| `abort` | 终止当前 step，不写盘、不推进 |
| `silent skip` | 不输出任何信息，不触发任何事件，直接结束 |

## 输入规范化

- **大小写**：所有字符串比较前 `lowercase`。
- **空白**：trim 首尾空格；多空格合并为 1 个。
- **模糊答复**（视为 invalid）：`不知道` / `随便` / `skip` / `idk` / `-` / 规范化后为空。

## 失败处理统一模式

任何 step 内询问用户，遵循：

```
1. 用户答合法 → 采用。
2. 用户答 invalid → 列出完整选项集再问 1 次（fallback prompt）。
3. 第 2 次仍 invalid → abort 当前 step。
```

**禁止 guessing**：不猜测用户意图，不给"看起来最像"的结果作默认。

---

# PIPELINE 1 — write

## 1.1 目标

把 **对话内容** + **已积累的 triggers** 组合成结构化 markdown 文档：选类型 → 选路径 → 选填充策略 → 预览 → 落盘 → 校验 → 进度反馈。

**核心价值**：让文档从"重头写"变成"从讨论中沉淀"；用模板锁结构，用 checklist 保真实性。

## 1.2 输入

| 字段 | 来源 | 必需 | 说明 |
|---|---|---|---|
| `hint` | CLI: `/know write <hint>` | 否 | 合法 → 跳过类型推断 |
| `name_hint` | CLI: `/know write <hint> <name>` | 否 | 合法 → 跳过名称推断 |
| `conversation` | 当前会话 | 是 | 推断 + 填充的素材 |
| `triggers` | `docs/triggers.jsonl` + `$XDG_CONFIG_HOME/know/triggers.jsonl` | 否 | Fill 阶段作补充素材 |
| `project_layout` | `git ls-files` + 文件系统 | 是 | 判断文件/父文档是否存在 |

## 1.3 输出

| 产物 | 目的 |
|---|---|
| `docs/**/*.md` | 新建或按 section 修改文档 |
| 父文档进度字段 | tech→PRD §4 / prd→roadmap 里程碑 |
| 屏幕标记 | `[written]` / `[progress]` / `[validate]` 等 |

**不产 events**：write 与 events.jsonl 无交集。

## 1.4 路径规则

| Type | 布局 | 路径模板 |
|---|---|---|
| roadmap / capabilities / ops / marketing | 单文件 | `docs/<type>.md` |
| arch / ui / schema / decision | 目录 | `docs/<type>/<name>.md` |
| prd / tech | 需求 | `docs/requirements/<name>/<type>.md` |

**层级**：`roadmap → prd → tech`。其他类型独立。
**Roadmap 版本**：所有版本在一个文件里，作为 `### v{n}` section 存于 `## 2. 版本规划` 下；新版本 = `mode=update`。

---

## 1.5 详细流程

---

### Step 1a — Type Inference（类型推断）

#### 目标

确定文档是 10 种 type 中的哪一种：`roadmap / prd / tech / arch / decision / schema / ui / capabilities / ops / marketing`。

#### 输入

```jsonc
{
  "hint": "tech" | null,             // 来自 CLI
  "conversation": "<对话全文>",
  "user_replies": []                 // 本 step 内用户对 AI 的追加回答
}
```

#### 输出

```jsonc
{
  "type": "tech",                    // ∈ 10 类
  "questions_asked": 0               // 观测用，不影响下游
}
```

或 `{ "outcome": "abort" }`。

#### 触发条件

write pipeline Step 1 的第一个子步骤，每次 `/know write` 必触发。

#### 执行过程

1. **hint 合法性判断**：`lowercase(hint) ∈ 10 类集合` → 直接返回，不进行推断。
2. **hint 为空或非法**：进入 inference check。
   - 遍历 10 个 type，对每个做一次 yes/no 判断：
     > *"如果把完整 conversation 换成这个 type 的 exemplar，新读者是否能复现同样的写作意图？"*
   - 记录所有答 yes 的 type。
3. **根据 yes 的分布决定分支**：
   - 恰好 1 个 yes → 直接返回该 type（**2a**）。
   - ≥2 个 yes 且都在一个组（A/B/C）内 → 进 2b，**跳过 Q1 直接问 Q2**。
   - 多组有 yes，或 0 个 yes → 进 2c，**从 Q1 开始问**。
4. **用户回答解析**：
   - 合法形式：`A / B / C / D` 字母；或显式 type 名（如 "prd"）。
   - 显式 type 名 → 短路后续未问的 Q2，直接采用。
   - 其他 → invalid。
5. **invalid 处理**：列出所有 10 个 type 再问一次；仍 invalid → `abort`。

#### 用户交互 prompt

**Q1 完整文本**：

```
你要写哪类文档？
  A) 计划 / 需求         (roadmap, prd)
  B) 技术方案            (tech, arch, decision, schema)
  C) 产品 / 运营介绍     (capabilities, ui, ops, marketing)
```

**Q2-A / Q2-B / Q2-C**：

```
Q2-A (选 A 后)：
  A) 项目总计划 / 版本规划        → roadmap
  B) 单需求的用户故事/验收标准   → prd

Q2-B (选 B 后)：
  A) 实现细节 / 数据流           → tech
  B) 系统架构 / 模块分解         → arch
  C) 决策记录（为什么选 X 不选 Y）→ decision
  D) 接口 / 数据结构规范         → schema

Q2-C (选 C 后)：
  A) 对外功能清单                → capabilities
  B) 界面 / 交互说明             → ui
  C) 运营流程 / 反馈闭环         → ops
  D) 推广 / 发布方案             → marketing
```

**Invalid fallback**：

```
无法识别 '{reply}'。请从下列 10 类中选一个（字母 A-J 或直接类型名）：
  A) roadmap     B) prd          C) tech         D) arch         E) decision
  F) schema      G) ui           H) capabilities  I) ops          J) marketing
```

#### Inference check 的判据细节

对每个 type 的 exemplar 做对比：

| Type | Exemplar | 匹配标志 |
|---|---|---|
| roadmap | "v1 交付 A/B/C；v2 扩展 D；Q2 发布" | 含版本号/时间线/里程碑 |
| prd | "用户可上传 pdf；成功率 95%" | 含用户故事/验收标准 |
| tech | "采用 SQLite；WAL 模式；按 project_id 分表" | 含具体实现方案/数据流 |
| arch | "recall 模块 = scope 推断 + query + rank" | 含模块分解/数据流图 |
| decision | "选 JSONL 不选 SQLite，因 diff 友好" | 含权衡/选型对比 |
| schema | "POST /api/v2/users 含 name, email" | 含接口/字段规范 |
| capabilities | "支持文件上传、OCR、全文检索" | 含对外功能清单 |
| ui | "点击按钮触发弹窗；表单 3 段" | 含界面/交互描述 |
| ops | "发布后看反馈；两周一迭代" | 含运营/反馈闭环 |
| marketing | "博客 + Twitter + 官网 landing" | 含推广/渠道 |

#### 硬规则

1. 所有字符串 lowercase 后匹配。
2. 合法 hint 立即采用，不得追问。
3. invalid 触发 1 次 full-list fallback；第 2 次 invalid → abort。
4. Q1/Q2 选项必须完整展示，不得缩写。
5. inference check 失败要降级到 2b/2c，不得用"最像"凑答案。

#### 成功示例

**场景 A：hint 直用**
```
CLI:   /know write tech
输入:  { hint: "tech", conversation: "讨论 SQLite 实现" }
执行:  rule 1 命中 → 直接返回 type=tech
输出:  { type: "tech", questions_asked: 0 }
```

**场景 B：高置信推断**
```
输入:  { hint: null, conversation: "recall 模块分 scope 推断、query、rank 三段" }
执行:  inference check → 仅 arch exemplar 通过（"模块分解+数据流"匹配）
输出:  { type: "arch", questions_asked: 0 }
```

**场景 C：中置信问 Q2**
```
输入:  { hint: null, conversation: "聊了方案，没定是画架构图还是记录选型" }
执行:  inference check → B 组内 arch + decision 都 yes → 跳 Q1 问 Q2-B
AI问:  "你是想写哪种工程类？ A) 实现 B) 架构 C) 决策 D) 接口"
用户:  "C"
输出:  { type: "decision", questions_asked: 1 }
```

#### 失败 / 异常示例

**场景 D：invalid 后给对答案**
```
输入:  { hint: null, conversation: "零散", user_replies: ["我要 runbook", "prd"] }
执行:  Q1 问 → "我要 runbook" invalid → fallback 列全 10 类
      → 用户 "prd" 合法 → 采用
输出:  { type: "prd", questions_asked: 2 }
```

**场景 E：两轮都 invalid → abort**
```
输入:  { hint: null, user_replies: ["不知道", "随便"] }
执行:  Q1 → invalid → fallback → invalid → abort
输出:  { outcome: "abort" }
```

#### 测试覆盖

| tc id | 覆盖点 |
|---|---|
| tc01-hint-valid | 规则 1 直通 |
| tc02-hint-case | 大小写规范化后直通 |
| tc03-guess-full | 2a 高置信 |
| tc04-guess-q1-ask-q2 | 2b 中置信 |
| tc05-ask-q1-q2 | 2c 低置信 |
| tc06-invalid-then-valid | fallback 后合法 |
| tc07-persistent-invalid-abort | 两次 invalid → abort |

`tests/write/type-inference.jsonl` 共 7 条。

---

### Step 1b — Name Inference（名称推断）

#### 目标

为需要 slug 的 type 产出 kebab-case `name`。Roadmap 等单文件类型返回 `null`。

#### 输入

```jsonc
{
  "type": "arch",                    // 已由 1a 确定
  "conversation": "...",
  "name_hint": null,                 // CLI 第二参数
  "user_replies": []
}
```

#### 输出

```jsonc
{ "name": "recall-pipeline" }
```

或 `{ "name": null }`（单文件 type）或 `{ "outcome": "abort" }`。

#### 触发条件

每次都触发，紧跟 1a 之后。但对单文件 type（roadmap/capabilities/ops/marketing）立即返回 null。

#### 执行过程

1. **查表**：根据 type 判断是否需要 name。若不需要 → 返回 `null`，step 结束。
2. **name_hint 处理**：非空 → 规范化为 kebab-case → 返回。
3. **从对话推断 slug**：
   - 寻找**显式名词短语**（如 `recall pipeline`、`cache layer`、`upload flow`）。
   - 找到 → 规范化 → 返回。
   - 没找到 → 进入用户询问。
4. **询问用户**：`AI问：这个 <type> 的主题/需求名是什么？（kebab-case）`。
5. **用户答 invalid**（见规范化失败或匹配模糊黑名单）→ 再问 1 次；仍 invalid → abort。

#### Kebab-case 规范化（单一规则）

```
lowercase
→ 替换 [\s._/] 为 -
→ 剔除 [a-z0-9-] 外字符
→ 合并重复 -
→ 去首尾 -
→ 空字符串 invalid
```

**示例**：
- `Know Learn` → `know-learn`
- `recall_pipeline.v2` → `recall-pipeline-v2`
- `"Hello World!"` → `hello-world`
- `"   "` → invalid

#### 用户交互 prompt

**询问**：

```
这个 <type> 的主题是什么？（kebab-case，例如 recall-pipeline）
```

**Invalid fallback**：

```
"<reply>" 无法用作 slug。请直接给出一个 kebab-case 名称（只能含 a-z 0-9 和 -）。
```

#### 硬规则

1. Type 不需 name 时 **必须**返回 `null`；反之**不允许**返回 null。
2. `name_hint` 规范化后直用，不得追问。
3. 对话推断必须是显式短语，不得从无关提及"构造"slug。
4. Invalid 处理遵循统一失败模式（1 次 fallback → abort）。

#### 成功示例

**场景 A：单文件类型**
```
输入:  { type: "roadmap" }
执行:  查表 → roadmap 不需要 name
输出:  { name: null }
```

**场景 B：name_hint 规范化**
```
输入:  { type: "arch", name_hint: "Know Learn" }
执行:  规范化 → "know-learn"
输出:  { name: "know-learn" }
```

**场景 C：从对话推断**
```
输入:  { type: "tech", conversation: "我们要做 recall pipeline 升级" }
执行:  识别短语 "recall pipeline" → 规范化 → "recall-pipeline"
输出:  { name: "recall-pipeline" }
```

**场景 D：问用户**
```
输入:  { type: "arch", conversation: "零散", user_replies: ["storage-layer"] }
执行:  无显式短语 → 问用户 → "storage-layer" 合法
输出:  { name: "storage-layer" }
```

#### 失败示例

**场景 E：反复 invalid**
```
输入:  { user_replies: ["不知道", "随便"] }
执行:  第 1 次 invalid → fallback → 第 2 次仍 invalid → abort
输出:  { outcome: "abort" }
```

#### 测试覆盖

| tc id | 覆盖点 |
|---|---|
| tc01-no-name-needed | roadmap → null |
| tc02-hint-direct | hint 直用 |
| tc03-hint-normalize | hint 规范化 |
| tc04-infer-from-conv | 对话推断 |
| tc05-ask-when-unclear | 问用户 |
| tc06-invalid-then-valid | fallback 后合法 |
| tc07-persistent-invalid-abort | 反复 invalid → abort |

`tests/write/name-inference.jsonl` 共 7 条。

---

### Step 1c — Mode Inference（模式推断）

#### 目标

决定本次写入是新建（`create`）还是更新（`update`）。

#### 输入

```jsonc
{
  "type": "arch",
  "name": "cache",
  "path": "docs/arch/cache.md",     // 由 type + name 按 1.4 规则拼出
  "user_replies": []
}
```

#### 输出

```jsonc
{ "mode": "create" }  // 或 "update"
```

或 `{ "outcome": "redirect-1b" }`（用户选 Rename，回 Step 1b）
或 `{ "outcome": "abort" }`。

#### 触发条件

路径已由 1a/1b 拼出后触发。

#### 执行过程

1. **文件存在性检查**：对 `{path}` 做 `test -f`。
2. **分支 a — 文件不存在**：`mode = create`，step 结束。
3. **分支 b — 文件存在 + type=roadmap**：`mode = update`（roadmap 始终是单文件，新版本作为 section 追加）。
4. **分支 c — 文件存在 + 其他 type**：**强制 STOP:choose**：
   - A) 更新已有文件 → `mode = update`
   - B) 换个 name → 返回 `redirect-1b`（上游重入 1b 拿新 name）
   - C) 取消 → `abort`

#### 用户交互 prompt

```
[write] 文件已存在: {path}
  A) 更新已有文件（Update mode）
  B) 换个 name 新建
  C) 取消

请选择 (A/B/C):
```

#### 硬规则

1. **永不静默覆盖**已有文件。分支 c 强制触发选择。
2. Roadmap 的"新版本" = update，不是 create。
3. 用户选 B → 必须返回 `redirect-1b`，由上游重入 name 推断，不在本 step 做。

#### 成功示例

**场景 A：新文件**
```
输入:  { path: "docs/arch/new.md", file_exists: false }
输出:  { mode: "create" }
```

**场景 B：roadmap 自动 update**
```
输入:  { type: "roadmap", path: "docs/roadmap.md", file_exists: true }
输出:  { mode: "update" }
```

**场景 C：用户选 Update**
```
输入:  { path: "docs/arch/cache.md", file_exists: true, user_replies: ["A"] }
输出:  { mode: "update" }
```

**场景 D：用户选 Rename**
```
输入:  { path: "docs/arch/cache.md", file_exists: true, user_replies: ["B"] }
输出:  { outcome: "redirect-1b" }
```

**场景 E：用户选 Cancel**
```
输入:  { path: "docs/arch/cache.md", file_exists: true, user_replies: ["C"] }
输出:  { outcome: "abort" }
```

#### 测试覆盖

`tests/write/mode-inference.jsonl` 共 5 条，覆盖所有分支。

---

### Step 1d — Parent Inference（父级推断）

#### 目标

找到本文档的父文档路径（若有），供 Step 6 Progress Propagation 使用。

#### 输入

```jsonc
{
  "type": "tech",
  "name": "upload",
  "roadmap_exists": true,
  "prd_exists": false,
  "user_replies": []
}
```

#### 输出

```jsonc
{ "parent_path": "docs/requirements/upload/prd.md" }
```

或 `{ "parent_path": null }`（无父 / 用户选跳过）
或 `{ "outcome": "redirect-prd" }`（用户选先建 PRD）。

#### 触发条件

所有 type 都触发，但 5 个子规则对无父类型瞬间返回 null。

#### 执行过程

1. **查父级映射表**：
   - `prd → roadmap (docs/roadmap.md)`
   - `tech → prd (docs/requirements/<name>/prd.md)`
   - 其他 → 无父
2. **Type 无父** → 返回 `{ parent_path: null }`。
3. **Type 有父且父文件存在** → 返回父路径。
4. **prd 无 roadmap**：输出 `[write] roadmap 不存在，继续但无法 propagate。`，返回 `{ parent_path: null, note: "absence-noted" }`。
5. **tech 无 prd**：**STOP:choose**：
   - A) 不带 parent 继续 → `{ parent_path: null }`
   - B) 先建 PRD → `{ outcome: "redirect-prd" }`
6. **prd 有 roadmap 但里程碑归属模糊** → 问用户里程碑编号（M1/M2/...）。

#### 用户交互 prompt

**Tech 无 PRD**：

```
[write] 未找到 parent PRD: docs/requirements/{name}/prd.md
  A) 不带 parent 继续（Progress 不会反馈给 PRD）
  B) 先建 PRD
```

**PRD 里程碑模糊**：

```
[write] 检测到 roadmap 有多个里程碑，请问这个 PRD 属于哪个？（M1 / M2 / ...）
```

#### 硬规则

1. Parent 缺失永不静默；`note: "absence-noted"` 必须输出。
2. 此 step 不创建父文档，只返回 redirect 信号。
3. `abort` 不在此 step 产生；redirect 由上游处理。

#### 成功示例

**场景 A：无父**
```
输入:  { type: "arch" }
输出:  { parent_path: null }
```

**场景 B：prd + roadmap 存在**
```
输入:  { type: "prd", name: "upload", roadmap_exists: true }
输出:  { parent_path: "docs/roadmap.md" }
```

**场景 C：tech 无 prd 选 continue**
```
输入:  { type: "tech", name: "upload", prd_exists: false, user_replies: ["A"] }
输出:  { parent_path: null }
```

**场景 D：tech 无 prd 选 redirect**
```
输入:  { type: "tech", name: "upload", prd_exists: false, user_replies: ["B"] }
输出:  { outcome: "redirect-prd" }
```

#### 测试覆盖

`tests/write/parent-inference.jsonl` 共 5 条。

---

### Step 1.5 — Sufficiency Gate（充分性门禁）

#### 目标

对高风险 type 校验：**对话里有没有足够内容**足以写出一份合格的文档？不够就让用户补充或降级。

#### 输入

```jsonc
{
  "type": "tech",
  "conversation": "...",
  "user_replies": []
}
```

#### 输出

```jsonc
{
  "verdict": "pass" | "degrade" | "reject",
  "violations": [
    { "question": "Q1", "reason": "未提及具体存储引擎" },
    ...
  ]
}
```

或 `{ "user_action": "supplement" | "degrade-to-<type>" | "abort" }`。

#### 触发条件

仅对高风险 type 触发：`prd / tech / arch / schema / decision / ui`。其他类型瞬间 pass。

#### 执行过程

1. **Gate 判断**：type 是否高风险？否 → `pass`，step 结束。
2. **加载问题清单**：`cat workflows/templates/sufficiency-gate.md` 中对应 type 的问题组（每 type 约 5-8 题）。
3. **逐题回答**：
   - 用对话里的原话作答。
   - 没原话可引 → 明确写 "not present in conversation"。
   - **禁止用推理/猜测回答**。
4. **聚合**：
   - 全 yes → `pass`。
   - 部分 yes 部分 no → `degrade`。
   - 全 no → `reject`。
5. **非 pass 时 STOP:choose**：
   - A) 补充对话 → 返回让用户继续对话，然后重跑本 step。
   - B) 降级到 `<suggested_type>` → 返回 `redirect-step1`，携带新 type。
   - C) 取消 → abort。

#### 降级建议表

| 当前 type | 建议降级到 |
|---|---|
| prd | capabilities（保留"有哪些能力"的价值） |
| tech | decision（只记关键选型） |
| arch | decision（只记关键决策） |
| schema | decision |
| decision | （已最低，无降级；用户必须补充或 cancel） |
| ui | capabilities |

#### 用户交互 prompt

```
[write] Sufficiency check: {type}
  ✅ Q1: {问题} — {对话原话引用}
  ❌ Q2: {问题} — 对话中未提及
  ❌ Q3: {问题} — 对话中未提及
  ...
Verdict: {pass | degrade | reject}

选择下一步:
  A) 补充对话后重跑检查
  B) 降级为 {suggested_type}
  C) 取消
```

#### 硬规则

1. 每题必须用**对话原话或明确"not present"**回答，不得用推理。
2. 降级目标固定为当前 type 的最低风险邻居（见表）。
3. 用户选 B → 必须重入 Step 1，重推 name/mode/parent（因 type 变了）。

#### 成功示例

**场景 A：非高风险跳过**
```
输入:  { type: "capabilities", conversation: "功能清单草稿" }
输出:  { verdict: "pass" }
```

**场景 B：全 yes**
```
输入:  { type: "prd", conversation: "含完整用户故事+验收标准+范围+边界" }
输出:  { verdict: "pass", violations: [] }
```

**场景 C：部分 → 降级**
```
输入:  { type: "tech", conversation: "仅聊实现方向", user_replies: ["B"] }
输出:  { verdict: "degrade", user_action: "degrade-to-decision" }
```

**场景 D：全 no → 取消**
```
输入:  { type: "arch", conversation: "几乎无内容", user_replies: ["C"] }
输出:  { verdict: "reject", user_action: "abort" }
```

#### 测试覆盖

`tests/write/sufficiency.jsonl` 共 5 条。

---

### Step 2 — Confirm

#### 目标

把 Step 1 推断出的全部参数（type / name / mode / path / parent）一次性展示给用户，让他确认或编辑。

#### 输入

```jsonc
{
  "params": {
    "type": "arch",
    "name": "cache",
    "mode": "create",
    "path": "docs/arch/cache.md",
    "parent": null
  },
  "user_replies": []
}
```

#### 输出

```jsonc
{
  "outcome": "proceed-step3" |       // 用户确认
             "re-enter-step1a" |     // 改 type
             "re-enter-step1c" |     // 改 name
             "sequential-steps-3-6"  // 用户选 both（双 type）
}
```

#### 触发条件

Step 1 的 4 个子步 + 1.5 都跑完、有完整参数集后触发。**必触发**，不得跳过。

#### 执行过程

1. **渲染参数块**：按固定模板展示所有字段。
2. **等待 `STOP:confirm`**。
3. **用户答 `yes`** → `proceed-step3`。
4. **用户答 `change <field>=<value>`**：
   - 按依赖链处理（`type → name → mode → parent`）：改上游触发下游重推。
5. **用户答 `both`**（前提：Step 1 推了多候选）→ 按候选顺序串行跑 Steps 3-6。

#### 依赖链重推规则

| 改的字段 | 重推哪些 |
|---|---|
| type | name + mode + parent 全重推 |
| name | mode + parent 重推 |
| mode | 无需重推 |
| path | 无需重推（直接覆盖） |
| parent | 无需重推 |

#### 用户交互 prompt

**主 prompt**：

```
[write] Inferred from conversation
  Type:   arch
  Name:   cache
  Path:   docs/arch/cache.md
  Mode:   create
  Parent: —

Correct? (yes / change <field>=<value>)
```

**多候选场景**：

```
[write] 对话包含 2 种候选 type：
  1) arch   (docs/arch/cache.md)
  2) decision (docs/decision/cache-choice.md)

选择 (1 / 2 / both):
```

#### 硬规则

1. **必 STOP:confirm**，即使推断高置信。
2. 改字段只重推下游，不做全量。
3. `both` 只在 Step 1 确实产生了 2 候选时才允许。

#### 成功示例

**场景 A：直接确认**
```
输入:  { params: {...}, user_replies: ["yes"] }
输出:  { outcome: "proceed-step3" }
```

**场景 B：改 type**
```
输入:  { params: { type: "arch" }, user_replies: ["change type=decision"] }
输出:  { outcome: "re-enter-step1a", new_hint: "decision" }
```

#### 测试覆盖

`tests/write/confirm.jsonl` 共 4 条。

---

### Step 3 — Template Loading

#### 目标

加载 type 对应的 markdown 模板（含 section headers 和 INCLUDE/EXCLUDE 注释）。

#### 输入

```jsonc
{ "type": "arch" }
```

#### 输出

模板文本（纯 markdown）。

#### 触发条件

Step 2 确认后触发。

#### 执行过程

1. **执行 `cat workflows/templates/<type>.md`**。
2. **文件存在** → 返回内容。
3. **文件不存在** → 生成 fallback 骨架：

```markdown
# {Title}

## Overview

## Details

## Open Questions
```

#### 硬规则

1. 模板文件是文档结构 single source of truth，此 step 不修改它。
2. Fallback 只在模板**真正缺失**时用；不得替代"看起来不完整"的已有模板。

#### 成功示例

```
输入:  { type: "arch" }
执行:  cat workflows/templates/arch.md → 成功
输出:  "# {Title}\n\n## 1. 定位与边界\n..."
```

此 step 无独立测试（过于机械，靠下游 step 的测试间接覆盖）。

---

### Step 4 — Fill（填充）

#### 目标

把对话内容 + triggers 填入模板 section，产出完整 markdown。

#### 输入

```jsonc
{
  "template": "<模板文本>",
  "conversation": "<对话全文>",
  "triggers": {
    "project": [...],                // 来自 docs/triggers.jsonl
    "user": [...]                    // 来自 $XDG_CONFIG_HOME/know/triggers.jsonl
  },
  "existing_doc": "<现有内容>",      // 仅 update 模式
  "mode": "create" | "update"
}
```

#### 输出

```jsonc
{
  "filled_document": "<完整 markdown>",
  "tbd_sections": ["Metrics", "Risks"]  // 标注 TBD 的 section 名
}
```

#### 触发条件

Step 3 加载模板后触发。

#### 执行过程（Create 模式）

1. **加载两 level triggers**：合并 project + user，按 scope 索引。
2. **逐 template section**：
   - 2a. 从对话里收集**相关引语**（按 section 主题匹配）。
   - 2b. 从 triggers 里找**同 scope 或关联 scope 的 trigger**。
   - 2c. 遵守 section 开头的 `<!-- INCLUDE: 必须包含 X -->` / `<!-- EXCLUDE: 不要 Y -->`。
   - 2d. 产出结构化散文（不用口语）；代码/表格**从对话原文逐字复制**（不改写）。
   - 2e. 证据不足 → 写 `TBD — {具体缺什么}`（不能只写 `TBD`）。
3. **歧义处理**：对话里两个人说法不一，或存在未决讨论 → 前缀 `Open question:`。
4. **交叉引用**：用项目根相对路径（`docs/arch/recall.md`），不用绝对路径。
5. **语言一致**：跟随用户语言（对话中文就中文，英文就英文）。
6. **应用 Progress 字段**（见下表）。

#### 执行过程（Update 模式）

1. **读现有文档全文**。
2. **扫 conversation 找涉及的 section**（不是随便匹配，要有明确 topic）。
3. **逐 section 处理**：
   - 对话涉及到的 → 重新生成（用 create-mode 规则）。
   - 未涉及到的 → **byte-identical 保留**（一个字都不改）。
4. **模板里新增 section**：若文档里缺，补上（内容或 TBD）。
5. **路径修补**：只在涉及的 section 内修断链相对路径。
6. **无 section 被讨论** → `STOP:choose`：A) 新增 section B) 取消。

#### Triggers 使用规则

| Tag | 使用方式 | 示例 |
|---|---|---|
| `insight` | 按 summary 引用，不复制原文 | "根据我们的设计决策，选用 JSONL 而非 SQLite..." |
| `rule` | 同 scope 的章节**必须遵守**；违反则调整内容 | 若 rule 说"必须验签"，PRD 描述 API 时必须体现验签步骤 |
| `trap` | 进入 `## Open Questions` 或相关"风险"小节 | "风险：长连接闭包导致内存泄漏（历史已踩坑）" |

#### Progress 字段（Create 模式自动填）

| Type | 字段 | 规则 |
|---|---|---|
| roadmap | 里程碑.进度 | 统计链接到该里程碑的 PRD。格式 `完成数/总数` |
| roadmap | 里程碑.需求 | 链接每条 PRD；空则 `—` |
| roadmap | 里程碑编号 | 每版本从 M1 重新开始 |
| prd | §4 方案.任务表 | 每条 tech doc 一行；进度 `完成数/总数` |
| tech | §4 迭代记录 | 种初始条目，含当日日期 + sprint 摘要 |

#### Update 规则 by type

| Type | Section | 规则 |
|---|---|---|
| tech | §2 方案 | 随理解深化覆盖 |
| tech | §3 关键决策 | 追加新行；**绝不重写**已有行 |
| tech | §4 迭代记录 | **前置**今天条目；绝不覆盖历史 |

#### H1 标题规则

| Scope | Title 格式 |
|---|---|
| Project single | `{项目名} {文档类型}` |
| Project directory | `{主题名} {文档类型}` |
| Requirement (prd) | `{用户入口}`（不含 "PRD" 字样） |
| Requirement (tech) | `{需求名} 技术方案` |

#### 硬规则

1. **禁止编造**：证据缺失必须 `TBD — {具体}` 或 `Open question:`。
2. Create 模式：每个模板 section **恰好填一次**。
3. Update 模式：**只动对话涉及的 section**。
4. Triggers 只引用不复制（防止原文漂移时文档失真）。
5. 代码/表格逐字复制（防止 AI 自作主张改）。

#### 成功示例

**场景 A：create 全满**
```
输入:  template=[Overview, Design, Risks], 
       conversation_covers=[Overview, Design, Risks],
       triggers_in_scope=[]
执行:  每 section 都有充足材料
输出:  filled_sections=[Overview, Design, Risks], tbd_count=0
```

**场景 B：create 部分 TBD**
```
输入:  template=[Overview, Design, Risks, Metrics],
       conversation_covers=[Overview, Design]
执行:  Risks/Metrics 无材料 → 标 TBD
输出:  filled_sections=[Overview, Design], 
       tbd_sections=[Risks, Metrics]
```

**场景 C：引用 trigger**
```
输入:  template=[Security],
       conversation_covers=[Security],
       triggers=[{tag:"rule", scope:"Auth", summary:"JWT 必须校验签名"}]
执行:  Security section 提到认证 → 引用 trigger summary
输出:  "## Security\n按规范，JWT 必须校验签名..."
```

**场景 D：update 只动涉及**
```
输入:  existing_sections=[A, B, C], 
       conversation_discusses=[B]
执行:  B 重写，A/C byte-identical
输出:  regenerated=[B], verbatim=[A, C]
```

#### 测试覆盖

`tests/write/fill.jsonl` 共 5 条。

---

### Step 5 — Write（预览 + 落盘）

#### 目标

给用户看一眼最终文档，等确认后落盘。

#### 输入

```jsonc
{
  "filled_document": "...",
  "path": "docs/arch/cache.md",
  "mode": "create" | "update",
  "tbd_sections": ["Metrics"],
  "changed_sections": [...]            // 仅 update
}
```

#### 输出

- 文件写入磁盘
- 屏幕 `[written] {path}` 或 `[written] {path} (updated {n} sections)`
- 或 `{ outcome: "abort" }`

#### 触发条件

Step 4 Fill 完成、准备落盘时触发。

#### 执行过程

1. **预览**：
   - `create` → 展示全文。
   - `update` → 仅展示变动 section 的 before/after diff。
2. **TBD 阈值检查**：`tbd_sections.length > 3` → 额外插入警告行：
   ```
   [write] {n} sections marked TBD: {list}. Still write?
   ```
3. **等 STOP:confirm**：
   - `yes` → 落盘。
   - `edit <section>` → 调整该 section 后回 Step 4 重新 fill → 回到预览。
   - `no` → abort。
4. **落盘**：
   - `mkdir -p $(dirname path)`。
   - `create` → Write tool。
   - `update` → Edit tool，逐 section 替换。
   - Tech 文档额外：在 `§4 迭代记录` 顶部 prepend 今天的条目。
5. **输出**：`[written] {path}` 或 `[written] {path} (updated {n} sections)`。

#### 用户交互 prompt

**Create 预览**：

```
[write] Preview: docs/arch/cache.md

# Cache 架构

## 1. 定位与边界
...

Write? (yes / edit <section> / no)
```

**Update 预览（diff）**：

```
[write] Update preview: docs/roadmap.md

## 2. 版本规划
- v1 做 A/B/C
+ v1 做 A/B/C；新增 D

Write? (yes / edit <section> / no)
```

**TBD 警告**：

```
[write] 5 sections marked TBD: Overview, Metrics, Risks, Deploy, Monitoring. Still write?
```

#### 硬规则

1. 预览强制，不得静默落盘。
2. TBD > 3 → 必须插警告，强制二次确认。
3. `edit` 循环回 Step 4，直到 `yes` 或 `no`。
4. Create 撞已有文件在 Step 1c 已处理，本 step 到时 mode 已定。

#### 成功示例

**场景 A：create 确认**
```
输入:  { mode: "create", tbd_count: 0, user_replies: ["yes"] }
执行:  预览 → 确认 → Write tool
输出:  "[written] docs/arch/cache.md"
```

**场景 B：TBD 阈值触发**
```
输入:  { mode: "create", tbd_count: 5, user_replies: ["yes"] }
执行:  预览 + TBD 警告 → 用户再确认 → 落盘
输出:  "[written] ... (5 sections TBD)"
```

**场景 C：edit 循环**
```
输入:  { user_replies: ["edit Overview", "yes"] }
执行:  预览 → edit Overview → 回 Step 4 → 重预览 → 确认
输出:  "[written] ..."
```

#### 测试覆盖

`tests/write/write-op.jsonl` 共 5 条。

---

### Step 5.5 — Validate（校验）

#### 目标

文档落盘后跑 checklist 校验结构、语言约束、数据置信度、完整性。

#### 输入

```jsonc
{
  "path": "docs/arch/cache.md",
  "type": "arch",
  "checklist_exists": true,
  "round": 0
}
```

#### 输出

```jsonc
{
  "verdict": "pass" | "fail" | "force-through",
  "violations": [...],
  "unresolved_count": 0
}
```

#### 触发条件

`templates/<type>-checklist.md` 存在才触发；否则 silent skip。

#### 执行过程

1. **Gate**：checklist 文件是否存在？否 → skip。
2. **加载 checklist**：`cat workflows/templates/<type>-checklist.md`。
3. **逐项检查**：
   - **Structure** — 所有必需 section/field 都在？无多余的字段？
   - **Language** — 字段符合其 `✅/❌` 模式约束？（某些字段要求中文/英文/固定模板）
   - **Data** — 每个数值都有 source？（见下铁律）
   - **Completeness** — 非可选字段是真内容，不是 `TBD` 或占位？
   - **Diagrams** — 若 checklist 引用 `diagram-checklist.md`，加跑，检查图表触发条件对齐。
4. **聚合**：有违规 → `fail`；无 → `pass`。
5. **fail 处理**：
   - 列出违规 → 修改文档 → 回 Step 5 重预览。
   - 计数 round。
6. **Round 上限**：`round ≥ 3` → 第 4 轮强制 `force-through`，输出 `[validate] forced through, {n} checks unresolved`。

#### Data confidence 铁律（核心防编造）

每个数值（数字/百分比/时间）必须 cite 来源：

| Source | 输出形式 |
|---|---|
| 实测 | `{value} + {citation}`（如 "95%（2026-04-23 基准测试）"） |
| 估算 | `{value} + 估算 + {basis}`（如 "50ms 估算（按 p95 网络延迟推算）"） |
| 目标 | `{value} + 目标值，待验证`（如 "80% 目标值，待验证"） |
| 无数据 | `无数据（{reason}）`（如 "无数据（未实施）"） |

**精确数字无任何 source → 必 fail**，不可豁免。

#### 用户交互 prompt

**校验输出**：

```
[validate] arch checklist: 4/5 passed
  ✅ Structure: all required sections present
  ✅ Language: 中文内容符合约束
  ❌ Data: "命中率 95%" 缺 source — 必须加 "实测/估算/目标"
  ✅ Completeness: no TBD in required fields
  ✅ Diagrams: not required

修复后重预览？(yes / cancel)
```

**Force-through**：

```
[validate] forced through, 1 checks unresolved
(Data: "命中率 95%" 仍缺 source)
```

#### 硬规则

1. Checklist 缺失 = skip，不是"0 check 全过"。
2. Round ≤ 3；超限 force-through 且标注未决数。
3. Data confidence **不可商量**：编造数字即使其他全过也 fail。

#### 成功示例

**场景 A：无 checklist 跳过**
```
输入:  { type: "capabilities", checklist_exists: false }
输出:  { verdict: "skip" }
```

**场景 B：一次通过**
```
输入:  { type: "tech", checklist_exists: true, doc_issues: [] }
输出:  { verdict: "pass" }
```

**场景 C：编造数字失败**
```
输入:  { type: "prd", doc_issues: ["uncited_number:95%"] }
执行:  Data check fail → 要求修复
输出:  { verdict: "fail", violations: ["data confidence"] }
```

**场景 D：3 轮内修复成功**
```
输入:  { round: 2, doc_issues: ["structure_missing"] }
执行:  修复 → pass
输出:  { verdict: "pass", rounds_used: 2 }
```

**场景 E：超 3 轮强制**
```
输入:  { round: 3, doc_issues: ["persistent"] }
执行:  force-through
输出:  { verdict: "force-through", unresolved_count: 1 }
```

#### 测试覆盖

`tests/write/validate.jsonl` 共 5 条。

---

### Step 6 — Progress Propagation（进度反馈）

#### 目标

把子文档的状态更新到父文档的进度字段。

#### 输入

```jsonc
{
  "type": "tech",
  "path": "docs/requirements/upload/tech.md",
  "parent_path": "docs/requirements/upload/prd.md",
  "parent_exists": true
}
```

#### 输出

- 父文档被 Edit（只动进度字段）
- `[progress] {parent_path} updated ({value})` 
- 或 silent skip

#### 触发条件

Step 5.5 完成后触发。

#### 执行过程

1. **查父级**：type 无父 → skip。
2. **父文件存在性**：不存在 → skip（可能前置 step 1d 用户选了不创建）。
3. **Edit tool 更新进度字段**：
   - `tech → PRD`：定位 `§4 方案.任务表`，找到对应行（行首匹配 `<tech_name>`），更新进度列。
   - `prd → roadmap`：定位对应里程碑行，更新 `完成PRD数/总PRD数`。
4. **输出**：`[progress] {parent_path} updated ({new_value})`。

#### 用户交互 prompt

无。本 step 完全自动，不需用户介入。

#### 硬规则

1. 只改进度字段，不动相邻内容。
2. Parent 不存在 → silent skip，**永不在此 step 创建 parent**。
3. Edit 失败（权限 / 文件损坏）→ `[progress] skip: {reason}`，不阻塞主流程。

#### 成功示例

**场景 A：无父跳过**
```
输入:  { type: "arch", parent_path: null }
输出:  silent skip
```

**场景 B：tech → PRD**
```
输入:  { type: "tech", parent: "docs/requirements/upload/prd.md", parent_exists: true }
执行:  Edit PRD §4 方案任务表，"upload" 行进度 0/1 → 1/1
输出:  "[progress] docs/requirements/upload/prd.md updated (1/1)"
```

**场景 C：prd → roadmap**
```
输入:  { type: "prd", parent: "docs/roadmap.md", parent_exists: true }
执行:  Edit roadmap M2 里程碑进度 1/3 → 2/3
输出:  "[progress] docs/roadmap.md updated (2/3)"
```

**场景 D：parent 缺失 silent skip**
```
输入:  { type: "tech", parent_exists: false }
输出:  silent skip
```

#### 测试覆盖

`tests/write/progress.jsonl` 共 4 条。

---

## 1.6 write 关键硬规则总汇

1. 所有字符串 lowercase 后匹配。
2. 无效输入 → 1 次 full-list fallback → 仍无效 → `abort`（不猜）。
3. 撞名必 STOP:choose，不自动切 update。
4. Create 模式每 section 填一次；Update 模式只动涉及 section。
5. 数字无来源必 fail。
6. Triggers 只引用不复制。
7. Validate 最多 3 轮修复，超限 force-through。
8. 父文档不存在在本 pipeline 里永远不创建。

## 1.7 write 测试 Fixtures 总表

| 文件 | Step | 条数 |
|---|---|---|
| `tests/write/type-inference.jsonl` | 1a | 7 |
| `tests/write/name-inference.jsonl` | 1b | 7 |
| `tests/write/mode-inference.jsonl` | 1c | 5 |
| `tests/write/parent-inference.jsonl` | 1d | 5 |
| `tests/write/sufficiency.jsonl` | 1.5 | 5 |
| `tests/write/confirm.jsonl` | 2 | 4 |
| `tests/write/fill.jsonl` | 4 | 5 |
| `tests/write/write-op.jsonl` | 5 | 5 |
| `tests/write/validate.jsonl` | 5.5 | 5 |
| `tests/write/progress.jsonl` | 6 | 4 |

共 52 条。

---

# PIPELINE 2 — learn

## 2.1 目标

把会话中的 tacit knowledge 沉淀为 triggers。原则：**宁缺勿滥**——只沉淀代码表面看不出来的"为什么 / 踩过的坑 / 必须遵守的约束"。

## 2.2 输入

| 字段 | 来源 | 必需 |
|---|---|---|
| `conversation` | 当前会话 | 是（`/know learn` 扫全对话） |
| `claim` | CLI: `/know learn "<claim>"` | 否（传了就当单 candidate） |
| 现有 triggers | 两 level triggers.jsonl | 是（conflict 用） |
| 现有 keywords 词表 | `know-ctl keywords` | 是（Generate 优先复用） |

## 2.3 输出

| 产物 | 目的 |
|---|---|
| 追加行到 triggers.jsonl | 本体 |
| `created` event → events.jsonl | 观测 + M3 归因 |
| `[persisted]` / `[skipped]` / `[conflict]` | 屏幕反馈 |

## 2.4 Entry Schema（8 字段）

```jsonc
{
  "tag":     "rule | insight | trap",
  "scope":   "Auth.session",
  "summary": "session 过期必须刷新 — 避免静默登出",  // ≤80
  "strict":  true | false | null,
  "ref":     "docs/decision/auth.md#refresh" | null,
  "keywords": ["authentication","session-refresh"],  // 5-8 kebab
  "source":  "learn",
  "created": "2026-04-23",
  "updated": "2026-04-23"
}
```

**Level**（靠文件位置表达，不在 JSON 里）：
- `project` → `docs/triggers.jsonl`（git 跟踪）
- `user` → `$XDG_CONFIG_HOME/know/triggers.jsonl`（跨项目方法论）

---

## 2.5 详细流程

---

### Step 1 — Collect（收集）

#### 目标

扫对话，产出 **已拆分、已去噪** 的 trigger 候选（≤ 5 条）。合并了原 Detect + Extract + Filter 三步。

#### 输入

```jsonc
{
  "conversation": "<对话全文>",
  "claim": null | "<explicit claim>"
}
```

#### 输出

```jsonc
{
  "candidates": [
    { "summary_draft": "session 过期必须刷新", "likely_tag": "rule" },
    { "summary_draft": "benchmark 设双策略对照", "likely_tag": "insight" }
  ]
}
```

或 `{ "candidates": [] }`（无可沉淀）。

#### 触发条件

`/know learn` 或 `/know learn "<claim>"`。

#### 执行过程

1. **claim 快捷路径**：若 `claim` 非空 → 直接作为单 candidate，跳过扫描，`likely_tag` 默认 `insight`。
2. **扫对话找信号**：按 signal types 表扫。每条信号必须**同时通过质量 4 问**才算候选。
3. **拆分**：
   - 一个结论 + 直接原因 = 1 条。
   - 两个独立事实 = 2 条。
   - 不确定 → 不拆（宁少勿多）。
4. **截取**：候选数 > 5 → 按优先级取前 5：
   - 用户显式纠正 > 收敛结论 > 易再发生 > 项目相关。
5. **展示候选 + STOP:choose**。

#### 质量 4 问（每候选自查，任一 yes 即 drop）

1. 无明确结论或规则？
2. 是一次性/短期状态？
3. 能否从代码表面直接看出？
4. 没有"为什么 / 踩过坑 / 约束"的长期价值？

#### Signal types（帮扫描分类）

| Signal | 典型语言 | Likely tag |
|---|---|---|
| 用户纠错 | "不是 / 应该 / 错了 / must / should" | rule / insight |
| 技术选型 | "选 X 不选 Y / 决定用 / tradeoff" | insight |
| 根因 | "根因 / 问题是 / turns out" | trap |
| 业务逻辑 | "流程是 / 机制是 / algorithm" | insight |
| 硬约束 | "必须 / 不能 / never / forbidden" | rule |
| 外部集成 | "API / webhook / SDK 约束" | insight |

#### 用户交互 prompt

```
[learn] step: collect
会话价值摘要：本次对话围绕 {主题} 进行了 {活动}。
关键产出：
  - {产出1}
  - {产出2}

检测到 {N} 条可持久化知识：
  1. [{likely_tag}] {summary_draft}
  2. [{likely_tag}] {summary_draft}

持久化？(all / 编号列表 / skip)
```

#### 硬规则

1. 最多 5 条候选。
2. 每候选必须过 4 问全部检查。
3. 拆分"不确定"时不拆。

#### 成功示例

**场景 A：无信号**
```
输入:  { conversation: "随便聊天" }
输出:  { candidates: [] } + "[learn] No high-value knowledge detected."
```

**场景 B：claim 模式**
```
输入:  { claim: "JWT 必须校验签名" }
输出:  { candidates: [{ summary_draft: "JWT 必须校验签名", likely_tag: "rule" }] }
```

**场景 C：单纠错**
```
输入:  { conversation: "用户: 你忘了 webhook 必须先验签再解 body" }
执行:  signal=用户纠错 → 过 4 问 → 1 条候选
输出:  { candidates: [{ ..., likely_tag: "rule" }] }
```

**场景 D：>5 截取**
```
输入:  conversation 含 7 条信号
执行:  按优先级截前 5
输出:  { candidates: [...5 items...] }
```

**场景 E：代码表面可读出 drop**
```
输入:  { conversation: "讨论 let x = 1 这种代码一眼可读内容" }
执行:  4 问第 3 题 yes → drop
输出:  { candidates: [] }
```

#### 测试覆盖

`tests/learn/collect.jsonl` 共 5 条。

---

### Step 2 — Generate（字段化）

#### 目标

把每条 candidate 变成含 7 字段的正式 entry（tag / scope / strict / summary / ref / keywords / level）。

#### 输入

```jsonc
{
  "candidate": {
    "summary_draft": "webhook 必须先验签再解 body",
    "likely_tag": "rule"
  }
}
```

#### 输出

```jsonc
{
  "entry": {
    "tag": "rule",
    "scope": "Payment.webhook",
    "strict": true,
    "summary": "webhook 必须先验签再解 body — 防注入",
    "ref": null,
    "keywords": ["webhook","signature-verification","security"],
    "level": "project"
  }
}
```

#### 触发条件

用户选中的每条 candidate 依次跑。

#### 执行过程（7 子步序）

**2a — Tag**
- 优先级 `trap > rule > insight`。
- ≥2 等价 → STOP:choose 问用户。

**2b — Scope**
- 优先级（从高到低）：
  1. 显式文件路径（`src/auth/session.ts` → `Auth.session`）。
  2. 模块 / 子系统名（`Auth`、`Payment`）。
  3. 反复出现的功能域（`Search.reranker`）。
  4. 广稳定边界（`Infra`）。
  5. `"project"`（最后手段）。

**2c — Strict**
- 仅 `tag=rule` 适用。
- `true`：违反会导致编译失败 / 数据损坏 / 安全漏洞 / 外部 API 硬要求。
- `false`：推荐实践 / 风格约定。
- `insight`/`trap` → **必须** `null`。

**2d — Summary**
- 格式：`{结论} — {原因}`。
- ≤ 80 字符；超长去修饰 → 只留核心；仍超 → 拆成 2 条 entry。

**2e — Ref**（可选）
- 可以是 `docs/decision/x.md#anchor`、`src/auth/session.ts:42`、`https://...` 或 `null`。
- `rule + strict=true` 推荐有 ref。

**2f — Keywords**
- 5-8 个，kebab-case（`[a-z0-9-]`，长度 2-40）。
- **优先复用** `know-ctl keywords` 输出的词表。
- 示例词表：
  ```
  authentication (8)
  webhooks (5)
  signature-verification (3)
  ```

**2g — Level**
- Scope 以 `methodology.*` 开头 → `user`。
- Summary 是领域无关通用工程教训 → `user`。
- Scope 命名项目局部模块 → `project`。
- 引用项目特有文件/类/配置 → `project`。
- 模糊 → STOP:choose 问用户。

#### 用户交互 prompt

**多 tag 等价时**：

```
[learn] step: generate — tag 选择
候选 tag：[rule / trap]（都合理）
选哪个？
```

**Level 模糊时**：

```
[learn] step: generate — level 选择
Scope: {scope}
Summary: {summary}

建议 level: {suggested}
确认？(ok / project / user)
```

#### 硬规则

1. `rule + strict=null` 或 `insight/trap + strict=不为null` 必 reject。
2. `summary > 80` 必须重写。
3. Keywords 字符必须匹配 `[a-z0-9-]{2,40}`。
4. 新 keyword 加入词表是副作用；老 keyword 优先复用。

#### 成功示例

**场景 A：rule + strict=true**
```
输入:  candidate={ summary_draft: "webhook 必须先验签", likely_tag: "rule" }
执行:  tag=rule, scope=Payment.webhook, strict=true, 
      summary="webhook 必须先验签再解 body — 防注入",
      keywords=[webhook, signature-verification, security], level=project
输出:  正式 entry
```

**场景 B：insight + methodology → user**
```
输入:  candidate={ summary_draft: "benchmark 设双策略" }
执行:  scope=methodology.benchmark → level=user
输出:  entry with level=user
```

**场景 C：summary 超长重写**
```
输入:  summary_draft 120 字
执行:  去修饰 → 仍超 → 拆 2 条 entry
输出:  [entry1, entry2]
```

#### 测试覆盖

`tests/learn/generate.jsonl` 共 5 条。

---

### Step 3 — Conflict（冲突处理）

#### 目标

检查新 entry 与已有 triggers 是否重复、矛盾、或可合并。

#### 输入

```jsonc
{
  "entry": { /* 完整 entry */ },
  "existing_triggers": [...]
}
```

#### 输出

```jsonc
{ "outcome": "pass-through" | "update-existing" | "merged" | "keep-both" | "skip" }
```

#### 触发条件

每条 Generate 后的 entry 都跑。

#### 执行过程

1. **Phase 1 — 关键词检索**：从 summary 抽 2-4 个关键词（按 summary 长度）。
   - ≤30 字符 → 2 个。
   - 31-60 字符 → 3 个。
   - >60 字符 → 4 个。
   - 关键词优先级：scope 模块名 > 专有名词 > 动作动词 > 跳过 generic 词。
2. **执行 search**：
   ```bash
   bash "$KNOW_CTL" search "<kw1>|<kw2>|<kw3>"
   ```
3. **零候选** → `pass-through`，step 结束。
4. **Phase 2 — 关系分类**：对每个候选 match 判：
   - `unrelated` — 不相关，跳过。
   - `merge` — 同话题，不同角度 → 建议合并。
   - `duplicate` — 同结论，不同措辞 → 建议 skip 或合并。
   - `conflict` — 互斥结论 → **必须展示**。
5. **分类依据**（单一语义相似度不够，还要考虑）：
   - scope（同 scope 更可能冲突）
   - 结论方向（同/反）
   - tag（rule vs insight 很少冲突）
   - 适用范围（项目局部 vs 全局）
   - 时间顺序（后者覆盖前者？）
6. **非 unrelated → STOP:choose**。

#### 用户交互 prompt

```
[conflict] Similar entry found:
  Existing: {existing.summary}
  New:      {new.summary}
  Relation: {duplicate | conflict | merge}

Choose:
  A) Update existing  （用新的覆盖）
  B) Keep both        （两个都保留）
  C) Merge            （合并成一条新 summary）
  D) Skip new         （丢弃新的）
```

#### 硬规则

1. `conflict` 绝不静默；必须展示让用户决定。
2. 语义相似度只定候选，分类还要考虑 5 个额外维度。
3. 空候选直接 pass-through，不要勉强匹配。

#### 成功示例

**场景 A：无冲突**
```
输入:  entry scope=Auth.session, 现有无相关
输出:  { outcome: "pass-through" }
```

**场景 B：duplicate → Update**
```
输入:  existing.summary="A", new.summary="A 同义重述", user_replies=["A"]
输出:  { outcome: "update-existing" }
```

**场景 C：merge → C**
```
输入:  existing="A 视角 1", new="A 视角 2", user_replies=["C"]
输出:  { outcome: "merged" } — 合成一条新 entry
```

**场景 D：conflict → Keep both**
```
输入:  existing="A", new="A 反向", user_replies=["B"]
输出:  { outcome: "keep-both" }
```

**场景 E：skip new**
```
输入:  duplicate 但用户选 D
输出:  { outcome: "skip" }
```

#### 测试覆盖

`tests/learn/conflict.jsonl` 共 5 条。

---

### Step 4 — Confirm

#### 目标

把最终 entry 展示给用户，接受编辑或确认。

#### 输入

```jsonc
{
  "entry": { /* 完整 entry */ },
  "user_replies": []
}
```

#### 输出

```jsonc
{ "outcome": "accepted" | "skipped" | "force-confirm-or-cancel" }
```

#### 触发条件

Conflict 解决后，每条 entry 跑一遍。

#### 执行过程

1. **展示 entry**：tag / scope / strict / summary / ref / keywords / level 全字段。
2. **等 STOP:confirm**：
   - `confirm` → `accepted`。
   - `edit <field>=<value>` → 改字段，回到展示（计数 round）。
   - `skip` → `skipped`。
   - `merge-with <existing>` → 走合并逻辑（简化：直接用老 entry 覆盖 summary）。
3. **Round 上限**：`round ≥ 3` → 强制 `A) 确认当前 B) 取消`。
4. **User-level 二次确认**：若 entry `level=user`，额外一步：
   - 列出受影响的 scope（例如 `methodology.benchmark`），提示"将跨所有项目生效"。
   - 要求 `y` / `1:project` / `cancel`。

#### 用户交互 prompt

**主展示**：

```
[learn] step: confirm
  tag:      rule
  scope:    Auth.session
  strict:   true
  summary:  session 过期必须刷新 — 避免静默登出
  ref:      docs/decision/auth.md#refresh
  keywords: [authentication, session-refresh, security]
  level:    project

确认 (confirm) / 编辑 (edit <field>=<value>) / 跳过 (skip)
```

**User-level 二次确认**：

```
[learn] 即将写入 user 级，跨所有项目生效。确认以下 {M} 条？
  1. [insight] methodology.benchmark — benchmark 双策略 …
  2. [rule]    methodology.upgrade   — 算法升级前先建观测 …

回复 "y" 确认；或 "1:project, 2:project" 降回 project；或 "cancel" 撤销。
```

#### 硬规则

1. `STOP:confirm` 必不可跳过。
2. 3 轮编辑后强制收敛。
3. User-level 二次确认必须列出**受影响 scope 名**。

#### 成功示例

**场景 A：直接确认**
```
输入:  user_replies=["confirm"]
输出:  { outcome: "accepted" }
```

**场景 B：先 edit 再 confirm**
```
输入:  user_replies=["edit scope=Auth.jwt", "confirm"]
执行:  改 scope → 回展示 → confirm
输出:  { outcome: "accepted", edit_rounds: 1 }
```

**场景 C：skip**
```
输入:  user_replies=["skip"]
输出:  { outcome: "skipped" }
```

**场景 D：3 轮强制**
```
输入:  user_replies=["edit a","edit b","edit c"]
执行:  第 3 轮后强制 → 展示 "A) 确认当前 B) 取消"
输出:  { outcome: "force-confirm-or-cancel" }
```

**场景 E：user-level 二次确认**
```
输入:  level=user, user_replies=["confirm", "y"]
输出:  { outcome: "accepted" }
```

#### 测试覆盖

`tests/learn/confirm.jsonl` 共 5 条。

---

### Step 5 — Write（落盘）

#### 目标

把 confirmed entries 写入 triggers.jsonl，emit `created` event。

#### 输入

```jsonc
{
  "entries": [
    { /* entry with level */ },
    ...
  ]
}
```

#### 输出

- triggers.jsonl 追加行
- events.jsonl `created` event
- `[persisted] <scope> :: <summary> (<level>)` 屏幕

#### 触发条件

Confirm 全部通过后触发。

#### 执行过程

1. **Decay 入口**：pipeline 入口（本 step 之前）跑一次 `bash "$KNOW_CTL" decay`（v7 no-op）。
2. **逐 entry append**：
   ```bash
   TODAY=$(date +%Y-%m-%d)
   bash "$KNOW_CTL" append --level <level> '{
     "tag":"<tag>",
     "scope":"<scope>",
     "summary":"<summary>",
     "strict":<strict_or_null>,
     "ref":<ref_or_null>,
     "keywords":<keywords_array_or_null>,
     "source":"learn",
     "created":"'"$TODAY"'",
     "updated":"'"$TODAY"'"
   }'
   ```
3. **Append 失败处理**：显式 `[error] append failed: {reason}`，不静默重试。
4. **事件记录**：append 内部自动 emit `created` event。

#### 硬规则

1. 8 字段完整才 append；partial 禁止。
2. append 失败立即报错，不静默。
3. user-level 未过二次确认 → 只 abort 那条，其他继续。

#### 成功示例

**场景 A：project 写**
```
输入:  entries=[{level:"project", tag:"rule", scope:"Auth.session", strict:true}]
执行:  append to docs/triggers.jsonl
输出:  "[persisted] Auth.session :: ... (project)"
```

**场景 B：user 写**
```
输入:  entries=[{level:"user", tag:"insight", scope:"methodology.x"}]
执行:  append to $XDG_CONFIG_HOME/know/triggers.jsonl
输出:  "[persisted] methodology.x :: ... (user)"
```

**场景 C：schema 违规**
```
输入:  entries=[{tag:"rule", strict:null}]
执行:  know-ctl append 校验 fail
输出:  "[error] append failed: rule requires strict"
```

**场景 D：空 list**
```
输入:  entries=[]
输出:  no-op, silent
```

#### 测试覆盖

`tests/learn/write.jsonl` 共 4 条。

---

## 2.6 原 9 步合并记录

| 原步骤 | 命运 | 理由 |
|---|---|---|
| 1 Detect | → **Collect** | 扫 + 拆 + 去噪一次完成 |
| 2 Extract | → **Collect** | 拆分规则简单 |
| 3 Filter | → **Collect** | 4 问预检在扫描时顺便做 |
| 4 Generate | 保留 | 核心 |
| 5 Conflict | 保留 | 核心 |
| 6 Challenge（5 题自审）| **删除** | 4 题已被质量 4 问覆盖，1 题已在 Generate |
| 7 Level | → **Generate 2g** | 作为 entry 的字段，和其他字段一起定 |
| 8 Confirm | 保留 | 唯一用户触点 |
| 9 Write | 保留 |  |

9 步 → 5 步。

## 2.7 learn 关键硬规则

1. 8 字段完整才 persist；partial 禁止。
2. rule 必须 strict ∈ {true, false}；insight/trap 必须 null。
3. summary ≤ 80，超长重写。
4. level=user 必须二次确认。
5. conflict 绝不静默。
6. 新 keywords 只在 learn 产生；recall 只复用。
7. invalid → 1 次 fallback → abort。

## 2.8 learn 测试 Fixtures 总表

| 文件 | Step | 条数 |
|---|---|---|
| `tests/learn/collect.jsonl` | 1 | 5 |
| `tests/learn/generate.jsonl` | 2 | 5 |
| `tests/learn/conflict.jsonl` | 3 | 5 |
| `tests/learn/confirm.jsonl` | 4 | 5 |
| `tests/learn/write.jsonl` | 5 | 4 |

共 24 条。

---

# PIPELINE 3 — recall

## 3.1 目标

**代码修改前**自动查询相关 triggers 并提示 AI。**提醒不阻断**。同时记录事件供 M3/M4/M5 等指标派生。

## 3.2 输入

| 字段 | 来源 | 必需 |
|---|---|---|
| 即将执行的工具调用 | Edit / Write / Bash (改文件) | 是 |
| 当前文件路径 | 工具参数 | 否（scope P1） |
| 最近 tool call 历史 | session 上下文 | 否（scope P2） |
| 当前 task 上下文 | 对话 | 是（keywords 用） |
| Triggers | 两 level triggers.jsonl | 是 |
| Keywords 词表 | `know-ctl keywords` | 是 |

## 3.3 输出

| 产物 | 目的 |
|---|---|
| `[recall]` 屏幕输出 max 3 条 | 提示 AI |
| `recall_query` event | M3/M4/M5 数据源 |
| `hit` event（采纳时）| M3 分子 |

## 3.4 触发规则

**触发**：即将 `Edit` / `Write` / `Bash`（改文件类）。

**Skip when any**：
- 两 level triggers 文件都不存在。
- 同 scope 本 session 已查过。
- 只读工具（`Read` / `Glob` / `Grep`）。

---

## 3.5 详细流程

---

### Step 1 — Infer Context（推断上下文）

#### 目标

从当前工具调用推出 `scope` + `keywords`（用作查询参数）。

#### 输入

```jsonc
{
  "tool": "Edit",
  "file": "src/auth/session.ts",
  "recent_paths": [...],            // 最近 10 次 tool call 路径
  "task": "jwt 过期刷新",           // 从对话 context 推断的任务描述
  "vocabulary": ["jwt", "auth", "cache-invalidation", ...]  // know-ctl keywords 输出
}
```

#### 输出

```jsonc
{
  "scope": "Auth.session",
  "keywords": ["jwt", "authentication", "session-management"]
}
```

#### 触发条件

每次 recall 第一步。

#### 执行过程

**Scope 推断（3 级 fallback）**：

1. **P1 — 当前文件路径 → module 记法**：
   - `src/auth/session.ts` → strip 前缀 `src`、`lib`、`app`、`tests`、`scripts`、`skills`、`docs`、`workflows`
   - 去扩展名 → 用 `.` 替 `/`
   - 结果：`Auth.session`。
   - 大小写规范：首字母大写（首段）。
2. **P2 — 最近 10 次 tool call 路径**：
   - 统计路径出现频次。
   - ≥ 2 次的路径按 P1 规则推 scope。
3. **P3 — fallback**：`"project"`。

**Keywords 推断**：

1. 跑 `bash "$KNOW_CTL" keywords` 得动态词表（含频次）。
2. AI 从词表选 3-5 个最相关的，按：
   - 当前 file 类型（`.ts` / `.sh` / `.md` 分别偏向不同词）
   - 正在改的功能
   - task context 的关键词
3. **禁止自由生成新词**（新词只在 learn 产生）。
4. 词表空或无合适词 → 用 task 中出现的 1-3 个近似词试查（可能返回空）。

#### 硬规则

1. 新 keywords 只在 learn 产生；recall 阶段只从词表选。
2. P1 scope 推断必须用 file 而非目录（若 file 为 null 直接 P2/P3）。
3. P2 的"≥2 次"必须真计数，不能拍脑袋"感觉多就用"。

#### 成功示例

**场景 A：P1 命中**
```
输入:  { tool:"Edit", file:"src/auth/session.ts", task:"jwt 过期" }
执行:  P1: src/auth/session.ts → Auth.session
      Keywords: [jwt, authentication, session-management]
输出:  { scope:"Auth.session", keywords:[jwt, authentication, session-management] }
```

**场景 B：P2 从历史**
```
输入:  { file:null, recent_paths:["src/auth/a.ts","src/auth/b.ts"], task:"auth" }
执行:  P2: /src/auth/ 出现 2 次 → scope=Auth
输出:  { scope:"Auth", keywords:[...] }
```

**场景 C：P3 fallback**
```
输入:  { tool:"Bash", file:null, recent_paths:[], task:"通用" }
执行:  P3 → scope="project"
输出:  { scope:"project", keywords:[...] }
```

**场景 D：keywords 来自词表**
```
输入:  vocabulary=[jwt, authentication, cache-invalidation], task="jwt 验证"
执行:  只选 vocabulary 里的词 → [jwt, authentication]
输出:  keywords 严格是 vocabulary 的子集
```

#### 测试覆盖

`tests/recall-pipeline/infer-context.jsonl` 共 4 条。

---

### Step 2 — Query & Log（查询 + 记录）

#### 目标

调 `know-ctl query` 拿 entries，立即 emit `recall_query` event（含 returned_scopes 以供 M3 归因）。

#### 输入

```jsonc
{
  "scope": "Auth.session",
  "keywords": ["jwt","authentication"],
  "session_queried": ["Auth.session"]   // 本 session 已查 scope 列表
}
```

#### 输出

```jsonc
{
  "entries": [                         // know-ctl 返回的 JSONL，已排序
    { /* entry + _level + _kw_hits */ },
    ...
  ],
  "logged": true
}
```

或 `{ "outcome": "skip" }`（同 scope 已查）。

#### 触发条件

Step 1 产出 scope + keywords 后。

#### 执行过程

1. **Skip 检查**：若 `scope ∈ session_queried` → skip，不查不 log。
2. **Query**：
   ```bash
   bash "$KNOW_CTL" query "{scope}" --keywords "{k1},{k2},{k3}"
   ```
   - 返回 JSONL，每行一个 entry，含 8 字段 + `_level` + `_kw_hits`。
   - 排序：`_kw_hits` 降序；平手内 `_level=project` 优先。
3. **解析**：
   - `matched = wc -l` of returned JSONL。
   - `returned_scopes = [.scope for entry in returned]`（前 N 条）。
   - `total_kw_hits = sum(.​_kw_hits)`。
4. **Log**：
   ```bash
   bash "$KNOW_CTL" recall-log "{scope}" "{matched}" \
     --keywords "{k1,k2,k3}" \
     --kw-hits "{total_kw_hits}" \
     --returned-scopes "{s1,s2,s3}"
   ```
5. **更新 session_queried**：把本次 scope 加入，防重复查。

#### 硬规则

1. 查询前必 skip 检查。
2. `returned_scopes` 参数必传（M3 归因依赖）。
3. 同 scope 本 session 查 1 次是硬上限（不是 per-tool-call）。

#### 成功示例

**场景 A：有结果**
```
输入:  scope="Auth.session", keywords=["jwt","auth"], matched=2
执行:  query → 2 entries
      recall-log 带 returned_scopes=["Auth.session","Auth.jwt"]
输出:  { entries: [...2...], logged: true }
```

**场景 B：空结果 log**
```
输入:  scope="Nothing", keywords=["x"], matched=0
执行:  query 返回空 → 仍 log (matched=0, returned_scopes=[])
输出:  { entries: [], logged: true }
```

**场景 C：同 scope 跳过**
```
输入:  scope="Auth", session_queried=["Auth"]
输出:  { outcome: "skip" }
```

#### 测试覆盖

`tests/recall-pipeline/query-log.jsonl` 共 3 条。

---

### Step 3 — Present Top 3（呈现）

#### 目标

把 query 结果渲染为可读提示，给 AI 看。

#### 输入

```jsonc
{
  "entries": [
    { "tag":"rule","strict":true,"summary":"X","_level":"project","ref":"docs/y.md" },
    { "tag":"insight","strict":null,"summary":"Y","_level":"user","ref":null },
    { "tag":"trap","strict":null,"summary":"Z","_level":"project","ref":null },
    ...
  ]
}
```

#### 输出

屏幕文本：

```
[recall] [project] ⚠ X
Why:  ...
Ref:  docs/y.md

[recall] [user] Y
Why:  ...
Ref:  —

[recall] [project] Z
Why:  ...
Ref:  —
```

或完全静默（空结果）。

#### 触发条件

Query 有结果后。

#### 执行过程

1. **截取前 3 条**（entries 已按 `_kw_hits` 排序）。
2. **零结果** → 不输出任何东西（silent）。
3. **逐条渲染**：
   - Level 前缀：`[recall] [project]` 或 `[recall] [user]`。
   - `tag=rule && strict=true` → 加 `⚠` 前缀。
   - `Why:` 一行 AI 说明"这条与当前操作的相关性"。
   - `Ref:` 字段值或 `—`（若 null）。

#### 处理强度（AI 自判，不做机械分级）

| 条件 | AI 应对 |
|---|---|
| `rule + strict=true + ⚠` | 严格遵守；若当前计划违反 → 立即调整 |
| `rule + strict=false` | 遵守，但允许有充分理由的权衡 |
| `insight` | 参考；纳入设计时考虑 |
| `trap` | 警惕；预防性检查 |

#### 硬规则

1. 最多 3 条。
2. 零结果 silent，不输出 `[recall]` 但 Query event 仍记。
3. `⚠` 仅 `rule && strict=true`，其他不加。

#### 成功示例

**场景 A：top 3 渲染**
```
输入:  entries=[rule+strict, insight, trap]
输出:
  [recall] [project] ⚠ {rule summary}
  Why: ...
  Ref: docs/y.md

  [recall] [user] {insight summary}
  Why: ...
  Ref: —

  [recall] [project] {trap summary}
  Why: ...
  Ref: —
```

**场景 B：空静默**
```
输入:  entries=[]
输出:  (no output)
```

**场景 C：>3 截断**
```
输入:  entries=5 条
输出:  只显示前 3 条
```

#### 测试覆盖

`tests/recall-pipeline/present.jsonl` 共 3 条。

---

### Step 4 — Hit on Adoption（采纳记录）

#### 目标

AI 真的采纳了某 trigger 时 emit `hit` event，作为 M3 采纳率的数据源。

#### 输入

```jsonc
{
  "ai_response_references": "quotes trigger summary" | "quotes scope name" | null,
  "behavior": "explicit citation" | "plan change" | "implicit alignment"
}
```

#### 输出

```jsonc
{ "hit_emitted": true | false }
```

#### 触发条件

AI 基于 recall 输出做后续工作时检查是否发生采纳。

#### 执行过程

1. **扫 AI 回复/动作**：检查是否满足"采纳 3 条定义"中任一。
2. **满足** → emit hit：
   ```bash
   bash "$KNOW_CTL" hit "{summary-keyword}" --level {entry._level}
   ```
   - 会自动 emit `hit` event，含 `scope` 字段（从 trigger 回填）。
3. **不满足** → 不 emit。

#### 采纳的明确定义（满足**任一**即算）

1. **AI 回复里引用** 该 trigger 的 summary / scope / ref。
2. **AI 改变原计划** 并**显式**把该 trigger 作为理由。
3. **AI 拒绝或调整某步** 并**显式**引用该 trigger。

#### 不算采纳

- 读了 recall 输出但没行动。
- 行为恰好符合某规则但**未引用它**（"顺势对齐"不算）。

#### 硬规则

1. Hit 必须由**显式引用**触发，不允许"顺势对齐"就算采纳。
2. Hit 事件含 `scope`（know-ctl 自动回填）。
3. 一个 recall 可能产生多个 hit（前 3 条都被 AI 引用）；每个独立 emit。

#### 成功示例

**场景 A：引用 summary**
```
输入:  ai_response="根据 trigger '{summary}'，我采用 ..."
执行:  定义 1 满足 → emit hit
输出:  { hit_emitted: true }
```

**场景 B：引用 scope**
```
输入:  ai_response="Auth.session 的规则要求..."
执行:  定义 1 满足（引用 scope）→ emit hit
输出:  { hit_emitted: true }
```

**场景 C：顺势对齐不触发**
```
输入:  ai_response="我这么做是因为 A 理由"，behavior="碰巧符合某 rule"
执行:  未引用 trigger → 不 emit
输出:  { hit_emitted: false }
```

**场景 D：只读不触发**
```
输入:  ai_response=null, behavior="读了 recall 但没行动"
输出:  { hit_emitted: false }
```

#### 测试覆盖

`tests/recall-pipeline/hit.jsonl` 共 4 条。

---

## 3.6 原 8 步合并记录

| 原步骤 | 命运 | 理由 |
|---|---|---|
| 1 Scope Inference | → **Infer Context** | 和 Keywords 同一认知 |
| 2 Keywords Inference | → **Infer Context** | 同上 |
| 3 Query | → **Query & Log** | 单一 CLI 调用 |
| 4 Record Query | → **Query & Log** | 同一序列 |
| 5 Rank | **删除** | know-ctl 内部做，非 AI step |
| 6 Select | → **Present Top 3** | 和 Act 同一动作 |
| 7 Act | → **Present Top 3** | 渲染 |
| 8 Hit (optional) | 升级为必要 Step 4 | 采纳条件显式化 |

8 步 → 4 步。

## 3.7 recall 关键硬规则

1. 永远提醒不阻断（无 block/warn/suggest 分级）。
2. 同 scope 本 session 不重复查。
3. 新 keywords 只在 learn 产生；recall 只复用。
4. Hit 必须由**显式引用**触发。
5. Scope 支持双向前缀（查 `Auth` 能命中 `Auth.session`；查 `Auth.session.refresh` 能命中 `Auth.session`）。
6. 黑盒调用 `know-ctl` CLI。
7. recall 失败不阻塞主流程。

## 3.8 Learn hint（附加能力）

**触发条件**（全部满足）：
- recall 本 session 已触发过。
- 用户本 session ≥ 5 条消息。
- 本 session 未提示过。

**输出**（追加在 recall 输出后，不单独中断）：

```
[know] tip: this conversation has learnable insights — run /know learn before ending
```

每 session 最多 1 次。

## 3.9 recall 指标派生

| 指标 | 定义 | 数据来源 |
|---|---|---|
| **M3 采纳率** | 30 天 recall_query（matched>0）中 1h 内有 hit.scope ∈ returned_scopes 的比例 | recall_query.returned_scopes + hit.scope |
| **M4 利用率** | 30 天内 returned_scopes 的 union / 总 trigger scope 数 | recall_query.returned_scopes |
| **M5 深度分布** | recall_query.matched 的 median / mean / bucket | recall_query.matched |
| **死 trigger 名单** | 30 天未进任何 returned_scopes 的 trigger | recall_query.returned_scopes + triggers.jsonl |

## 3.10 recall 测试 Fixtures 总表

| 文件 | Step | 条数 |
|---|---|---|
| `tests/recall-pipeline/infer-context.jsonl` | 1 | 4 |
| `tests/recall-pipeline/query-log.jsonl` | 2 | 3 |
| `tests/recall-pipeline/present.jsonl` | 3 | 3 |
| `tests/recall-pipeline/hit.jsonl` | 4 | 4 |

共 14 条。

---

# 三者关系

```
                       ┌─────────┐
                       │  learn  │
                       └────┬────┘
                            │ 写 trigger
                            ▼
                    ┌────────────────┐
                    │ triggers.jsonl │◄── 读（Fill 素材） ── write
                    │ (project+user) │
                    └────────┬───────┘
                             │ 读
                             ▼
                        ┌─────────┐
                        │ recall  │ ← Edit/Write/Bash 前
                        └────┬────┘
                             │ 写 recall_query / hit
                             ▼
                    ┌────────────────┐
                    │ events.jsonl   │ ──── metrics/report-recall ──► M3/M4/M5
                    └────────────────┘
```

## 依赖方向

- **learn**：只写 triggers + events(created)。
- **write**：读 triggers（作 Fill 素材）；**不写** events。
- **recall**：读 triggers；写 events(recall_query, hit)。
- 三者**无同步依赖**；均为独立会话动作。

## 事件归属

| Event | 产生者 | 消费者 |
|---|---|---|
| `created` / `updated` / `deleted` | learn / CLI 手动 | history / metrics |
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
