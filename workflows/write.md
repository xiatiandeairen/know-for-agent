# write — 文档撰写

## 1. 概述

基于对话内容与 `triggers.jsonl` 生成结构化 markdown 文档。支持 10 种 type，分三种布局（单文件、目录、需求）。流程：推断参数 → 确认 → 填充 template → 预览 → 写入 → 校验 → 回写 progress。

## 2. 核心原则

1. **落盘前先确认**。path、type、完整预览均需用户显式确认。
2. **不编造**。证据缺失写 `TBD — {缺失内容}` 或 `Open question:`；数值必须标注来源（实测 / 估算 / 目标 / 无数据），无来源一律校验失败。
3. **trigger 是证据，不是正文**。按 summary 引用，禁止原文粘贴。rule 约束、insight 建议、trap 作为风险呈现。
4. **澄清有上限**。一次无效回复触发单次完整列表回退；第二次无效则 `abort`。禁止猜测。
5. **template 与 checklist 是唯一结构来源**。写入器只填充与满足，绝不私自重定义结构。
6. **update 保留历史**。仅重写对话明确讨论的 section；append-only section（`tech §3 决策`、`§4 迭代记录`）永不覆盖。
7. **修复有上限**。校验最多循环 3 轮，第 4 轮强制出文并报告未解数。

## 3. 定义

| 术语 | 含义 |
|---|---|
| `type` | `roadmap, prd, tech, arch, decision, schema, ui, capabilities, ops, marketing` 之一 |
| `hint` | 可选的 type 字符串，通过 `/know write <hint>` 传入 |
| `name` | kebab-case slug（主题名或需求名）|
| `mode` | `create` \| `update` |
| `parent` | 上游文档，完成后回写其 progress 字段 |
| `trigger` | `docs/triggers.jsonl` 或 `$XDG_CONFIG_HOME/know/triggers.jsonl` 的一条记录 |
| `exemplar` | 每个 type 的语义锚点例句，Step 1a 使用 |
| `STOP:confirm` | 阻塞，等待用户 yes/no |
| `STOP:choose` | 阻塞，等待用户从列表选项中选一 |
| `abort` | 终止当前步骤，不写文件 |

## 4. 规则

### 4.1 输入处理

- 字符串匹配大小写不敏感，先归一为小写。
- `hint` 有效则直接采用，不再提问。
- 回复视为无效：小写后为空、匹配 `不知道 / 随便 / skip / idk / -`、或不在当前 prompt 的候选集内。
- 无效回复允许一次完整列表回退；第二次无效即 `abort`。

### 4.2 文件安全

- 禁止静默覆盖。`create` 目标已存在时提示 `Update / Pick different name / Cancel`。
- roadmap 永远单文件；新版本属 `update`，非 `create`。
- `create` 把 template 每个 section 写一次；`update` 只动对话讨论过的 section。

### 4.3 内容完整性

- 禁止：无来源的精确数字、编造细节、虚构的交叉引用。
- 每个数字必须满足其一：`数值 + 引用`、`数值 + 估算 + 依据`、`数值 + 目标值，待验证`、`无数据（{原因}）`。
- trigger 按 summary 引用，原文粘贴禁止。
- append-only section（`tech §3 关键决策`、`tech §4 迭代记录`）永不覆盖。

### 4.4 澄清上限

- sufficiency、mode、inference 各自最多 1 次澄清提问，否则推进或 abort。
- 校验最多 3 轮修复；第 4 轮强制出文并标注未解数。

## 5. 工作流

模型：推断与撰写（1a、4）用 `opus`，其他用 `sonnet`。

### 5.1 路径解析

| Type | Path |
|---|---|
| `roadmap / capabilities / ops / marketing` | `docs/<type>.md` |
| `arch / ui / schema / decision` | `docs/<type>/<name>.md` |
| `prd / tech` | `docs/requirements/<name>/<type>.md` |

层级：`roadmap → prd → tech`，其余独立。roadmap 版本以 `### v{n}` 挂在 `## 2. 版本规划` 下，里程碑编号按版本重置。

### 5.2 Step 1 — 参数推断

4 个子步产出 `{type, name, mode, parent}`，统一模式：*hint → 自动推断 → 一次澄清 → 完整列表回退 → abort*。

#### 1a — `type`

```
1. hint ∈ 10 种 type（小写）                    → 直接采用。
2. exemplar 推断检查：
     命中单个 type                              → 返回。
     命中单个分组（A/B/C）                      → 问 Q2。
     零命中或跨多组                             → 先 Q1，再 Q2。
3. 无效回复 → 列全部 10 种 type → 再无效 → abort。
```

**推断检查**：逐 type 自问「若以此 exemplar 替代对话，读者能否还原相同写作意图？」恰好命中一个 type → 2a；命中一整个分组 → 2b；否则 2c。

**Exemplars**

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

**澄清提问**

Q1（三分组）— A：`roadmap, prd` · B：`tech, arch, decision, schema` · C：`capabilities, ui, ops, marketing`

Q2-A：`roadmap | prd`
Q2-B：`tech | arch | decision | schema`
Q2-C：`capabilities | ui | ops | marketing`

可接受回复：字母，或直接写 type 名（直接短路跳过 Q2）。

#### 1b — `name`

```
1. 该 type 不需要 name                         → null。
2. name_hint 存在                              → 归一化返回。
3. 对话中含明确名词短语                        → 归一化返回。
4. 否则 → 问用户 → 无效 → 重试 1 次 → abort。
```

**归一化**：小写 → 把 `[space/._/]` 替换为 `-` → 去除 `[a-z0-9-]` 之外字符 → 折叠重复 → trim `-`。结果为空则无效。

#### 1c — `mode`

```
1. 文件不存在                                   → create。
2. type = roadmap（永远单文件）                 → update。
3. 文件存在 → [STOP:choose]：
     A) Update                                  → update。
     B) Pick a different name                   → 回 1b。
     C) Cancel                                  → abort。
```

#### 1d — `parent`

| Type | Parent |
|---|---|
| prd | `docs/roadmap.md` |
| tech | `docs/requirements/<name>/prd.md` |
| 其他 | 无 |

```
1. 该 type 无 parent                            → null。
2. parent 存在                                  → 返回路径。
3. prd 且 roadmap 缺失                          → 继续，标注缺失。
4. tech 且 prd 缺失 → [STOP:choose]：
     A) Continue without parent                 → null。
     B) Create PRD first                        → 跳转。
5. prd 里程碑归属不明                           → 询问里程碑编号。
```

### 5.3 Step 1.5 — Sufficiency gate

仅在高风险 type（`prd, tech, arch, schema, decision, ui`）运行。

```
1. 加载 templates/sufficiency-gate.md 的问题组。
2. 每题以对话原文引用或明确 "not present" 作答。
3. 全 yes  → pass。
   混合    → degrade。
   全 no   → reject。
4. degrade / reject → [STOP:choose]：
     A) 补充对话                                → 重跑本步。
     B) Degrade 为 <建议 type>                  → 回 Step 1。
     C) Cancel                                  → abort。
```

### 5.4 Step 2 — 确认

```
[write] Inferred from conversation
  Type:   {type}
  Name:   {name or —}
  Path:   {resolved path}
  Mode:   {create | update}
  Parent: {parent or none}
Correct? (yes / change <field>=<value>)
```

字段依赖：`type → name → mode → parent`。修改某字段则其下游全部重跑；直接改 `mode` 或 `path` 则直接生效。

### 5.5 Step 3 — 加载 template

```bash
cat "{project_root}/workflows/templates/{type}.md"
```

template 缺失则合成 `# Title / ## Overview / ## Details / ## Open Questions`。

### 5.6 Step 4 — 填充

同时加载 `docs/triggers.jsonl` 与 `$XDG_CONFIG_HOME/know/triggers.jsonl`。

**Create 模式**

```
对每个 template section：
  1. 收集相关对话引文与在 scope 内的 trigger。
  2. 遵守 <!-- INCLUDE / EXCLUDE --> 提示。
  3. 产出结构化正文；代码块与表格原样保留。
  4. 证据不足 → "TBD — {缺失内容}"。
不明确之处以 "Open question:" 开头。
交叉引用用项目根相对路径；输出语言随用户。
handoff 前应用 progress fields。
```

**Update 模式**

```
1. 完整读取现有文档。
2. 列出对话讨论过的全部 section。
3. 只重写列出的 section；其余 byte-identical。
4. 补齐缺失的 template section（写内容或 TBD）。
5. 仅在被改动 section 内修复坏的相对路径。
6. 若无 section 被讨论 → [STOP:choose] A) 新增 section  B) cancel。
```

**Progress fields（create）**

| Type | Field | Rule |
|---|---|---|
| roadmap | 里程碑.进度 | `完成数/总数`，按关联 PRD 统计 |
| roadmap | 里程碑.需求 | 链接每个 PRD，空则 `—` |
| roadmap | 里程碑编号 | 每个版本从 M1 重新开始 |
| prd | §4 方案.任务表 | 每个 tech 文档一行；progress = `完成数/总数` |
| tech | §4 迭代记录 | 以今日日期与 sprint 摘要起头 |

**各 type update 规则**

| Type | Section | Rule |
|---|---|---|
| tech | §2 方案 | 随认知深化覆写 |
| tech | §3 关键决策 | 仅追加 |
| tech | §4 迭代记录 | 今日置顶；永不覆盖历史 |

**H1 titles**

| Scope | Title |
|---|---|
| 项目单文件 | `{项目名} {文档类型}` |
| 项目目录 | `{主题名} {文档类型}` |
| 需求（prd） | `{用户入口}` |
| 需求（tech） | `{需求名} 技术方案` |

### 5.7 Step 5 — 写入 [STOP:confirm]

写前预览。

```
[write] Preview: {path}
{create: 完整内容 · update: 改动 section 的 diff}
Write? (yes / edit <section> / no)
```

若 `TBD` 超过 3 个 section，前置 `{n} sections marked TBD: {list}. Still write?`，要求二次确认。

`yes` 后：

```bash
mkdir -p "$(dirname "{path}")"
```

- `create` → Write 工具。
- `update` → 逐 section 用 Edit 工具；`tech` 需把迭代记录条目置顶。

```
[written] {path}
[written] {path} (updated {n} sections)
```

### 5.8 Step 5.5 — 校验

Gate：`templates/{type}-checklist.md` 不存在则跳过。

```bash
cat "{project_root}/workflows/templates/{type}-checklist.md"
```

检查项：
- **Structure** — 必需 section/字段齐全。
- **Language** — 字段满足其 `✅/❌` 语言约束。
- **Data confidence** — 每个数字满足 §4.3 四种来源形式之一；无来源精确数字判失败。
- **Completeness** — 非可选字段含真实内容而非占位。
- **Diagrams** — checklist 引用了 `diagram-checklist.md` 则连带跑。

违规处理：列出 → 修复 → 重新预览。最多 3 轮；第 4 轮强制出文并标 `[validate] forced through, {n} checks unresolved`。

### 5.9 Step 6 — 回写

```
1. 该 type 无 parent 或 parent 文件缺失         → 静默跳过。
2. 否则 → 用 Edit 工具只改 parent 的 progress 字段。
```

| 写入 type | Parent field |
|---|---|
| tech | PRD `§4 方案` 任务表 progress 列 |
| prd | roadmap 里程碑表 `完成PRD数/总PRD数` |

```
[progress] {parent_path} updated ({value})
```

## 6. 示例

### 高置信推断（Steps 1a → 5）

```
/know write
conversation: "recall 模块 = scope 推断 + query + rank; 增加 ranking weight"
→ 1a 命中 arch exemplar → type=arch。
→ 1b 从对话提取 "recall" → name=recall。
→ 1c docs/arch/recall.md 不存在 → mode=create。
→ 1d 无 parent。
→ Confirm：Type=arch, Path=docs/arch/recall.md, Mode=create。
→ Fill → Preview → Write → 校验通过。
```

### 模糊，一次澄清

```
/know write
conversation: "聊了方案，但没定是画架构图还是记录选型"
→ 1a 收敛到分组 B → 问 Q2-B。
user: decision
→ type=decision。后续同上。
```

### Update 并回写 roadmap

```
/know write prd
→ 1b name=upload-flow；docs/requirements/upload-flow/prd.md 已存在。
→ 1c → Update。
→ Fill 只动 §4 方案。
→ Preview 显示 diff。
→ 校验通过。
→ Step 6 改 docs/roadmap.md 里程碑表 progress 列。
```

## 7. Edge Cases

| 情形 | 行为 |
|---|---|
| hint 是合法名但不在 10 种目录内（如 `runbook`） | 视为 null，走推断。 |
| 连续两次无效回复 | 当前步骤 `abort`。 |
| create 目标文件已存在 | Step 1c 呈现 Update / Rename / Cancel。 |
| `tech` 无 parent PRD | Step 1d 问 Continue / Create PRD first。 |
| sufficiency reject 且用户选 B | 以降级后的 type 回 Step 1，name 与 mode 重新推导。 |
| 预览含 4+ 个 TBD section | 警告并要求二次 `yes`。 |
| 校验 3 轮仍未清零 | 强制出文并标 `[validate] forced through, {n} unresolved`。 |
| parent 存在但无法编辑（权限、语法坏） | 记 `[progress] skip: {reason}` 后继续。 |

## Recovery

| 错误 | 恢复 |
|---|---|
| Write / Edit 工具失败 | 暴露错误，禁止静默重试。 |
| `create` 中途发现文件已存在 | 回 Step 1c。 |
| checklist 文件损坏 | 视为缺失，跳过校验并告警。 |
