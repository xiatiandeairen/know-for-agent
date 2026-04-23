# tests/write — write pipeline 测试场景

**不是 benchmark**，是回归参考：保证 workflow 行为符合 spec。

## 文件

| 文件 | 测什么 |
|---|---|
| `type-inference.jsonl` | Step 1a Type 推断 |

## schema

只测 **输入 → 输出**，不关心中间过程（问了几次、走了哪条分支）。

```jsonc
{
  "id": "tcNN-description",
  "input": {
    "hint": "tech" | null,           // /know write <hint>
    "conversation": "一句话对话气质",
    "user_replies": ["..."]          // 预期用户对 AI 提问的回答
  },
  "expected": {
    "type": "tech" | "abort"         // 最终 type；abort = 反复无效回答导致放弃
  }
}
```

## 验收口径

手工跑，≥8/11 合理 → 通过。
