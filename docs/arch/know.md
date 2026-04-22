# Know 系统架构

## 1. 定位与边界

### 职责

顶层整合架构：把 7 个子模块（learn / write / extract / review / recall / decay / storage）组合为"编辑前加载、对话后沉淀、代码可挖掘、定期审计"的知识闭环，为 AI agent 提供项目级 + 用户级双层记忆。

### 不负责

- 单个模块的内部组件设计（→ 各子模块独立 arch 文件）
- 模块内部字段与接口（→ schema/know-ctl.md）
- 产品需求与优先级（→ prd / roadmap）
- 代码修改执行（→ agent 的 Edit/Bash 工具）

### 子模块文件索引

| 子模块 | 类型 | 架构文件 |
|---|---|---|
| Learn | Pipeline | [learn.md](learn.md) |
| Write | Pipeline | [write.md](write.md) |
| Extract | Pipeline | [extract.md](extract.md) |
| Review | Pipeline | [review.md](review.md) |
| Recall | Always-on | [recall.md](recall.md) |
| Decay | Always-on | [decay.md](decay.md) |
| Dual-level Storage | Infrastructure | [storage.md](storage.md) |

## 2. 结构与交互

### 组件图

```
                      [SKILL.md 路由]
                      /know {cmd} 分发
                            │
         ┌──────┬────────┬──┴───┬────────┬──────┐
         ▼      ▼        ▼      ▼        ▼      ▼
      [Learn][Write][Extract][Review] [Recall][Decay]
        │      │       │       │         │      │
        └──────┴───┬───┴───────┴─────┬───┘      │
                   │                 │          │
                   ▼                 ▼          ▼
        [Storage: know-ctl.sh]  [Storage]  [Storage]
        append/update/delete    query       decay
                   │
      ┌────────────┴────────────────────────┐
      ▼                 ▼                     ▼
[$PROJECT_DIR/docs/]   [$XDG_CONFIG/know/]   [$XDG_DATA/know/]
  triggers.jsonl         triggers.jsonl       events.jsonl
  结构化 md 文档          user source         runtime (全部)
  (project source)       (跨项目共享)         带 project_id+level
  git-tracked            用户 dotfiles        per-machine
```

### 组件表

| 组件 | 职责 | 边界规则 |
|---|---|---|
| SKILL.md 路由 | 解析 `/know` 命令分发到对应 workflow | 禁止包含管线执行逻辑；必须关键词匹配或会话扫描 |
| 4 个 Pipeline（learn/write/extract/review） | 用户主动触发的结构化管线 | 各 pipeline 禁止跨调；必须通过 know-ctl 访问存储 |
| 2 个 Always-on（recall/decay） | 事件触发的后台行为 | recall 在编辑前；decay v7 no-op；禁止独立 cron |
| Storage (know-ctl.sh) | 所有模块的存储 I/O 唯一入口 | 禁止模块直访 triggers.jsonl；必须用 --level 参数显式 |
| 文档层（$PROJECT_DIR/docs/） | 项目文档 + project triggers，git 跟踪 | write 唯一写入 md；triggers 由 know-ctl 维护 |
| user source 层（$XDG_CONFIG/know/） | 用户跨项目 triggers | 只通过 know-ctl 访问 |
| 运行时层（$XDG_DATA/know/events.jsonl） | 全部事件（per-machine） | append-only；metrics/stats 实时派生 |

### 数据流

```
对话   --/know learn--> Learn   --append--> triggers.jsonl (project 或 user)
对话   --/know write--> Write   --生成 md--> $PROJECT_DIR/docs/
代码   --/know extract-> Extract --append--> triggers.jsonl (project)
存量   --/know review--> Review  --delete/update--> triggers.jsonl

编辑前 --hook--> Recall --query--> 两 level 合并 --rank--> 提示（⚠ if rule+strict=true）

所有写操作 --> events.jsonl（带 project_id + level）

learn 入口 --> Decay (v7 no-op)
```

| 来源 | 目标 | 数据格式 | 类型 | 说明 |
|---|---|---|---|---|
| 4 pipelines | Storage | JSONL CRUD + `--level` | 强 | 所有写入走同一个 CLI 入口 |
| Storage | Recall | query 结果 + `_level` | 强 | recall 依赖 level 做 rank |
| Storage | Decay | 按 level 读 index | 强 | decay 对每 level 独立运行 |
| Write | 文档层 | Markdown | 强 | 不经 know-ctl，直写项目根 |
| 各模块 | events.jsonl | append-only JSONL | 弱 | 缺失不影响业务结果 |

## 3. 设计决策

### 驱动因素

| 因素 | 类型 | 对架构的影响 |
|---|---|---|
| Claude Code skill 不支持持久进程 | 技术约束 | 所有状态持久化到文件；每次调用无状态 |
| 知识跨会话、跨项目复用 | 业务需求 | 双 level 存储 + XDG 外部路径 |
| 文档走 Git / IDE 工具链 | 业务需求 | 文档放 `$PROJECT_DIR/docs/`（不在 XDG） |
| Skill 上下文窗口有限 | 技术约束 | SKILL.md 只放路由；详细步骤按需加载到 workflow |
| recall 不可阻断编辑 | 质量要求 | 最高 warn，不真 block；max 3 条 |
| 部署环境纯文件系统 | 技术约束 | JSONL + Markdown + bash + jq，零依赖 |

### 关键选择

| 决策 | 选择 | 被拒方案 | 为什么 |
|---|---|---|---|
| 管线定义方式 | 独立 workflow 文件 | 全在 SKILL.md | 上下文窗口有限，按需加载 |
| 存储唯一入口 | know-ctl.sh CLI | 每模块直读 JSONL | 集中校验 / level 路由 / 事件记录 |
| Always-on 触发 | 事件寄生（编辑前 / learn 入口） | 独立 cron 或守护 | 无持久进程，必须搭便车 |
| 双层存储 | 物理目录隔离 | entry 加字段 | 物理边界最清晰（见 storage.md）|
| 文档位置 | 项目根 docs/ | .know/docs/ | 工具链原生支持 |

### 约束

- 禁止子模块之间直接调用（必须通过 SKILL.md 路由或 know-ctl）
- 禁止 SKILL.md 包含管线执行逻辑
- 必须所有操作幂等或 append-only（无持久进程）
- 必须 recall 对同 scope 同 session 不重复查询
- 必须 write user level 经工作流二次确认

## 4. 质量要求

| 属性 | 指标 | 目标 |
|---|---|---|
| 模块独立性 | 子模块可单独替换不影响其他 | 7/7（各有独立 arch + 接口只走 SKILL.md/know-ctl） |
| 存储一致性 | 两 level 隔离的 self-test 通过数 | 29/29（当前实测） |
| 系统响应 | 单次 /know 命令端到端耗时 | <2s p95（目标值，待验证） |
| 零依赖 | 运行时非 bash / jq / git 的外部依赖数 | 0（设计保证） |
