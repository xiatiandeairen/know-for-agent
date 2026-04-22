# Decay 架构设计

> **v7 状态**: 临时 no-op。`know-ctl decay` 调用输出"已推延"消息，不执行任何删除/降级。新策略在下个 sprint（v7.x）重做，届时本文档会更新。以下内容描述 v7 之前的设计意图，供下个 sprint 参考。

## 1. 定位与边界

### 职责

负责按时间与命中的双维度规则清理过期条目，为知识库提供自动精简能力，防止低价值条目随时间累积稀释 recall 精准度。

### 不负责

- 条目的语义质量判断（→ learn Step 3 Filter / Step 7 Challenge）
- 手动清理动作（→ review 管线的 Delete 选项）
- 命中统计本身（→ recall 的 hit 子命令）
- 降级后的条目重新评估（→ 后续 recall 会自然调整权重）

## 2. 结构与交互

### 组件图

```
[learn 入口触发] ─call─> [know-ctl decay] ─per level─> [规则引擎]
  每次 learn Step 1           参数解析                    t2+h=0+>30d → delete
  之前运行一次                 两 level 独立                t1+h=0+>180d → demote
                                                               │
                                                               ▼
[计数器更新] <─metrics_inc─ [事件日志] <─emit_event─ [条目改写]
  total_decayed                events.jsonl           index.jsonl 原地重写
  各 level metrics.json        deleted/demoted        entries/ 路径文件删除
```

### 组件表

| 组件 | 职责 | 边界规则 |
|---|---|---|
| learn 入口触发 | 在 learn Step 1 执行前调用 decay | 禁止独立于 learn 调用（避免并发覆盖）；必须在信号检测前完成 |
| 规则引擎 | 按年龄 + 命中判断删除 / 降级 / 保留 | 禁止改变规则（见约束）；必须对每条 entry 独立判定 |
| 条目改写 | 删除 tier=2 或降级 tier=1 的 entry | 禁止改 tier=2 的值以外的任何字段；必须保留 hits、revs、created |
| 事件日志 | append-only 记录 deleted / demoted 事件 | 禁止覆盖既有事件；必须含日期 + summary |
| 计数器更新 | 累加到 metrics.json total_decayed | 失败不阻塞主流程；必须只累加不重置 |

### 数据流

```
know-ctl decay --level X --read--> index.jsonl (level X)
                          │
                          v
               规则引擎 --条件判定--> 删除集 / 降级集 / 保留集
                          │
                          ├--rewrite--> index.jsonl (原子 mv tmpfile)
                          ├--rm------> entries/{tag}/{slug}.md
                          ├--append--> events.jsonl (deleted / demoted)
                          └--inc-----> metrics.json total_decayed
```

| 来源 | 目标 | 数据格式 | 类型 | 说明 |
|---|---|---|---|---|
| 规则引擎 | index.jsonl | JSONL 全量重写 | 强 | 删除/降级必须原子；读→改→写→mv |
| 规则引擎 | entries/ 文件 | 文件系统删除 | 强 | 与索引删除同事务意义 |
| 规则引擎 | events.jsonl | JSONL append | 弱 | 缺失不影响结果，只影响可追溯 |
| 规则引擎 | metrics.json | JSON 写 | 弱 | 统计用，失败仅影响 metrics 视图 |

## 3. 设计决策

### 驱动因素

| 因素 | 类型 | 对架构的影响 |
|---|---|---|
| 低价值条目会稀释 recall 精准度 | 业务需求 | 必须有自动清理，不能仅靠手动 review |
| 已命中条目证明了价值不应清理 | 业务需求 | 命中与否是核心过滤维度 |
| critical 知识即使少用也可能关键 | 质量要求 | tier=1 保留期远长于 tier=2（180d vs 30d） |
| 误删无法恢复 | 质量要求 | tier=1 首次降级为 tier=2 再删，给"再命中"机会 |

### 关键选择

| 决策 | 选择 | 被拒方案 | 为什么 |
|---|---|---|---|
| 触发时机 | learn 入口一次 | 每次启动或 cron | learn 是用户主动操作，此时清理对时序感知最清晰；cron 需守护进程 |
| 规则维度 | 年龄 + 命中 + tier | 只按年龄 | 只按年龄会误删高频 critical；引入 hits 让"被用过"条目幸存 |
| tier=1 处理 | 先降级再删 | 直接删 | 给一次"你是否还要这条"的机会，减少误删 |
| 跨 level | 各自独立衰减 | 全局衰减 | user level 跨项目命中模式不同，统一规则会误删跨项目方法论 |

### 约束

- 禁止更改既有规则（tier=2+hits=0+>30d 删；tier=1+hits=0+>180d 降级）—— 用户已有条目按此节奏生存
- 禁止删除 hits>0 或 updated<阈值 的条目（命中或近期改过视为活跃）
- 必须两 level 独立执行，互不影响对方的 metrics.total_decayed
- 必须原子重写 index.jsonl（避免中断导致数据丢失）

## 4. 质量要求

| 属性 | 指标 | 目标 |
|---|---|---|
| 清理覆盖率 | 符合规则的条目中实际被处理的比例 | 100%（规则确定性保证） |
| 误删率 | 被删条目中后续 7 天被追补的比例 | <5%（目标值，待验证） |
| 执行耗时 | 单次 decay 完成耗时 | <1s（100 条内；目标值，待验证） |
| 衰减率 | 已创建条目中被 decay 清除的比例 | 10%-30% 为健康区间（当前实测 0/73） |
