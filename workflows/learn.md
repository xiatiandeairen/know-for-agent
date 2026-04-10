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
[suggest-learn] Detected 2 high-value knowledge items:
1. [constraint] Thresholds defined only in PressureLevel, no hardcoded numbers
2. [pitfall] DataEngine singleton leaks state across test targets
Persist? [all / select / skip]
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
| "Use Combine not AsyncStream — no stack traces, weak backpressure" | no | conclusion + reason is a unit, reason alone is meaningless |
| "DataEngine is a singleton / DataEngine leaks state across tests" | yes | two independent facts, knowing one doesn't require the other |
| "API returns 200 with payload {user, token}" | no | data structure description is one complete unit |
| "Chose JSONL over SQLite; JSONL newlines need escaping" | yes | tech choice and usage caveat are independently retrievable |

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
| "PressureLevel enum has values 35/55/75" | YES | grep can find it |
| "Chose PressureLevel enum because v1 had scattered magic numbers causing inconsistent scoring" | NO | code shows the enum, not *why* it was chosen |
| "DataEngine is a singleton" | YES | code structure reveals it |
| "DataEngine singleton leaks state across test targets" | NO | requires having encountered the bug |

---

## Step 4: 2-Question Tier Assessment

```
Q1: What happens if a future session lacks this knowledge?
    Negligible impact         → DROP
    Likely to waste time      → memo (tier 2)
    Likely to cause errors    → critical (tier 1)

Q2: Will this be needed again?
    Unlikely   → demote one level (critical→memo, memo→DROP)
    Likely     → keep
    Frequently → promote one level (memo→critical)
```

critical (tier 1) additionally requires confirmed knowledge (verified via test, reproduction, or multi-source agreement). If impact is high but knowledge is unconfirmed, assign memo — if the knowledge is valuable, it will surface again in future conversations and can be promoted then.

### Calibration Examples

**critical (tier 1)**:
- "Thresholds defined only in PressureLevel, no hardcoding" — violation causes multi-module scoring inconsistency (broad error)
- "Must use Combine, not AsyncStream" — wrong choice causes debugging difficulty, no stack traces (repeated error)
- "index.jsonl one entry per line, no formatted JSON" — violation causes parse failure (data corruption)

**memo (tier 2)**:
- "Panel animation uses Canvas real-time drawing, not frame animation" — not knowing just wastes exploration time (time waste)
- "decay command runs monthly" — forgetting doesn't break functionality (operational note)
- "Score algorithm referenced formula from paper X" — useful background but doesn't affect implementation (context)

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

### Detail File (critical tier 1 only)

Body format varies by tag:

| Tag | Sections |
|-----|----------|
| rationale | `# Title` → Why → Rejected alternatives → Constraints |
| constraint | `# Title` → Rule → Why → How to check |
| pitfall | `# Title` → Symptoms → Root cause → Lesson |
| concept | `# Title` → Overview → Key steps → Boundaries |
| reference | `# Title` → What it is → Usage → Caveats |

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
[conflict] Similar entry found:

Existing: {existing summary}
New: {new summary}

Choose:
A) Update existing entry
B) Keep both
C) Merge into one
D) Skip new entry
```

---

## Step 7: Display and Confirm

Wait for user confirmation before proceeding.

Present complete entry:

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

For critical (tier 1): write detail file to `$ENTRIES_DIR/{tag}/{slug}.md`.

**Slug generation**:
1. Take summary text
2. Extract 2-4 English keywords (module names, API names, key terms)
3. Join with hyphens, lowercase: `pressure-thresholds`, `combine-over-asyncstream`
4. Max 50 characters; truncate at last complete word
5. Must be filesystem-safe: `[a-z0-9-]` only

For memo (tier 2): index entry only, `path: null`.

```
[persisted] entries/constraint/pressure-thresholds.md (tier 1)
```
