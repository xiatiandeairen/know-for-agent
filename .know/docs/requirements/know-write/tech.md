# /know write 技术方案

## 1. 背景

### 技术约束

- 文档格式: 纯 Markdown，无 frontmatter，保持文档干净
- 路径解析: 必须使用 `{project_root}` 绝对路径解析，相对路径不可靠
- 更新模式: 文件已存在时只重写对话涉及的章节，其余章节不动
- 索引方向: 树状向下索引（roadmap → prd → tech），不回指父级，避免循环引用

### 前置依赖

- workflows/templates/ 目录下 10 种文档模板 — 已完成
- CLAUDE.md 文档索引机制 — 已完成
- know learn 管线（write 独立于 learn，但共享 SKILL.md 路由） — 已完成

## 2. 方案

### 文件/模块结构

- `skills/know/SKILL.md` — 意图路由，/know write 入口
- `workflows/write.md` — 6 步工作流定义
- `workflows/templates/{type}.md` — 10 种文档模板（roadmap/capabilities/ops/marketing/arch/ui/schema/decision/prd/tech）
- `.know/docs/{type}.md` — 项目单文件文档（roadmap, capabilities, ops, marketing）
- `.know/docs/{type}/{topic}.md` — 项目目录文档（arch, ui, schema, decision）
- `.know/docs/requirements/{name}/` — 需求级文档（prd + tech）
- `CLAUDE.md ## 文档索引` — 索引 + 层级关系 + 级联标记

### 核心流程

1. 用户触发 `/know write [hint]` → Resolve 解析入口，推断 type/topic/mode/parent → Confirm 展示推断结果供用户确认
2. Template 加载 `workflows/templates/{type}.md` → Fill 根据 mode 生成内容（create: 全文生成 / update: 定点章节更新）
3. Write 预览内容 → 用户确认 → 写入目标文件
4. Index 更新 CLAUDE.md 文档索引 → 级联标记直接子文档 `⚠ needs update` → 子文档更新后自动清除标记

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 文档发现机制 | 目录约定 + capabilities.md | CLAUDE.md 索引会膨胀，SKILL.md 已定义路径约定让 AI 可推断；动态扫描不可靠 |
| 版本管理方式 | 单文件 + git 管历史 + 定点章节更新 | 版本目录（v1/v2/...）引入复杂性且 diff 困难，git 天然支持历史追踪 |
| 更新策略 | 定点章节更新，不全量重写 | 全量重写丢失未变更内容且 token 开销大，定点更新保留原文降低代价 |
| 索引方向 | 树状向下，不回指父级 | 双向引用导致循环更新和维护负担，单向索引结构清晰 |
| 路径定义 | Path Resolution 单一来源表 + Script Paths | 原 6 处分散定义导致 AI 拼接路径不一致，集中定义消除歧义 |
| 模板路径解析 | `{project_root}/workflows/templates/` | 相对路径在不同工作目录下解析结果不同，绝对路径保证一致 |
| 文档格式 | 纯 Markdown，无 frontmatter | YAML frontmatter 增加解析复杂度且文档可读性下降，纯 Markdown 最简洁 |

## 4. 迭代记录

### 2026-04-15

- 稳定性修复（Path Resolution 单一来源表替代 6 处分散路径定义）
- 消除 `{feature}` 虚假抽象（改为固定 `impl/`）
- 全 8 步添加 Gate 标准化声明
- cross-reference 基准明确为项目根相对路径
- template 路径改用 `{project_root}` 解析

### 2026-04-10

- write 管线端到端跑通（8 步工作流实现，9 种文档模板就绪，CLAUDE.md 索引维护和级联标记完成）
