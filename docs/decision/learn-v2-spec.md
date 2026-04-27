# learn v2 spec（M2）

> 状态：设计锁定（2026-04-26 sprint 收敛）
> 范围：M2，仅 N（新增）模式。U / D / E / F 留 M3。
> 实现产物：`workflows/learn.md` + `tests/{unit,capability}/learn/`

## 1. 知识的功能定义

**知识** = 在新会话中，AI **无法从（当前代码 + 训练 + 用户当下输入）推出**，但项目协作需要它持有的**判断 / 约束 / 模式**。

否定定义（这些不是 know 的知识）：
- 代码当前状态 → grep
- 历史变更 → git log / git blame
- 通用编程 best practice → 训练已有
- 一次性问题 / 任务进度 → commit message / TODO
- 长篇结构化文档 → `docs/`（write 命令承载）

推论：entry = **短小 + 可触发 + 有 invalidation 边界的判断单元**。本质是"行为约束触发对"，不是"信息记录"。

## 2. 知识类型（authoring 提示，不持久化）

3 类对应 4 个内容字段名（字段名编码 tag + 强度）：

| 类 | 字段名 | 等价语义 | AI 行为 |
|---|---|---|---|
| R 约束（强）| `must` | rule + strict=true | 必须遵守，不得 override |
| R 约束（弱）| `should` | rule + strict=false | 推荐遵守，可 override 需说明 |
| T 警示 | `avoid` | trap | 警惕陷阱，主动避开 |
| P 偏好 | `prefer` | insight | 倾向偏好，非强制 |

class 维度仅在 authoring 期辅助 AI 思考分类，不写入 entry metadata。

## 3. Entry 物理形态——4 字段 YAML

```yaml
- when: 改 webhook handler 时
  must: webhook 必须先验签再解 body — 防伪造
  how: HMAC-SHA256(env.WEBHOOK_SECRET, raw_body) 比对 X-Sig；见 src/webhook/verify.ts
  until: webhook 提供商改用 mTLS

- when: 写 worker 任务且涉及 DB 时
  avoid: 在 worker 里 await 数据库事务 — 死锁主连接池

- when: 准备 commit/push 时
  prefer: PR 拆原子 commit — 单点回滚 + 可读性
```

| 字段 | 必填 | 含义 | 来源 |
|---|---|---|---|
| `when` | 必 | trigger 描述（AI 见到什么时应想起）| Q3 产物 |
| `must` / `should` / `avoid` / `prefer` | 必（选 1）| 知识内容 + 强度 + 类型 一并编码 | 主体 |
| `how` | 选（must/should 涉及技术细节时必）| 实现 / 参考（指向代码或文档）| Q4 产物 |
| `until` | must 必，其余选 | 失效条件 | Q2.b 产物 |

**砍掉的字段**：`id`（YAGNI 至 M3 加 U/D 时再加）、`tag` / `strict`（合进字段名）、`理由` 独立字段（嵌进内容字段，破折号分隔）、`created` / `updated`（git log）、复用场景（仅 Q2.a 产物，不持久化）、class（不持久化）、HTML 注释、⚠ 视觉标记、sub-bullets。

## 4. CLAUDE.md 内 `## know` 段结构

`## know` 是弱 section——文件其余内容不动。3 种文件状态对应 3 种写入策略：

| 文件状态 | 策略 |
|---|---|
| 无 `## know` 段 | 文件末尾创建 `## know` + YAML block |
| `## know` 段存在但无 YAML block（已有自由内容）| 段末尾创建新 YAML block，已有内容不动 |
| `## know` 段已有 YAML block | append entry 到 list 末尾 |

形态：

```markdown
## know

\`\`\`yaml
- when: ...
  must: ...

- when: ...
  avoid: ...
\`\`\`
```

## 5. Entropy gate（4 问，必经）

任一 fail → reject 进 rewrite 流程（§7）。

### Q1 信息熵

> 如果 AI 不知道这条规则，仅靠当前代码 + 通用编程知识，能不能得到等效结论？
> - 能 → ❌ 冗余，拒绝
> - 不能 → ✓ 通过

**强制产物**：写出"假如不知道这条，AI 会得到的结论"。不能只回 yes/no。

### Q2 复用价值 + 失效

#### Q2.a 复用价值

> 写出至少 1 个**未来**会用上这条的场景（不能是当前正在解决的场景）。
> 写不出 → ❌ 拒绝（一次性问题，归 commit message 即可）

产物不持久化，仅作 gate。

#### Q2.b 失效检查

> 写出"失效检查条件"——什么状态 / 事件下本条不再成立。
> 写不出 → ❌ 拒绝（对适用边界没想清）

**强制产物**：填入 `until` 字段（must 必填，其余选填）。

### Q3 可触发

> 我能说出 AI 在做什么时（文件路径 / 关键词 / 代码模式）应该想起这条吗？
> 说不出 → ❌ 拒绝（无 trigger，等同死条目）

**强制产物**：填入 `when` 字段。

### Q4 可执行

> AI 在 trigger context 下，仅靠这条 entry 能完成动作吗？
> - 是（声明性 rule，如"用中文回答"）→ ✓，`how` 可省
> - 否（涉及技术细节）→ 必须补 `how` 字段指向代码或文档

**强制产物**：必要时填入 `how` 字段。

## 6. 落位决策树（5 步）

```
step 1 (level): 这条知识在另一个项目还成立吗？
  yes → user
  no  → step 2

step 2 (level): 这条知识能指出一个具体代码目录吗？
  yes → module
  no  → project

step 3 (file):
  user    → ~/.claude/CLAUDE.md
  project → ./CLAUDE.md
  module  → <对话中涉及的最深代码目录>/CLAUDE.md

step 4 (section): 见 §4

step 5 ([STOP:choose]): 把 候选位置 + 候选 entry 呈给用户确认 / 调整
```

**默认 level 偏好**（step 1/2 决策起点，AI 先猜）：

| 字段 | 默认 level |
|---|---|
| `must` / `should` | project / module |
| `avoid` | module |
| `prefer` | user |

**module 边界**：自动取对话涉及代码文件的 parent dir 作候选；step 5 让用户确认 / 改。多语言或无 manifest 项目退化为最深的代码目录。

## 7. Rewrite 流程

```
gate fail (Q1 / Q2.a / Q2.b / Q3 / Q4 任一)
  ↓
AI 反馈：
  [learn] gate fail: {Q 名}
  原 entry: {当前候选}
  原因: {为什么 fail}
  请补充上下文 / 回复 "skip" 放弃
  [STOP:confirm]
  ↓ (补充内容)        ↓ (skip)
AI 重跑 gate (1 次)    终态 reject
  ↓ pass    ↓ fail
继续写入   终态 reject (不再 rewrite)
```

**关键约束**：
- 仅 1 次 rewrite 机会（防止拉锯）
- 不提供 `force` 跳过 gate（用户真要写就直接 Edit CLAUDE.md，不走 learn）
- Reject 不持久化，仅 conversation 反馈 + 简短 reason

## 8. 写入冲突 / 重复检测

写入前 AI 扫目标 file 的 `## know` YAML list，**语义相似度判断**（AI judgment，非算法阈值）：

- `when` 字段语义重合 + 内容字段语义重合 → 视为重复
- → 提示 `[learn] 近似条目已存在: {existing}，建议 U 模式修改（M3 暂未实现）`
- → 用户选: `skip`（默认） / `add anyway`（强制添加） / `cancel`

M2 不实现 U 模式，但识别"近似已存在"避免 dogfood 期重复堆积。

## 9. git commit 前缀

格式：`know: {action} {field}({when}) — {brief}`

| action | M2 是否产 |
|---|---|
| `add` | ✓ |
| `update` | M3 |
| `remove` | M3 |

例：

```
know: add must (改 webhook handler 时) — webhook 验签
know: add prefer (准备 commit 时) — PR 拆原子 commit
```

AI 在 learn pipeline 写入完成 [STOP:confirm] 时附带建议 commit message，用户可调整。

## 10. 测试分层

| 目录 | 性质 | M2 内容 |
|---|---|---|
| `tests/unit/learn/` | 单元测试（jsonl，按决策点拆）| 8 个文件，见下表 |
| `tests/capability/learn/` | 场景指标测试（端到端 fixture） | 5 个 markdown，见下表 |

### tests/unit/learn/

| 文件 | 测什么 |
|---|---|
| `gate-q1-entropy.jsonl` | Q1 信息熵 pass/fail cases |
| `gate-q2a-reuse.jsonl` | Q2.a 复用价值 pass/fail |
| `gate-q2b-invalidation.jsonl` | Q2.b 失效条件 pass/fail |
| `gate-q3-trigger.jsonl` | Q3 可触发 pass/fail |
| `gate-q4-actionable.jsonl` | Q4 可执行 pass/fail |
| `locate-level.jsonl` | level 决策（user/project/module）cases |
| `locate-module-boundary.jsonl` | module 边界推断 cases |
| `id-format.jsonl` | （M2 暂无 id；占位，M3 启用）|

行格式：`{"input": "...", "expect": "pass/fail", "reason": "..."}`

### tests/capability/learn/

| 文件 | 字段 | level | gate 结果 |
|---|---|---|---|
| `F1-webhook.md` | `must` + `how` + `until` | project | 全过 → 写入 |
| `F2-pr-atomic-commit.md` | `prefer` | user | 全过 → 写入 |
| `F3-https-reject.md` | — | — | Q1 fail → reject |
| `F4-sync-io-deadlock.md` | `avoid` | module | 全过 → 写入 |
| `F5-pg-decision.md` | `should` | project | 全过 → 写入 |

每文件结构：对话片段 + 期望 gate 决策 + 期望 entry + 期望落位。

## 11. M2 验收

**验收 = capability 5 fixture 全过**（人工 dogfood 走一遍对照）。
unit jsonl 作为持续回归参考，不作为 M2 通过门。

## 12. M2 输出物清单

1. `workflows/learn.md`（v2 重写，仅 N 模式 + 4 gate + 5 步决策树 + 重复检测 + commit prefix 建议）
2. `skills/know/SKILL.md` route 加 learn pipeline（已有 routing 表，确认 learn 指向 v2 workflow）
3. `tests/unit/learn/*.jsonl`（8 个文件）
4. `tests/capability/learn/F{1-5}-*.md`（5 fixture）
5. 在 know 项目自身 `./CLAUDE.md` 创建首条 dogfood entry（用 N 模式自验）

## 13. M2 边界（不做）

- U / D / E / F 模式
- routing 整合 5 模式 sub-route（M3）
- evolution skill 下架（M3 后）
- F 类 inline 注释 `@know:flow=...`（M3）
- Force 跳过 gate
- Rejection log 持久化
- ID 字段（M3 加 U/D 时启用）
- 多次 rewrite（仅 1 次）

## 14. 历史决策依据

| 决策 | 选 | 否决理由 |
|---|---|---|
| 写入路径 | AI 直接 Edit + prompt-only gate | 脚本兜底违背"v2 无 retrieval / 无 hooks" |
| metadata 字段 | 4 字段 YAML | 5 字段 + HTML 注释 + sub-bullet 视觉污染 + 字段冗余 |
| class 持久化 | 不 | 对 AI 消费无差异，AI 只看 tag + trigger + 内容 |
| 6 类 vs 3 类 | 3 类（authoring 提示）| 3 类 1-1 对应 tag，避免冗余维度 |
| 时间稳定性阈值 | 删 6 个月 80%，改"复用 + 失效检查" | 时间窗武断；产物失效条件更有用 |
| ⚠ 视觉标记 | 不要 | YAML 字段名 `must` + `how` 已显性表达 |
| ID 格式 | M2 不要 | YAGNI；M3 加 U/D 再设计 |
| Force 跳过 gate | 不提供 | gate 是质量边界，绕不得；用户真要写就直接 Edit |
