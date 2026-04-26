# 里程碑历史（pivot 前 archive）

本文件归档 pivot 前的迭代记录（旧 retrieval 范式下的 v1-v7、M1-M15），仅作历史参考。

**当前产品已 pivot 为 markdown authoring 方向**，新里程碑见 [roadmap.md](../roadmap.md)，重新从 M1 编号。本文件不再追加内容。

## v1 — 闭环验证（2025-04-08 → 2025-04-11）

| # | 核心方向 | 结果 | 日期 |
|---|---|---|---|
| M1 | 验证 learn 管线端到端可行性 | 全链路跑通，可从对话提取知识并写入；提取准确率无量化数据 | 2025-04-08 |
| M2 | 验证 write 管线端到端可行性 | 10 种文档类型全部支持，内容质量参差（模版填充约束不足） | 2025-04-09 |
| M3 | 验证知识召回的实际防错效果 | recall 机制可用，实测防御 2 次 | 2025-04-10 |
| M4 | 验证真实场景持续可用性 | 持续使用无阻塞，知识条目持续增长 | 2025-04-11 |

## v2 — 可观测性（2025-04-12 → 2025-04-13）

| # | 核心方向 | 结果 | 日期 |
|---|---|---|---|
| M5 | 建立核心运营指标体系 | learn/recall/write 3 管线指标上线（know-ctl metrics） | 2025-04-12 |
| M6 | 知识全生命周期可追踪 | history 命令可查事件链；早期条目缺 created 事件不补全 | 2025-04-13 |
| M7 | 数据驱动优化闭环 | 完成 ≥1 次基于数据的优化；具体效果待查证 | 2025-04-13 |

## v3 — 可靠性（2025-04-14 → 2025-04-16）

| # | 核心方向 | 结果 | 日期 |
|---|---|---|---|
| M8 | know-ctl 自动化回归测试 | 6 核心命令全覆盖，self-test 通过 | 2025-04-14 |
| M9 | 文档一致性机器检测 | 3 类偏差可检测；HTML 注释偶误判 | 2025-04-15 |
| M10 | write 流程规则完整性 | 规则完善；模版内容质量约束不足（后续修复） | 2025-04-16 |

## v4 — recall 有效性（2025-04-16，部分完成）

| # | 核心方向 | 结果 | 日期 |
|---|---|---|---|
| M11 | 知识库瘦身 | 73→36 条，覆盖率 9%→50%；命中率 2% 未达标 | 2025-04-16 |
| M12 | recall scope 匹配优化 | 6 个 scope 与文件路径对齐，覆盖率 50%（与 M11 合并完成） | 2025-04-16 |
| M13 | recall 价值量化 | 未开始（需 2 周实际使用数据验证） | — |

## v5 — recall 可观测

| # | 核心方向 | 结果 | 日期 |
|---|---|---|---|
| M14 | recall 事件采集 | `know-ctl recall-log` 写入 events.jsonl 的 `recall_query` 事件；SKILL.md recall Query 后调用；仅 project level（user 未覆盖） | 已完成 |
| M15 | recall 数据消费 | `know-ctl metrics` 新增 Recall Run 面板：queries 总量 / 命中率 / 空查率 / scope 覆盖；`/know report` §3 Recall 段消费同一数据源 | 已完成 |

## v6 — 目录与作用域重构（2026-04-22）

| # | 核心方向 | 结果 | 日期 |
|---|---|---|---|
| — | 将 `.know/` 拆为项目根 `docs/` + `$XDG_DATA_HOME/know/{projects/{id},user}/`；新增 `level` 维度（project/user）贯穿 CLI + workflow；learn 增 "Level" 步骤；user 写入二次确认 | 18/18 anchors + 29/29 self-test；sprint 20260422-134413-380 | 2026-04-22 |

## v7 — Schema 简化 + 3 文件存储（2026-04-22）

| # | 核心方向 | 结果 | 日期 |
|---|---|---|---|
| — | Schema 11→8 字段（删 tier/tm/path，加 strict/ref）；存储收敛到 3 JSONL（docs/triggers + XDG_CONFIG/triggers + XDG_DATA/events）；events 单文件带 project_id+level 字段；learn 10→9 步；recall 去 suggest/warn/block 分级；decay 临时 no-op；migrate-v7 一次性迁移 | 33/33 self-test；14/14 anchors；sprint 20260422-160156-242 | 2026-04-22 |
