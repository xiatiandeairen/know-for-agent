# know check 技术方案

## 1. 背景

### 技术约束

- 模版结构：section 编号可能因插入而偏移，匹配只能基于标题文本不能依赖编号
- 检查范围：只验证文档结构（section 数量、名称），不检查内容质量
- 模版推断：文件名到模版的映射必须覆盖所有已有模版类型（prd/tech/roadmap 等）

### 前置依赖

- `workflows/templates/` 下各模版文件 — 已完成
- `/know check` 入口 — 待实现（当前无对应 workflow）

## 2. 方案

### 实现位置

check 作为 know skill 的第三个 pipeline，独立 workflow 文件 `workflows/check.md`，由 SKILL.md 路由分发。

### 核心流程

1. 扫描 `$DOCS/` 下所有 `.md` 文件 → 待检查文件列表
2. 路径推断 → 从文件名（prd.md/tech.md 等）映射到 `$TEMPLATES/` 对应模版 → 模版路径
3. section 提取 → `grep '^## '` 提取文档和模版的标题列表，忽略编号只比较标题文本 → 差异报告（多出/缺少）

路径通过 know-paths.sh 解析：
```bash
DOCS=$(bash "$KNOW_PATHS" docs)
TEMPLATES=$(bash "$KNOW_PATHS" templates)
```

### 数据结构

- 路径模式：glob，文件名到模版的映射规则
- section 标题：string[]，从 `## N. 标题` 中提取的纯标题文本

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| section 匹配策略 | 只比标题文本，忽略编号 | 精确编号匹配会因插入新 section 导致误报，标题文本稳定 |
| 模版推断方式 | 文件名去 .md 后缀匹配模版目录 | 基于目录结构推断需额外约定，文件名天然携带类型信息 |

## 4. 迭代记录

### 2026-04-14

- tech 方案设计完成（覆盖 2 个检查维度：section 数量、section 名称）

### 2026-04-27

- 更新实现位置：独立 workflow 替代旧 know-ctl.sh cmd_check 方案
- 移除 CLAUDE.md 索引检查维度（与当前架构不符）
- 路径解析改用 know-paths.sh
