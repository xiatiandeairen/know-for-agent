# /know write 技术方案

## 1. 背景

### 技术约束

- 文档格式：纯 Markdown，无 frontmatter，保持文档干净
- 路径解析：通过 know-paths.sh 统一解析（docs / templates）
- 更新模式：文件已存在时只重写对话涉及的章节，其余章节不动
- 索引方向：树状向下索引（roadmap → prd → tech），不回指父级，避免循环引用

### 前置依赖

- `workflows/templates/` 下 10 种文档模板 — 已完成
- `scripts/know-paths.sh` — 路径解析 CLI — 已完成

## 2. 方案

### 文件/模块结构

- `skills/know/SKILL.md` — 意图路由，/know write 入口
- `workflows/write.md` — 8 步工作流定义（参数推断→充分性检查→确认→模板→填充→写入→校验→回写）
- `workflows/templates/{type}.md` — 10 种文档模板（roadmap/capabilities/ops/marketing/arch/ui/schema/decision/prd/tech）
- `$DOCS/{type}.md` — 项目单文件文档（roadmap, capabilities, ops, marketing）
- `$DOCS/{type}/{name}.md` — 项目目录文档（arch, ui, schema, decision）
- `$DOCS/requirements/{name}/{type}.md` — 需求级文档（prd + tech）

其中 `$DOCS = bash know-paths.sh docs`，`$TEMPLATES = bash know-paths.sh templates`。

### 核心流程

1. 用户触发 `/know write [hint]` → 推断 type / name / mode / parent → 充分性检查（高风险类型强制）→ 确认展示推断结果
2. 加载 `$TEMPLATES/{type}.md` → 填充内容（create: 全文生成 / update: 定点章节更新）→ 预览 diff
3. 用户确认 → Write/Edit 写入目标文件
4. 回写父文档 progress 字段（tech→prd 任务表，prd→roadmap 里程碑）

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 版本管理方式 | 单文件 + git 管历史 + 定点章节更新 | 版本目录引入复杂性且 diff 困难，git 天然支持历史追踪 |
| 更新策略 | 定点章节更新，不全量重写 | 全量重写丢失未变更内容且 token 开销大 |
| 索引方向 | 树状向下，不回指父级 | 双向引用导致循环更新和维护负担 |
| 路径解析 | know-paths.sh 统一解析 | 分散定义导致 AI 拼接路径不一致 |
| 充分性把关 | 问题式 gate（高风险类型强制） | 评分不可重现，问题链可审计 |
| 数据置信 | 标注来源或"目标值，待验证" | 禁止编造精确数字（历史已踩过） |

## 4. 迭代记录

### 2026-04-27

- 文档路径从 `.know/docs/` 更新为 `$DOCS`（know-paths.sh 解析）
- 移除 CLAUDE.md 索引维护和级联标记（已简化为仅回写父文档 progress 字段）
- 步骤数从 6 步更新为 8 步（新增充分性检查、校验、回写三步）

### 2026-04-15

- 稳定性修复：Path Resolution 单一来源表替代分散路径定义
- cross-reference 基准明确为项目根相对路径

### 2026-04-10

- write 管线端到端跑通（8 步工作流，10 种文档模板就绪）
