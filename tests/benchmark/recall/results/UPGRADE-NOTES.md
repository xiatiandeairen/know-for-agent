# v1 Benchmark 升级对比

本文件对比 sprint 20260422-212954-520（recall-keywords-upgrade）前后 v1 benchmark 数字。

- `2026-04-22-pre.md` — 升级前基线（scope 前缀单向 + project 特例）
- `2026-04-22.md` — 升级后（scope 双向 + 删 project 特例 + `--keywords` 支持但 fixture 未用 keywords）

## 对比

| type | Before F1 | After F1 | Δ | 原因 |
|---|---|---|---|---|
| exact | 85 | 85 | — | 精确匹配不受影响 |
| prefix | 88 | **100** | **+12** | **双向前缀**让父 scope 在子 scope 编辑时也能召回 |
| confuse | 100 | 100 | — | AuthZ/Auth 区分继续正确 |
| cross-level | 40 | 40 | — | fixture 未标 keywords，keywords 机制未在此 fixture 下生效 |
| empty | **0** | **100** | **+100** | **删 project 特例**让 README/.gitignore 不再返全库 |
| **overall** | **35** | **84** | **+49** | — |

## 解读

### 根本问题修复

- **empty F1 0→100**：v1 Finding 1（scope="project" 返全库）在本次 sprint 删除，empty 类从"返回 15 条错误 candidate"变为"返回 0 条"
- **prefix F1 88→100**：v1 Finding 2（单向前缀）修复为双向，父 scope 的约束在子 scope 编辑时也能召回

### cross-level 为什么没变

cross-level 要求 user 级 triggers 被 project 场景召回。本次引入 keywords 机制理论上能解决——但 **benchmark fixture 的 triggers 没有 keywords 字段**（仍是 v7.0 8 字段无 keywords）。所以 `--keywords` 未被实际测到。

**下个 sprint 扩展方向**：fixture-triggers.jsonl 加 keywords + scenarios 加 query_keywords 推断 → 重跑看 cross-level 升到多少。

### overall F1 35 → 84 的含义

scope 改动两处（删 project 特例 + 双向前缀）带来 49 分提升。keywords 机制的提升**尚未在 v1 benchmark 上体现**（受制于 fixture 没 keywords）。
