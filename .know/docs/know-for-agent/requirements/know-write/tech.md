# /know write 技术方案

## 背景

know 插件有 retrieve 和 learn 两条管线，面向知识条目（短摘要 ≤220 tokens）。用户在对话中讨论的完整设计文档无处沉淀。需要新增 write 能力，将对话结果按模板写入 `docs/` 目录。

## 方案

### 整体结构

```
skills/know/SKILL.md                    ← 意图路由，新增 write 入口
workflows/write.md                       ← 10 步工作流
workflows/templates/{type}.md            ← 9 种文档模板
docs/{project}/{type}/[name]/v{n}.md     ← 产出目录
CLAUDE.md ## 文档索引                     ← 索引 + 层级关系
```

### 工作流（10 步）

```
/know write [hint]
  │
  ├─ 1. Trigger          解析 hint
  ├─ 2. Infer            推断 project / type / name / version / parent
  │     ├─ 2a: type      对话内容特征匹配 9 种类型
  │     ├─ 2b: name      对话主题 → kebab-case slug（可选，roadmap 无 name）
  │     ├─ 2c: version   检查目录是否存在 → 新建 v1 或递增
  │     ├─ 2d: parent    prd←roadmap, tech/ui/api←prd, 其余独立
  │     └─ 2e: project   检查 docs/ 已有项目目录，单项目直接用，多项目确认
  ├─ 3. Confirm          展示推断结果，歧义时让用户选择
  ├─ 4. Version          ls docs/{project}/{type}/[name]/v*.md → max+1
  ├─ 5. Template         加载 workflows/templates/{type}.md
  ├─ 6. Fill             从对话提取内容，按模板结构组织完整散文
  ├─ 7. Preview          展示全文，用户确认
  ├─ 8. Write            mkdir -p + 写入文件
  ├─ 9. Index            更新 CLAUDE.md 文档索引
  └─ 10. Done            输出路径 + 版本号
```

### 推断规则

| 对话特征 | 推断类型 |
|---------|---------|
| 功能列表、优先级、方向 | roadmap |
| 需求、用户故事、做/不做 | prd |
| 架构、模块、数据流、实现 | tech |
| 布局、交互、组件、状态 | ui |
| 系统边界、模块拆分、基础设施 | arch |
| 接口、请求响应、协议 | api |
| 选 A 不选 B、trade-off | decision |
| 发布、用户获取、反馈、迭代 | ops |
| 推广、内容策略、launch plan | marketing |

名称取对话核心主题，转 kebab-case。有 hint 时优先匹配。

### 版本机制

- `v{n}.md` 递增，全量写入
- 旧版本文件保留，不删不改
- CLAUDE.md 索引始终指向最新版本

### 目录结构

```
docs/{project}/{type}/[name]/v{n}.md

示例:
docs/know-for-agent/roadmap/v1.md              ← 无 name
docs/know-for-agent/prd/know-write/v1.md       ← 有 name
docs/know-for-agent/tech/know-write/v1.md      ← 有 name
```

### 索引格式（CLAUDE.md）

```markdown
## 文档索引

### Roadmap
- [know-for-agent Roadmap](docs/know-for-agent/roadmap/v1.md) v1 | 2026-04-09

### PRD
- [/know write](docs/know-for-agent/prd/know-write/v1.md) v1 | 2026-04-09 ← roadmap
```

索引不存在时创建 `## 文档索引` + 9 个类型 header。

## 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 元数据存储 | CLAUDE.md，无独立 meta 文件 | agent 天然读 CLAUDE.md，少一个文件 |
| 写入模式 | 全量覆写 | 单一事实源，版本文件管历史 |
| 模板位置 | workflows/templates/ | 跟插件走，不污染用户项目 |
| 层级标注 | `← parent` 文本标记 | 人可读、agent 可解析、零依赖 |
| 文档格式 | 纯 Markdown，无 frontmatter | 元数据全在索引里，文档保持干净 |
| name 可选 | roadmap 等单文档类型不需要 name | 避免冗余嵌套 |
| project 维度 | 目录加 {project} 层 | 支持多项目，单项目自动推断 |
| 交互风格 | 自然语言确认，参考 sprint skill | 用户友好，不暴露内部标记 |

## 边界情况

| 场景 | 处理 |
|------|------|
| 对话内容不足 | 提示缺失章节，用户选择标"待定"或跳过 |
| 同一对话涉及多种文档 | 列出选项，支持逐个处理 |
| 目标版本文件已存在 | 重新 ls 取最新版本号 +1，不覆盖 |
| CLAUDE.md 不存在 | 创建并初始化 9 个类型 header |
| 预览后要求修改 | 调整内容重新预览，不计版本号 |
| 多项目仓库 | 检查 docs/ 子目录，多个时让用户确认 |
| 直接修改 v1 而非新建 v2 | 用户明确要求时直接 Edit，不走版本递增 |
