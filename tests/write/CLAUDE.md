# tests/write — write pipeline 测试场景

**不是 benchmark**，是回归参考：保证 workflow 行为符合 spec。

## 文件

| 文件 | 对应 Step | 主要字段 |
|---|---|---|
| `type-inference.jsonl` | 1a Type | `hint`, `conversation`, `user_replies` → `type` |
| `name-inference.jsonl` | 1b Name | `type`, `conversation`, `name_hint`, `user_replies` → `name` |
| `mode-inference.jsonl` | 1c Mode | `type`, `path`, `file_exists`, `user_replies` → `mode` |
| `parent-inference.jsonl` | 1d Parent | `type`, `name`, `roadmap_exists`, `prd_exists`, `user_replies` → `parent_path` |
| `sufficiency.jsonl` | 1.5 Sufficiency | `type`, `conversation`, `user_replies` → `verdict` |
| `confirm.jsonl` | 2 Confirm | `params`, `user_replies` → `outcome` |
| `fill.jsonl` | 4 Fill | template + conversation + triggers → filled sections |
| `write-op.jsonl` | 5 Write | `mode`, `tbd_count`, `user_replies` → `outcome` |
| `validate.jsonl` | 5.5 Validate | `type`, `checklist_exists`, `doc_issues` → `verdict` |
| `progress.jsonl` | 6 Progress | `type`, `parent_path`, `parent_exists` → `outcome` |

## 通用 schema

```jsonc
{
  "id": "tcNN-description",
  "input": { ...以该 step 的 Input 字段为准 },
  "expected": { ...该 step 的 Output 字段 }
}
```

只关注 **输入 → 输出**，不测中间状态（走了哪条分支、问了几次）。

## 验收

每份测试集手工走一遍，≥80% 结果合理即通过；失败项分析是 AI 变异、spec 歧义、还是 expected 错。
