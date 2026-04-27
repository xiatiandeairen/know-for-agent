# tests/capability/learn — learn pipeline 测试场景

**不是 benchmark**，是回归参考：保证 workflow 行为符合 spec。

## 文件

| 文件 | Stage | 主要字段 |
|---|---|---|
| `detect.jsonl` | Stage 1 detect | `conversation` → `candidates[]` (label + summary) |
| `gate-entropy.jsonl` | Stage 2 gate — 信息熵 | `claim`, `label` → `result` (pass/adjust/reject) |
| `gate-reuse.jsonl` | Stage 2 gate — 复用+失效 | `claim`, `field` → `result`, `until` |
| `gate-trigger.jsonl` | Stage 2 gate — 可触发 | `claim` → `result`, `when` |
| `gate-action.jsonl` | Stage 2 gate — 可执行 | `claim` → `result`, `how` |
| `refine.jsonl` | Stage 3 refine | `when`, `claim` → `updated` or `skip` |
| `locate.jsonl` | Stage 4 locate | `claim`, `evidence` → `level`, `file` |
| `write.jsonl` | Stage 5 write | `entry`, `file_state` → `outcome` |

## 通用 schema

```jsonc
{
  "id": "tcNN-description",
  "input": { ...以该 stage 的输入字段为准 },
  "expected": { ...该 stage 的输出字段 }
}
```

只关注 **输入 → 输出**，不测中间状态。

## 验收

每份测试集手工走一遍，≥80% 结果合理即通过；失败项分析是 AI 变异、spec 歧义、还是 expected 错。
