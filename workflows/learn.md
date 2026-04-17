# learn — Knowledge Persistence

## Progress

Steps: 9
Names: Detect, Extract, Filter, Assess, Generate, Conflict, Challenge, Confirm, Write

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

### Tier definitions

| Tier | Name | When to use |
|------|------|-------------|
| 1 | critical | Not knowing this causes AI to produce code that fails to compile or causes data loss/corruption. Must be confirmed knowledge. |
| 2 | memo | Worth noting, helps avoid wasted time, but AI would eventually discover the issue through tests/review. |

### Trigger mode definitions

| tm | When to use | Recall behavior |
|----|-------------|-----------------|
| `guard` | Important rules, known traps, easily violated during code changes | Prioritize; warn or block |
| `info` | Background knowledge, insights, recommended practices | Suggest when relevant |

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

## Step 4: Assess

Model: opus

Determine tier: `critical`, `memo`, or `drop`.

### critical

Suitable when:
- Missing this knowledge easily leads to wrong implementation
- Causes obvious error, failure, or rework
- Is an important rule, basically confirmed
- Has strong protective value for code changes

### memo

Suitable when:
- Has reuse value, saves understanding cost
- Helps reduce repeated discussion or low-level mistakes
- Not a hard rule, but worth preserving

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
| Choice/comparison ("chose X over Y") | insight |
| Prohibition ("must not", "forbidden", "always") | rule |
| Bug/error/root-cause discovery | trap |
| Flow/algorithm/architecture/business-rule | insight |
| Integration/API/SDK/config | insight |

≥2 tags equally likely → ask user.

### 5b: Scope

Generate using SKILL.md Scope Guidelines. Scope should be stable, reusable, and hittable.

### 5c: Trigger Mode

| Claim type | Suggested tm |
|-----------|--------------|
| rule + high risk | `guard` |
| rule + advisory | `info` |
| trap + easy to repeat | `guard` |
| insight | `info` |

### 5d: Summary

Format: `{conclusion} — {key reason/context}`

Requirements: concise, readable, ≤80 chars, real information density, not an empty title.

Overflow: remove qualifiers → core conclusion only → still over → split into two entries.

### 5e: Detail File (critical only)

| Tag | Recommended sections |
|-----|---------------------|
| insight | Why → Rejected alternatives → Constraints |
| rule | Rule → Why → How to check |
| trap | Symptoms → Root cause → Lesson |

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

0 results → skip Phase 2, proceed to Step 8.

### Phase 2: Relationship classification

Compare each candidate against new claim. Classify as:

| Relationship | Action |
|-------------|--------|
| unrelated | → Step 8 |
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

## Step 7: Challenge

Model: opus

Adversarial review of each generated entry before user sees it. Goal: catch weak, vague, or misclassified entries before they pollute the knowledge base.

### Per entry, answer 5 questions internally

| # | Challenge question | Fail action |
|---|-------------------|-------------|
| 1 | Is the conclusion falsifiable? Can you construct a scenario where it's wrong? | If trivially falsifiable → drop or narrow scope |
| 2 | Would a different AI, without this knowledge, actually produce broken code? | If no → demote tier 1 to tier 2 |
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
1. [{tag}] {summary} — tier {tier}, tm {tm}, scope {scope}
2. ...

持久化？ [all / 选编号 / skip]
```

[STOP:choose] User selects → each surviving entry processed through Steps 8-9.

---

## Step 8: Confirm [STOP:confirm]

Show complete entry for user review.

Max 3 edit rounds. After 3rd edit: `A) Confirm current  B) Cancel entry`.

User can: confirm, edit summary/scope/tag/tier/tm, merge with existing, skip, cancel.

If user is repeatedly uncertain → suggest downgrading to memo.

---

## Step 9: Write

Model: sonnet

```bash
# [RUN] append accepts exactly 1 argument: a complete JSON string. No positional args.
TODAY=$(date +%Y-%m-%d) && bash "$KNOW_CTL" append '{"tag":"{tag}","tier":{tier},"scope":"{scope}","tm":"{tm}","summary":"{summary}","path":{path_or_null},"hits":0,"revs":0,"source":"learn","created":"'"$TODAY"'","updated":"'"$TODAY"'"}'
```

**Slug**: summary → 2-4 English keywords → hyphenated lowercase → `[a-z0-9-]` → max 50 chars.

| Tier | Write |
|------|-------|
| critical | Index entry + `$ENTRIES_DIR/{tag}/{slug}.md` |
| memo | Index entry only (`path: null`) |

```
[persisted] entries/rule/pressure-thresholds.md (critical)
```

---

## Completion

- All selected claims processed through Steps 2-9
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
