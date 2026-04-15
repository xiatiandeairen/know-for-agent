# Recall 完整逻辑必须在 SKILL.md
## Why
Recall 是被动触发的（AI 改代码前自动执行），不经过 /know 命令，不会加载 workflow 文件。如果 Recall 的 scope 推断、query 命令、suggest/warn/block 逻辑不在 SKILL.md，recall 会失效。
## Rejected alternatives
Recall 逻辑放 learn.md — 日常编码不触发 learn，recall 永远不执行。
## Constraints
Tag/tier/tm 在 SKILL.md 只需一行速查表（defensive=warn/block, directive=suggest, passive=不主动）。完整定义放 learn.md 供 Assess 使用。
