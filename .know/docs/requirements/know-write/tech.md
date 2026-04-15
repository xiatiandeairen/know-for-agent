# /know write 技术方案

<!-- 核心问题: 怎么实现、做到哪了？ -->

## 1. 背景

know 插件有 learn 管线，面向知识条目（短摘要 ≤220 tokens）。用户在对话中讨论的完整设计文档无处沉淀。需要新增 write 能力，将对话结果按模板写入 `.know/docs/` 目录。

## 2. 方案

### 整体结构

```
skills/know/SKILL.md                    ← 意图路由，/know write 入口
workflows/write.md                       ← 6 步工作流
workflows/templates/{type}.md            ← 10 种文档模板
.know/docs/{type}.md                     ← 项目单文件（roadmap, capabilities, ops, marketing）
.know/docs/{type}/{topic}.md             ← 项目目录（arch, ui, schema, decision）
.know/docs/requirements/{name}/          ← 需求级文档（prd + tech）
CLAUDE.md ## 文档索引                     ← 索引 + 层级关系
```

### 工作流（6 步）

```
/know write [hint]
  │
  ├─ 1. Resolve          解析入口 + 推断 type/topic/mode/parent
  ├─ 2. Confirm          展示推断结果，用户确认
  ├─ 3. Template         加载 workflows/templates/{type}.md
  ├─ 4. Fill             create: 全文生成 / update: 定点章节更新
  ├─ 5. Write            预览 → 确认 → 写入文件
  └─ 6. Index            更新 CLAUDE.md + 级联标记 + 进度传播
```

### 文档类型（10 种，2 层 3 形式）

**项目单文件**（`docs/`）：roadmap, capabilities, ops, marketing

**项目目录**（`docs/{type}/`）：arch, ui, schema, decision

**需求级**（`requirements/{name}/`）：prd, tech

### 父文档关系

roadmap → prd → tech，其余类型独立。树状向下索引，不回指父级。

### 更新机制

文件已存在时进入 update mode：只重新生成对话涉及的章节，其余不动。

父文档写入后，CLAUDE.md 索引中标记直接子文档 `⚠ needs update`，子文档更新后自动清除。

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 文档发现 | 目录约定 + capabilities.md | CLAUDE.md 索引膨胀，SKILL.md 已定义路径约定，AI 可推断 |
| 写入模式 | 单文件，git 管历史，定点章节更新 | 消除版本目录复杂性，统一更新机制 |
| 更新策略 | 定点章节更新，不全量重写 | 降低重写代价，保留未变更内容 |
| 文档格式 | 纯 Markdown，无 frontmatter | 文档保持干净 |
| 索引方向 | 树状向下，不回指父级 | 避免循环引用，结构清晰 |
| 路径单一来源 | Path Resolution 表 + Script Paths | 分散定义导致 AI 拼接不一致 |
| 模板路径 | `{project_root}/workflows/templates/` | 相对路径不可靠，统一用项目根 |

## 4. 迭代记录

### 2026-04-15

稳定性修复：Path Resolution 单一来源表替代 6 处分散路径定义，`{feature}` 虚假抽象消除为固定 `impl/`，全 8 步添加 Gate 标准化声明，cross-reference 基准明确为项目根相对路径，template 路径改用 `{project_root}` 解析。

### 2026-04-10

write 管线端到端跑通：8 步工作流实现，9 种文档模板就绪，CLAUDE.md 索引维护和级联标记完成。
