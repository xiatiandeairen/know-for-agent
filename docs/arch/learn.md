# Learn 架构设计

## 1. 定位与边界

### 职责

负责从对话文本中检测、筛选、结构化隐性知识并写入知识库，为 recall 提供可召回的条目来源。

### 不负责

- 条目的召回与提示（→ recall 架构）
- 过期条目清理（→ decay 架构，仅在 learn 入口调一次）
- 从源码挖掘知识（→ extract.md workflow，独立管线）
- 写 Markdown 文档（→ write.md workflow）

## 2. 结构与交互

### 组件图

```
[入口]                       [信号管线]
  /know learn                  Step 1 Detect (signal types)
  decay no-op 前置              Step 2 Extract (split into units)
                                Step 3 Filter (drop noise)
                                        │
                                        ▼
[条目构建]                    [Level 决策]
  Step 4 Generate               Step 7 Level
    tag → scope →               scope 前缀推断
    (if rule) strict →          project / user 选择
    summary → ref               user 二次确认
  Step 5 Conflict (existing)
  Step 6 Challenge (5 Qs)
                                        │
                                        ▼
[持久化]
  Step 8 Confirm (user)
  Step 9 Write
  know-ctl append --level X
```

### 组件表

| 组件 | 职责 | 边界规则 |
|---|---|---|
| 信号管线 | 从对话扫描 ≤5 个候选知识点 | 禁止无结论信号入候选；必须 top 5 截断 |
| 条目构建 | 把候选转为带 8 字段的 entry | 禁止猜测字段；Generate 子步：tag→scope→(if rule) strict→summary→ref |
| Challenge | 对每条 entry 跑 5 道对抗问题 | ≥3 道失败 → drop；必须明示变更（drop/rewrite/adjust） |
| Level 决策 | 选择 project 或 user 存储目标 | 禁止 CLI 默认绕过；必须对 user 二次确认 |
| 持久化 | append 到 triggers.jsonl（对应 level） | 禁止绕过 know-ctl append；写入时触发 created event |

### 数据流

```
对话文本 --scan--> 信号候选(≤5) --filter--> claim 集
   claim --Generate(tag/scope/strict/summary/ref)--> 草稿 entry
   草稿 --Conflict(search existing)--> 决定（新增/merge/skip）
   草稿 --Challenge(5 Qs)--> 最终 entry 集
   entry --Level 推断/选择--> (entry, level)
   (entry, level) --know-ctl append --level X--> triggers.jsonl (对应 level)
                                          │
                                          └--> events.jsonl: created
```

| 来源 | 目标 | 数据格式 | 类型 | 说明 |
|---|---|---|---|---|
| 对话 | 信号管线 | 自然语言文本 | 强 | 无对话输入无法启动管线 |
| Conflict | know-ctl search | 2-4 个 keyword | 弱 | search 失败可降级为无冲突 |
| Level 决策 | 用户 | 选择 + 可选覆盖 | 强 | 默认值可被用户改写；user 必须二次确认 |
| 持久化 | know-ctl append | 8 字段 JSON + `--level` | 强 | append 校验 + strict 规则，失败则 claim 被跳过 |

## 3. 设计决策

### 驱动因素

| 因素 | 类型 | 对架构的影响 |
|---|---|---|
| 对话中 90%+ 信息不值得存 | 业务需求 | 必须有多级过滤（Filter + Assess + Challenge） |
| AI 倾向扩张候选集 | 质量要求 | 必须 top 5 截断 + Challenge 5 问对抗 |
| 同一结论在多处讨论会重复入库 | 质量要求 | 必须 Conflict 步骤比对既有 entries |
| user level 影响所有项目 | 质量要求 | 必须工作流层二次确认，CLI 层保持幂等 |
| strict=true rule 的 context 应被人浏览 | 业务需求 | 建议配 ref 指向 docs 段；不存独立详情文件 |

### 关键选择

| 决策 | 选择 | 被拒方案 | 为什么 |
|---|---|---|---|
| 条目产出 | 10 步串行管线 | 一次性 LLM 产出完整 entry | 串行让每步可验证、可 drop；一次性产出难以约束质量 |
| Level 步骤位置 | Challenge 之后、Confirm 之前 | Generate 时同步决定 | Level 与 entry 质量正交；Challenge 可能 drop 整条，先定 level 浪费 |
| 冲突解决 | 每 claim 单独比对既有库 | 批量比对 | 串行更精确；批量会掩盖 merge/duplicate 边界 |
| critical 的 context | 通过 ref 指向 docs/ 现有段 | 独立 md 散文件 | 散文件孤岛，不在 docs/ 体系；ref 让 context 复用叙事文档 |

### 约束

- 禁止 Step 1 Detect 产出 >5 候选（超出按优先级截断）
- 禁止 Challenge 产出 >50% drop 时仍继续（说明过滤层前面失效）
- 必须 user level 写入前经 workflow 层 `[STOP:confirm]`（防止误污染所有项目）
- 必须每条 append 成功后立即写入（禁止批量延迟，防中断丢失）

## 4. 质量要求

| 属性 | 指标 | 目标 |
|---|---|---|
| 候选准确率 | top 5 候选中真正被持久化的比例 | >40%（目标值，待验证） |
| Challenge 过滤率 | Challenge 后 drop/demote 的比例 | 20%-50% 为健康区间（实测无数据） |
| 管线耗时 | 单次 /know learn 端到端 | <30s（目标值，待验证） |
| append 失败率 | append 子命令报错比例 | <1%（目标值，待验证） |
