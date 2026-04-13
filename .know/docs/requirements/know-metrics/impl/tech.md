# know metrics 技术方案

<!-- 核心问题: 怎么实现、做到哪了？ -->

## 1. 背景

PRD 定义了 6 个场景驱动指标（learn 2 + recall 2 + write 2）。4 个可从现有数据实时计算，2 个需要新增记录点。`know-ctl metrics` 展示全部 6 个，`/know review` 消费其中 3 个（命中率逐条、衰减率、覆盖率）。

技术约束：
- know-ctl.sh 是纯 bash + jq，不引入新依赖
- 数据必须 git 可追踪（不用 SQLite 或外部存储）
- 指标实时计算，不缓存

## 2. 方案

### 数据归属

| 指标 | know-ctl metrics | /know review | 数据源 |
|------|:---:|:---:|------|
| 命中率 | ✓ 全局比率 | ✓ 逐条标注 hits=0 | index.jsonl |
| 衰减率 | ✓ | ✓ 存入质量参考 | metrics.json + index.jsonl |
| 防御次数 | ✓ | | index.jsonl |
| 覆盖率 | ✓ | ✓ scope 推断质量 | metrics.json + index.jsonl |
| 过期文档数 | ✓ | | CLAUDE.md |
| 文档覆盖率 | ✓ | | roadmap + CLAUDE.md |

### 新增存储：`.know/metrics.json`

```json
{
  "total_created": 0,
  "queried_scopes": []
}
```

- 首次 `know-ctl metrics` 或 `know-ctl record_created` 时自动创建
- `queried_scopes` 为去重数组，只记录 scope 名，不记录时间
- git 可追踪，与 index.jsonl 同目录

### know-ctl 新增命令

#### `cmd_metrics`

实时聚合 3 个数据源，输出 6 个指标：

```
=== know metrics ===

Learn — 存的有用吗？
  命中率:    {hit_count}/{total} ({percent}%)
  衰减率:    {decayed}/{total_created} ({percent}%)

Recall — 帮我避错了吗？
  防御次数:  {defensive_hits}
  覆盖率:    {queried_scopes}/{total_scopes} ({percent}%)

Write — 文档跟上了吗？
  过期文档:  {stale_count}
  文档覆盖:  {covered}/{total_milestones} ({percent}%)
```

计算逻辑：

| 指标 | 计算 |
|------|------|
| 命中率 | `jq '[.hits > 0] \| map(select(.)) \| length' / total` |
| 衰减率 | `(total_created - total) / total_created`（total_created 来自 metrics.json） |
| 防御次数 | `jq 'select(.tm == "active:defensive") \| .hits' \| sum` |
| 覆盖率 | `metrics.json.queried_scopes \| length / total unique scopes in index` |
| 过期文档数 | `grep -c "⚠ needs update" CLAUDE.md` |
| 文档覆盖率 | 解析最新 roadmap 里程碑表中需求列非 `—` 的行数 / 总里程碑数 |

边界情况：
- index.jsonl 不存在 → 全部指标显示 0
- metrics.json 不存在 → total_created = 当前条目数（首次校准），queried_scopes = []
- CLAUDE.md 不存在 → 过期文档 0，文档覆盖率 0/0
- total_created = 0 → 衰减率显示 0%

#### `cmd_record_created`

```bash
# learn Step 8 写入后调用
bash "$KNOW_CTL" record_created
```

读取 metrics.json，`total_created += 1`，写回。

#### `cmd_record_query`

```bash
# recall query 执行时调用
bash "$KNOW_CTL" record_query "{scope}"
```

读取 metrics.json，`queried_scopes` 中无此 scope 则追加，写回。

### review 流程变更

**Step 2 Display 前**增加 review 摘要：

```
[review] 衰减率 {percent}% | 覆盖率 {percent}%
```

**Step 2 Display 表格**增加 ⚠ 列：

```
| # | tag | tier | scope | hits | age | summary | ⚠ |
|---|-----|------|-------|------|-----|---------|---|
| 1 | constraint | critical | Auth | 0 | 45d | ... | hits=0 |
| 2 | rationale | critical | Auth | 3 | 10d | ... | |
```

`⚠` 列标注规则：
- `hits=0` + age > 7d → 标注 `hits=0`（清理候选）
- 其余为空

### 调用链路

```
/know learn → Step 8 Write → know-ctl append → know-ctl record_created
                                                      ↓
                                               metrics.json.total_created += 1

recall → know-ctl query → know-ctl record_query "{scope}"
                                   ↓
                            metrics.json.queried_scopes += scope

/know review → Step 2 → know-ctl metrics（内部调用，获取衰减率/覆盖率）
                       → 表格增加 ⚠ 标注

用户手动 → know-ctl metrics → 实时聚合 → 6 个指标输出
```

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| metrics 数据存储 | `.know/metrics.json` 单文件 | 轻量、git 可追踪、与 index.jsonl 同目录 |
| 指标计算方式 | 实时聚合，不缓存 | 数据量小（百条级），实时计算延迟可忽略 |
| 文档覆盖率解析 | 解析最新版本 roadmap | `ls -d .know/docs/v*/ \| sort -V \| tail -1` 取最新 |
| review 消费方式 | Step 2 前摘要 + 表格 ⚠ 列 | 不改 review 核心流程，只增加信息密度 |
| queried_scopes 去重 | 数组去重，不记录时间 | 只关心"查过没有"，不关心"什么时候查的" |
| metrics.json 初始化 | 首次调用自动创建，total_created 校准为当前条目数 | 兼容已有项目，无需手动初始化 |

## 4. 迭代记录

### 2026-04-13

tech 方案设计完成：6 个指标的计算逻辑、2 个新增数据收集命令（record_created, record_query）、review 流程增强、metrics.json 存储结构。
