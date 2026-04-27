# know 产品路线图

## 1. 产品愿景

### 产品核心

- **定位**: AI 辅助的高熵知识单元 authoring 工具 + Claude Code 生态原生载体——把隐性知识结构化沉淀为可被 AI 自动消费的 markdown 单元，存储位置与 Claude Code 嵌套加载机制对齐
- **动机**: AI agent 跨会话协作需要稳定、高熵、可治理的项目知识；CLAUDE.md 手工维护缺纪律导致低熵规则堆积，私有检索系统经实证 ROI 不显著且自断生态——know 砍 retrieval、保 authoring 纪律
- **长远愿景**: AI agent 在项目中像有经验的团队成员一样工作——尊重约束、复用决策、不重蹈覆辙；写入纪律强制完整上下文与信息熵，存储与生态原生加载机制天然兼容

### 价值体系

- **即时价值**：写入纪律强制每条知识完整上下文 + 高熵；entropy gate 拒绝率（目标: ≥20%）
- **累积价值**：知识库随 dogfood 增长且不腐化；总规则数（目标: ≥30 / 30 天）、AI 主动遵守次数（目标: ≥1 例 / 30 天）
- **战略价值**：AI 协作从"每次重 brief"升级为"知识可追溯且可治理"；跨会话知识复用率（无数据，待 dogfood 测量手段建立）

### 核心问题

- AI 在新会话重复犯已知错误——每次新会话（估算: 日均 5-20 次，作者使用频率），估算 10-30 分钟重新探索 + 回归 bug 风险（作者体感）。现有应对：手工写 CLAUDE.md，缺 authoring 纪律导致低熵规则混入，无生命周期治理
- 设计决策 / 教训 / 业务流缺乏结构化沉淀通道——每次架构 / 复盘 / 业务流变更，估算返工 1-4 小时（作者体感）。现有应对：散落在 git commit / 零散 markdown，缺分类与治理

### 目标用户

| 角色 | 典型场景 | Before | After | 预估提效 |
| ---- | ---- | ---- | ---- | ---- |
| Claude Code 独立开发者 | 跨会话维护中大型项目 + 沉淀长期决策 / 教训 / 流程 | CLAUDE.md 越写越乱，低熵规则混入降低 AI 行为可预期性 | learn entropy gate 拒绝水货 + 结构化 YAML entry + write 10 种文档模板 | 待验证（dogfood 30 天后量化） |
| AI 编程工具 skill / plugin 开发者 | 为 AI 构建项目级上下文层 | 自建知识层成本高，格式不统一 | 复用 know learn + write + entropy gate，存储格式与 Claude Code 原生兼容 | 待验证（无外部用户数据） |

### 竞品对比

| 方案 | 定位 | 核心功能 | 优势 | 局限 |
| ---- | ---- | ---- | ---- | ---- |
| **know** | AI 辅助知识 authoring + 治理 | learn（detect→gate→refine→locate→write）、entropy gate、write 10 种模板 | authoring 纪律、生态原生、零运行时 | 不做 retrieval（依赖 Claude Code 嵌套加载）、需 git 协作 |
| CLAUDE.md 手工维护 | 项目级 AI 提示文件 | 手工编写规则 | 零依赖 | 缺纪律 / 缺分类 / 缺治理，低熵规则易堆积 |
| Cursor Rules | IDE 级 AI 行为配置 | 项目规则 + 行为约束 | IDE 集成 | Cursor 限定，无 authoring 纪律，无生命周期 |
| evolution skill | AI 行为复盘工具 | 元认知分析 + 改进策略 | 专注 AI 自我改进 | 与 know 输出目标重合，已融入 learn gate 设计 |

## 2. 版本规划

> pivot 前的迭代历史（旧 retrieval 范式下的 v1-v7、M1-M15）已归档到 [milestones/history.md](milestones/history.md)，与当前产品方向不再相关。

### 汇总

| 版本 | 核心方向 | 状态 | 里程碑 |
| ---- | ---- | ---- | ---- |
| v1 | write 能力——10 种结构化文档生成 | 已实现 | M1 |
| v2 | learn 体系——5 stage pipeline + entropy gate | 进行中 | M2-M4 |

### 版本详情

#### v1 — write 能力（已实现）

- **战略意图**: 提供结构化文档生成能力，10 种类型（roadmap / capabilities / ops / marketing / arch / ui / schema / decision / prd / tech）+ 模板 + sufficiency gate + 数据置信规则
- **状态**: write 管线已实现，workflows/write.md 可用

#### v2 — learn 体系（进行中）

- **战略意图**: 把 know 重新定位为"高熵知识单元 authoring + 生态原生载体"，对齐 Claude Code 加载机制；保留独有的 authoring 纪律和 entropy gate；命令面收敛至 learn + write 双入口
- **当前状态**: workflows/learn.md 已设计完成（5 stage：detect → gate → refine → locate → write），待 dogfood 验证
- **投入产出**: 26h 开发 + 30 天 dogfood → 预期消除运行时检索基础设施维护负担，把工程预算挪到 entropy gate 与位置决策的打磨
- **风险与依赖**: entropy gate 5 道能否稳定拒绝低熵；位置决策（project/module/user）依赖 AI 推荐质量；user level 升级需要真实跨项目证据
- **成功指标**: 30 天 dogfood，累计 ≥30 条规则，entropy gate 拒绝率 ≥20%，AI 后续会话主动遵守 ≥1 例

**核心指标**（基线 → v2）：

| 指标 | 基线 | v2 目标 | 来源 |
| ---- | ---- | ---- | ---- |
| 持久化文件格式 | — | markdown only（## know YAML block） | 架构设计 |
| 入口命令数 | — | 2（learn / write） | 收敛 |
| learn stage 数 | 0 | 5（detect/gate/refine/locate/write） | 设计 |
| entropy gate 数 | 0 | 5（信息熵/复用/可触发/可执行/失效） | 设计 |
| entropy gate 拒绝率 | — | ≥20%（dogfood 30 天目标） | 待 dogfood 实测 |

## 3. 里程碑

| # | 版本 | 核心方向 | 状态 | 完成日期 |
| ---- | ---- | ---- | ---- | ---- |
| M1 | v1 | write 能力交付：10 种文档类型 + 模板 + sufficiency gate + 数据置信规则 | 已完成 | 2025-04-09（详细演化见 [history.md](milestones/history.md)） |
| M2 | v2 | learn pipeline 设计：5 stage（detect/gate/refine/locate/write）+ entropy gate + locate 脚本化 | 已完成 | 2026-04-27 |
| M3 | v2 | dogfood 启动：≥10 条规则写入，gate 运转验证，各 level 各 ≥1 条 | 未开始 | — |
| M4 | v2 | dogfood 验证（30 天）：≥30 规则、entropy 拒绝率 ≥20%、AI 主动遵守 ≥1 例 | 未开始 | — |
