# Recall 架构设计

## 1. 定位与边界

### 职责

负责在代码修改前自动查询相关知识并提示 AI agent，为 learn 持久化的知识提供"编辑前加载"的注入通道。

### 不负责

- 知识的写入与衰减（→ learn.md workflow / decay 系统）
- scope 字段的初始定义（→ learn Step 5b Generate）
- 存储层访问（→ know-ctl query）
- 强制阻断编辑操作（设计为"提示而非阻断"；rule+strict=true 的 ⚠ 前缀是信号，不是 block）

## 2. 结构与交互

### 组件图

```
[编辑前 Hook] ─trigger─> [Scope 推断]    ┐
  Edit/Write/Bash         P1 path→module │
  触发时机判断             P2 call history │   ┌─> [合并查询 know-ctl query]
  Read/Glob 跳过           P3 project     │   │     - scope 双向前缀
                                          ├───>    - keywords 交集（≥1 命中）
                        [Keywords 推断]   │     - 两 level 扫描
                          动态词表        │     - 输出含 _level + _kw_hits
                          know-ctl keywords │
                          选 3-5 词       ┘         │
                                                    ▼
[输出格式化] <─max 3─ [Rank by _kw_hits] <── jsonl ── [Record Query]
  [project]/[user]      交集词数降序                  recall-log
  ⚠ rule+strict=true    同值 project > user          --keywords + --kw-hits
  hit 记录                                            events.jsonl
                                                      （project_id + level
                                                       + keywords[] + kw_hits）
                                                              │
                                                              ▼
                                                      [metrics / report-recall]
                                                      avg kw_hits / top kw /
                                                      with-kw 比例 / --days 窗口
```

### 组件表

| 组件 | 职责 | 边界规则 |
|---|---|---|
| 编辑前 Hook | 判断当前操作是否需要触发 recall | 禁止对 Read/Glob/Grep 触发；必须避免同 scope 同 session 重复查询 |
| Scope 推断 | 从当前文件路径或最近调用推导 scope | 禁止凭空生成；必须按 P1→P2→P3 优先级降级 |
| **Keywords 推断（v7.3）** | **从动态词表（`know-ctl keywords`）选 3-5 个 task-relevant keywords** | **禁止自由生成新词（新词只在 learn 时产生）；必须从现有词表选** |
| 合并查询 | 通过 know-ctl query 扫描两 level；scope 双向前缀 ∪ keywords 交集 | 禁止绕过 know-ctl 直访 triggers.jsonl；必须保留 `_level` + `_kw_hits` 字段 |
| Record Query | 记录查询事件供 metrics 分析 | 禁止失败阻塞主流程；event 含 project_id + level + keywords[] + kw_hits 字段 |
| **Metrics 观测层（v7.4）** | **metrics Recall 面板 + report-recall 窗口报告；消费 events.jsonl 的 keywords/kw_hits 字段** | **只读消费；旧事件缺字段时按 null/0 兜底** |
| Rank / Select | 按 `_kw_hits` 降序挑 max 3 条；同值 project > user | 禁止返回 >3 条；由 know-ctl query 已排好序 |
| 输出格式化 | 渲染 `[recall] [level] {⚠ if rule+strict=true} ...` 给用户 | 禁止输出机制细节；必须带 Why + Ref（若非 null） |

### 数据流

```
know-ctl query (两 level) --JSONL+_level--> Rank --top3--> 用户输出
                                   │
                                   └--> know-ctl recall-log --JSONL--> events.jsonl
                                                                        （project_id + level）
match hit --> know-ctl hit --emit event--> events.jsonl (不改 triggers.jsonl)
```

| 来源 | 目标 | 数据格式 | 类型 | 说明 |
|---|---|---|---|---|
| know-ctl query | Rank | JSONL + `_level` | 强 | 查询结果含来源 level，无此字段无法区分展示 |
| Rank | 用户输出 | 文本 | 强 | 渲染给 AI agent 的提示内容 |
| Rank | recall-log | 参数（scope, matched） | 弱 | 记录失败不影响主流程 |
| 用户 hit | know-ctl hit | 参数（summary/path, level） | 弱 | 命中计数，缺失不影响召回 |

## 3. 设计决策

### 驱动因素

| 因素 | 类型 | 对架构的影响 |
|---|---|---|
| 编辑前加载是 know 的核心防错时机 | 业务需求 | 必须在 Edit/Write/Bash 前触发，不能是被动查询 |
| "不知道自己不知道"无法由 AI 主动 query | 业务需求 | 必须自动 scope 推断，不能依赖用户提供 scope |
| 过度打扰会抑制使用意愿 | 质量要求 | max 3 条；同 scope 同会话不重复；无匹配时完全静默 |
| 两 level 共存后选择必须同时考虑 | 技术约束 | 合并查询是默认；rank 需引入 level 优先级 |

### 关键选择

| 决策 | 选择 | 被拒方案 | 为什么 |
|---|---|---|---|
| 触发时机 | Edit/Write/Bash 前自动 | 用户手动触发 | 隐性知识的价值在"不知道要查"，主动提醒才有防错价值 |
| 合并语义 | 读类默认合并两 level | 只查 project | user level 的跨项目方法论必须能在当前项目触发 |
| 阻断强度 | 不分级，rule+strict=true 加 ⚠ 给 AI 信号 | suggest/warn/block 三档 | 分级无使用证据（v6 命中率 2%）；AI 看到 ⚠ 自然会重视 |
| level 排序 | 同 scope 平手时 project > user | 不排序 | 本地项目知识更精确，应优先 |

### 约束

- 禁止 recall 对同一 scope 在同一会话内重复查询（避免重复打扰）
- 禁止在无 index.jsonl 时触发（静默跳过）
- 必须保留 `_level` 字段到输出（AI 需要区分来源判断可信度）
- 必须通过 know-ctl query 访问存储（禁止绕过到 index.jsonl）

## 4. 质量要求

| 属性 | 指标 | 目标 |
|---|---|---|
| 触发准确率 | 应触发场景中实际触发的比例 | >90%（目标值，待验证） |
| 召回精准度 | 召回条目中与当前操作相关的比例 | >70%（目标值，待验证） |
| 单次延迟 | Query→输出端到端耗时 | <500ms p95（目标值，待验证） |
| 空查率 | 触发但 0 匹配的比例 | <30%（当前实测: 无近期 recall_query 数据） |
