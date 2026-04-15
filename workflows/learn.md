# learn — Knowledge Persistence

## Progress

Steps: 8
Names: Detect, Extract, Filter, Assess, Generate, Conflict, Confirm, Write

Shared definitions (schema, tiers, scope, output markers) → SKILL.md.

---

## Decay

Run at Step 1 entry, before signal detection. Skip if `.know/index.jsonl` does not exist.

```bash
# [RUN]
bash "$KNOW_CTL" decay
```

- Output `[decay] {N} deleted, {M} demoted` if any action taken.
- Silent if no entries affected.

---

## Step 1: Detect

Model: opus

**Trigger**: `/know learn` or routed from `/know` → scan full conversation.

### Signal types

| Signal | Typical language | Likely tag |
|--------|-----------------|------------|
| User correction | don't, not X use Y, wrong, should be, 必须, 不能 | constraint / rationale |
| Technical choice | chose, decided, instead of, tradeoff, 选了, 决定用 | rationale |
| Root cause | root cause, caused by, turns out, 根因, 问题是 | pitfall |
| Business logic | the flow is, algorithm, works by, 机制是, 流程是 | concept |
| Constraint declared | must not, forbidden, never, always, 千万别 | constraint |
| External integration | API, endpoint, SDK, webhook, 第三方接口 | reference |

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

[STOP:choose] User selects → each claim processed through Steps 2-8 sequentially.

---

## Step 2: Extract

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
- One choice + one rejection reason = usually one rationale entry
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
- Project-specific decision or constraint

### Output

```
[skipped] {summary}
Reason: {drop reason}
```

---

## Step 4: Assess

Model: opus

Determine tier: `critical`, `memo`, or `drop`.

### critical

Suitable when:
- Missing this knowledge easily leads to wrong implementation
- Causes obvious error, failure, or rework
- Is an important constraint, basically confirmed
- Has strong protective value for code changes

### memo

Suitable when:
- Has reuse value, saves understanding cost
- Helps reduce repeated discussion or low-level mistakes
- Not a hard constraint, but worth preserving

### drop

Suitable when:
- Low reuse, unconverged, weak value

### Signals to consider

- Did user explicitly say "must"/"cannot"/"reason is"?
- Is there verification, reproduction, test, or clear experience conclusion?
- Is it related to a critical implementation path?
- Would it protect against mistakes during future code changes?

### Output per claim

- tier + brief reason
- If downgraded from critical to memo: explain why (e.g. insufficient confirmation)

---

## Step 5: Generate

Model: opus

Convert claim into a formal entry. Execute sub-steps in order: tag → scope → tm → summary → detail file.

### 5a: Tag

| Pattern | Tag |
|---------|-----|
| Choice/comparison ("chose X over Y") | rationale |
| Prohibition ("must not", "forbidden", "always") | constraint |
| Bug/error/root-cause discovery | pitfall |
| Flow/algorithm/architecture/business-rule | concept |
| Integration/API/SDK/config | reference |

≥2 tags equally likely → ask user.

### 5b: Scope

Generate using SKILL.md Scope Guidelines. Scope should be stable, reusable, and hittable.

### 5c: Trigger Mode

| Claim type | Suggested tm |
|-----------|--------------|
| constraint + high risk | `active:defensive` |
| constraint + advisory | `active:directive` |
| pitfall + easy to repeat | `active:defensive` |
| rationale | `passive` |
| concept | `passive` |
| reference | `passive` (or `active:directive` if important integration rule) |

### 5d: Summary

Format: `{conclusion} — {key reason/context}`

Requirements: concise, readable, ≤80 chars, real information density, not an empty title.

Overflow: remove qualifiers → core conclusion only → still over → split into two entries.

### 5e: Detail File (critical only)

| Tag | Recommended sections |
|-----|---------------------|
| rationale | Why → Rejected alternatives → Constraints |
| constraint | Rule → Why → How to check |
| pitfall | Symptoms → Root cause → Lesson |
| concept | Overview → Key steps → Boundaries |
| reference | What it is → Usage → Caveats |

No frontmatter — all metadata in index.jsonl.

---

## Step 6: Conflict

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

## Step 7: Confirm [STOP:confirm]

Show complete entry for user review.

Max 3 edit rounds. After 3rd edit: `A) Confirm current  B) Cancel entry`.

User can: confirm, edit summary/scope/tag/tier/tm, merge with existing, skip, cancel.

If user is repeatedly uncertain → suggest downgrading to memo.

---

## Step 8: Write

Model: sonnet

```bash
# [RUN]
bash "$KNOW_CTL" append '{"tag":"...","tier":...,"scope":"...","tm":"...","summary":"...","path":"...","hits":0,"revs":0,"last_hit":null,"source":"learn","created":"YYYY-MM-DD","updated":"YYYY-MM-DD"}'
```

**Slug**: summary → 2-4 English keywords → hyphenated lowercase → `[a-z0-9-]` → max 50 chars.

| Tier | Write |
|------|-------|
| critical | Index entry + `$ENTRIES_DIR/{tag}/{slug}.md` |
| memo | Index entry only (`path: null`) |

```
[persisted] entries/constraint/pressure-thresholds.md (critical)
```

---

## Completion

- All selected claims processed through Steps 2-8
- Each persisted entry has: valid index line + detail file (if critical)
- User saw `[persisted]` or `[skipped]` for every claim

## Recovery

| Error | Recovery |
|-------|----------|
| `know-ctl.sh` fails on append | Show error message. Do not retry silently. |
| User cancels mid-batch | Remaining claims discarded. Already-persisted entries kept. |
| Detail file write fails | Remove corresponding index entry. Report error. |
| Single claim fails in batch | Skip to next claim. Continue processing. Report skipped count at end. |
| Conflict check fails | Treat as no conflict, proceed to confirm. |
