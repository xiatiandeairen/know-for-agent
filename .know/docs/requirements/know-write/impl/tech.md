# /know write 技术方案

## 背景

know 插件有 learn 管线，面向知识条目（短摘要 ≤220 tokens）。用户在对话中讨论的完整设计文档无处沉淀。需要新增 write 能力，将对话结果按模板写入 `.know/docs/` 目录。

## 方案

### 整体结构

```
skills/know/SKILL.md                    ← 意图路由，新增 write 入口
workflows/write.md                       ← 9 步工作流
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
  │     ├─ 2a: type      对话内容特征匹配 9 种类型
  │     ├─ 2b: name      对话主题 → kebab-case slug（项目版本级单文件无需 name）
  │     ├─ 2c: version   项目版本级检查 v*/ 目录递增；需求/功能级 update mode
  │     └─ 2d: parent    prd←roadmap, tech/ui←prd, 其余独立
  ├─ 3. Confirm          展示推断结果，歧义时让用户选择
  ├─ 4. Template         加载 workflows/templates/{type}.md
  ├─ 5. Fill             create: 全文生成 / update: 定点章节更新
  ├─ 6. Preview          create: 全文预览 / update: 变更 diff
  ├─ 7. Write            create: Write tool / update: Edit tool + changelog
  └─ 8. Index            更新索引 + 级联标记 + 标记清除
```

### 文档类型（9 种，3 层）

**项目版本级**（`v{n}/` 下）：

| 类型 | 路径 | 说明 |
|------|------|------|
| roadmap | `v{n}/roadmap.md` | 产品路线图，单文件 |
| arch | `v{n}/arch.md` | 架构设计，单文件 |
| ops | `v{n}/ops.md` | 运营：发布、反馈、迭代，单文件 |
| marketing | `v{n}/marketing.md` | 营销：推广、内容策略、launch plan，单文件 |
| schema | `v{n}/schema/{topic}.md` | API/接口规范，目录，按主题分文件 |
| decision | `v{n}/decision/{topic}.md` | ADR 决策记录，目录，按主题分文件 |

**需求级**（`requirements/{name}/`）：prd.md

**功能级**（`requirements/{name}/{feature}/`）：tech.md / ui.md

### 推断规则

| 对话特征 | 推断类型 |
|---------|---------|
| 功能列表、优先级、时间线、里程碑 | roadmap |
| 用户故事、验收标准、需求、范围 | prd |
| 系统设计、数据模型、实现方案 | tech |
| 线框、布局、交互流、组件规格 | ui |
| 系统边界、模块拆分、基础设施 | arch |
| 接口、请求响应、协议、schema 规范 | schema |
| 选 A 不选 B、trade-off 分析 | decision |
| 发布计划、反馈循环、迭代 | ops |
| 推广、内容策略、launch plan | marketing |

名称取对话核心主题，转 kebab-case。有 hint 时优先匹配。

### 父文档关系

prd ← roadmap，tech/ui ← prd，其余类型独立。父文档缺失时：prd 无 roadmap → 继续，备注"关联 roadmap 尚未创建"；tech/ui 无 prd → 警告用户，选择继续或先创建 prd。

### 版本机制

- 项目版本级文档：`v{n}/` 目录递增，旧版本保留，CLAUDE.md 索引按版本分组
- 需求/功能级文档：定点更新（update mode），用 git 追溯历史

### 更新机制

#### Update Mode（需求/功能级）

文件已存在时进入 update mode，与 create mode 的区别：

| 步骤 | Create Mode | Update Mode |
|------|-------------|-------------|
| Step 5 Fill | 全文生成 | 只重新生成对话涉及的章节，其余不动 |
| Step 6 Preview | 展示全文 | 只展示变更章节的 diff |
| Step 7 Write | Write tool 全量写入 | Edit tool 逐章节替换 + 追加 changelog |

Changelog 格式：`- YYYY-MM-DD: {变更摘要}`，追加在文档末尾 `## Changelog` section。

#### 级联标记（Cascade Marking）

父文档写入后，自动在 CLAUDE.md 索引中标记直接子文档：

```
- [know-learn](.know/docs/requirements/know-learn/prd.md) | 2026-04-10 ← roadmap ⚠ needs update
```

规则：
- 只标记直接子文档（roadmap→prd，不穿透到 tech）
- 子文档更新后自动清除标记
- 已有标记的不重复标记

### 目录结构

```
.know/docs/
├── v1/                                        ← 项目版本级
│   ├── roadmap.md                             ← 单文件类型
│   ├── arch.md
│   ├── schema/{topic}.md                      ← 目录类型，按主题
│   └── decision/{topic}.md
└── requirements/                              ← 需求/功能级
    └── know-write/
        ├── prd.md                             ← 需求文档
        └── write-workflow/
            └── tech.md                        ← 功能文档
```

### 索引格式（CLAUDE.md）

```markdown
## Know

### 文档索引

#### v1
- [know Roadmap](.know/docs/v1/roadmap.md) | 2026-04-09
- [架构设计](.know/docs/v1/arch.md) | 2026-04-09

#### Requirements
- [know-write](.know/docs/requirements/know-write/prd.md) | 2026-04-09 ← roadmap
  - [write-workflow / tech](.know/docs/requirements/know-write/write-workflow/tech.md) | 2026-04-09 ← prd
```

索引不存在时创建 `## Know` → `### 文档索引` + `#### v1` 和 `#### Requirements` header。

## 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 元数据存储 | CLAUDE.md，无独立 meta 文件 | agent 天然读 CLAUDE.md，少一个文件 |
| 写入模式 | 项目版本级全量覆写+版本递增，需求级定点更新 | 版本级保留历史，需求级用 git 追溯 |
| 更新策略 | 定点章节更新 + changelog，不全量重写 | 降低重写代价，保留未变更内容 |
| 级联标记 | 父文档写入后标记直接子文档 `⚠ needs update` | 提醒用户下游文档可能过时 |
| 模板位置 | workflows/templates/ | 跟插件走，不污染用户项目 |
| 层级标注 | `← parent` 文本标记 | 人可读、agent 可解析、零依赖 |
| 文档格式 | 纯 Markdown，无 frontmatter | 元数据全在索引里，文档保持干净 |
| name 可选 | roadmap 等项目版本级单文件类型不需要 name | 避免冗余嵌套 |
| 目录结构 | `.know/docs/` 下按 `v{n}/` 和 `requirements/` 分层 | 项目版本和需求文档职责清晰 |
| 交互风格 | 自然语言确认，参考 sprint skill | 用户友好，不暴露内部标记 |

## 边界情况

| 场景 | 处理 |
|------|------|
| 对话内容不足 | 提示缺失章节，用户选择标"待定"或跳过 |
| 同一对话涉及多种文档 | 列出选项，支持逐个处理 |
| 目标版本文件已存在 | 重新 ls 取最新版本号 +1，不覆盖 |
| CLAUDE.md 不存在 | 创建 `## Know` → `### 文档索引` + `#### v1` 和 `#### Requirements` |
| 预览后要求修改 | 调整内容重新预览，不计版本号 |
| 需求文档已存在 | 进入 update mode，定点更新涉及章节 + 追加 changelog |
| 直接修改 v1 而非新建 v2 | 用户明确要求时直接 Edit，不走版本递增 |
| 父文档更新后子文档状态 | 索引标记 `⚠ needs update`，子文档更新后自动清除 |
