# know lifecycle 技术方案

<!-- 核心问题: 怎么实现、做到哪了？ -->

## 1. 背景

M1 metrics 提供聚合指标，但看不到单条知识的历史。需要事件日志记录完整生命周期，增强 index.jsonl 的 last_hit 字段辅助 review 判断。

技术约束：
- 事件记录嵌入现有命令，不依赖 AI 行为
- 追加写入，不修改历史
- 纯 bash + jq

## 2. 方案

### 存储：`.know/events.jsonl`

```json
{"ts":"2026-04-13","event":"created","summary":"文档树状向下索引..."}
{"ts":"2026-04-15","event":"hit","summary":"文档树状向下索引..."}
{"ts":"2026-04-20","event":"updated","summary":"文档树状向下索引..."}
```

每行一个事件。用 summary 子串匹配关联到 index.jsonl 条目。

### 事件记录嵌入

| 事件 | 嵌入命令 | 触发条件 |
|------|---------|---------|
| created | cmd_append | 每次 append |
| hit | cmd_hit | 每次 hit |
| updated | cmd_update | 每次 update |
| demoted | cmd_decay | tier 1 → 2 时 |
| deleted | cmd_decay / cmd_delete | 条目被删除时 |

辅助函数：
```bash
emit_event() {
    local event="$1" summary="$2"
    local ts=$(date +%Y-%m-%d)
    echo "{\"ts\":\"$ts\",\"event\":\"$event\",\"summary\":\"$summary\"}" >> "$EVENTS_FILE"
}
```

### index.jsonl 增强

cmd_hit 同时更新 `last_hit` 字段：
```bash
jq -c '.last_hit = "YYYY-MM-DD"'
```

已有条目无 last_hit → jq 自动补 null，不影响现有逻辑。

### 新增命令：`cmd_history`

```bash
know-ctl history "keyword"
```

按 summary 子串匹配，时间正序输出：
```
2026-04-13 created  文档树状向下索引...
2026-04-15 hit      文档树状向下索引...
2026-04-20 updated  文档树状向下索引...
```

无匹配 → `No matching events found`
events.jsonl 不存在 → `No event log`

### review 生命阶段标注

| 阶段 | 条件 | 标注 |
|------|------|------|
| 新建 | created < 7d, hits = 0 | 🆕 |
| 活跃 | last_hit < 30d | ✅ |
| 沉默 | last_hit > 30d 或 (hits=0 + created > 7d) | 💤 |
| 濒危 | 符合 decay 条件 | ⚠ |

review Step 2 表格替换原 ⚠ 列为生命阶段列。

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 事件关联方式 | summary 子串匹配 | 不引入 ID 系统，与现有 hit/delete/update 的匹配方式一致 |
| 存储格式 | JSONL 追加 | 与 index.jsonl 一致，jq 可查询 |
| last_hit 位置 | index.jsonl 内 | review 时无需读 events.jsonl，从 index 直接判断阶段 |
| 生命阶段 | 4 级 | 覆盖完整生命周期，标注简洁 |

## 4. 迭代记录

### 2026-04-13

tech 方案设计完成。
