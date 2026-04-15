# SKILL.md 只放常驻上下文
日常编码只触发 Recall，不需要 learn/write/extract 的管线定义。
## Why
520 行 SKILL.md 每次全量加载浪费上下文。瘦身到 206 行后 Recall 信息完整，管线详情在 /know learn 时才加载。
## Rejected alternatives
在 SKILL.md 中保留所有定义 — 导致每次对话多消耗 300+ 行无用上下文。
## Constraints
Recall 依赖的 tag/tier/tm 必须保留精简版在 SKILL.md。完整定义放 learn.md Shared Definitions。
