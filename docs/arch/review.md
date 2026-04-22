# Review 架构设计

## 1. 定位与边界

### 职责

负责对知识库存量做交互式审计：列出条目、标注生命周期阶段（new/active/silent/endangered）、逐条决定删除 / 更新 / 合并 / 保留，为自动 decay 触达不到的质量问题提供人工处置通道。

### 不负责

- 自动清理（→ decay 架构；review 是手工补充）
- 新条目写入（→ learn / extract）
- 跨条目语义比对（依赖关键词匹配，不做嵌入相似度）

## 2. 结构与交互

### 组件图

```
[入口]                       [Load]
  /know review [scope]         Step 1 Load
  [--level user]               know-ctl query {scope} [--level X]
  默认 scope=project            结果带 _level 字段
                                        │
                                        ▼
[Display]                    [Process]
  Step 2 Display                Step 3 Process（对用户选中的每条）
  按生命周期排序                 分支：
  endangered > silent             A) Delete  → know-ctl delete --level X
  > new > active                  B) Update  → know-ctl update --level X
  渲染表（level 列）               C) Merge   → update(target) + delete(source)
                                   D) Keep    → 无动作
```

### 组件表

| 组件 | 职责 | 边界规则 |
|---|---|---|
| Load | 按 scope + level 拉取条目 | 禁止绕过 know-ctl query；必须保留 `_level` 字段 |
| Lifecycle 标注 | 按 created/hits 计算 new/active/silent/endangered | 禁止与 decay 规则冲突（endangered = decay 即将作用的条目） |
| Display | 以表格呈现，含 level 列 | 禁止省略 level 列（双 level 下用户必须能区分） |
| Process | 逐条执行 A/B/C/D 动作 | 禁止批量（避免误删）；必须传 `--level` 到 know-ctl 动作 |

### 数据流

```
/know review [scope] [--level user] --> know-ctl query
                                         │ (JSONL + _level)
                                         v
         [Lifecycle 标注]  <──  parse created/hits
                   │
                   v
         [Display 表格]  →  用户选择编号
                              │
                              v
         [Process 分支]
         ├── Delete: know-ctl delete --level {entry._level}
         ├── Update: know-ctl update --level {entry._level}
         ├── Merge:  know-ctl update (target) + know-ctl delete (source)
         └── Keep:   无
```

| 来源 | 目标 | 数据格式 | 类型 | 说明 |
|---|---|---|---|---|
| know-ctl query | Lifecycle 标注 | JSONL + `_level` | 强 | level 决定 Process 动作的 `--level` 参数 |
| Process | know-ctl 动作 | CLI 参数（含 `--level`） | 强 | 缺 `--level` 会默认 project，user 条目误操作 |
| Process | events.jsonl | 写入 deleted/updated 事件 | 弱 | 审计用，缺失不影响业务结果 |

## 3. 设计决策

### 驱动因素

| 因素 | 类型 | 对架构的影响 |
|---|---|---|
| decay 只能按年龄 + 命中粗过滤 | 业务需求 | 必须有人工通道处理"有 hits 但已过时"等 edge case |
| 合并候选需要用户语义判断 | 业务需求 | 必须含 Merge 分支；AI 不自主判合并 |
| user 条目影响面大于 project | 质量要求 | 必须按 level 过滤展示 + Process 必须传 `--level` |
| 用户倾向一次处理多条 | 质量要求 | Display 支持多选，但 Process 逐条执行避免误删 |

### 关键选择

| 决策 | 选择 | 被拒方案 | 为什么 |
|---|---|---|---|
| 排序维度 | 生命周期优先，age 降序次之 | 创建时间 | endangered / silent 最需要动作；时间排序不体现紧迫度 |
| `--level` 传递 | 从 `_level` 字段回读 | 询问用户 | user 已在 query 阶段选择，Process 不应再问 |
| 删除策略 | 逐条确认 | 批量删除 | review 的价值在挑剔，批量会把错删放大 |
| Lifecycle 规则 | 与 decay 规则对齐 | 独立规则 | 避免"review 说活 / decay 说死"的冲突 |

### 约束

- 禁止 Process 分支跳过 `--level {entry._level}`（缺省会默认 project 造成误操作）
- 禁止绕过 know-ctl 直接 mv/rm 文件
- 必须对 user 级条目的 Delete / Merge 二次确认（与 learn Step 8 的 user 保护对称）
- 必须 Lifecycle 标注与 decay 规则同步更新（见 decay 架构 §3.约束）

## 4. 质量要求

| 属性 | 指标 | 目标 |
|---|---|---|
| 覆盖率 | 审计条目数 / 总条目数 | ≥20%（目标值，待验证） |
| 正确率 | Process 动作执行后 know-ctl 报错比例 | <1%（目标值，待验证） |
| endangered 挽救率 | endangered 条目中被 Update/Keep 的比例 | >30%（目标值，待验证） |
| 单次耗时 | review 开始到用户完成 Process 的平均耗时 | <5 min（10 条内；目标值，待验证） |
