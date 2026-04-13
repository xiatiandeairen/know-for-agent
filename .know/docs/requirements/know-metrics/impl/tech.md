# know metrics 技术方案

<!-- 核心问题: 怎么实现、做到哪了？ -->

## 1. 背景

PRD 定义了 6 个场景驱动指标（learn 2 + recall 2 + write 2）。4 个可从现有数据实时计算，2 个需要新增记录点。`know-ctl metrics` 展示全部 6 个，`/know review` 消费其中 3 个（命中率逐条、衰减率、覆盖率）。

技术约束：
- know-ctl.sh 是纯 bash + jq，不引入新依赖
- 数据必须 git 可追踪
- 指标实时计算，不缓存

## 2. 方案

### 新增存储：`.know/metrics.json`

```json
{
  "total_created": 0,
  "total_decayed": 0,
  "queried_scopes": []
}
```

- 首次调用自动创建，`total_created` 校准为当前条目数
- `total_decayed` 记录实际衰减（delete + demote）次数
- `queried_scopes` 去重数组，只记录 scope 名

### 数据收集（嵌入现有命令，无需 AI 记住调用）

| 收集点 | 嵌入位置 | 动作 |
|--------|---------|------|
| 创建计数 | `cmd_append` 内部 | `total_created += 1` |
| 衰减计数 | `cmd_decay` 内部 | `total_decayed += (deleted + demoted)` |
| 查询 scope | `cmd_query` 内部 | `queried_scopes` 追加去重 |

### `cmd_metrics` 计算逻辑

| 指标 | 计算 | 数据源 |
|------|------|--------|
| 命中率 | hits > 0 的条目数 / 总条目数 | index.jsonl |
| 衰减率 | total_decayed / total_created | metrics.json |
| 防御次数 | tm=active:defensive 条目的 hits 总和 | index.jsonl |
| 覆盖率 | queried_scopes 数 / index 中唯一 scope 数 | metrics.json + index.jsonl |
| 过期文档数 | CLAUDE.md 中 `⚠ needs update` 出现次数 | CLAUDE.md |
| 文档覆盖率 | `.know/docs/requirements/*/prd.md` 存在数 / 最新 roadmap 里程碑行数 | 文件系统 + roadmap |

输出格式：

```
=== know metrics ===

Learn — 存的有用吗？
  命中率:    2/4 (50%)
  衰减率:    1/5 (20%)

Recall — 帮我避错了吗？
  防御次数:  3
  覆盖率:    2/4 (50%)

Write — 文档跟上了吗？
  过期文档:  1
  文档覆盖:  2/4 (50%)
```

边界情况：
- index.jsonl 不存在 → 全部指标显示 0
- metrics.json 不存在 → 自动创建，total_created = 当前条目数
- CLAUDE.md 不存在 → 过期文档 0
- total_created = 0 → 衰减率显示 0%
- 最新 roadmap 无里程碑表 → 文档覆盖 0/0

### review 流程变更

Step 2 Display 前增加摘要：
```
[review] 衰减率 20% | 覆盖率 50%
```

Step 2 Display 表格增加 ⚠ 列：
- `hits=0` + age > 7d → 标注 `hits=0`

### 文件变更

| 操作 | 文件 | 说明 |
|------|------|------|
| modify | scripts/know-ctl.sh | 新增 cmd_metrics，append/decay/query 内嵌数据收集 |
| modify | workflows/review.md | Step 2 增加摘要 + ⚠ 列 |

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 数据收集方式 | 嵌入现有命令 | 不依赖 AI 记住调用，不会丢数据 |
| 衰减率计算 | total_decayed / total_created | 手动删除不计入衰减，只记录 decay 命令的实际动作 |
| 文档覆盖率 | 统计 prd.md 文件存在数 | 不解析 markdown 表格，避免格式脆弱性 |
| 独立命令 vs 嵌入 | 取消 record_created/record_query | 合并进 append/query，减少调用链 |

## 4. 迭代记录

### 2026-04-13

tech 方案 v2：修正 5 个设计问题（衰减率误算、文档覆盖率脆弱、冗余命令、调用时机依赖 AI、初始化精度）。数据收集改为嵌入现有命令，metrics.json 增加 total_decayed 字段。
