# review — Knowledge Audit

## Progress

Steps: 3
Names: Load, Display, Process

Shared definitions (schema, tiers, decay, output blocks, paths) → SKILL.md.

---

## Step 1: Load

Model: sonnet

Gate (always): runs on `/know review` trigger.

```
/know review          → scope = "project"
/know review <scope>  → scope = argument
```

```bash
# [RUN]
bash "$KNOW_CTL" query "{scope}"
```

**Gate**: 0 results → `[review] No entries found.` → exit.

Parse each result line, compute age in days from `created` field.

---

## Step 2: Display [STOP:choose]

Model: sonnet

Gate (auto): Step 1 returned ≥1 entry → enter. 0 entries → exit.

Pre-display: show review summary from metrics (衰减率 + 覆盖率):

```bash
# [RUN]
bash "$KNOW_CTL" metrics 2>/dev/null | grep -E "衰减率|覆盖率"
```

```
[review] 衰减率 {衰减率} | 覆盖率 {覆盖率}
```

Sort by lifecycle stage (most actionable first), then age desc within each stage:

1. `[endangered]` — most urgent, about to be decayed
2. `[silent]` — cleanup candidates
3. `[new]` — recently added, not yet validated
4. `[active]` — healthy, lowest priority

Lifecycle stage — compute per entry using `created`, `hits`, `last_hit` (null = never hit):

| Stage | Condition | Label |
|-------|-----------|-------|
| new | age < 7d AND hits = 0 | `[new]` |
| active | last_hit is not null AND last_hit < 30d ago | `[active]` |
| silent | last_hit is null or last_hit > 30d ago, AND age ≥ 7d | `[silent]` |
| endangered | meets decay delete/demote criteria (→ learn.md Decay) | `[endangered]` |

```
[review] {N} entries found:

| # | tag | tier | scope | hits | age | summary | stage |
|---|-----|------|-------|------|-----|---------|-------|
| 1 | constraint | critical | Auth | 5 | 30d | Thresholds... | [active] |
| 2 | rationale | memo | Auth | 0 | 15d | ... | [silent] |

All ok? Or enter numbers to process (e.g. "2" or "1,3"):
```

| User Response | Action |
|--------------|--------|
| all ok / ok / 没问题 | exit |
| Number(s) | → Step 3 with selected entries |

---

## Step 3: Process

Model: sonnet

Gate (auto): user selected ≥1 entry in Step 2 → enter. User said "all ok" → exit.

For each selected entry:

```
[review] #{N}: {summary}
Tag: {tag} | Tier: {tier} | Hits: {hits} | Age: {age}d
Action? A) Delete  B) Update  C) Keep
```

### A) Delete

```bash
# [RUN]
bash "$KNOW_CTL" delete "{summary_keyword}"
```

Output: `[review] Deleted: {summary}`

### B) Update

User describes change → re-generate summary (+ detail file if critical) → show updated entry [STOP:confirm] → on confirm:

```bash
# [RUN]
bash "$KNOW_CTL" update "{old_summary_keyword}" '{"summary":"{new_summary}"}'
```

If critical: overwrite detail file with new content.

Output: `[review] Updated: {new_summary}`

### C) Keep

Output: `[review] Kept: {summary}`

After all processed: `[review] Done: {deleted} deleted, {updated} updated, {kept} kept`

---

## Completion

- All selected entries processed with `[review]` confirmation each
- Index and detail files consistent with actions taken

## Recovery

| Error | Recovery |
|-------|----------|
| `know-ctl delete/update` fails | Show error, skip entry, continue next |
| User cancels mid-process | Already-processed entries kept, remaining skipped |
