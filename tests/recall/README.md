# tests/recall — recall 测试场景集

**不是 benchmark**，是 test scenarios。承认离线测试无法提供"真实能力评分"，只做：
1. smoke（防算法退化）
2. 诊断（指出哪条 trigger 写得不好）

真实能力评估走生产指标（`know-ctl metrics` 的 M4/M5 + follow-up 的 M3）。

## 数据源

- **triggers**: 直接读 `docs/triggers.jsonl` + `$XDG_CONFIG_HOME/know/triggers.jsonl`（无合成 fixture）
- **scenarios**: 混合
  - `origin: auto` — 每条真实 trigger 派生 1 条 self-check（由 generate-scenarios.sh 一次性生成）
  - `origin: manual` — 人工加的 contamination（真实文件 × 预期空召）

## 指标

| # | 指标 | 定义 | 行动阈值 |
|---|---|---|---|
| M1 | 自查率 | self-check 全命中 / 总数 | < 75% 审查 trigger scope/keywords |
| M2 | 污染率 | contamination 误召 / 总数 | > 0% 审查产生误召的 trigger |

## 运行

```bash
# 生成 / 刷新 self-check scenarios
bash tests/recall/generate-scenarios.sh

# 跑一遍出数
bash tests/recall/run.sh
```

## scenarios.jsonl schema

```jsonc
{
  "id": "self-<scope> | cont-<slug>",
  "kind": "self-check | contamination",
  "origin": "auto | manual",
  "level": "project | user | null",
  "file_path": "real/repo/path" | null,
  "expected": {
    "include": ["scope1"],
    "exclude": [] | ["scope1"] | "*"
  },
  "notes": "..."
}
```

## 维护

- triggers 变化后，`bash generate-scenarios.sh` 重新生成 auto 部分（manual 保留）
- 新 contamination 人工在 scenarios.jsonl 末尾追加 `"origin": "manual"` 行
- 历史 results/*.md 时间戳命名，不覆盖

## 当前基线（2026-04-23）

- M1 = 75% (3/4) — 1 条 file_path→scope 推断偏差（Know.keywords 映射到 arch.know）
- M2 = 0% (0/5) — 无误召

## Follow-ups

- M3 采纳率：需 `recall_query.returned_scopes[]` + `hit.scope` 事件字段
- file_path → scope 推断规则优化（当前 scope 首段 grep，可按需演进）
