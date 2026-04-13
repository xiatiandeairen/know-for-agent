# learn — Knowledge Persistence

## Progress

Steps: 8
Names: Detect, Extract, Filter, Assess, Generate, Conflict, Confirm, Write

Shared definitions (schema, tiers, output blocks, paths) → SKILL.md.

---

## Decay

Run at Step 1 entry, before signal detection. Skip if `.knowledge/index.jsonl` does not exist.

```
memo     + hits=0 + age > 30d  → delete
critical + hits=0 + age > 180d → demote to memo
critical + revs > 3            → demote to memo (unstable)
```

```bash
# [RUN]
bash "$KNOW_CTL" decay
```

- Output `[decay] {N} deleted, {M} demoted` if any action taken.
- Silent if no entries affected.

---

## Step 1: Detect

Model: opus

**Pre-step**: run decay (→ Decay section above).

**Explicit**: `/know learn` → scan full conversation.

**Implicit**: AI detects signals during conversation, batches after current task completes:

| Signal | Keywords (>=1 must match) | Likely Tag |
|--------|--------------------------|------------|
| User correction | don't, not X use Y, change to, wrong, should be | constraint / rationale |
| Technical choice | chose, picked, decided, over, instead of, compared | rationale |
| Root cause | turns out, root cause, the issue was, because of | pitfall |
| Business logic | the flow is, algorithm, works by, rule is | concept |
| Constraint declared | must not, always, forbidden, never | constraint |
| External integration | API, endpoint, SDK, configured via | reference |

**Gate**: signal must contain >=1 keyword from its row. No match → silently drop. Ambiguous without clear keyword → drop.

**Default**: no signals → "No persistable knowledge detected in this conversation."

[STOP:choose] User selects → each claim processed through Steps 2-8 sequentially (one at a time, confirm each before next).

---

## Step 2: Extract

Model: opus

One claim = one independently retrievable knowledge unit.

| # | Rule |
|---|------|
| 1 | Knowing A doesn't require knowing B → separate |
| 2 | Conclusion + its direct reason = one unit (do not split) |
| 3 | Strip conversation noise, keep only actionable conclusion |
| 4 | Uncertain whether to split → do not split |

| Conversation | Split? | Why |
|-------------|:------:|-----|
| "Use Combine not AsyncStream — no stack traces, weak backpressure" | no | conclusion + reason is one unit |
| "DataEngine is a singleton / DataEngine leaks state across tests" | yes | two independent facts |
| "Chose JSONL over SQLite; JSONL newlines need escaping" | yes | choice and caveat independently retrievable |

---

## Step 3: Filter

Model: sonnet

Sequential check. First match → `[skipped]` block → DROP.

**Skipped block format**:
```
[skipped] {summary}
Reason: {drop reason}
```

| # | Rule | Test | Example DROP |
|---|------|------|-------------|
| 1 | Code-derivable | AI reaches same conclusion via grep/git log in <2 min | "PressureLevel enum has 35/55/75" |
| 2 | CLAUDE.md material | Needed every session as project rule | coding conventions |
| 3 | Auto memory material | Personal preference, not project knowledge | "I prefer vim" |
| 4 | No conclusion | Discussion hasn't converged | "still deciding between A and B" |
| 5 | One-time | Will not recur | "used temp flag for this deploy" |

**Derivable boundary** — code shows *what*, not *why*:

| Claim | Derivable? |
|-------|:----------:|
| "PressureLevel enum has values 35/55/75" | yes |
| "Chose PressureLevel enum because v1 had scattered magic numbers" | no |
| "DataEngine singleton leaks state across test targets" | no |

---

## Step 4: Assess

Model: opus

```
Q1: Impact if a future session lacks this knowledge?
    Negligible       → DROP
    Wastes time      → memo
    Causes errors    → critical

Q2: Will this situation recur?
    Unlikely         → demote one level (critical→memo, memo→DROP)
    Likely           → keep current level
    Frequently       → promote one level (memo→critical)
```

**Constraint**: critical requires confirmed knowledge (verified via test, reproduction, or multi-source agreement). High impact + unconfirmed → memo. Promote when confirmed later.

| Claim | Tier | Why |
|-------|------|-----|
| Thresholds defined only in PressureLevel, no hardcoding | critical | violation → multi-module inconsistency |
| Must use Combine, not AsyncStream | critical | wrong choice → no stack traces, repeated |
| Panel animation uses Canvas, not frame animation | memo | wasted exploration time only |
| decay command runs monthly | memo | forgetting → no breakage |

---

## Step 5: Generate

Model: opus

### 5a: Tag

| Pattern | Tag |
|---------|-----|
| Choice/comparison ("chose X over Y") | rationale |
| Prohibition ("must not", "forbidden", "always", "never") | constraint |
| Bug/error/root-cause discovery | pitfall |
| Flow/algorithm/architecture/business-rule | concept |
| Integration/API/SDK/config | reference |

**Default**: claim matches >=2 tags equally → show all 5, ask user.

### 5b: Scope

Infer scope from **conversation context** (not current file operation — that is Recall's scope, → SKILL.md Recall). First match wins:

| Priority | Source | Method |
|----------|--------|--------|
| P1 | Explicit file paths in conversation | `src/{module}/` → `{module}`, nested → dot notation |
| P2 | Recent tool calls | Last 10 Read/Edit paths; module with >=2 occurrences wins |
| P3 | Keywords | Exact module name mentioned in conversation |
| P4 | Fallback | `"project"` |

Cross-module: JSON array `["A","B"]`.

### 5c: Trigger Mode

| Claim contains | tm |
|---------------|----|
| must not / forbidden / never / always | active:defensive |
| recommended / prefer / should | active:directive |
| none of the above | passive |

### 5d: Summary

→ SKILL.md Summary Rules.

Overflow (>80 chars): remove qualifiers → core conclusion only → still over → split into two entries with narrower scope.

### 5e: Detail File (critical only)

| Tag | Sections |
|-----|----------|
| rationale | Why → Rejected alternatives → Constraints |
| constraint | Rule → Why → How to check |
| pitfall | Symptoms → Root cause → Lesson |
| concept | Overview → Key steps → Boundaries |
| reference | What it is → Usage → Caveats |

No frontmatter — all metadata in index.jsonl.

---

## Step 6: Conflict

Model: sonnet

### Phase 1: Keyword Pre-filter

Extract N keywords from summary:

| Summary length | Keywords |
|---------------|----------|
| <=30 chars | 2 |
| 31-60 chars | 3 |
| >60 chars | 4 |

```bash
# [RUN]
bash "$KNOW_CTL" search "<kw1>|<kw2>"
```

0 results → skip Phase 2, proceed to Step 7.

### Phase 2: LLM Similarity

Compare each candidate against new claim:

| Verdict | Action |
|---------|--------|
| Unrelated | → Step 7 |
| Supplementary (same topic, different angle) | → Step 7 |
| Duplicate (same conclusion) | → `[conflict]` block [STOP:choose] |
| Contradictory (opposite conclusion) | → `[conflict]` block [STOP:choose] |

**Conflict block format**:
```
[conflict] Similar entry found:
Existing: {summary}
New: {summary}
Choose: A) Update existing  B) Keep both  C) Merge  D) Skip new
```

### Conflict Resolution

| Choice | Action |
|--------|--------|
| A) Update existing | → Update flow (below) |
| B) Keep both | → Step 7 with new entry |
| C) Merge | → Combine summaries into one, proceed to Step 7 |
| D) Skip new | → Discard new claim, return to conversation |

### Update Flow

1. Replace existing summary with new claim's summary
2. Re-generate detail file using new claim (→ Step 5e template)
3. Show updated entry for confirmation (→ Step 7)
4. On confirm:

```bash
# [RUN]
bash "$KNOW_CTL" update "{existing_summary_keyword}" '{"summary":"{new_summary}"}'
```

5. If critical: overwrite detail file at existing path

`know-ctl update` auto-increments `revs` and updates `updated`.

---

## Step 7: Confirm [STOP:confirm]

Display complete entry for review. → SKILL.md Examples for format.

| User Response | Action |
|--------------|--------|
| Confirms (ok/好/confirm/继续) | → Step 8 |
| Edits summary | Re-run Step 6 with new summary |
| Edits tag | Adjust detail file sections to match new tag template |
| Edits other fields (scope, tier) | Re-display for confirmation |
| Cancels (取消/cancel/skip) | Discard entry, return to conversation |

---

## Step 8: Write

Model: sonnet

```bash
# [RUN]
bash "$KNOW_CTL" append '{"tag":"...","tier":...,"scope":"...","tm":"...","summary":"...","path":"...","hits":0,"revs":0,"created":"YYYY-MM-DD","updated":"YYYY-MM-DD"}'
```

**Slug**: summary → 2-4 English keywords (module names, API names, key terms) → hyphenated lowercase → `[a-z0-9-]` only → max 50 chars → truncate at last complete word.

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

## Examples

### Signal batch

```
[suggest-learn] Detected 2 high-value claims:
1. [constraint] Thresholds defined only in PressureLevel, no hardcoded numbers
2. [pitfall] DataEngine singleton leaks state across test targets
Persist? [all / select / skip]
```

### Entry confirmation

```
[learn] Entry pending confirmation:

Tag: constraint | Tier: 1 | Scope: LoppyMetrics
Summary: Thresholds defined only in PressureLevel, no hardcoded numbers

--- entries/constraint/pressure-thresholds.md ---
# Thresholds defined only in PressureLevel
All pressure thresholds (35/55/75) are defined in the PressureLevel enum.
## Why
Scattered magic numbers caused inconsistent scoring in v1.
## How to check
grep for hardcoded 35/55/75 outside PressureLevel.

Confirm?
```
