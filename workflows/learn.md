# learn — 知识沉淀

5 stage 串行：detect → gate → refine → locate → write。每条 claim 独立走完一次，某条 fail 不阻断其余。

每个 stage 入口先输出两行：

```
[learn] stage X/5 — {name}
目的：{purpose}
```

Stage 概览：

- Stage 1 detect — 从对话抽全部 claim 候选，用户取子集（Step 1）
- Stage 2 gate — 5 道闸筛选，任一 fail 则 reject（Step 2-6）
- Stage 3 refine — 从多个维度加工知识，提升 entry 质量（Step 7-9）
- Stage 4 locate — 决定写入哪个 CLAUDE.md（Step 10）
- Stage 5 write — 起草 entry，查重，确认，写入（Step 11-15）

---

## Stage 1: detect

```
[learn] stage 1/5 — detect
目的：从最近 ≤20 轮对话中抽出全部 claim 候选并由用户取子集；找不到就请用户用一句话给出。
```

### Step 1 — detect

先按来源分类，再扫描：

**A 类（用户纠正了 AI 的判断）** — 直接进候选，无需额外验证：

- 用户指出 AI 的输出有误，给出了正确做法
- 用户否定了 AI 的方案，提出了不同方向
- 用户补充了 AI 遗漏的约束或前提

**B 类（AI 主动捕捉）** — 列为候选，但需通过强化版信息熵才能留下：

- 本次对话做了哪些技术选择，且说明了理由？
- 遇到了什么问题，总结出什么经验？
- 用户表达了什么倾向或风格要求？

A 类标注 `[纠正]`，B 类标注 `[捕捉]`，输出时一并列出。

输出模版：

```
[learn] 检出 {N} 条 claim 候选：
  1. {claim 主体}
  2. {claim 主体}
  ...
请回复编号（如 "1,3" 取子集 / "all" 全要 / "none" 取消 / 自由文本补一条）
```

等待用户回复后继续。用户确认子集后，Stage 2-5 对每条 claim 独立各走一遍。

- 无候选 → 输出 `[learn] no claim detected — 请用一句话说出要沉淀的知识`，等待用户输入
- 单条候选 → 直接进 Stage 2，不走选择菜单

---

## Stage 2: gate

```
[learn] stage 2/5 — gate
目的：对每条 claim 独立跑 5 道闸；某条 fail 仅 reject 该条，不影响其余。
```

每道闸：pass → 继续；未通过 → 给出调整建议等用户确认，重跑一次；仍不过 → `[learn] reject: {原因}`。

闸从大到小排列，越靠前能过滤的范围越广。classify 不是过滤闸，先于 gate 执行。

### Step 2 — classify

违反这条会有什么后果？

- 不可逆（安全 / 数据 / 金钱损失）→ `must`
- 可恢复 → `should`
- 触发陷阱 → `avoid`
- 只是倾向 → `prefer`

输出 `[learn] 选 {field}（{中文标签}）`。

### Step 3 — 信息熵

**[纠正] 类**：直接 pass，跳过信息熵检验——用户纠正本身即证明 AI 会犯错。

**[捕捉] 类**：

Q1: 在只有项目 CLAUDE.md 的全新会话里，AI 会在什么具体操作中犯什么具体错误？

- 能写出具体错误场景 → pass
- 写不出 → 未通过。调整：把 claim 绑定到一个 AI 真实会犯错的场景重答。仍写不出 → reject

### Step 4 — 复用

Q1: 除了当前任务，列出一个未来会用上这条的场景。

- 列得出 → 通过（产物不入 entry）
- 列不出 → 把 claim 改写为能跨任务迁移的表述，重列。仍列不出 → reject

Q2: 什么条件下这条不再成立？→ 填入 `until` 字段（`must` 必填，其余选填）

- 想不出 → 推断框架版本 / 配置开关 / 外部服务的变化点重答。仍想不出 → reject

### Step 5 — 可触发

Q1: 改哪个文件、用哪个库、遇到什么代码模式时，AI 应该想起这条？→ 填入 `when` 字段
Q2: 这个触发描述能定位到具体文件路径 / 关键词 / 代码模式吗？

- 能 → pass
- 不能 → 未通过。从对话涉及的路径、函数名、库名重答 Q1

### Step 6 — 可执行

Q1: 这条是声明性规则还是需要操作步骤？

- 声明性（如"用中文回答"）→ pass，省略 `how`
- 需要操作步骤 → 继续 Q2

Q2: 具体怎么做？代码在哪 / 文档在哪？→ 填入 `how` 字段

- 写得出 → pass
- 写不出 → 从对话中找操作步骤或文档引用重答。仍写不出 → reject

---

## Stage 3: refine

```
[learn] stage 3/5 — refine
目的：从场景泛化、知识深化、颗粒度校准三个维度加工 claim，提升 entry 的覆盖面和推理质量。
```

每个步骤均为可跳过的加工，无需调整则直接继续。有改动时输出调整内容等用户确认。

### Step 7 — 场景泛化

Q1: `when` 描述的触发场景，背后的本质操作是什么？
Q2: 还有哪些文件路径 / 库 / 代码模式在本质上属于同一类场景，却没被当前 `when` 覆盖？

- 有 → 提出更通用但仍精准的 `when` 描述，等用户确认后更新
- 无 → 跳过

### Step 8 — 知识深化

Q1: 这条规则为什么成立？违反后发生的机制是什么（不只是后果描述）？
Q2: 这个根因能用一句话补入 claim 的理由部分，让 AI 在边界情况下能推断而不是机械执行吗？

- 能且当前理由不够充分 → 提出补充后的 claim 表述，等用户确认后更新
- 已充分 → 跳过

### Step 9 — 颗粒度校准

Q1: 这条 claim 包含几个独立的"当 X 时做 Y"逻辑？

- 1 个 → 跳过
- 多个 → 拆分为多条独立 claim，列出拆分方案等用户确认；确认后每条从 Step 7 重走

---

## Stage 4: locate

```
[learn] stage 4/5 — locate
目的：决定 entry 写到哪个 CLAUDE.md（level: user / project / module → file path）。
```

### Step 10 — locate

Q1: 能指出一个具体代码目录吗？yes → module；no → Q2
Q2: 在另一个项目里，AI 实际发生过这个错误，或有具体理由相信会发生？yes → user；no → project

升到 user 需要真实跨项目证据，"理论上成立"不够。

field 默认起点：

- `must` / `should` → project / module
- `avoid` → module
- `prefer` → project（除非有跨项目实例）

路径通过脚本解析：

```bash
KNOW_PATHS="$(git rev-parse --show-toplevel)/scripts/know-paths.sh"
# user level
bash "$KNOW_PATHS" user-claude-md
# project level
bash "$KNOW_PATHS" project-claude-md
# module level：取对话涉及文件路径的最深"有意义"目录，拼 /CLAUDE.md
MODULE_DIR={从对话上下文提取，给 1-3 候选}
echo "$MODULE_DIR/CLAUDE.md"
```

输出：

```
[learn] 候选落位:
  level: {level}
  file:  {path}
  module 候选（如适用）: {dir1} / {dir2} / {dir3}
请确认 / 改 level / 改 file / cancel
```

等待用户确认后进入 Stage 5。

---

## Stage 5: write

```
[learn] stage 5/5 — write
目的：产出 YAML entry → 查重 → 用户确认 → 写文件 → 给 commit 建议。
```

### Step 11 — format

仅产出已通过 gate + refine 加工后的字段，不加额外字段：

```yaml
- when: {可触发产物}
  must: {claim 主体} — {理由}    # 或 should / avoid / prefer
  how: {可执行产物}              # 仅技术细节 rule
  until: {失效检查产物}          # must 必填，其余选
```

输出 `[learn] entry candidate:` + YAML block。

### Step 12 — conflict

读目标 file 的 `## know` YAML block（不存在则跳过）。`when` 重合 + 内容字段重合 → 视为重复。

发现重复：

```
[learn] 近似条目已存在:
  {existing entry YAML}
本流程不修改已有 entry。请选: skip / add anyway / cancel
```

等待用户回复：`skip`（默认）→ 终止；`add anyway` → 继续写入；`cancel` → 取消。

### Step 13 — confirm

```
[learn] 即将写入:
  file: {path}
  section: ## know (YAML block)
  entry:
    {YAML}
确认写入？(yes / no / 调整某字段)
```

等待用户回复：`yes` → 写入；`no`/`cancel` → 终止；调整某字段 → 重走 Step 11 + Step 13。

### Step 14 — write

按目标 file 状态执行 Edit：

- file 不存在 → 创建，内容为 `## know` + YAML block 含 entry
- file 存在 + 无 `## know` 段 → 文件末尾追加 `## know` + YAML block 含 entry
- `## know` 段存在 + 无 YAML block → 段末追加新 YAML block，已有自由内容不动
- `## know` 段已有 YAML block → append entry 到 list 末尾

输出 `[learn] written: {file}`。

### Step 15 — suggest-commit

```
[learn] suggested commit message:
  know: add {field} ({when 简短化}) — {claim 简短化}
```

不自动 commit。

