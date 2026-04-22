# Write 架构设计

## 1. 定位与边界

### 职责

负责按固定模板生成 11 类结构化文档，把对话中的讨论结果沉淀到项目根 `docs/`，保持与代码同版本演进。

### 不负责

- 知识条目持久化（→ learn.md workflow）
- 文档内容的事实准确性（依赖对话上下文；write 仅保证结构和规范）
- 文档的后续修改推送 / PR（→ Git / IDE 工具链）
- 跨文档一致性自动修复（→ check 命令只检测）

## 2. 结构与交互

### 组件图

```
[入口]                          [Resolve / Sufficiency]
  /know write [hint]              Step 1 Resolve type + path
                                  Step 2 Sufficiency gate
                                  （prd/tech/arch/schema/decision/ui）
                                         │
                                         ▼
[Template → Draft]              [Validate]
  Step 3 Confirm                  Step 7 Validate
  Step 4 Template                 - against checklist
  Step 5 Fill                     - diagram triggers
  Step 6 Write                    - data confidence
  docs/{path}.md                         │
                                         ▼
[Progress]
  Step 8 Progress
  更新父文档引用（roadmap→prd→tech）
```

### 组件表

| 组件 | 职责 | 边界规则 |
|---|---|---|
| Resolve | 从 hint + 对话推断 type + path | 禁止产出不在 11 类内的 type；必须用 Path Resolution 表（write.md §2） |
| Sufficiency gate | 判断内容量是否撑得起高风险文档类型 | 不足 → 降级为父文档；必须对 prd/tech/arch/schema/decision/ui 强制 |
| Template→Draft | 按模板填充、生成 Markdown | 禁止结构外 section；必须保留 HTML 注释引导（跨句协作） |
| Validate | 对照 checklist + diagram-checklist 检查 | 禁止绕过数据置信规则；必须标来源或"目标值，待验证" |
| Progress | 写入父文档引用（roadmap 的 milestone 行 / prd 的 tech 链接等） | 禁止双向引用（→ rule: 向下引用不回指父级）；必须 append-only 到父文档 |

### 数据流

```
hint + 对话 --> Resolve --(type, path)--> Sufficiency
                                           │
                                           ├── pass ──> Template → Fill → docs/{path}.md
                                           └── fail ──> 降级 prompt
                                                          │
                                         Validate <────── Draft
                                                          │
                                         docs/ ───────────┤
                                                          │
                                         Progress <───────┘
                                         追加到父文档（roadmap/prd）
```

| 来源 | 目标 | 数据格式 | 类型 | 说明 |
|---|---|---|---|---|
| 对话 | Resolve | 自然语言 hint + 上下文 | 强 | 无上下文无法推断 type |
| Template | Draft | Markdown 模板字符串 | 强 | 模板定义的 section 结构不可变 |
| Draft | docs/ | Markdown 文件 | 强 | write 的最终交付物 |
| Draft | Progress | 父文档 section 增量 | 弱 | 父不存在时 Progress 跳过，不阻塞 |

## 3. 设计决策

### 驱动因素

| 因素 | 类型 | 对架构的影响 |
|---|---|---|
| AI 倾向写结构散乱 / 冗长 / 无数据的文档 | 质量要求 | 必须有模板 + checklist + 数据置信三道约束 |
| 高风险文档类型（prd/tech/arch）内容不足时产物无用 | 质量要求 | Sufficiency gate 强制；不足则降级 |
| 11 种类型的路径分布不同（单文件 / 目录 / 需求嵌套） | 技术约束 | 必须统一 Path Resolution 表为单一数据源 |
| 文档与代码同步演进 | 业务需求 | 文档放项目根 `docs/`，随 git 跟踪 |

### 关键选择

| 决策 | 选择 | 被拒方案 | 为什么 |
|---|---|---|---|
| 模板体系 | 3 文件链（template + checklist + update） | 单一大模板 | 检查清单独立可 lint；变更规则独立可 enforce；大模板难维护 |
| 文档位置 | 项目根 `docs/` | `.know/docs/` | IDE / Git / PR 工具链对标准 `docs/` 原生支持 |
| 充分性把关 | 问题式 gate | LLM 评分 | 评分不可重现；问题链可审计 |
| 数据置信 | 标注来源或"目标值，待验证" | 无约束 | 禁止编造精确数字（历史已踩过） |

### 约束

- 禁止产出 11 类外的文档类型（roadmap / capabilities / ops / marketing / arch / ui / schema / decision / prd / tech / milestone）
- 禁止写不到 Sufficiency gate 所需信息量的高风险类型（必须降级）
- 禁止在文档里编造精确数字（必须标来源 / 估算 / 目标 / 无数据）
- 必须使用 Path Resolution 表（write.md §2），禁止硬编码字面路径

## 4. 质量要求

| 属性 | 指标 | 目标 |
|---|---|---|
| 类型覆盖 | 支持的文档类型数 | 11 种（当前实测：完整）|
| 结构一致性 | check 命令偏差率 | 0 个（当前实测：无偏差） |
| Sufficiency 通过率 | 高风险类型首次通过 gate 的比例 | >60%（目标值，待验证） |
| 数据编造率 | 精确数字无来源标注的比例 | 0%（必须零容忍） |
