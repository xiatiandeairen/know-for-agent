# Know 架构设计

## 1. 定位与边界

### 职责

负责项目隐性知识的持久化与结构化文档生成，为 AI agent 提供跨会话的知识记忆和文档编写能力。

### 不负责

- 代码修改与执行（→ agent 本身的 Edit/Bash 工具）
- 任务调度与编排（→ sprint skill）
- 知识条目的语义理解与推理（→ Claude 模型能力，know 只做存取和触发）
- 持久进程或后台服务（→ 无，所有操作为无状态脚本调用）

## 2. 结构与交互

### 组件图

```
[SKILL.md 路由] --dispatch--> [Workflow 文件]     [know-ctl.sh CLI]
  解析 /know 命令              5 个独立管线定义       12 个子命令
  关键词匹配分发               各含完整步骤链          操作 .know/ 文件
       |                           |                      |
       |                           +--- # [RUN] ----------+
       |                                                   |
       v                                                   v
[Recall 系统]                                     [.know/ 存储层]
  编辑前自动触发                                    index.jsonl
  查询+排序+提示                                    entries/ docs/
                                                   events.jsonl
[Decay 系统]                                       metrics.json
  learn 入口时运行
  过期清理+降级
```

### 组件表

| 组件 | 职责 | 边界规则 |
|------|------|---------|
| SKILL.md 路由 | 解析用户 `/know` 输入并分发到对应 workflow 文件 | 禁止包含管线执行逻辑；必须通过关键词匹配或会话扫描决定目标 |
| Workflow 文件 | 定义单个管线的完整步骤链（learn 8 步、write 7 步等） | 禁止跨管线调用；必须通过 `# [RUN]` 标记调用 know-ctl.sh |
| know-ctl.sh | 对 .know/ 目录执行原子 CRUD 操作（query/append/hit/delete/update/decay 等 13 个子命令） | 禁止包含业务判断逻辑；必须是纯数据操作 |
| Recall 系统 | 在代码修改前自动查询相关知识并提示 | 禁止阻断无关操作；必须 scope 推断后查询，max 3 条 |
| Decay 系统 | 在 learn 入口清理过期或低价值条目 | 禁止删除 tier=1 且 age<180d 的条目；必须遵守条件表 |
| .know/ 存储层 | 以文件形式持久化所有知识条目、事件日志、指标和文档 | 禁止引入外部数据库；必须保持 JSONL 纯文本格式 |

### 数据流

```
用户输入 --/know cmd--> SKILL.md --workflow路径--> Workflow
                                                    |
                              know-ctl append/update/delete
                                                    |
                                                    v
                                            index.jsonl (JSONL)
                                                    |
              know-ctl query <scope> <---recall触发--+
                        |                            |
                   JSONL 行 ---rank/select--> [recall] 输出
                                                    |
              know-ctl decay <---learn入口触发-------+
                        |
                   删除/降级 --> events.jsonl (append-only)
                                metrics.json (计数器)
```

| 来源 | 目标 | 数据格式 | 类型 | 说明 |
|------|------|---------|------|------|
| Workflow | index.jsonl | JSONL (12 字段 schema) | 强 | learn/extract 管线写入知识条目 |
| index.jsonl | Recall 系统 | JSONL 行经 grep 过滤 | 强 | recall 查询依赖 index 存在，无 index 静默跳过 |
| Workflow | docs/ | Markdown 文件 | 强 | write 管线生成结构化文档 |
| know-ctl.sh | events.jsonl | JSONL 事件记录 | 弱 | append-only 审计日志，缺失可降级 |
| know-ctl.sh | metrics.json | JSON 计数器 | 弱 | 聚合指标，缺失时自动初始化 |
| templates/ | Workflow | Markdown 模板 | 强 | write 管线依赖模板生成文档骨架 |

## 3. 设计决策

### 驱动因素

| 因素 | 类型 | 对架构的影响 |
|------|------|------------|
| Claude Code skill 不支持持久进程 | 技术约束 | 所有状态必须持久化到文件，无后台服务，每次调用无状态 |
| 知识跨会话存活 | 业务需求 | 需要文件级持久化层（.know/ 目录），不能依赖内存或会话上下文 |
| Skill 上下文窗口有限 | 技术约束 | SKILL.md 只放路由和常驻定义，管线详细步骤按需加载到 workflow 文件 |
| 知识召回不能阻断正常开发 | 质量要求 | recall 设计为"提示而非阻断"，max 3 条，不确定时降级（block→warn→suggest） |
| 部署环境为纯文件系统 | 技术约束 | 存储层使用 JSONL + Markdown 纯文本，CLI 用 bash + jq，零外部依赖 |

### 关键选择

| 决策 | 选择 | 被拒方案 | 为什么 |
|------|------|---------|--------|
| 存储格式 | JSONL 纯文本 | SQLite | SQLite 需要编译依赖，JSONL 纯文本可直接 grep，部署零依赖 |
| 管线定义方式 | 独立 workflow Markdown 文件 | 全部写在 SKILL.md | SKILL.md 体积膨胀会占满上下文窗口，按需加载控制 token 消耗 |
| CLI 实现 | Bash 脚本 (know-ctl.sh) | Python/Node CLI | Bash 在所有 macOS/Linux 环境原生可用，无运行时依赖 |
| recall 触发方式 | 编辑前自动触发 | 用户手动查询 | 隐性知识的价值在于"不知道自己不知道"，必须主动提醒 |
| 事件日志 | append-only JSONL | 无日志 | 可审计变更历史，append-only 避免并发写冲突 |

### 约束

- 禁止引入外部数据库或运行时依赖（部署环境为纯文件系统，仅 bash + jq 可用）
- 禁止 SKILL.md 包含管线执行逻辑（上下文窗口有限，SKILL.md 必须保持最小常驻体积）
- 必须所有操作幂等或 append-only（无持久进程意味着任何步骤可能中断后重试）
- 禁止 recall 系统对同一 scope 在同一会话内重复查询（避免重复打扰开发流程）

## 4. 质量要求

| 属性 | 指标 | 目标 |
|------|------|------|
| 知识存活率 | 已创建条目中未被 decay 清除的比例 | >80%（实测: 58 条已创建，0 条 decay，当前 100%，来源 metrics.json） |
| recall 精准度 | 召回条目中与当前操作相关的比例 | >70%（目标值，待验证） |
| 管线执行时间 | 单次 know-ctl 子命令执行耗时 | <500ms p95（目标值，待验证） |
| 存储可读性 | index.jsonl 可直接用 grep/jq 查询 | 100%（设计保证，JSONL 纯文本格式） |
| 文档覆盖率 | 里程碑中有配套 PRD 的比例 | >80%（目标值，待验证） |
