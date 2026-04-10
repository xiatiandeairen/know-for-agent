# learn — Mental Model Correction

Persist tacit high-value knowledge that code and git cannot express. Reduce future exploration errors by recording rationale, constraints, pitfalls, concepts, and references.

---

## Step 1: Trigger

Two modes:

**Explicit** — User invokes `/know learn`. Process current conversation immediately.

**Implicit** — AI detects one of 6 signal types during conversation:

| Signal | Detection Pattern | Likely Tag |
|--------|------------------|------------|
| User correction | "don't do X", "we use Y here", "change to Z" | constraint / rationale |
| Technical choice | "chose X", "X over Y", "compared A and B" | rationale |
| Root cause found | "turns out", "root cause is", "the issue was" | pitfall |
| Business logic explained | "the flow is", "algorithm works by", "rule is" | concept |
| Constraint declared | "must not", "always", "forbidden", "never" | constraint |
| External integration | "integrated X", "API endpoint", "configured via" | reference |

### Signal Filtering Rule

Only propose signals that contain at least one detection pattern keyword from the table above. Specifically:

- User correction: contains correction verbs ("don't", "not X use Y", "change to", "wrong", "should be")
- Technical choice: contains choice verbs ("chose", "picked", "decided", "over", "instead of", "compared")
- Root cause found: contains discovery phrases ("turns out", "root cause", "the issue was", "because of", "caused by")
- Business logic explained: contains explanation phrases ("the flow is", "algorithm", "works by", "rule is", "the logic")
- Constraint declared: contains constraint words ("must not", "always", "forbidden", "never", "required")
- External integration: contains integration terms ("API", "endpoint", "SDK", "configured via", "integrated")

Signals without any matching keyword are silently dropped. Do not propose ambiguous or incidental mentions.

Implicit signals are batched and proposed after task completion. User selects which to persist, then each claim is processed sequentially through Step 2-8 (one at a time, confirm each before next):

```
> [suggest-learn] 检测到 2 条高价值知识:
> 1. [constraint] 阈值只在 PressureLevel 定义，禁止硬编码数字
> 2. [pitfall] DataEngine 单例在测试 target 间泄漏状态
> 持久化? [全部 / 选择 / 跳过]
```

---

## Step 2: Claim Extraction

Extract minimal knowledge units from conversation context.

Rules:
- One claim = one fact / rule / decision / pattern
- Multiple claims → split, process each independently
- Strip conversation noise, keep only the actionable conclusion

**Claim boundary**: one claim = one independently retrievable knowledge unit. If knowing A does not require knowing B, they are separate claims.

**Examples**:

| Conversation content | Split? | Reason |
|---------------------|--------|--------|
| "用 Combine 不用 AsyncStream — 没有堆栈信息，背压弱" | 不拆 | 结论+原因是整体，原因脱离结论无意义 |
| "DataEngine 是单例 / DataEngine 在测试间泄漏状态" | 拆 | 两个独立事实，知道其一不需要知道其二 |
| "API 返回 200 时 payload 是 {user, token}" | 不拆 | 数据结构描述是一个完整单元 |
| "选了 JSONL 不用 SQLite；JSONL 的换行符需要转义" | 拆 | 技术选型和使用注意事项可独立检索 |

**Rule**: prefer not splitting over over-splitting. A claim with context is more useful than a fragment without.

---

## Step 3: Route Interception (fast DROP)

Sequential check. First match terminates.

```
Readily derivable from code/git?  → DROP
Needed every session?              → Belongs in CLAUDE.md
Personal preference?               → Belongs in auto memory
No clear conclusion yet?           → DROP (persist after confirmation)
One-time information?              → DROP
```

**"Readily derivable"** = an AI unfamiliar with this codebase can reach the same conclusion via grep, git log, or code reading within 2 minutes.

| Example | Derivable? | Why |
|---------|-----------|-----|
| "PressureLevel enum has values 35/55/75" | ✓ YES | grep can find it |
| "选 PressureLevel enum 是因为 v1 散落的魔法数字导致评分不一致" | ✗ NO | code shows the enum, not *why* it was chosen |
| "DataEngine is a singleton" | ✓ YES | code structure reveals it |
| "DataEngine singleton leaks state across test targets" | ✗ NO | requires having encountered the bug |

---

## Step 4: 2-Question Tier Assessment

```
Q1: What happens if a future session lacks this knowledge?
    Negligible impact         → DROP
    Likely to waste time      → 备忘 (tier 2)
    Likely to cause errors    → 重要 (tier 1)

Q2: Will this be needed again?
    Unlikely   → demote one level (重要→备忘, 备忘→DROP)
    Likely     → keep
    Frequently → promote one level (备忘→重要)
```

重要 (tier 1) additionally requires confirmed knowledge (verified via test, reproduction, or multi-source agreement). If impact is high but knowledge is unconfirmed, assign 备忘 — if the knowledge is valuable, it will surface again in future conversations and can be promoted then.

### Calibration Examples

**重要 (tier 1)**:
- "阈值只在 PressureLevel 定义，禁止硬编码" — 违反导致多模块评分不一致 (broad error)
- "必须用 Combine 而非 AsyncStream" — 错误选择导致调试困难，无堆栈 (repeated error)
- "index.jsonl 每行一条，禁止格式化 JSON" — 违反导致解析失败 (data corruption)

**备忘 (tier 2)**:
- "Panel 动画用 Canvas 实时绘制，非帧动画" — 不知道只是多花时间探索 (time waste)
- "decay 命令每月跑一次即可" — 忘了不影响功能 (operational note)
- "score 算法参考了论文 X 的公式" — 有用背景但不影响实现 (context)

See SKILL.md → Tier Rules for tier definitions and decay policy.

---

## Step 5: Entry Generation

### Tag Classification

| Pattern | Tag |
|---------|-----|
| Choice/comparison verbs, "chose X over Y" | rationale |
| "must not", "forbidden", "always", "never" | constraint |
| Bug/error/root-cause/lesson | pitfall |
| Flow/algorithm/architecture/business-rule | concept |
| Integration/API/SDK/tool-name/config | reference |

Ambiguous → present all 5 tags and ask user to choose.

### Scope Inference

Priority order, first match wins:

```
P1: Explicit file paths in conversation
    Extract module from path using industry-standard directory conventions:
    src/{module}/          → {module}
    lib/{module}/          → {module}
    packages/{module}/     → {module}
    apps/{module}/         → {module}
    services/{module}/     → {module}
    components/{module}/   → {module}
    plugins/{module}/      → {module}
    Nested paths use dot notation: src/auth/middleware/ → auth.middleware

P2: Recent tool calls
    Last 10 Read/Edit file_path → extract module using P1 rules
    Module appearing ≥2 times → scope

P3: Keywords
    Exact module name match in conversation text

P4: Fallback
    scope ≥3 modules → "project"
    scope empty → "project"
```

For cross-module scope, use JSON array format: `["ModuleA", "ModuleB"]`. See SKILL.md → JSONL Schema for serialization details.

### Trigger Mode Inference

```
Contains "must not / forbidden / never / always" → active:defensive
Contains "recommended / prefer / should"         → active:directive
Otherwise                                        → passive
```

### Summary Compression

- ≤ 80 characters
- Must contain retrieval anchor terms (module names, API names, error patterns)
- Structure: conclusion + key reason
- Example: "Use Combine not AsyncStream — no stack traces, weak backpressure"

If summary exceeds 80 characters after initial compression:
1. Remove secondary qualifiers (adjectives, parenthetical notes)
2. Shorten to core conclusion only
3. If still over 80 chars, split into two entries with narrower scope each

### Detail File (重要 tier 1 only)

Body format varies by tag:

| Tag | Sections |
|-----|----------|
| rationale | `# 标题` → 为什么 → 被拒绝的方案 → 约束 |
| constraint | `# 标题` → 规则 → 为什么 → 检查方式 |
| pitfall | `# 标题` → 症状 → 根因 → 教训 |
| concept | `# 标题` → 概述 → 关键步骤 → 边界 |
| reference | `# 标题` → 是什么 → 用法 → 注意事项 |

No frontmatter in .md files — all metadata lives in index.jsonl.

---

## Step 6: Conflict Detection (2-phase)

### Phase 1: Keyword Pre-filter

Extract keywords from new summary. Count scales with summary length:

```
summary ≤ 30 chars → 2 keywords
summary 30-60 chars → 3 keywords
summary > 60 chars → 4 keywords
```

```bash
# [RUN]
bash "$KNOW_CTL" search "<keyword1>|<keyword2>"
```

**Input**: pipe-separated keywords as regex alternation pattern
**Output**: matching JSONL entries, one per line (full JSON objects)
**Returns**: 0-N lines; empty output means no matches
**Matching**: searches `summary` field by regex

→ Candidate set (typically 0-5 entries)

### Phase 2: LLM Similarity Assessment

Present candidate summaries alongside new claim summary. Classify:

| Verdict | Action |
|---------|--------|
| Unrelated | Proceed to Step 7 (new entry) |
| Supplementary (same topic, different angle) | Proceed to Step 7, optionally note relation |
| Duplicate (same conclusion) | Display conflict block, ask user to choose |
| Contradictory (opposite conclusion) | Display conflict block, ask user to choose |

Conflict block format:

```
> [conflict] 发现相似条目:
>
> 已有: {existing summary}
> 新增: {new summary}
>
> 请选择:
> A) 更新已有条目
> B) 保留两条
> C) 合并为一条
> D) 跳过新条目
```

---

## Step 7: Display and Confirm

Wait for user confirmation before proceeding.

Present complete entry:

```
> [learn] 待确认条目:
>
> 标签: constraint | 层级: 1 | 范围: LoppyMetrics
> 触发: active:defensive
> 摘要: 阈值只在 PressureLevel 定义，禁止硬编码数字
>
> --- entries/constraint/pressure-thresholds.md ---
> # 阈值只在 PressureLevel 定义
> 所有压力阈值 (35/55/75) 在 PressureLevel 枚举中定义。
> ## 为什么
> 分散的魔法数字导致 v1 评分不一致。
> ## 检查方式
> grep 检查 PressureLevel 外是否有硬编码的 35/55/75。
```

User confirms → Step 8.

User edits → apply changes, then:
- If summary was modified → re-run Step 6 (conflict detection) with new summary
- If other fields changed (tag, scope, tier, detail content) → re-display for confirmation without re-running conflict detection
- If user changes tag → adjust detail file section structure to match new tag format

User cancels → discard entry, return to conversation.

---

## Step 8: Write

```bash
# [RUN] Append to index
bash "$KNOW_CTL" append '{"tag":"constraint","tier":1,"scope":"LoppyMetrics","tm":"active:defensive","summary":"Thresholds defined only in PressureLevel, no hardcoded numbers","path":"entries/constraint/pressure-thresholds.md","hits":0,"revs":0,"created":"2026-04-08","updated":"2026-04-08"}'
```

**Input**: single-line JSON string matching JSONL schema (10 fields)
**Output**: none on success; error message on failure (invalid JSON, missing fields)
**Effect**: appends one line to index.jsonl
**Validation**: script validates required fields (tag, tier, scope, summary, created, updated)

For 重要 (tier 1): write detail file to `$ENTRIES_DIR/{tag}/{slug}.md`.

**Slug generation**:
1. Take summary text
2. Extract 2-4 English keywords (module names, API names, key terms)
3. Join with hyphens, lowercase: `pressure-thresholds`, `combine-over-asyncstream`
4. Max 50 characters; truncate at last complete word
5. Must be filesystem-safe: `[a-z0-9-]` only

For 备忘 (tier 2): index entry only, `path: null`.

```
> [persisted] entries/constraint/pressure-thresholds.md (层级 1)
```
