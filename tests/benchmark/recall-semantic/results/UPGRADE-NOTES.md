# v2 Benchmark 升级对比

本文件对比 sprint 20260422-212954-520（recall-keywords-upgrade）前后 v2 语义 benchmark 数字。

- `2026-04-22-pre.md` — 升级前基线（scope 前缀单向 + project 特例 + 无 keywords 机制）
- `2026-04-22.md` — 升级后（scope 双向 + 删 project 特例 + `--keywords` 支持）

## Strategy A（当前算法实际行为）对比

| type | Before R@must | After R@must | Δ |
|---|---|---|---|
| concept-match | 0% | 0% | — |
| cross-cutting | 0% | 0% | — |
| analogy | 0% | 0% | — |
| risk-domain | 0% | 0% | — |
| intent-gap | 81% (precision penalty 11%) | 0% | -81 |

## 为什么 A 反而降了

**核心原因**：benchmark fixture-triggers.jsonl 的 triggers **没有 keywords 字段**（fixture 是 v2 初版，未包含 keywords；本 sprint 也不改 fixture）。runner 调用 `know-ctl query <scope>` **不传 --keywords**，所以 keywords 路径没用上。

scope 那侧两个改动：
- **删 scope="project" 特例**：让 intent-gap 的 scope=project 不再返全库。原来 scope=project 返 20 条，其中 "must_recall 的 t01-t03 在返回集内" 凑了 recall@must=81%（但 precision 极差）
- **scope 双向前缀**：对 scope 具体的 scenarios 有用；对 intent-gap（scope="project" 或无）无帮助

删 project 特例是**质量修正**（去掉虚假召回），不是召回能力下降。这个 R@must 从 81% 降到 0% 应被理解为"不再靠蒙"——真实语义召回能力（keywords 路径）待 fixture 补 keywords 后再测。

## 本次无法真正验证 keywords 机制

v2 要验证 keywords 带来的语义提升，需要：

1. fixture-triggers.jsonl 每条 trigger 标 `keywords` 字段（覆盖 _concepts 里已标的那些概念）
2. runner 从 scenario.required_concepts 提取 keywords 传给 `know-ctl query --keywords ...`
3. 重跑 Strategy A，预期 recall@must 大幅上升接近 B 上界 100%

这是下个 sprint 的工作。

## 当前数据的真实解读

- **v1 benchmark F1 35→84**：scope 改动效果已验证（empty + prefix 修复）
- **v2 benchmark Strategy A 没变**：keywords 效果未验证（fixture 限制）
- **Strategy B 仍 100%**：理论上界不变，实施 keywords 后 A 应接近 B

## 待办（下个 sprint）

- [ ] 扩展 v2 fixture：为每条 trigger 加 `keywords` 字段（复用 `_concepts` 值）
- [ ] 扩展 v2 runner：scenario 的 `required_concepts` 作为 query keywords 传给 know-ctl
- [ ] 重跑 Strategy A 验证 keywords 机制带来的召回提升
