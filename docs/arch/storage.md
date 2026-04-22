# Storage 架构设计（v7）

## 1. 定位与边界

### 职责

定义 know 知识库的 3 文件存储布局：把项目 source、用户 source、运行时 state 三类数据分放不同位置，为 CLI 提供确定的 level→path 映射，为 workflow 提供"写哪里、读哪里"的决策依据。

### 不负责

- 条目的字段定义（→ learn workflow + schema/know-ctl.md）
- 合并查询的 rank 策略（→ recall 架构）
- 旧 `.know/` 和 v6 XDG 数据的自动搬迁（用户运行 `know-ctl migrate-v7`）
- 文件级并发写锁（append-only 容忍单机并发）

## 2. 结构与交互

### 组件图

```
[路径变量层]                           [level 路由]
  PROJECT_DIR   → <project>/            level_to_triggers():
  PROJECT_TRIGGERS = docs/triggers.jsonl    project → PROJECT_TRIGGERS
  USER_TRIGGERS                             user    → USER_TRIGGERS
    = $XDG_CONFIG_HOME/know/
      triggers.jsonl
  EVENTS_FILE
    = $XDG_DATA_HOME/know/
      events.jsonl

[三个 JSONL 文件]                      [Legacy 检测]
  (1) docs/triggers.jsonl                 init 时扫：
      project source                       $XDG_DATA_HOME/know/projects/{id}
      git-tracked                          $XDG_DATA_HOME/know/user
                                         命中提示 migrate-v7
  (2) $XDG_CONFIG/know/triggers.jsonl
      user source
      per-user（dotfiles-git 可选）

  (3) $XDG_DATA/know/events.jsonl
      runtime events
      per-machine（永不 git）
      每行带 project_id + level
```

### 组件表

| 组件 | 职责 | 边界规则 |
|---|---|---|
| 路径变量层 | 定义 3 个路径 + project_id 编码 | 禁止 workflow / 子命令硬编码路径；必须通过变量引用 |
| level 路由 | level 枚举值 → triggers 文件映射 | 禁止接受 `both` 或其他值；必须在 `level_to_triggers` 集中维护 |
| 三个 JSONL 文件 | source × 2（project / user） + runtime × 1 | 禁止混用（source 不写 events；events 不存 trigger 定义） |
| Legacy 检测 | init 时识别 v6 XDG 布局并提示迁移 | 禁止自动迁移；必须只读检测 |

### 数据流

```
know-ctl append --level {X} → level_to_triggers → triggers.jsonl (对应)
                                    +
                                append event → events.jsonl (全局)

know-ctl query [--level X]  → level_to_triggers → 读 1 或 2 个文件
                              并补 _level 字段

know-ctl hit                → 仅 append event；不动 triggers.jsonl

know-ctl metrics/stats      → 扫 events.jsonl 实时派生
                              （无 metrics.json cache）

write 管线（docs 生成）      → <project>/docs/{type}.md
                              （不经 know-ctl；直写项目根）
```

| 来源 | 目标 | 数据格式 | 类型 | 说明 |
|---|---|---|---|---|
| know-ctl 写类 | triggers.jsonl | 8 字段 JSONL | 强 | append/update/delete 的 SoT |
| know-ctl 所有命令 | events.jsonl | 事件 JSONL（带 project_id + level） | 强 | runtime 统一 SoT；metrics 派生自它 |
| write 管线 | docs/ 各 md 文件 | Markdown | 强 | 不经 know-ctl |
| init | stderr | 文本提示 | 弱 | legacy 检测，仅提示 |

## 3. 设计决策

### 驱动因素

| 因素 | 类型 | 对架构的影响 |
|---|---|---|
| 项目知识是团队资产，clone 应得到 | 业务需求 | project triggers 必须在项目 git 内 |
| 方法论跨项目共享 | 业务需求 | user source 独立位置，可随用户 dotfiles 走 |
| 运行时数据 per-machine 且频繁变 | 质量要求 | 必须和 source 物理分离；不污染 git diff |
| XDG 规范语义 | 技术约束 | `CONFIG_HOME` = 用户声明；`DATA_HOME` = 派生状态 |
| 跨项目分析需求（v6 P2 延后项） | 业务需求 | events 合并为单文件 + 字段分组；摒弃目录分隔 |
| 源与派生不该并存 | 质量要求 | 删 metrics.json（从 events 派生）、删 hits 字段（同理） |

### 关键选择

| 决策 | 选择 | 被拒方案 | 为什么 |
|---|---|---|---|
| 文件数 | **3 个** | 多目录结构（v6）| 简化认知面；新项目无需创建目录 |
| project source 位置 | `<project>/docs/triggers.jsonl` | `.know/triggers.jsonl`（另目录） | docs/ 已是"项目知识根"；独立 `.know/` 会把 trigger 工具化 |
| user source 位置 | `$XDG_CONFIG_HOME/know/triggers.jsonl` | `$XDG_DATA_HOME/know/user/` | XDG 规范：CONFIG 是用户声明，DATA 是派生；user source 是用户写的 |
| runtime 合并 | 单 events.jsonl + project_id + level 字段 | 每 project / user 独立 events 文件 | 跨项目分析天然支持；新 project 零初始化代价 |
| 派生数据缓存 | 不缓存（实时从 events 算） | 保留 metrics.json | metrics 命令 <50ms；cache 维护引入 drift 风险 |

### 约束

- 禁止子命令硬编码路径字面量（必须走 level_to_triggers / PROJECT_TRIGGERS 等变量）
- 禁止 `--level` 接受 `both` 枚举外值
- 必须用 ensure_triggers_file + ensure_events_file 初始化，不创建非必要目录
- 必须保留 `$CLAUDE_PROJECT_DIR` fallback 到 `pwd`（plugin 环境下不保证 CLAUDE_PROJECT_DIR）
- `init` 检测到 v6 XDG 布局必须打印 migrate-v7 命令（辅助迁移）

## 4. 质量要求

| 属性 | 指标 | 目标 |
|---|---|---|
| 两 level 隔离 | self-test 相关断言通过率 | 100%（当前 33/33） |
| 文件数量 | 每个 project + user 组合占用文件数 | 3（固定） |
| 路径解析稳定 | 相同 pwd 多次调用得到相同路径 | 100%（纯函数） |
| events 单文件性能 | 单次 metrics 命令扫描耗时 | <100ms（10k 事件内，目标值待验证） |
| 迁移完整性 | migrate-v7 后数据条数 = 源条数 | 100%（migrate-v7 确定性保证） |
