# Know 架构设计

## 1. 定位与边界

### 职责

项目隐性知识的持久化与结构化文档生成，为 AI agent 提供跨会话、跨项目的知识记忆和文档编写能力。

### 不负责

- 代码修改与执行（→ agent 本身的 Edit/Bash 工具）
- 任务调度与编排（→ sprint skill）
- 知识条目的语义理解与推理（→ Claude 模型能力，know 只做存取和触发）
- 持久进程或后台服务（→ 无，所有操作为无状态脚本调用）

## 2. 结构与交互

### 组件图

```
[SKILL.md 路由]  --dispatch--> [Workflow 文件]      [know-ctl.sh CLI]
  解析 /know 命令                 5 个管线定义         13 个子命令
  关键词匹配分发                  各含完整步骤链        --level project|user
       |                              |                      |
       |                              +--- # [RUN] ----------+
       v                                                      v
[Recall 系统]                                  [docs/ 项目根]（Git 跟踪）
  编辑前自动触发                                  结构化文档（11 类）
  两 level 合并查询                               roadmap/prd/tech/arch/...
  [project]/[user] 标注
                                                [$XDG_DATA_HOME/know/]
[Decay 系统]                                    知识库（Git 外、按 user 隔离）
  learn 入口时运行                                projects/{id}/  level=project
  两 level 各自衰减                                 index.jsonl entries/
                                                    events.jsonl metrics.json
                                                user/             level=user
                                                    （同上，跨项目共享）
```

### 组件表

| 组件 | 职责 | 边界规则 |
|------|------|---------|
| SKILL.md 路由 | 解析 `/know` 输入并分发到对应 workflow | 禁止包含管线执行逻辑；通过关键词匹配或会话扫描决定目标 |
| Workflow 文件 | 定义单个管线的完整步骤链（learn 10 步、write 8 步、review 3 步、extract 5 步） | 禁止跨管线调用；通过 `# [RUN]` 调用 know-ctl.sh；user 写入必须二次确认 |
| know-ctl.sh | 对两 level 目录执行原子 CRUD（13 个子命令） | 禁止包含业务判断；读类命令默认两 level 合并（带 `_level` 字段），写类默认 project |
| Recall 系统 | 编辑前自动查询相关知识并提示 | 两 level 合并查询；同 scope 匹配 project > user；max 3 条 |
| Decay 系统 | 在 learn 入口清理过期条目 | 两 level 独立衰减；禁止删除 tier=1 且 age<180d 的条目 |
| docs/ 文档层 | 项目结构化文档（随项目仓库版本化） | 位于项目根 `docs/`，git 跟踪；write 管线生成 |
| 知识库层 | 项目级 + 用户级双存储 | 位于 `$XDG_DATA_HOME/know/`（不在项目树内）；按 project-id 隔离；user 跨项目共享 |

### 数据流

```
用户输入 --/know cmd--> SKILL.md --workflow--> Workflow
                                                  |
                               know-ctl append --level {project|user}
                                                  |
                                                  v
                        $XDG_DATA_HOME/know/{projects/{id}|user}/index.jsonl
                                                  |
          know-ctl query <scope> <---recall触发---+ (两 level 合并扫描)
                    |                              |
           JSONL 行 (带 _level) --rank--> [recall] [project]/[user] 前缀输出
                                                  |
          know-ctl decay <---learn入口触发---------+ (两 level 各自)
                    |
           删除/降级 --> events.jsonl (append-only, 各 level 独立)
                        metrics.json (各 level 独立计数)

write 管线 --> docs/{type}.md | docs/{type}/{topic}.md | docs/requirements/{req}/
         （位于项目根，不在 XDG）
```

| 来源 | 目标 | 数据格式 | 类型 | 说明 |
|------|------|---------|------|------|
| Workflow | index.jsonl (对应 level) | JSONL (11 字段) | 强 | learn/extract 写入知识条目；--level 决定写哪个 |
| index.jsonl (两 level) | Recall 系统 | JSONL + `_level` 字段 | 强 | 默认两 level 合并；无任一 index 静默跳过 |
| Workflow | docs/ | Markdown | 强 | write 生成；位于项目根，随 git 版本化 |
| know-ctl.sh | events.jsonl | JSONL 事件记录 | 弱 | append-only 审计；各 level 独立 |
| know-ctl.sh | metrics.json | JSON 计数 | 弱 | 聚合指标；当前各 level 独立（跨 level 聚合未做） |
| templates/ | Workflow | Markdown 模板 | 强 | write 依赖模板生成文档骨架 |

## 3. 设计决策

### 驱动因素

| 因素 | 类型 | 对架构的影响 |
|------|------|------------|
| Claude Code skill 不支持持久进程 | 技术约束 | 所有状态持久化到文件，无后台服务 |
| 知识跨会话存活 | 业务需求 | 文件级持久化层；不能依赖内存或会话上下文 |
| 方法论跨项目复用 | 业务需求 | 引入 user level；XDG 存储位于项目外 |
| Skill 上下文窗口有限 | 技术约束 | SKILL.md 只放路由和常驻定义，详细步骤按需加载到 workflow |
| 知识召回不能阻断正常开发 | 质量要求 | recall 两 level 合并但"提示而非阻断"，max 3，降级（block→warn→suggest） |
| 部署环境为纯文件系统 | 技术约束 | JSONL + Markdown，bash + jq，零外部依赖 |
| 文档需随代码走 Git/IDE 工具链 | 业务需求 | `docs/` 放项目根（而非 XDG），git 跟踪；知识库不污染仓库 |

### 关键选择

| 决策 | 选择 | 被拒方案 | 为什么 |
|------|------|---------|--------|
| 存储格式 | JSONL 纯文本 | SQLite | SQLite 需要编译依赖；JSONL 可直接 grep，部署零依赖 |
| 文档位置 | 项目根 `docs/` | `.know/docs/`（重构前） | docs 属于项目，应跟 git / IDE / PR diff 工具链；知识库缓存不属于 |
| 知识库位置 | `$XDG_DATA_HOME/know/` | 项目内 `.know/` | 知识库是 per-user state，不应污染项目仓库；符合 XDG 规范 |
| 作用域分层 | `level=project\|user`（物理目录分） | 在 index.jsonl 加 level 字段 | 物理隔离天然独立；查询/迁移/权限更清晰 |
| 合并查询语义 | 默认 read 两 level 合并、write 只 project | 默认 project-only | 读场景希望所有知识都能帮到手；写场景安全默认（user 影响所有项目） |
| user 写入保护 | workflow 层二次确认 | CLI 层阻塞 | CLI 要保持幂等可脚本化；workflow 知道语境，适合做交互 |
| 管线定义方式 | 独立 workflow 文件 | 全写在 SKILL.md | SKILL.md 膨胀会占满上下文；按需加载控 token |
| CLI 实现 | Bash 脚本 | Python/Node | Bash 原生可用，无运行时依赖 |
| recall 触发 | 编辑前自动 | 用户手动 | "不知道自己不知道"必须主动提醒 |

### 约束

- 禁止引入外部数据库或运行时依赖（仅 bash + jq）
- 禁止 SKILL.md 包含管线执行逻辑（上下文窗口有限）
- 必须所有操作幂等或 append-only（无持久进程，步骤可能中断后重试）
- 禁止 recall 对同一 scope 在同一会话内重复查询
- 写入 user level 必须经 workflow 层二次确认
- 旧 `.know/` 目录不再读取；迁移由用户手工完成（`know-ctl init` 检测后提示）

## 4. 质量要求

| 属性 | 指标 | 目标 |
|------|------|------|
| 知识存活率 | 已创建条目中未被 decay 清除的比例 | >80%（当前实测：project 100%，user 未投入使用） |
| recall 精准度 | 召回条目中与当前操作相关的比例 | >70%（目标值，待验证） |
| 管线执行时间 | 单次 know-ctl 子命令耗时 | <500ms p95（目标值，待验证） |
| 存储可读性 | index.jsonl 可直接用 grep/jq 查询 | 100%（设计保证） |
| 文档覆盖率 | 里程碑中有配套 PRD 的比例 | >80%（目标值，待验证） |
| 两 level 隔离 | self-test 中 append/delete 互不影响 | 100%（29/29 self-test 覆盖） |
