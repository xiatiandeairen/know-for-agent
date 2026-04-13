# /know learn 技术方案

<!-- 核心问题: 怎么实现、做到哪了？ -->

## 1. 背景

know 插件需要将对话中产生的隐性知识持久化为结构化条目，供未来会话加载使用。learn 管线是知识的入口，负责信号检测、质量过滤、结构化和持久化。

## 2. 方案

### 整体结构

```
skills/know/SKILL.md                     ← 意图路由，/know learn 入口
workflows/learn.md                       ← 8 步工作流
scripts/know-ctl.sh                      ← append/search 命令
.know/index.jsonl                   ← JSONL 索引
.know/entries/{tag}/{slug}.md       ← 详情文件（tier 1）
```

### 工作流（8 步）

```
/know learn (或隐式信号)
  │
  ├─ 1. Trigger          显式调用 / 6 种隐式信号检测
  ├─ 2. Claim Extract    对话 → 最小知识单元，独立可检索
  ├─ 3. Route Intercept  5 条 fast-DROP：可推导 / CLAUDE.md / memory / 无结论 / 一次性
  ├─ 4. Tier Assess      Q1 缺失影响 × Q2 复现频率 → critical(T1) / memo(T2) / DROP
  ├─ 5. Entry Generate   tag + scope + tm + summary(≤80ch) + detail(.md)
  ├─ 6. Conflict Detect  关键词预筛(know-ctl search) + LLM 语义判断
  ├─ 7. Confirm          展示完整条目，用户确认/编辑/取消
  └─ 8. Write            know-ctl append + 写入 entries/{tag}/{slug}.md
```

### JSONL 条目结构（10 字段）

```json
{
  "tag":      "rationale|constraint|pitfall|concept|reference",
  "tier":     1|2,
  "scope":    "Module.Class.method",
  "tm":       "passive|active:defensive|active:directive",
  "summary":  "≤80 chars，含检索锚点词",
  "path":     "entries/{tag}/{slug}.md|null",
  "hits":     0,
  "revs":     0,
  "created":  "YYYY-MM-DD",
  "updated":  "YYYY-MM-DD"
}
```

### 信号检测规则

| 信号 | 检测模式 | 推断 tag |
|------|---------|---------|
| 用户纠正 | "don't", "not X use Y", "change to", "wrong", "should be" | constraint / rationale |
| 技术选型 | "chose", "picked", "decided", "over", "instead of", "compared" | rationale |
| 根因发现 | "turns out", "root cause", "the issue was", "because of" | pitfall |
| 业务逻辑 | "the flow is", "algorithm", "works by", "rule is" | concept |
| 约束声明 | "must not", "forbidden", "always", "never" | constraint |
| 外部集成 | "API", "endpoint", "SDK", "configured via" | reference |

### 路由拦截（5 条 DROP 规则）

顺序检查，首条命中即终止：

| 规则 | 判断标准 |
|------|---------|
| 代码可推导 | 不熟悉代码库的 AI 也能在 2 分钟内通过 grep/git log 得出 |
| 属于 CLAUDE.md | 每次会话都需要的项目级规则 |
| 属于 auto memory | 与项目无关的个人偏好 |
| 无结论 | 讨论未收敛 |
| 一次性 | 不会再遇到 |

### 冲突检测（2 阶段）

**阶段 1: 关键词预筛** — 从摘要提取关键词（≤30ch→2词, 30-60ch→3词, >60ch→4词），`know-ctl search` 匹配候选集。

**阶段 2: LLM 语义判断** — 候选摘要 vs 新摘要，分类为：无关 / 补充 / 重复 / 矛盾。重复或矛盾 → 展示冲突选项。

### 详情文件格式（按 tag）

| Tag | 文件结构 |
|-----|---------|
| rationale | `# 标题` → 为什么 → 被拒绝的方案 → 约束 |
| constraint | `# 标题` → 规则 → 为什么 → 检查方式 |
| pitfall | `# 标题` → 症状 → 根因 → 教训 |
| concept | `# 标题` → 概述 → 关键步骤 → 边界 |
| reference | `# 标题` → 是什么 → 用法 → 注意事项 |

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 存储格式 | JSONL + 独立 .md | 索引用 jq 过滤，详情用 Markdown 可版本控制 |
| 冲突检测 | 2 阶段 | 关键词预筛缩小范围，LLM 语义判断避免误判 |
| 信号检测 | 关键词匹配 | 简单可靠，避免过度提议打扰用户 |
| 确认机制 | 必须用户确认 | 隐性知识的准确性依赖人类判断 |
| Scope 推断 | 文件路径 > 工具调用 > 关键词 > 兜底 | 优先用确定性高的信号 |
| 分层 | 2 级 | 足够区分优先级，不增加决策负担 |

## 4. 迭代记录

### 2026-04-10

learn 管线端到端跑通：8 步工作流实现，know-ctl.sh CLI 工具完成，SKILL.md 添加 learn 路由和存储架构。
