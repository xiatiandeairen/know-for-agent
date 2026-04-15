# extract — Code Knowledge Mining

## Progress

Steps: 6
Names: Scope, Scan, Extract, Filter, Confirm, Write

Shared definitions (schema, tiers, scope, output markers) → SKILL.md.

---

## Step 1: Scope

Model: sonnet

Determine which files to scan by inferring from conversation context:

| Priority | Source | Method |
|----------|--------|--------|
| P1 | Recent tool calls | Last 10 Read/Edit paths in this conversation → deduplicate |
| P2 | Conversation mentions | Explicit file paths mentioned by user |
| P3 | Fallback | Ask user: `[extract] No files detected in conversation. Provide path or glob:` |

```
[extract] step: scope
Scan scope:
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

Read each file in scope. Identify knowledge that is **not self-evident from the code alone** — the "why" behind the "what".

### 5 knowledge types to look for

| Type | What to look for | Example |
|------|-----------------|---------|
| Design decisions | Why this pattern, why this split, why this wrapper exists | "Uses pub/sub instead of direct calls for decoupling" |
| Implicit constraints | Rules enforced by convention, not compiler | "All handlers must call validate() before processing" |
| Non-obvious dependencies | Ordering, initialization, coupling | "SessionStore must init before AuthMiddleware" |
| Configuration rules | Config combinations that must stay in sync | "TIMEOUT_MS must be < RETRY_INTERVAL_MS" |
| Defensive patterns | Guards against known failure modes | "Retry with backoff because upstream rate-limits at 100 req/s" |

### Scanning principles

- Do not restate what the code surface-level shows
- Focus on "why is it written this way" and "what goes wrong if you don't know this"
- Max 3 knowledge items per file. If more found → rank by impact (causes errors > wastes time), take top 3.

Output: internal list of `{file, knowledge_item, likely_tag}` tuples. Not shown to user.

---

## Step 3: Extract

Model: opus

Convert each knowledge item to a claim. Each claim should capture:

- **Conclusion**: the core knowledge
- **Reason**: why this matters
- **Scope**: affected area
- **Risk**: what goes wrong if you don't know this

Formal fields:

| Field | Source |
|-------|--------|
| tag | Inferred from knowledge type (→ learn.md Step 5a patterns) |
| scope | File path → module notation (e.g. `src/auth/middleware.ts` → `auth.middleware`) |
| summary | ≤80 chars, `{conclusion} — {key reason}` format |

Examples:
- `Retry must use idempotency key — webhook delivery may be duplicated`
- `Worker should start before subscription binding — early events may be missed`

If Step 2 found 0 items → `[extract] No extractable knowledge found in scanned files.` → exit.

---

## Step 4: Filter

Model: sonnet

Apply learn.md Step 3 Filter rules with one addition:

| Condition | Action |
|-----------|--------|
| **Code-obvious** — a developer reading this file would understand within 30 seconds without external context | DROP |

This is stricter than learn's "code-derivable" rule because extract starts from code — the bar for "not derivable" is higher.

### Usually KEEP from code

- Reason not visible from surface code
- Easy to repeat mistakes
- Involves external systems, timing, ordering, idempotency, config coupling
- Has long-term protective value even if single-file

After filtering, apply learn.md Step 4 Assess to assign tier.

```
[skipped] {summary}
Reason: {drop reason}
```

---

## Step 5: Confirm [STOP:choose]

Model: sonnet

If 0 claims survived → `[extract] All items filtered (code-obvious or low impact).` → exit.

```
[extract] step: confirm
Found {N} knowledge items from {M} files:

1. [{tag}] {summary} (tier: {tier})
   Source: {file_path}
2. [{tag}] {summary} (tier: {tier})
   Source: {file_path}

Persist? [all / select numbers / skip]
```

---

## Step 6: Write

Model: sonnet

For each selected claim, execute learn.md Steps 5-8:

1. **Generate** (learn.md Step 5): tag already assigned. Generate remaining fields (tm, detail file if critical). Set `source: "extract"`.
2. **Conflict** (learn.md Step 6): check for duplicates against existing index.
3. **Per-entry confirm** (learn.md Step 7): show complete entry for final review.
4. **Write** (learn.md Step 8): append to index, write detail file if critical.

```
[persisted] entries/{tag}/{slug}.md (critical)
```

---

## Completion

- All selected claims processed
- Each persisted entry has: valid index line + detail file (if critical)
- User saw `[persisted]` or `[skipped]` for every claim

## Recovery

| Error | Recovery |
|-------|----------|
| File read fails | Skip file, continue with remaining. Report skipped files at end. |
| All files excluded (binary/generated) | `[extract] No scannable files in scope.` → exit. |
| Single claim fails in batch | Skip claim, continue. Report skipped count at end. |
| Conflict check fails | Treat as no conflict, proceed to confirm. |
