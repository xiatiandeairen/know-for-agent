# extract — Code Knowledge Mining

## Progress

Steps: 6
Names: Scope, Scan, Extract, Filter, Confirm, Write

Shared definitions (schema, tiers, output blocks, paths) → SKILL.md.

---

## Step 1: Scope

Model: sonnet

Gate (always): runs on extract pipeline entry.

Determine which files to scan by inferring from conversation context:

| Priority | Source | Method |
|----------|--------|--------|
| P1 | Recent tool calls | Last 10 Read/Edit paths in this conversation → deduplicate |
| P2 | Conversation mentions | Explicit file paths mentioned by user |
| P3 | Fallback | Ask user: `[extract] No files detected in conversation. Provide path or glob:` |

```
[extract] Scan scope:
- src/auth/middleware.ts
- src/auth/session.ts
- src/config/index.ts

Correct? (add/remove files, or confirm)
```

[STOP:confirm] User confirms or adjusts scope.

**Limits**:
- Max 10 files per extraction run. >10 → rank by conversation relevance, take top 10, note remainder.
- Binary/generated files → auto-exclude.

---

## Step 2: Scan

Model: opus

Gate (always): scope confirmed in Step 1.

Read each file in scope. For each file, identify knowledge that is **not self-evident from the code alone** — the "why" behind the "what":

| Knowledge type | What to look for | Example |
|----------------|-----------------|---------|
| Design decisions | Patterns chosen over alternatives | "Uses pub/sub instead of direct calls for decoupling" |
| Implicit constraints | Rules enforced by convention, not compiler | "All handlers must call validate() before processing" |
| Non-obvious dependencies | Ordering, initialization, or coupling | "SessionStore must init before AuthMiddleware" |
| Configuration rules | Config combinations that must stay in sync | "TIMEOUT_MS must be < RETRY_INTERVAL_MS" |
| Defensive patterns | Guards against known failure modes | "Retry with backoff because upstream rate-limits at 100 req/s" |

**Per-file cap**: max 3 knowledge items per file. If more found → rank by impact (violation causes errors > violation wastes time), take top 3.

Output: raw list of `{file, knowledge_item, likely_tag}` tuples. Internal only, not shown to user.

---

## Step 3: Extract

Model: opus

Gate (auto): Step 2 found ≥1 knowledge item → enter. 0 found → `[extract] No extractable knowledge found in scanned files.` → exit.

Convert each knowledge item to a claim with preliminary fields:

| Field | Source |
|-------|--------|
| tag | Inferred from knowledge type (→ learn.md Step 5a patterns) |
| scope | File path → module notation (e.g. `src/auth/middleware.ts` → `auth.middleware`) |
| summary | ≤80 chars, `{conclusion} — {key reason}` format (→ SKILL.md Summary Rules) |

---

## Step 4: Filter

Model: sonnet

Gate (always): runs for each extracted claim.

Apply learn.md Step 3 Filter rules with one addition:

| # | Rule | Test | Action |
|---|------|------|--------|
| 0 | **Code-obvious** | A developer reading this file would understand this within 30 seconds without external context | DROP |

Rule 0 runs before all other filter rules. It is stricter than learn.md's "code-derivable" rule because extract starts from code — the bar for "not derivable" is higher.

**Skipped block format**:
```
[skipped] {summary}
Reason: {drop reason}
```

After filtering, apply learn.md Step 4 Assess (binary filter chain) to assign tier.

---

## Step 5: Confirm [STOP:choose]

Model: sonnet

Gate (auto): ≥1 claim survived Filter + Assess → enter. 0 survived → `[extract] All items filtered (code-obvious or low impact).` → exit.

```
[extract] Found {N} knowledge items from {M} files:

1. [{tag}] {summary} (tier: {tier})
   Source: {file_path}
2. [{tag}] {summary} (tier: {tier})
   Source: {file_path}

Persist? [all / select numbers / skip]
```

---

## Step 6: Write

Model: sonnet

Gate (auto): user selected ≥1 claim → enter. User skipped → exit.

For each selected claim, execute learn.md Steps 5-8 (Generate → Conflict → Confirm → Write):

1. **Generate** (learn.md Step 5): tag already assigned in Step 3. Generate remaining fields (tm, detail file if critical).
2. **Conflict** (learn.md Step 6): check for duplicates against existing index.
3. **Per-entry confirm** (learn.md Step 7): show complete entry for final review.
4. **Write** (learn.md Step 8): append to index, write detail file if critical.

```
[persisted] entries/{tag}/{slug}.md (critical)
```

---

## Completion

- All selected claims processed through Steps 3-6
- Each persisted entry has: valid index line + detail file (if critical)
- User saw `[persisted]` or `[skipped]` for every claim

## Recovery

| Error | Recovery |
|-------|----------|
| File read fails | Skip file, continue with remaining. Report skipped files at end. |
| All files excluded (binary/generated) | `[extract] No scannable files in scope.` → exit. |
| Single claim fails in batch | Skip claim, continue. Report skipped count at end. |
| Conflict check fails | Treat as no conflict, proceed to confirm. |
