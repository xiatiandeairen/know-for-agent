# know-ctl CLI 接口规范（v7）

## 1. 概述

### 范围

know-ctl.sh 是 know 知识库的 CLI 管理接口，操作 8 字段 trigger schema 与 3 JSONL 文件布局。支持 `project` / `user` 双 level。

### 调用方

- Claude Code agent（通过 workflow）
- 终端用户（手工运行 `bash scripts/know-ctl.sh <cmd>`）

### 协议类型

CLI

## 2. 存储布局

### 3 个文件

```
<project>/docs/triggers.jsonl          project source（git-tracked）
$XDG_CONFIG_HOME/know/triggers.jsonl   user source（默认 ~/.config/know/；dotfiles-git 可选）
$XDG_DATA_HOME/know/events.jsonl       runtime events（默认 ~/.local/share/know/；per-machine）
```

### Level 语义

| 值 | 存储位置 | 说明 |
|---|---|---|
| `project` | `<project>/docs/triggers.jsonl` | 项目专属；随项目 git 走；团队共享 |
| `user` | `$XDG_CONFIG_HOME/know/triggers.jsonl` | 跨项目通用；用户私有；可手动同步 |

## 3. 数据结构

### Trigger Schema（8 字段）

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| tag | string | 是 | 枚举：`insight`（决策/心智模型）、`rule`（约束）、`trap`（踩坑）。选择优先级：trap > rule > insight |
| scope | string \| string[] | 是 | keypath（如 `Auth.session`）；支持**双向前缀匹配**（entry.scope startsWith query OR query startsWith entry.scope）|
| summary | string | 是 | ≤80 chars，`{结论} — {原因}` |
| strict | bool \| null | 是 | `tag=rule` 时必须是 bool；其他 tag 必须 null |
| ref | string \| null | 否 | context 引用：`docs/x.md#a` / `src/f:42` / `https://...` / null |
| **keywords** | **string[] \| null** | 否 | **语义匹配用；每项 `^[a-z0-9-]+$`（长度 2-40）；learn 从动态词表选；既有可为 null（兼容）** |
| source | string | 是 | `learn` \| `extract` |
| created | string | 是 | `YYYY-MM-DD` |
| updated | string | 是 | `YYYY-MM-DD` |

### Event Schema（runtime, events.jsonl）

| 字段 | 类型 | 说明 |
|---|---|---|
| ts | string | `YYYY-MM-DD` |
| project_id | string | `$PROJECT_DIR` 绝对路径 `/` → `-` |
| level | string | `project` \| `user`（命中的 trigger 所属 level）|
| event | string | `created` / `updated` / `deleted` / `hit` / `recall_query` |
| summary | string | 触发 event 的 trigger summary |
| scope | string | 仅 `recall_query` 事件 |
| matched | int | 仅 `recall_query` 事件 |
| keywords | array\|null | 仅 `recall_query`；查询传入的关键词；旧事件为 null |
| kw_hits | int | 仅 `recall_query`；匹配 entries 的 `_kw_hits` 总和；旧事件为 0 |

## 4. 接口定义（14 子命令）

所有子命令（除 `recall-log` / `decay` / `check` / `self-test` / `migrate-v7`）接受 `--level project|user`。

**读类**（`query` / `search` / `stats` / `history`）不传 `--level` 时默认扫两 level 合并。

**写类**（`append` / `update` / `delete` / `hit`）不传 `--level` 时默认 project。

### init

- **路径**: `bash know-ctl.sh init [--level L]`
- **行为**: 创建 triggers.jsonl 空文件 + events.jsonl；检测 v6 数据时打印 migrate-v7 提示
- **响应**: 每 level 一行 `Initialized [level]: <path>`

### append

- **路径**: `bash know-ctl.sh append '<json>' [--level L]`
- **校验**: 必填 tag/scope/summary/source/created/updated；strict 规则（rule→bool；其他→null）
- **副作用**: append 到 triggers.jsonl；emit `created` event
- **响应**: `Appended [level]: {summary}`
- **错误**: exit 1（schema 无效）

### query

- **路径**: `bash know-ctl.sh query <scope> [--level L] [--tag t] [--keywords k1,k2,k3]`
- **响应**: JSONL，每行 trigger + `_level` + `_kw_hits`（keywords 命中数）字段；按 `_kw_hits` 降序排列
- **匹配**:
  - Scope 双向前缀（v7.3）：entry.scope startsWith query OR query startsWith entry.scope
  - Keywords 交集（若传 `--keywords`）：trigger.keywords ∩ query_keywords ≥ 1 → 命中
  - 两者 OR 关系（任一命中即进候选）；同时 tag 过滤（若传 `--tag`）
- **注意**: `scope="project"` 不再是特例（v7.3 删除），按字面前缀匹配（实际无 trigger 以 "project" 为 scope，故一般返空）

### keywords（新增 v7.3）

- **路径**: `bash know-ctl.sh keywords [--level L]`
- **响应**: 动态词表——聚合所有 triggers 的 keywords 字段，按使用次数降序输出
- **格式**: 每行 `{keyword} ({count})`
- **用途**: learn 时 Claude 先查词表优先复用；recall 时 Claude 从词表选 task keywords

### retag-keywords（新增 v7.3）

- **路径**: `bash know-ctl.sh retag-keywords [--level L]`
- **响应**: 列出所有 `keywords=null` 或空的既有 triggers；提示手动补 keywords 的命令
- **用途**: 旧 v7.x 数据逐条回补 keywords

### search

- **路径**: `bash know-ctl.sh search <pattern> [--level L]`
- **匹配**: summary 字段正则（大小写不敏感）

### hit

- **路径**: `bash know-ctl.sh hit <keyword> [--level L]`
- **副作用**: 只 emit `hit` event；**不修改 triggers.jsonl**（hits 字段已移除）
- **错误**: exit 1（无匹配）

### update

- **路径**: `bash know-ctl.sh update <keyword> '<json-patch>' [--level L]`
- **副作用**: 改 triggers.jsonl + emit `updated` event + 更新 updated 字段为今天

### delete

- **路径**: `bash know-ctl.sh delete <keyword> [--level L]`
- **副作用**: 删 triggers.jsonl 行 + emit `deleted` event

### decay（v7: no-op）

- **路径**: `bash know-ctl.sh decay`
- **响应**: `[decay] 已推延到下个 sprint（v7 schema 简化完成，衰减策略将在 v7.x 重做）`

### stats

- **路径**: `bash know-ctl.sh stats [--level L]`
- **响应**: 两 level 分段；每 level 按 tag / scope 计数 + rule 的 strict hard/soft 分布

### metrics

- **路径**: `bash know-ctl.sh metrics [--level L]`
- **行为**: 从 events.jsonl 实时 derived
- **输出**: 命中率、防御次数（hits on rule+strict=true）、Recall Run（recall_query 触发/命中/空查）+ 建议

### history

- **路径**: `bash know-ctl.sh history [keyword] [--level L]`
- **响应**: `{date}  [{level}] {event}  {summary}` 每行
- **过滤**: keyword 是 summary 正则；`--level` 限定 event 来源

### recall-log

- **路径**: `bash know-ctl.sh recall-log <scope> <matched> [--level L] [--keywords k1,k2,k3] [--kw-hits N]`
- **副作用**: emit `recall_query` event（带 scope / matched / keywords / kw_hits）；`--level` 默认 project
- **向后兼容**: 不传 `--keywords` → `keywords=null`；不传 `--kw-hits` → `kw_hits=0`

### report-recall

- **路径**: `bash know-ctl.sh report-recall [--days N] [--level L]`
- **行为**: 按 `--days`（默认 7）窗口 + 当前 project_id + level 过滤 recall_query events，输出 markdown
- **字段**: Summary 表（total/hit/empty/with-kw/avg kw_hits）+ Top scopes + Top keywords

### check

- **路径**: `bash know-ctl.sh check`
- **行为**: 扫 `<project>/docs/` 每个 md，对比 `workflows/templates/{name}.md` section 结构

### self-test

- **路径**: `bash know-ctl.sh self-test`
- **行为**: `XDG_CONFIG_HOME` 和 `XDG_DATA_HOME` 都隔离到 tmpdir；跑 33+ 项断言
- **覆盖**: init / append 合法+非法（8 字段 + strict 规则）/ query / search / hit / update / delete / stats / metrics / history / recall-log / decay no-op / event 含 project_id+level

### migrate-v7

- **路径**: `bash know-ctl.sh migrate-v7 [--dry-run]`
- **行为**: 读 v6 `$XDG_DATA_HOME/know/projects/{id}/{index.jsonl,entries,events.jsonl}` 和 `/user/`：
  1. Schema 转换：删 tier/tm/path/hits/revs；按规则填 strict；path→ref（归并 detail md 到 `docs/legacy-v6-details.md` 的 anchor 段）
  2. 写入 `<project>/docs/triggers.jsonl` + `$XDG_CONFIG_HOME/know/triggers.jsonl`
  3. 合并 events 到 `$XDG_DATA_HOME/know/events.jsonl`，每行补 project_id + level 字段
  4. legacy 数据不自动删，脚本结束打印 `rm -rf` 命令让用户确认

## 5. 约束与规则

- append 校验 6 必填字段（tag/scope/summary/source/created/updated）
- strict 硬规则：`tag=rule` 必须 bool；`tag=insight|trap` 必须 null
- ref 值必须是 string 或 null
- 所有日期 `YYYY-MM-DD`
- triggers.jsonl 每行必须合法 compact JSON
- scope 前缀匹配（startsWith）
- hit 只动 events.jsonl，不触碰 triggers.jsonl
- decay 在 v7 为 no-op，命令存在但无动作
- legacy v6 数据不读；`init` 检测到时提示 migrate-v7

## 6. 示例

**写入 project rule（硬约束）**

```bash
bash know-ctl.sh append '{"tag":"rule","scope":"Auth.session","summary":"session 过期必须触发刷新而非拒绝 — 避免静默登出","strict":true,"ref":"docs/decision/auth.md#session-refresh","source":"learn","created":"2026-04-22","updated":"2026-04-22"}'
# → Appended [project]: session 过期必须触发刷新而非拒绝 — 避免静默登出
```

**写入 user insight（跨项目方法论）**

```bash
bash know-ctl.sh append --level user '{"tag":"insight","scope":"methodology.general","summary":"PR 拆分按独立 review 粒度 — 大 PR 降低 review 质量","strict":null,"ref":null,"source":"learn","created":"2026-04-22","updated":"2026-04-22"}'
# → Appended [user]: PR 拆分按独立 review 粒度 — 大 PR 降低 review 质量
```

**非法：rule 但 strict=null**

```bash
bash know-ctl.sh append '{"tag":"rule","scope":"X","summary":"bad","strict":null,"ref":null,"source":"learn","created":"2026-01-01","updated":"2026-01-01"}'
# → Error: schema invalid (exit 1)
```

**合并查询**

```bash
bash know-ctl.sh query "Auth"
# → {"tag":"rule",...,"_level":"project"}
# → {"tag":"insight",...,"_level":"user"}
```
