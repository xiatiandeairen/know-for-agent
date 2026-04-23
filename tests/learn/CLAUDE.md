# tests/learn — learn pipeline 测试场景

回归参考：保证 workflow/learn.md 行为符合 spec。只测输入 → 输出。

| 文件 | 对应 Step |
|---|---|
| `collect.jsonl` | 1 Collect |
| `generate.jsonl` | 2 Generate |
| `conflict.jsonl` | 3 Conflict |
| `confirm.jsonl` | 4 Confirm |
| `write.jsonl` | 5 Write |

Schema 与 tests/write 一致：`{id, input, expected}`。验收：≥80% 合理即通过。
