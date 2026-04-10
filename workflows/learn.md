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

### Signal Confidence

Each detected signal is assessed for confidence:
- **High**: Explicit user statement with clear intent (e.g. "we always use X", "never do Y")
- **Medium**: Contextual inference from discussion (e.g. user corrected AI behavior)
- **Low**: Ambiguous or incidental mention

Only high and medium confidence signals are proposed. Low confidence signals are silently dropped.

Implicit signals are batched and proposed after task completion:

```
> [suggest-learn] 检测到 2 条高价值知识:
> 1. [constraint|T1] 阈值只在 PressureLevel 定义，禁止硬编码数字
> 2. [pitfall|T2] DataEngine 单例在测试 target 间泄漏状态
> 持久化? [全部 / 选择 / 跳过]
```

---

## Step 2: Claim Extraction

Extract minimal knowledge units from conversation context.

Rules:
- One claim = one fact / rule / decision / pattern
- Multiple claims → split, process each independently
- Strip conversation noise, keep only the actionable conclusion

---

## Step 3: Route Interception (fast DROP)

Sequential check. First match terminates.

```
Derivable from code/git?     → DROP
Needed every session?         → Belongs in CLAUDE.md
Personal preference?          → Belongs in auto memory
No clear conclusion yet?      → DROP (persist after confirmation)
One-time information?         → DROP
```

---

## Step 4: 3-Question Tier Assessment

Replace complex 5-dimension scoring with 3 concrete questions.

```
Q1: Can this be derived from code or git?
    Yes → DROP
    No  → continue

Q2: What happens if a future session lacks this knowledge?
    Negligible impact     → DROP
    Likely to waste time  → tier 3
    Likely to make errors → tier 2
    Errors with broad impact → tier 1

Q3: Will this be needed again?
    Unlikely   → demote one level (tier 2→3, tier 3→DROP)
    Likely     → keep
    Frequently → promote one level (tier 3→2, tier 2→1)
```

Final tier must satisfy: `tier 1` requires confirmed knowledge (verified via test, reproduction, or multi-source agreement).

See SKILL.md → Tier Rules for tier assignment criteria and confirmation requirements.

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
    src/mac/Packages/{Module}/ → {Module}
    src/mac/App/{SubDir}/      → App.{SubDir}
    src/plugins/{Plugin}/      → {Plugin}

P2: Recent tool calls
    Last 10 Read/Edit file_path → extract module
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

### Detail File (tier 1/2 only)

Body format varies by tag:

| Tag | Sections |
|-----|----------|
| rationale | `# Title` → Why → Rejected alternative → Constraint |
| constraint | `# Title` → Rule → Why → Check |
| pitfall | `# Title` → Symptom → Root cause → Lesson |
| concept | `# Title` → Overview → Key steps → Boundary |
| reference | `# Title` → What → Usage → Caveats |

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

User confirms → Step 8. User edits → adjust and re-display.

---

## Step 8: Write

```bash
# [RUN] Append to index
bash "$KNOW_CTL" append '{"tag":"constraint","tier":1,"scope":"LoppyMetrics","tm":"active:defensive","summary":"Thresholds defined only in PressureLevel, no hardcoded numbers","path":"entries/constraint/pressure-thresholds.md","hits":0,"revs":0,"created":"2026-04-08","updated":"2026-04-08"}'
```

For tier 1/2: write detail file to `$ENTRIES_DIR/{tag}/{slug}.md`.

For tier 3: index entry only, `path: null`.

```
> [persisted] entries/constraint/pressure-thresholds.md (层级 1)
```
