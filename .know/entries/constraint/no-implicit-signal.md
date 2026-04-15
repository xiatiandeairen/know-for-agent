# 不用隐式信号触发 know
## Rule
所有 know 操作必须通过 /know 显式入口触发，不依赖"记住这个""save this"等隐式关键词。
## Why
Claude Code 的 auto memory 在 system prompt 中，优先级高于 skill 文件。隐式关键词会被 auto memory 先拦截，知识写入 ~/.claude/memory/ 而非 .know/entries/。
## How to check
SKILL.md Input Normalization 中不应有自然语言触发行（如"记住这个" → learn）。所有入口以 /know 开头。
