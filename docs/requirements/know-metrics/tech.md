# know metrics 技术方案

## 1. 背景

### 技术约束

- know-ctl.sh: 纯 bash + jq，不引入新依赖
- 数据存储: 必须 git 可追踪（纯文本文件）
- 指标计算: 实时计算，不缓存中间结果
- 数据收集: 嵌入现有命令内部，不依赖 AI 主动调用

### 前置依赖

- know-ctl.sh append/decay/query 命令 — 已完成
- index.jsonl（含 hits 字段） — 已完成
- CLAUDE.md 文档索引（含 `⚠ needs update` 标记） — 已完成

## 2. 方案

### 文件/模块结构

- `scripts/know-ctl.sh` — CLI 入口，新增 cmd_metrics 函数；cmd_append/cmd_decay/cmd_query 内嵌数据收集逻辑
- `.know/metrics.json` — 辅助统计数据（total_created, total_decayed, queried_scopes）
- `.know/index.jsonl` — 知识条目索引，提供 hits/scope/tm 等字段供指标计算
- `workflows/review.md` — review 流程 Step 2 消费 3 个指标（命中率、衰减率、覆盖率）

### 核心流程

1. 数据收集（被动）：cmd_append 执行时 total_created += 1 → cmd_decay 执行时 total_decayed += (deleted + demoted) → cmd_query 执行时 queried_scopes 追加去重
2. `know-ctl metrics` 调用时 → 读取 index.jsonl + metrics.json + CLAUDE.md + 文件系统 → 实时计算 6 个指标
3. 计算结果按 3 组输出（Learn: 命中率+衰减率 / Recall: 防御次数+覆盖率 / Write: 过期文档数+文档覆盖率） → 格式化输出到 stdout

### 数据结构

| 字段 | 类型 | 用途 |
|------|------|------|
| total_created | number | 累计创建条目数，首次初始化为当前条目数 |
| total_decayed | number | 累计衰减（delete + demote）次数 |
| queried_scopes | string[] | 去重的查询 scope 数组 |

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 数据收集方式 | 嵌入现有命令内部 | 独立 record_created/record_query 命令依赖 AI 主动调用容易遗漏，嵌入命令内部保证不丢数据 |
| 衰减率分母 | total_created（累计创建数） | 用当前存活条目数做分母会因删除条目而膨胀衰减率，累计创建数反映真实比例 |
| 文档覆盖率计算 | 统计 prd.md 文件是否存在 | 解析 markdown 表格内容脆弱易断，文件存在性检查简单可靠 |
| 指标存储方式 | 实时计算，不缓存 | 缓存需要失效策略且可能与源数据不一致，实时计算虽慢但保证准确 |

## 4. 迭代记录

### 2026-04-13

- tech 方案 v2（修正 5 个设计问题：衰减率误算、文档覆盖率脆弱、冗余命令、调用时机依赖 AI、初始化精度）
- 数据收集改为嵌入现有命令（合并 record_created/record_query 进 append/query）
- metrics.json 增加 total_decayed 字段
