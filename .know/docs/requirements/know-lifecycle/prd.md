# know lifecycle

<!-- 核心问题: 需求到哪了、验收标准是什么？ -->

## 1. 问题

M1 的 metrics 提供了聚合指标（命中率 50%、衰减率 20%），但看不到单条知识的历史。用户看到一条 hits=3 的知识，不知道什么时候被命中、中间有没有更新过、是否经历过衰减。无法判断这条知识的价值趋势（越来越有用还是越来越过时）。每次 review 都面临这个盲区。

## 2. 目标用户

使用 know skill 的开发者，在 review 知识条目时需要判断单条知识的价值。

| 场景 | 痛点 |
|------|------|
| review 时看到 hits=0 | 不知道是刚创建的还是真的没用 |
| review 时看到 hits=5 | 不知道是近期密集命中还是几个月前的 |
| 想知道一条知识的完整经历 | 只有当前快照（hits/revs/created/updated），没有历史 |

当前替代方案：git log 追溯 index.jsonl 变更历史 — 噪音大，不直观，跨多次 commit 难以还原单条知识。

## 3. 核心假设

**提供单条知识的事件时间线 → 用户在 review 时能做出更准确的保留/删除决策。**

验证方式：用户在 review 中使用 history 查询后，做出 1 次基于时间线的决策（如"最近 30 天没命中过，删除"）。

## 4. 方案

- **Before**: 只看到 hits=3，不知道命中时间分布 → **After**: `know-ctl history "keyword"` 展示完整事件时间线
- **Before**: review 时无法区分"新建未用"和"长期沉默" → **After**: review 表格标注生命阶段（新建/活跃/沉默/濒危）
- **Before**: 手动删除、衰减、更新没有记录 → **After**: 每个生命周期事件自动追加到事件日志

### 事件类型

| 事件 | 时机 | 说明 |
|------|------|------|
| created | append | 条目创建 |
| hit | hit | 被 recall 命中 |
| updated | update | 内容被更新 |
| demoted | decay | 从 critical 降级为 memo |
| deleted | decay / review | 被清理删除 |

### 生命阶段（review 标注用）

| 阶段 | 条件 |
|------|------|
| 新建 | created < 7d，hits = 0 |
| 活跃 | last_hit < 30d |
| 沉默 | last_hit > 30d 或从未命中 + created > 7d |
| 濒危 | 符合 decay 删除/降级条件 |

### 任务

| 任务 | 文档 | 进度 |
|------|------|------|
| lifecycle-impl | [tech](impl/tech.md) | 1/1 |

## 5. 验收标准

- 用户运行 `know-ctl history "keyword"` → 按时间顺序展示该知识的所有事件
- 每个事件包含日期 + 事件类型 + summary
- append/hit/update/decay/delete 操作后 → 事件自动追加到 events.jsonl
- index.jsonl 的 hit 操作 → 同时更新 last_hit 字段
- `/know review` 表格 → 展示生命阶段列（新建/活跃/沉默/濒危）
- 无事件日志时 → history 输出"No events found"
- 关键词无匹配时 → history 输出"No matching entry"

## 6. 排除项

- 不支持事件日志清理/归档（推迟到 v3）
- 不支持跨项目事件聚合
- 不支持事件回溯修正（只追加，不修改历史）
