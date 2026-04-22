# Recall 语义升级：动态词表 + 关键词交集 决策记录

## 1. 背景

**触发事件:** v1 benchmark 揭示 scope 前缀匹配召回率低（F1=35），v2 语义 benchmark 证明 4 类语义挑战（concept-match / cross-cutting / analogy / risk-domain）recall@must=0%——算法对"跨 scope 的概念相关性"完全失效。Strategy B 用 concept 交集模拟上界达到 100%，证明"**概念级匹配**即可闭合大部分 gap"。

**约束:**
- 不引入 daemon（Ollama / LM server 等常驻服务）
- 不引入外部 API 付费依赖
- 不引入 embedding 模型（Python ML 栈、vector store）
- 保持 know 的"bash + jq 零运行时依赖"哲学
- 尽量简洁；复杂度要与召回提升对等

**决策范围:** recall 算法核心机制（语义匹配机制）；schema 扩展（可选 keywords 字段）；word vocabulary 治理模型。不涉及 decay / 外部 embedding 基础设施。

## 2. 决策

**我们决定：动态词表 + 关键词 set 交集**。

具体机制：
1. Schema 加可选 `keywords: string[] | null` 字段
2. **Hard rule**（CLI `validate_keyword` 强制）：每个 keyword 必须匹配 `^[a-z0-9-]+$`，长度 2-40
3. **Soft convention**（learn prompt 引导）：learn 时 Claude 先拉 `know-ctl keywords` 输出的动态词表，优先从中复用；新词自由加入即扩展词表
4. 词表**不是独立维护的文件**——由所有 triggers 的 keywords 字段聚合得到，数据 derived
5. recall 时 Claude 也从词表选 3-5 个 task keywords，调 `know-ctl query --keywords k1,k2,k3`
6. know-ctl 的 query 返回 `scope 双向前缀匹配 ∪ keywords 交集 ≥1` 的 union，按 `_kw_hits`（keywords 命中数）降序排列
7. 同时修 v1 benchmark 暴露的 scope 算法 bug：
   - 删 `scope="project"` 特例（不再 filter='true' 返全库）
   - scope 前缀改双向（`entry.scope startsWith query OR query startsWith entry.scope`），捕获父 scope 的约束

8. LLM 只在 agent loop 的两个时机参与：
   - learn 时 Claude 推 keywords（index-time 标注）
   - recall 时 Claude 推 task keywords（query-time 抽取）
   - 两个时机都用 **Claude agent 自身的上下文理解**，不是外部模型调用，**无需常驻 daemon**
9. 同义词治理由 `/know review` 新增的 KeywordAudit 步骤负责（软治理，定期运行）

## 3. 备选方案

### 方案 A: 裸 embedding + sqlite-vec（RAG DB）

**优点:**
- 语义召回上限高（ML-based similarity）
- 跨语言跨词汇天然处理

**缺点:**
- 需要 embedding 模型（Ollama / sentence-transformers / API）
- Ollama daemon 常驻占内存，外部 API 需 key + 付费 + 隐私
- 每次 recall 多一次 embedding 调用（几十 ms）
- 引入 Python 依赖链（~300MB 传递依赖）
- DB 同步复杂度（triggers.jsonl ↔ knowledge.db）
- 用户安装门槛显著升高

### 方案 B: AI-in-loop rank（不用 DB，直接让 Claude 从候选池选 top-3）

**优点:**
- 最简实施；无任何 schema / infra 改动

**缺点:**
- 非确定性（同候选池同 task，Claude 可能每次挑不同结果）
- 与 recall 职责（主动提醒，算法确定）矛盾——recall 要求"不管 AI 会不会想到，规则就送上来"
- benchmark 无法验证（runner 不调 Claude）
- Token 成本隐性增加（每次 recall 给 AI 看 20-30 候选）

### 方案 C: 受控词表 +概念扩展 + 多路召回 + AI 去噪（4 层）

**优点:**
- 召回率上限高（85-95%）

**缺点:**
- 4 层复杂度过度
- 词表治理文件 + 概念扩展层 + 多路联合 + 去噪过滤——认知负担大
- 每层都可能成为 bug 来源

### 方案 D: free-form keyword OR（无词表）

**优点:**
- 最简；无契约

**缺点:**
- 缺约束 → 词汇漂移（`webhook` vs `web_hook` vs `webhooks`）
- 召回率受 Claude 写 keywords 一致性影响
- 无治理机制

## 4. 影响

**正面影响:**
- 零新运行时依赖（不加 Python / Ollama / embedding model / DB）
- 两条简单规则（正则 + 复用约定）形成强契约
- 动态词表自然涌现、自然治理、自然收敛
- 既有 36 条 triggers 兼容（`keywords=null` 仍可用 scope 召回）
- 保留 v7 8 字段 schema 兼容性
- benchmark 可验证效果
- 未来需要更强语义时平滑升级（用 sqlite-vec 作 query 后端替换 know-ctl query 实现即可）

**负面影响:**
- 召回率上限在 85-95% 之间（不及 embedding 的 90%+ 上限）
- 词表 bootstrap 阶段噪音（需要 5-10 次 learn 才稳定）
- 同义词治理需要定期 `/know review`（软治理）
- 跨语言匹配靠"keywords 统一用英文"实现（中文 summary + 英文 keywords 桥接）

**后续行动:**
- v7.3 / v8：若 benchmark 跑后 keywords 方案在真实数据上召回率低于 80%，评估升级到方案 A（embedding + RAG DB）
- 定期 review 词表（每 20-30 条新 trigger 后）做归并治理
- 观察新 learn 时 Claude 生成 keywords 的命中词表复用率；低于 60% 则说明词表过小或 prompt 需加强引导

## 5. 状态

**accepted**

> 决策日期: 2026-04-22
> 相关 sprint: 20260422-212954-520（实施）+ 20260422-203833-969（v2 benchmark 提供数据支撑）
> 决策人: project author
> 前置决策:
> - [v7 schema 简化](v7-simplify-schema.md)
> - [XDG 双层存储](xdg-dual-level.md)
