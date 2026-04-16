# /know learn 技术方案

## 1. 背景

### 技术约束

- know-ctl.sh: 纯 bash + jq 实现，不引入额外依赖
- JSONL 索引: 每条目 10 字段定长结构，summary ≤80 chars
- 详情文件: Markdown 格式，存储于 entries/{tag}/{slug}.md，git 可追踪
- 信号检测: 仅关键词匹配，不使用 LLM 做触发判断

### 前置依赖

- know-ctl.sh append 命令 — 已完成
- know-ctl.sh search 命令 — 已完成
- index.jsonl schema（10 字段） — 已完成

## 2. 方案

### 文件/模块结构

- `skills/know/SKILL.md` — 意图路由，/know learn 入口
- `workflows/learn.md` — 8 步工作流定义（信号检测到写入的完整管线）
- `scripts/know-ctl.sh` — CLI 入口，提供 append/search 等子命令
- `.know/index.jsonl` — 知识条目 JSONL 索引
- `.know/entries/{tag}/{slug}.md` — tier 1 条目的详情文件

### 核心流程

1. 用户触发 `/know learn`（或由 6 种隐式信号检测启动） → Trigger → 进入管线
2. Claim Extract 从对话中提取最小知识单元 → Route Intercept 执行 5 条 fast-DROP 规则过滤 → 通过的 claim 进入评估
3. Tier Assess 按缺失影响 × 复现频率评定 critical(T1) / memo(T2) / DROP → Entry Generate 生成 tag + scope + tm + summary + detail
4. Conflict Detect 关键词预筛 + LLM 语义判断检查已有条目 → 识别重复/矛盾/补充/无关
5. Confirm 展示完整条目供用户确认/编辑/取消 → Write 调用 know-ctl append 写入索引 + entries 文件

### 数据结构

| 字段 | 类型 | 用途 |
|------|------|------|
| tag | string | 知识分类：rationale/constraint/pitfall/concept/reference |
| tier | number | 优先级层级：1(critical) 或 2(memo) |
| scope | string | 作用域，Module.Class.method 格式 |
| tm | string | 触发模式：passive/active:defensive/active:directive |
| summary | string | 摘要，≤80 chars，含检索锚点词 |
| path | string\|null | 详情文件路径，tier 2 为 null |
| hits | number | 命中次数 |
| revs | number | 修订次数 |
| created | string | 创建日期，YYYY-MM-DD |
| updated | string | 更新日期，YYYY-MM-DD |

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 知识条目持久化格式 | JSONL 索引 + 独立 .md 详情 | SQLite 引入二进制依赖且不可 git diff，JSONL 纯文本可 jq 过滤且 git 可追踪 |
| 冲突检测策略 | 2 阶段（关键词预筛 + LLM 语义判断） | 纯 LLM 全量比对 token 开销大，纯关键词误判率高；两阶段兼顾效率和准确性 |
| 信号检测方式 | 关键词模式匹配 | LLM 实时检测每轮对话 token 开销过高且易过度触发，关键词匹配简单可靠不打扰用户 |
| 确认机制 | 必须用户确认后才写入 | 自动写入可能存入错误知识，隐性知识的准确性依赖人类判断 |
| Scope 推断优先级 | 文件路径 > 工具调用 > 关键词 > 兜底 | 随机推断不稳定，按确定性从高到低排序保证一致性 |
| 知识分层 | 2 级（critical / memo） | 3+ 级增加决策负担但区分度收益递减，2 级足够区分"必须加载"和"按需加载" |

## 4. 迭代记录

### 2026-04-15

- 重构 Step 1 Detect（claim 列表前新增对话主题、活动类型、关键产出的结构化摘要）
- 删除隐式信号触发（与 auto memory 优先级冲突，改为统一通过 /know 路由入口）

### 2026-04-10

- learn 管线端到端跑通（8 步工作流实现，know-ctl.sh CLI 工具完成，SKILL.md 添加 learn 路由和存储架构）
