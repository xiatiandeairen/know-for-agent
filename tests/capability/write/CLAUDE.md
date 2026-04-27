# tests/capability/write — write pipeline 测试场景

**不是 benchmark**，是回归参考：保证 workflow 行为符合 spec。

## 文件

| 文件 | Stage | 主要字段 |
|---|---|---|
| `type-inference.jsonl` | Stage 1 infer (type) | `hint`, `conversation`, `user_replies` → `type` |
| `name-inference.jsonl` | Stage 1 infer (name) | `type`, `conversation`, `name_hint`, `user_replies` → `name` |
| `mode-inference.jsonl` | Stage 1 infer (mode) | `type`, `path`, `file_exists`, `user_replies` → `mode` |
| `parent-inference.jsonl` | Stage 1 infer (parent) | `type`, `name`, `roadmap_exists`, `prd_exists`, `user_replies` → `parent_path` |
| `sufficiency.jsonl` | Stage 2 gate | `type`, `conversation`, `user_replies` → `verdict` |
| `confirm.jsonl` | Stage 3 confirm | `params`, `user_replies` → `outcome` |
| `fill.jsonl` | Stage 4 draft (fill) | template + conversation → filled sections |
| `write-op.jsonl` | Stage 5 write (preview+write) | `mode`, `tbd_count`, `user_replies` → `outcome` |
| `validate.jsonl` | Stage 5 write (validate) | `type`, `checklist_exists`, `doc_issues` → `verdict` |
| `progress.jsonl` | Stage 5 write (sync) | `type`, `parent_path`, `parent_exists` → `outcome` |

## 通用 schema

```jsonc
{
  "id": "tcNN-description",
  "input": { ...以该 stage 的 Input 字段为准 },
  "expected": { ...该 stage 的 Output 字段 }
}
```

只关注 **输入 → 输出**，不测中间状态（走了哪条分支、问了几次）。

## 验收

每份测试集手工走一遍，≥80% 结果合理即通过；失败项分析是 AI 变异、spec 歧义、还是 expected 错。
