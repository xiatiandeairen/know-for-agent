# tests/recall-pipeline — recall pipeline 测试场景

回归参考：保证 skills/know/SKILL.md "Recall" section 行为符合 spec。

注意：本目录测的是 **recall 工作流的每一步**，不同于 `tests/recall/` 测的是 triggers 端到端召回质量（self-retrievability / contamination）。

| 文件 | 对应 Step |
|---|---|
| `infer-context.jsonl` | 1 Infer context (scope + keywords) |
| `query-log.jsonl` | 2 Query and log |
| `present.jsonl` | 3 Present top 3 |
| `hit.jsonl` | 4 Hit on adoption |

Schema: `{id, input, expected}`. 验收：≥80% 合理通过。
