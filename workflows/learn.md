# learn — Knowledge Persistence

## Progress

Steps: 9
Names: Detect, Extract, Filter, Generate, Conflict, Challenge, Level, Confirm, Write

Core infrastructure (paths, schema, recall, markers) → SKILL.md.

---

## Shared Definitions

These definitions are used by learn, extract, and review pipelines.

### Tag definitions

| Tag | Records | Examples |
|-----|---------|---------|
| insight | Cognitive understanding: decisions, rationale, mental models, concepts, frameworks | "Chose JSONL over SQLite — need line-level append without locking" |
| rule | Must/must-not constraints, ordering, boundaries | "Webhook signature must be verified before parsing body" |
| trap | Bugs, root causes, easy-to-repeat mistakes | "DataEngine singleton leaks state across test targets" |

### Strict definition (rule only)

| Value | When to use | Recall behavior |
|-------|-------------|-----------------|
| `true` | Hard constraint: violating causes compile failure, data corruption, security hole, or must-not-violate rule | Prefixed with ⚠ in recall output |
| `false` | Soft constraint: recommended practice, style convention, advisory rule | No prefix; informational |

`strict` is **required** for `tag=rule` and **must be `null`** for `tag=insight|trap`.

### Scope guidelines

Scope makes future recall hit the right entries. Not a directory tree replica.

**Generation priority**: explicit file path → module/subsystem name → recurring functional domain → broad stable boundary → `"project"` (last resort).

**Good**: `Auth.session`, `Payment.webhook`, `Search.reranker`, `Infra.queue.worker`

**Bad**: `src.app.services.payment.handlers.webhook.verify.signature.v2`, `misc`, `unknown`

### Conflict handling

| Relationship | Action |
|-------------|--------|
| **duplicate** | Same conclusion, different wording → suggest merge or skip |
| **conflict** | Mutually exclusive conclusions → must show to user, let them decide |
| **merge** | Complementary (same topic, different angle) → suggest merging |
| **unrelated** | Pass through |

Semantic similarity can find candidates, but final classification must also consider: scope, conclusion direction, tag, applicable range, chronology.

---

## Decay

Run at Step 1 entry, before signal detection. Skip if neither `$PROJECT_TRIGGERS` nor `$USER_TRIGGERS` exists.

```bash
# [RUN] v7: decay is a no-op (deferred); command remains callable
bash "$KNOW_CTL" decay
```

Output: `[decay] 已推延到下个 sprint（v7 schema 简化完成，衰减策略将在 v7.x 重做）`。

---

## Step 1: Detect

Model: opus

**Trigger**: `/know learn` or routed from `/know` → scan full conversation.

### Signal types

| Signal | Typical language | Likely tag |
|--------|-----------------|------------|
| User correction | don't, not X use Y, wrong, should be, 必须, 不能 | rule / insight |
| Technical choice | chose, decided, instead of, tradeoff, 选了, 决定用 | insight |
| Root cause | root cause, caused by, turns out, 根因, 问题是 | trap |
| Business logic | the flow is, algorithm, works by, 机制是, 流程是 | insight |
| Constraint declared | must not, forbidden, never, always, 千万别 | rule |
| External integration | API, endpoint, SDK, webhook, 第三方接口 | insight |

### Detection requirements

- Each candidate must have a clear conclusion or clear rule — drop vague signals.
- Max 5 candidates. >5 → rank by: user-corrected > converged conclusion > likely to recur > project-relevant. Take top 5.
- Prioritize: user explicit corrections, confirmed conclusions, things likely to recur.

### Summary + claim presentation

Output a structured conversation value summary before listing claims:

```
[learn] step: detect
会话价值摘要：
本次对话围绕 {主题} 进行了 {活动类型}。
关键产出：
- {产出1}
- {产出2}

检测到 {N} 条可持久化知识：
1. [{likely_tag}] {summary}
2. [{likely_tag}] {summary}

持久化？ [all / 选编号 / skip]
```

[STOP:choose] User selects → each claim processed through Steps 2-9 sequentially.

---

## Step 2: Extract（原步骤不变）

Model: opus

Split detected signals into independently retrievable knowledge units.

### Principles

Each unit should have:
- One core conclusion
- Preferably one key reason or context
- Be independently understandable and retrievable

### Splitting rules

- Conclusion + its direct reason = one unit (do not split)
- Two independent facts = split
- One choice + one rejection reason = usually one insight entry
- Uncertain whether to split → do not split (prefer fewer, not more)

### Output per unit

- `conclusion`: the core knowledge
- `reason`: why (if available)
- `evidence`: key evidence from conversation
- `suggested_tag`: preliminary tag

---

## Step 3: Filter

Model: sonnet

Drop claims that don't belong in the knowledge base. This is not about "store as little as possible" — it's about removing obvious noise while keeping genuinely valuable tacit knowledge.

### Direct DROP

| Condition | Why drop |
|-----------|----------|
| No clear conclusion | Speculation, divergent discussion, not converged |
| One-time or snapshot | Temporary state, ticket numbers, won't recur |
| Surface fact with no extra value | Restating what code obviously shows, no why/constraint/context |
| Weak long-term relevance | Only useful for this one conversation, no future reuse |

### Usually KEEP (even if single-file)

- Conclusion is non-obvious
- Reason not easily visible from surface code
- Easy to re-encounter (repeat mistakes)
- Involves business boundaries, external systems, timing, ordering
- Clear "why we did this" value
- Project-specific decision or rule

### Output

```
[skipped] {summary}
Reason: {drop reason}
```

---

## Step 4: Generate

Model: opus

Convert claim into a formal entry. Sub-steps in order: **tag → scope → (if rule) strict → summary → ref**.

### 4a: Tag

**Selection priority (tie-breaker rule)**: trap > rule > insight.

- 有"历史犯错"的根因（踩过且易再踩） → **trap**
- 是明确约束（必须/禁止做 X，含外部 API 约束等） → **rule**
- 否则（决策、心智模型、背景事实） → **insight**

| Pattern | Tag |
|---------|-----|
| Choice/comparison ("chose X over Y") | insight |
| Prohibition ("must not", "forbidden", "always") | rule |
| External API / SDK hard constraint (header required, version pinned) | rule（防错优先于解释） |
| Bug/error/root-cause discovery | trap |
| Flow/algorithm/architecture/business-rule | insight |

≥2 tags仍等价 → ask user（优先级规则已打破多数绑带情况）。

### 4b: Scope

Generate using SKILL.md Scope Guidelines. Scope should be stable, reusable, and hittable.

### 4c: Strict (tag=rule only)

**仅 tag=rule 时执行**；tag=insight|trap 跳过此步（strict 固定为 null）。

| Condition | strict |
|---|---|
| 违反会导致编译失败 / 数据损坏 / 安全漏洞 / 外部 API 硬要求 | `true` |
| 推荐实践 / 风格约定 / 建议性规则 | `false` |

### 4d: Summary

Format: `{conclusion} — {key reason/context}`

Requirements: concise, readable, ≤80 chars, real information density, not an empty title.

Overflow: remove qualifiers → core conclusion only → still over → split into two entries.

### 4e: Ref (optional)

指向该条目的完整 context 所在。值域：
- `"docs/decision/xxx.md#anchor"` — 项目文档段落
- `"src/auth/session.ts:42"` — 代码锚点
- `"https://..."` — 外部链接
- `null` — 无引用（summary 已足够）

建议场景：tag=rule + strict=true 时最好有 ref；summary ≥60 字常意味着值得配 doc 段。

---

## Step 5: Conflict

Model: sonnet

Check if new entry duplicates, conflicts with, or supplements existing entries.

### Phase 1: Keyword retrieval

Extract keywords from summary (scope module names → proper nouns → action verbs → skip generic words).

| Summary length | Keywords |
|---------------|----------|
| ≤30 chars | 2 |
| 31-60 chars | 3 |
| >60 chars | 4 |

```bash
# [RUN]
bash "$KNOW_CTL" search "<kw1>|<kw2>"
```

0 results → skip Phase 2, proceed to Step 7.

### Phase 2: Relationship classification

Compare each candidate against new claim. Classify as:

| Relationship | Action |
|-------------|--------|
| unrelated | → Step 7 |
| merge (complementary) | → suggest merge [STOP:choose] |
| duplicate (same conclusion) | → suggest skip or merge [STOP:choose] |
| conflict (opposite conclusion) | → must show, user decides [STOP:choose] |

**Conflict block**:
```
[conflict] Similar entry found:
Existing: {summary}
New: {summary}
Relationship: {duplicate|conflict|merge}
Choose: A) Update existing  B) Keep both  C) Merge  D) Skip new
```

Do not classify based on semantic similarity alone. Also consider: scope, conclusion direction, tag, applicable range, chronology.

---

## Step 6: Challenge

Model: opus

Adversarial review of each generated entry before user sees it. Goal: catch weak, vague, or misclassified entries before they pollute the knowledge base.

### Per entry, answer 5 questions internally

| # | Challenge question | Fail action |
|---|-------------------|-------------|
| 1 | Is the conclusion falsifiable? Can you construct a scenario where it's wrong? | If trivially falsifiable → drop or narrow scope |
| 2 | Would a different AI, without this knowledge, actually produce broken code? | If no → for tag=rule demote strict=true→false; for others consider drop |
| 3 | Is this a fact that can be derived by reading the code? | If yes → drop (code is the source of truth) |
| 4 | Does the summary capture the "why", not just the "what"? | If no → rewrite summary to include reason |
| 5 | Is the scope precise enough for recall to hit it, but not so narrow it's useless? | If too broad or too narrow → adjust scope |

### Execution

- Run all 5 questions per entry. Record pass/fail.
- **All pass** → proceed to Step 8 unchanged.
- **Any fail** → apply fix (drop / demote / rewrite / adjust), mark what changed.
- **≥3 fail** → drop entry, report reason.

### Output

```
[learn] step: challenge
{N} entries reviewed:
  ✓ {summary}                          — passed
  △ {summary}                          — {field}: {old} → {new}
  ✗ {summary}                          — dropped: {reason}

Surviving entries ({M}/{N}):
1. [{tag}{⚠ if rule+strict=true}] {summary} — scope {scope}{ref: ... if not null}
2. ...

持久化？ [all / 选编号 / skip]
```

[STOP:choose] User selects → each surviving entry processed through Steps 7-9.

---

## Step 7: Level

Model: sonnet

Decide storage level for each surviving entry: `project` (default) or `user` (cross-project).

### Inference (default suggestion)

| Signal in scope or summary | Suggest |
|---|---|
| Scope starts with `methodology.*` | user |
| Summary is domain-agnostic (generic engineering lesson, no project-specific identifier) | user |
| Scope names a project-local module (e.g. `Auth.session`, `Search.reranker`) | project |
| References project-specific file/class/config | project |

When uncertain → suggest `project` (safe default; upgrade later via `know-ctl delete` + append `--level user`).

### Interaction

```
[learn] step: level
{N} 条待持久化知识的 level 归属：

1. [{tag}] {summary}
   建议: {project|user} — {reason}
2. ...

确认？回复 "ok" 接受全部建议；或 "1:user, 3:user" 覆盖特定编号；或 "all user" 全改 user。
```

[STOP:choose]

### User-level write confirmation

任何被标 `user` 的条目 → Step 9 写入前再确认一次：

```
[learn] 即将写入 user 级，跨所有项目生效。确认以下 {M} 条？

1. [{tag}] {summary}
2. ...

回复 "y" 确认；或 "1:project, 3:project" 降回 project；或 "cancel" 撤销这部分。
```

[STOP:confirm] Default on silence: treat as confirm after explicit `y`; any other single word → re-ask with options.

---

## Step 8: Confirm [STOP:confirm]

Show complete entry for user review.

Max 3 edit rounds. After 3rd edit: `A) Confirm current  B) Cancel entry`.

User can: confirm, edit summary/scope/tag/strict/ref, merge with existing, skip, cancel.

---

## Step 9: Write

Model: sonnet

```bash
# [RUN] append takes a JSON string + optional --level. Level is stored by file location, not in JSON.
TODAY=$(date +%Y-%m-%d) && bash "$KNOW_CTL" append --level {level} '{"tag":"{tag}","scope":"{scope}","summary":"{summary}","strict":{strict_or_null},"ref":{ref_or_null},"source":"learn","created":"'"$TODAY"'","updated":"'"$TODAY"'"}'
```

`{level}` = value confirmed in Step 7 (`project` | `user`). Omit `--level` falls back to project.

**Field values per tag**:

| Tag | strict | ref |
|-----|--------|-----|
| rule | true or false | optional string |
| insight | null (required) | optional string |
| trap | null (required) | optional string |

**Note**: v7 has no separate `entries/{tag}/{slug}.md` detail file. The `ref` field points to an existing paragraph in `docs/` (decision/arch/schema) or code/URL; context lives where humans browse.

```
[persisted] Auth.session :: session 过期必须触发刷新（project, strict=true, ref=docs/decision/auth.md#refresh）
```

---

## Completion

- All selected claims processed through Steps 2-9
- Each persisted entry has valid 8-field JSON line in the correct level's triggers.jsonl
- User saw `[persisted]` or `[skipped]` for every claim

## Recovery

| Error | Recovery |
|-------|----------|
| `know-ctl.sh` fails on append | Show error message. Do not retry silently. |
| User cancels mid-batch | Remaining claims discarded. Already-persisted entries kept. |
| Single claim fails in batch | Skip to next claim. Continue processing. Report skipped count at end. |
| Conflict check fails | Treat as no conflict, proceed to confirm. |
