# tests/write — write pipeline 测试场景

**不是 benchmark**，是回归参考：保证 workflow 行为符合 spec。

## 文件

| 文件 | 测什么 | 消费者 |
|---|---|---|
| `type-inference.jsonl` | Step 1a Type 推断 | 手工 / AI 自评 |

## schema

```jsonc
{
  "id": "tcNN-description",        // 编号 + 一句描述
  "input": {
    "hint": "tech" | null,         // /know write <hint>
    "conversation_summary": "...",  // 一句话描述对话气质
    "user_replies": ["A", "B"]      // 预期用户对 AI 提问的回答序列
  },
  "expected": {
    "type": "tech" | "<guess-any>",   // 期望最终 type
    "questions_asked": 0 | 1 | 2,      // 期望问询次数
    "note": "..."                      // 可选说明
  },
  "notes": "为什么这样期望"
}
```

## 验收口径

- 10 条 scenarios 人工跑一遍
- ≥ 8 条结果合理 → 通过
- 7 及以下 → 分析是 AI 变异、spec 歧义、还是 expected 错
