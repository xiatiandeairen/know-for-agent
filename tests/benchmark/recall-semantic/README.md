# recall semantic benchmark (v2)

**Semantic recall quality benchmark** — 测概念 / 模式 / 横切 / 风险域 / 意图 5 类语义召回能力，**不是字符串匹配**。

## 快速跑

```bash
bash tests/benchmark/recall-semantic/run.sh
```

产出 `results/YYYY-MM-DD.md`。

## 与 v1 的区别

| 维度 | v1 (`tests/benchmark/recall/`) | v2 (本目录) |
|---|---|---|
| **测什么** | 字符串匹配行为 | 语义召回能力 |
| **Scenario** | `{inferred_scope, expected_recalls}` | `{task, file_hints, required_concepts, graded expected}` |
| **Fixture** | scope-first 设计 | concept-first 设计（加 `_concepts`）|
| **算法假设** | scope.startsWith(query) | 无假设，双策略对比 |
| **暴露的问题** | "scope=project 返全库" | "字符串算法在 4 类场景 recall@must=0%" |

**两者保留**：v1 测"算法是否按字符串规则工作"；v2 测"算法是否真正做语义召回"。

## 结构

```
tests/benchmark/recall-semantic/
├── fixture-triggers.jsonl   # 20 triggers + _concepts[] 元字段
├── scenarios.jsonl          # 20 scenarios (5 类 × 4) + graded expected
├── run.sh                   # 双策略 runner
├── README.md                # 本文件
└── results/
    └── YYYY-MM-DD.md        # 每次执行基线
```

## 5 类语义挑战

| 类别 | 定义 | 例子 |
|---|---|---|
| **concept-match** | 同概念跨 scope | 写 Slack webhook → 需 Payment.webhook 签名 trap（不同 scope 同概念） |
| **cross-cutting** | 横切关注点跨模块 | 新 API 端点 → 输入校验/日志/向后兼容三个跨模块 rule |
| **analogy** | 结构模式类比 | email consumer ≈ queue worker，都需 idempotent + dead-letter |
| **risk-domain** | 风险领域内全量 | 改 auth 代码 → 该领域 rule 全应在视野 |
| **intent-gap** | scope 推断失败 | 任务描述"实现 login"，没有具体 file → 无 scope 可用 |

## 黑盒纪律

v2 的黑盒范围**窄于 v1**——因为我们引入了 Strategy B 模拟上界，必然知道算法有"概念匹配"这种可能性。

**仍然禁止**：
- 从 `cmd_query` 实现反推 fixture 设计（triggers 按真实知识领域，不按算法习惯）
- 从 `expected_recalls` 反推 `required_concepts`（required_concepts 独立标注，task 内容驱动）
- 在 runner 内联 jq 对 triggers.jsonl 做匹配（只许调 `know-ctl query` CLI）

**允许做**：
- Strategy B 的 concept-overlap 匹配是公开的"理想算法简化版"——这是基准提供的对照上界，不是反向验证

## 双策略 runner

### Strategy A — 当前 string-match (实际)

- 从 `file_hints[0]` 抽 scope：strip `src|lib|app|tests|scripts|migrations` 前缀 + strip 扩展名 + `/` → `.`
- 例：`src/integrations/slack/webhook.ts` → `integrations.slack.webhook`
- 空 file_hints → scope = `project`
- 调 `know-ctl query "$scope"`，从返回的 JSONL 提取 `_id`

### Strategy B — 理想 concept-match (保守上界)

- 对每 trigger：若 `trigger._concepts ∩ scenario.required_concepts ≠ ∅` → 召回
- 纯集合运算，无 ranking；只回答"if 算法能做概念匹配，上界是多少"
- 真实语义算法（embedding / LLM）可能**超越** Strategy B（B 只是保守基准）

## Graded 指标

每 scenario 含 4 组 expected：

- **must_recall**：缺失会让 AI 犯错的知识（核心指标 `recall@must`）
- **should_recall**：有帮助的上下文（次要 `recall@should`）
- **may_recall**：沾边无害（不计入指标）
- **must_not_recall**：明显无关；若出现在 actual → `precision_penalty`

每 strategy 对每 type 算聚合 + overall。Gap 表呈现 `B − A` 差值给出算法升级判断。

## 加场景指南

编辑 `scenarios.jsonl`，schema：

```json
{
  "id":"sXX",
  "type":"concept-match|cross-cutting|analogy|risk-domain|intent-gap",
  "task":"<natural language task description>",
  "file_hints":["<path>" or []],
  "required_concepts":["<concept>", ...],
  "must_recall":["tXX", ...],
  "should_recall":["tXX", ...],
  "may_recall":["tXX", ...],
  "must_not_recall":["tXX", ...],
  "rationale":"why these concepts / these expected"
}
```

**标注纪律**：
- `required_concepts` = task 本身需要哪些领域概念（task 内容驱动）
- `must_recall` = 该 task 如果 AI 缺这条 trigger 会犯错（经验判断）
- **两者独立**——不要让 `required_concepts = ∪ concepts of must_recall triggers`，会让 Strategy B 100% 命中变成循环

## 首次基线解读（2026-04-22）

Strategy A:
- concept-match / cross-cutting / analogy / risk-domain **recall@must = 0%** —— 字符串前缀匹配完全抓不到同概念不同 scope 的 trigger
- intent-gap recall@must = 81%（看似高）——实际是 `scope="project"` fallback 返回全库，"召回所有 must 同时召回所有 must_not"，precision_penalty 11%；不是真的召回好，是蒙的

Strategy B:
- 5 类 recall@must = 100%（保守上界；真实语义算法可能更高）
- precision_penalty 都 ≤10%

**Gap**: 4 类 +100%, intent-gap +19%。

→ **当前 recall 算法离语义召回有根本差距**，字符串匹配不是解决方案；需要引入语义层（embedding / LLM / 显式 concept tags in schema）。

## 下一步路径（review 阶段产出建议）

- **路径 1** — schema 扩展：triggers 加 `concepts[]` 字段（类似 `_concepts` 但成为 production schema），recall 用 concept overlap 代替 scope 前缀。保守上界即可达到。
- **路径 2** — embedding 召回：存 trigger 的 summary embedding；recall 时对当前 task 描述 embed + cosine similarity。上界更高，但需外部模型依赖。
- **路径 3** — LLM 辅助召回：recall 时把 task 描述 + triggers list 交 LLM 选相关。上限最高，但成本最大，适合关键场景。
- **路径 4** — 混合：scope 前缀做初筛，concept 或 embedding 做精召。兼顾速度和召回。
