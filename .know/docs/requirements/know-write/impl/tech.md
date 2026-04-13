# /know write 技术方案

<!-- 核心问题: 怎么实现、做到哪了？ -->

## 1. 背景

know 插件有 learn 管线，面向知识条目（短摘要 ≤220 tokens）。用户在对话中讨论的完整设计文档无处沉淀。需要新增 write 能力，将对话结果按模板写入 `.know/docs/` 目录。

## 2. 方案

### 整体结构

```
skills/know/SKILL.md                    ← 意图路由，新增 write 入口
workflows/write.md                       ← 8 步工作流
workflows/templates/{type}.md            ← 9 种文档模板
.know/docs/v{n}/                         ← 项目版本级文档
.know/docs/requirements/{name}/          ← 需求/功能级文档
CLAUDE.md ## 文档索引                     ← 索引 + 层级关系
```

### 工作流（8 步）

```
/know write [hint]
  │
  ├─ 1. Trigger          解析 hint
  ├─ 2. Infer            推断 type / name / version / parent
  ├─ 3. Confirm          展示推断结果，歧义时让用户选择
  ├─ 4. Template         加载 workflows/templates/{type}.md
  ├─ 5. Fill             create: 全文生成 / update: 定点章节更新
  ├─ 6. Preview          create: 全文预览 / update: 变更 diff
  ├─ 7. Write            create: Write tool / update: Edit tool
  └─ 8. Index            更新索引 + 级联标记 + 标记清除
```

### 文档类型（9 种，3 层）

**项目版本级**（`v{n}/` 下）：roadmap, arch, ops, marketing, schema, decision

**需求级**（`requirements/{name}/`）：prd

**功能级**（`requirements/{name}/{feature}/`）：tech, ui

### 父文档关系

roadmap → prd → tech/ui，其余类型独立。树状向下索引，不回指父级。

### 更新机制

文件已存在时进入 update mode：只重新生成对话涉及的章节，其余不动。

父文档写入后，CLAUDE.md 索引中标记直接子文档 `⚠ needs update`，子文档更新后自动清除。

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 元数据存储 | CLAUDE.md，无独立 meta 文件 | agent 天然读 CLAUDE.md，少一个文件 |
| 写入模式 | 项目版本级全量覆写+版本递增，需求级定点更新 | 版本级保留历史，需求级用 git 追溯 |
| 更新策略 | 定点章节更新，不全量重写 | 降低重写代价，保留未变更内容 |
| 级联标记 | 父文档写入后标记直接子文档 | 提醒下游文档可能过时 |
| 文档格式 | 纯 Markdown，无 frontmatter | 元数据全在索引里，文档保持干净 |
| 索引方向 | 树状向下，不回指父级 | 避免循环引用，结构清晰 |

## 4. 迭代记录

### 2026-04-10

write 管线端到端跑通：8 步工作流实现，9 种文档模板就绪，CLAUDE.md 索引维护和级联标记完成。
