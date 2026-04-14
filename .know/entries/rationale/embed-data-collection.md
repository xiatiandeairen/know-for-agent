# 数据收集嵌入现有命令，不独立调用

metrics 和 lifecycle 的数据收集（total_created, queried_scopes, events）全部嵌入 append/query/hit/decay/delete 内部，不需要 AI 额外调用 record_created 或 record_query。

## Why

独立调用依赖 AI 在 SKILL.md 指令中记住"query 后调 record_query"，AI 可能忘记，导致数据丢失。嵌入现有命令后数据收集是自动的。

## Rejected alternatives

record_created / record_query 独立命令 — 设计过但发现依赖 AI 行为不可靠，改为合并进 append/query。
