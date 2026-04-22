# know lifecycle 技术方案

## 1. 背景

### 技术约束

- 事件记录: 嵌入现有命令内部，不依赖 AI 主动调用
- events.jsonl: 追加写入（append-only），不修改历史事件
- know-ctl.sh: 纯 bash + jq，不引入新依赖
- 事件关联: 用 summary 子串匹配关联到 index.jsonl 条目，不引入 ID 系统

### 前置依赖

- know-ctl.sh append/hit/update/decay/delete 命令 — 已完成
- index.jsonl schema — 已完成
- M1 metrics 方案（lifecycle 在此基础上扩展事件粒度） — 已完成

## 2. 方案

### 文件/模块结构

- `scripts/know-ctl.sh` — CLI 入口，新增 cmd_history + emit_event 辅助函数；cmd_append/cmd_hit/cmd_update/cmd_decay/cmd_delete 内嵌事件记录
- `.know/events.jsonl` — 事件日志，每行一个事件（ts + event + summary）
- `.know/index.jsonl` — 知识条目索引，新增 last_hit 字段辅助 review 判断
- `workflows/review.md` — review Step 2 表格增加生命阶段列

### 核心流程

1. 知识操作触发事件记录：cmd_append → emit_event("created") / cmd_hit → emit_event("hit") + 更新 last_hit / cmd_update → emit_event("updated") / cmd_decay → emit_event("demoted"或"deleted")
2. `know-ctl history "keyword"` 调用时 → 按 summary 子串匹配 events.jsonl → 时间正序输出匹配事件列表
3. review Step 2 读取 index.jsonl 的 hits + last_hit + created 字段 → 按 4 级规则标注生命阶段（新建🆕 / 活跃✅ / 沉默💤 / 濒危⚠）

### 数据结构

| 字段 | 类型 | 用途 |
|------|------|------|
| ts | string | 事件时间戳，YYYY-MM-DD 格式 |
| event | string | 事件类型：created/hit/updated/demoted/deleted |
| summary | string | 关联条目的 summary，用于子串匹配 |

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 事件关联方式 | summary 子串匹配 | 引入 UUID ID 系统增加复杂度且需迁移现有数据，summary 匹配与现有 hit/delete/update 命令的匹配方式一致 |
| 事件存储格式 | JSONL 追加写入 | SQLite 引入二进制依赖，JSONL 与 index.jsonl 格式一致且 jq 可查询 |
| last_hit 字段位置 | index.jsonl 内部 | 放 events.jsonl 需要 review 时额外读取和聚合事件日志，放 index 内可直接判断阶段无需跨文件查询 |
| 生命阶段分级 | 4 级（新建/活跃/沉默/濒危） | 2 级区分度不够无法识别"沉默但未濒危"状态，5+ 级增加认知负担，4 级覆盖完整生命周期且标注简洁 |

## 4. 迭代记录

### 2026-04-13

- tech 方案设计完成（events.jsonl 存储结构、5 种事件类型、emit_event 辅助函数、cmd_history 命令、review 生命阶段标注）
