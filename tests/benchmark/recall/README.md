# recall benchmark

Black-box quality benchmark for know's recall mechanism.

## 快速跑

```bash
bash tests/benchmark/recall/run.sh
```

产出 `results/YYYY-MM-DD.md`，含 per-scenario 明细 + 按类别聚合 + 总体 precision / recall / F1。

## 结构

```
tests/benchmark/recall/
├── fixture-triggers.jsonl   # 15 条代表性 trigger（带 _id, _level 元字段）
├── scenarios.jsonl          # 15 个编辑场景 + 标注的 expected_recalls / expected_miss
├── run.sh                   # runner：隔离 + 调 know-ctl query + 打分 + 生成 report
├── README.md                # 本文件
└── results/                 # 每次执行的 report（按日期命名）
    └── YYYY-MM-DD.md
```

## 黑盒纪律

本基准的**核心价值**在黑盒：如果 benchmark 参照当前 recall 算法的实现设计 fixture 和 scenario，会变成"用算法验证算法自己"的循环论证，无法发现算法缺陷。

### 允许做

- 调 `know-ctl query <scope>` 当作 CLI
- 观察项目里真实出现的 scope 模式（workflows.*, Auth.session 之类）
- 按"AI 在编辑 X 文件时需要哪些 trigger 帮他避错"的用户体验判断标注 expected

### 禁止做

- 读 `scripts/know-ctl.sh` 的 `cmd_query` 实现
- 读 `skills/know/SKILL.md` 的 Recall 段（尤其是 Rank / Act 部分）
- 在 runner 里内联 jq 对 triggers.jsonl 做 scope 匹配（会把 recall 逻辑重实现一份）
- 按"前缀匹配规则"反向标注 expected_recalls（要按使用场景直觉）

## 场景分类（5 类 × 3 条）

| type | 描述 | 例子 |
|---|---|---|
| **exact** | inferred_scope 与 trigger scope 完全相等 | 编辑 `workflows/learn.md` → scope=workflows.learn → 期望 t01（scope=workflows.learn） |
| **prefix** | 父/子 scope 关系 | 编辑 `src/auth/session/refresh.ts` → scope=Auth.session.refresh → 期望父 t08 + 本层 t09 |
| **confuse** | 字面相似但语义不同 | `AuthZ.policy`（授权）不应召回 `Auth.*`（认证）的 trigger |
| **cross-level** | user 级 methodology 在 project 场景下的召回 | 开发新 CLI 时 user 级 `methodology.cli-design` 应命中 |
| **empty** | 不应召回任何 | 编辑 README / .gitignore / 全新 scope |

## 指标定义

Per-scenario：
- `tp` = |actual ∩ expected|
- `fp` = |actual − expected|
- `fn` = |expected − actual|
- `precision` = tp / (tp + fp)
- `recall` = tp / (tp + fn)
- `F1` = 2PR / (P + R)

**空集特殊处理**：
- expected=∅ AND actual=∅ → P=100 R=100 F1=100（正确空）
- expected=∅ AND actual=非空 → P=0 R=100 F1=0（false positive）
- expected=非空 AND actual=∅ → P=100 R=0 F1=0（complete miss）

## 加场景指南

新 scenario 加入 `scenarios.jsonl`，schema：

```json
{
  "id": "sNN",
  "type": "exact|prefix|confuse|cross-level|empty",
  "file_path": "<relative project path>",
  "op": "edit|write|bash",
  "inferred_scope": "<what recall should receive as scope input>",
  "expected_recalls": ["tNN", ...],
  "expected_miss": ["tNN", ...],
  "rationale": "为什么这样标注（黑盒视角下的理由）"
}
```

**标注纪律**：
1. 先确定 file_path 和 op，模拟真实编辑场景
2. 凭"这个场景下 AI 最需要看到哪些 trigger 才能避错"标 expected_recalls
3. 凭"哪些 trigger 若被召回会构成 noise"标 expected_miss
4. rationale 用自然语言写判断依据——不引用算法规则

如果 expected_recalls 里的 trigger 不存在于 fixture，run.sh 会报错。

## 隔离保证

runner 通过 `mktemp -d` 创建临时 `$CLAUDE_PROJECT_DIR` + `$XDG_CONFIG_HOME` + `$XDG_DATA_HOME`，把 fixture 按 `_level` 拆到正确位置。

这保证：
- 生产 `docs/triggers.jsonl` 不会被读写
- 生产 `$XDG_CONFIG_HOME/know/triggers.jsonl` 不受影响
- 生产 `$XDG_DATA_HOME/know/events.jsonl` 不会被污染

## 结果解读

- **F1 < 50**：召回质量堪忧，通常是前缀匹配策略过严或过宽
- **exact 类 recall < 90%**：精确匹配都丢，算法基础问题
- **confuse 类 P < 70%**：scope 匹配过宽，字面相似就召回（false positive 多）
- **empty 类 P < 50%**：fallback 策略（如 scope="project"）返回过多，成为噪声源
- **cross-level 类 recall 低**：user level 在 project 查询里被忽略或权重低

review 阶段用这些信号产出算法改进建议。
