# know-ctl CLI 接口规范

## 1. 概述

### 范围

know-ctl.sh 是 know 知识库的 CLI 管理接口，提供条目增删改查、命中追踪、衰减清理、质量度量，支持 `project` / `user` 双 level。

### 调用方

- Claude Code agent（通过 workflow 文件中的 bash 命令调用）
- 终端用户（手工运行 `bash scripts/know-ctl.sh <cmd>`）

### 协议类型

CLI

## 2. 路径与 Level

### 物理布局

```
$PROJECT_DIR/docs/                     文档（git 跟踪，由 write 管线生成）
$XDG_DATA_HOME/know/projects/{id}/     level=project（按项目隔离）
  ├── index.jsonl                      11 字段 JSONL
  ├── entries/{tag}/{slug}.md          详情文件（tier=1 only）
  ├── events.jsonl                     生命周期事件
  └── metrics.json                     聚合计数
$XDG_DATA_HOME/know/user/              level=user（跨项目共享，结构同上）
```

`{id}` = 项目绝对路径 `/` → `-`。`$XDG_DATA_HOME` 默认 `~/.local/share`。

### Level 语义

| 值 | 适用 | 由什么决定 |
|---|---|---|
| `project` | 项目专属知识（架构、约束、局部决策） | 默认写入目标；路径按项目 id 隔离 |
| `user` | 跨项目方法论（编码风格、通用经验） | 通过 `--level user` 显式写入；workflow 层二次确认 |

## 3. 数据结构

### Entry 字段（index.jsonl 每行一条 JSON）

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| tag | string | 是 | 枚举：`insight`（决策原因+心智模型）、`rule`（约束）、`trap`（踩坑） |
| tier | int | 是 | `1`=critical（不知道会产出编译失败/数据丢失的代码）、`2`=memo（会走弯路但能发现） |
| scope | string \| string[] | 是 | keypath，点分段（如 `Auth.session`、`methodology.general`），前缀匹配 |
| tm | string | 是 | 枚举：`guard`（recall 时 warn/block）、`info`（recall 时 suggest） |
| summary | string | 是 | `{结论} — {原因}`，≤80 字符，含可搜索锚词 |
| path | string \| null | 否 | 详情文件相对路径 `entries/{tag}/{slug}.md`；memo 为 null |
| hits | int | 否 | 被命中次数，默认 0 |
| revs | int | 否 | 修订次数，默认 0 |
| source | string | 否 | `learn` / `extract` |
| created | string | 是 | 创建日期 `YYYY-MM-DD` |
| updated | string | 是 | 最后更新日期 `YYYY-MM-DD` |

**Level 不在 entry 里**，由存储路径隐式决定；`query` / `search` 输出会补一个 `_level` 字段（`"project"` 或 `"user"`）供下游识别。

## 4. 接口定义（13 子命令）

所有子命令接受 `--level project|user`。**读类**（query / search / stats / history / decay / init）不传 `--level` 时默认作用在两 level 合并；**写类**（append / update / delete / hit）不传 `--level` 时默认 project。

### append

- **路径**: `bash know-ctl.sh append '<json>' [--level L]`
- **参数**:

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| json | string (JSON) | 是 | 完整 entry JSON（11 字段中至少 5 个必填） |
| --level | enum | 否 | 默认 `project` |

- **响应**: `Appended [project|user]: <summary>`
- **错误**: exit 1（缺 tag/tier/scope/summary/updated 任一；JSON 解析失败）

### query

- **路径**: `bash know-ctl.sh query <scope> [--level L] [--tag t] [--tier n] [--tm m]`
- **参数**:

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| scope | string | 是 | 前缀匹配；`project` 返回全部 |
| --level | enum | 否 | 缺省时两 level 合并 |
| --tag / --tier / --tm | | 否 | 精确过滤 |

- **响应**：每行一条 JSON（带 `_level` 字段），无匹配时空输出

### search

- **路径**: `bash know-ctl.sh search <pattern> [--level L]`
- **参数**: pattern 是 summary 字段的正则（大小写不敏感）；`--level` 缺省合并
- **响应**: 同 query 输出格式

### hit

- **路径**: `bash know-ctl.sh hit <path-or-keyword> [--level L]`
- **参数**: target 以 `entries/` 开头走 path 精确匹配，否则走 summary 正则；`--level` 缺省 project
- **响应**: 无标准输出。副作用：hits +1、updated=今天、events 记录 hit 事件

### delete

- **路径**: `bash know-ctl.sh delete <keyword> [--level L]`
- **响应**: `Deleted N entry [project|user]`；删除索引行 + 详情文件

### update

- **路径**: `bash know-ctl.sh update <keyword> '<json-patch>' [--level L]`
- **响应**: `Updated N entry [project|user] (revs incremented)`

### decay

- **路径**: `bash know-ctl.sh decay [--level L]`
- **行为**: 两 level 各自独立衰减
- **策略**:

| 条件 | 动作 |
|---|---|
| tier=2 + hits=0 + age>30d | 删除 |
| tier=1 + hits=0 + age>180d | 降级为 tier=2 |

- **响应**: `Decay [{level}]: {N} deleted, {M} demoted` 每 level 一行

### stats

- **路径**: `bash know-ctl.sh stats [--level L]`
- **响应**: 两 level 分段输出；按 tier/tag/scope 计数

### metrics

- **路径**: `bash know-ctl.sh metrics [--level L]`
- **响应**: 命中率 / 衰减率 / 防御次数 / 覆盖率 / 文档覆盖 / Recall Run 面板 + 建议；默认只看 project；跨 level 聚合视图尚未实现

### history

- **路径**: `bash know-ctl.sh history <keyword> [--level L]`
- **响应**: `{date}  [{level}] {event}  {summary}`

### recall-log

- **路径**: `bash know-ctl.sh recall-log <scope> <matched>`
- **行为**: 固定写入 project events.jsonl；不接受 `--level`
- **响应**: 无输出

### init

- **路径**: `bash know-ctl.sh init [--level L]`
- **行为**: 创建两 level 的目录骨架；检测到项目内残留 `.know/` 时打印迁移命令
- **响应**: `Initialized [project|user]: <path>` 每 level 一行

### self-test

- **路径**: `bash know-ctl.sh self-test`
- **行为**: 在 `XDG_DATA_HOME=$TMPDIR` 隔离环境跑 29 项断言，覆盖两 level 隔离、合并查询、指定 level 写入
- **响应**: `✓ All N tests passed` 或 `✗ N/M tests failed`

### check

- **路径**: `bash know-ctl.sh check`
- **行为**: 对 `$PROJECT_DIR/docs/` 每个 md 文件，按文件名匹配 `workflows/templates/{name}.md` 模板，对比 section 结构偏差
- **响应**: 一致 / 偏差清单

## 5. 约束与规则

- append 校验 5 个必填字段：tag / tier / scope / summary / updated，缺任一则 exit 1
- 所有日期字段必须 `YYYY-MM-DD`
- index.jsonl 每行必须是合法 compact JSON
- scope 支持 string 或 string[]，query 前缀匹配
- hit 的 target：`entries/` 开头走 path 精确，否则走 summary 正则（大小写不敏感）
- decay：tier=2+hits=0+>30d 删除；tier=1+hits=0+>180d 降级
- 写入 user level 不经 workflow 时不触发二次确认（CLI 直写保持幂等）；workflow 层（learn Step 8）必须先问确认
- 旧 `.know/` 路径**不读**；`init` 检测到残留会打印迁移命令，do not auto-migrate

## 6. 示例

**写入项目级条目**

```bash
bash know-ctl.sh append '{"tag":"rule","tier":1,"scope":"Auth.session","tm":"guard","summary":"session 过期必须触发刷新而非拒绝 — 避免用户静默登出","path":"entries/rule/session-refresh.md","hits":0,"revs":0,"source":"learn","created":"2026-04-22","updated":"2026-04-22"}'
# → Appended [project]: session 过期必须触发刷新而非拒绝 — 避免用户静默登出
```

**写入用户级方法论**（需 workflow 层确认，CLI 直写演示）

```bash
bash know-ctl.sh append --level user '{"tag":"insight","tier":2,"scope":"methodology.general","tm":"info","summary":"PR 拆分应按可独立 review 的粒度 — 大 PR 降低 review 质量","path":null,"hits":0,"revs":0,"source":"learn","created":"2026-04-22","updated":"2026-04-22"}'
# → Appended [user]: PR 拆分应按可独立 review 的粒度 — 大 PR 降低 review 质量
```

**合并查询**

```bash
bash know-ctl.sh query "methodology"
# → {"tag":"insight",...,"_level":"user"}
```
