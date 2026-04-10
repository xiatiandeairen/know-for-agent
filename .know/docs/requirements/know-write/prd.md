# /know write

## 问题

和 AI 讨论产品设计、技术方案后，结论散落在对话中，会话结束即丢失。`/know learn` 只写知识条目，不适合完整设计文档。

## 竞品与现状

| 方案 | 优势 | 不足 |
|------|------|------|
| 手动整理 | 完全可控 | 耗时，容易遗漏，格式不统一 |
| Notion AI / Docs AI | 有模板，协作能力强 | 脱离开发上下文，不和代码仓库联动 |
| Claude 自带 memory | 自动记忆 | 只记短条目，无结构化文档，无版本 |
| `/know learn` | 已集成，知识条目好用 | ≤220 tokens，不适合完整文档 |

**know write 的差异点**：在 AI 对话上下文中直接生成，和代码仓库同处一个 git 目录，有版本追溯，有模板约束结构。

## 方案

单一命令 `/know write`，AI 从对话推断文档类型，按模板生成结构完整的文档，写入 `.know/docs/`，CLAUDE.md 维护索引。

- 9 种模板：roadmap / prd / tech / ui / arch / schema / decision / ops / marketing
- 3 层目录结构：项目版本级（`v{n}/`）、需求级（`requirements/{name}/`）、功能级（`requirements/{name}/{feature}/`）
- 项目版本级文档支持版本递增，需求/功能级文档原地覆写（单一事实源）
- 层级关系：roadmap → prd → tech / ui / schema，arch 和 decision 独立，ops 和 marketing 独立

## 怎么做

`/know write` → 推断参数 → 用户确认 → 加载模板 → 从对话提取内容 → 预览确认 → 写入 → 更新 CLAUDE.md 索引

## 不做

- 增量合并（有版本，全量写）
- 文档联动更新（Later）
- 自定义模板（Later）
- 独立 read 管线（复用 CLAUDE.md）

## 怎么验证

- 实际跑一遍：讨论完一个特性 → `/know write` → 生成的文档人工 review 内容完整
- 项目版本级文档：同一文档写两次，v1 和 v2 目录都在，CLAUDE.md 索引按 `#### v1` `#### v2` 分组
- 需求/功能级文档：原地覆写，用 git diff 确认变更
- CLAUDE.md 索引正确维护层级关系（`← roadmap`、`← prd`）和日期标注
