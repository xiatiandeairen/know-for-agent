# review — Knowledge Audit

## Progress

Steps: 3
Names: Load, Display, Process

Shared definitions (schema, tiers, decay, output blocks, paths) → SKILL.md.

---

## Step 1: Load

Model: sonnet

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

Pre-display: show review summary from metrics (衰减率 + 覆盖率):

```bash
# [RUN]
bash "$KNOW_CTL" metrics 2>/dev/null | grep -E "衰减率|覆盖率"
```

```
[review] 衰减率 {衰减率} | 覆盖率 {覆盖率}
```

Sort: tier desc (critical first), then age desc (oldest first).

Lifecycle stage column — compute per entry using `created`, `hits`, `last_hit`, decay rules:

| Stage | Condition | Icon |
|-------|-----------|------|
| new | created < 7d, hits = 0 | 🆕 |
| active | last_hit < 30d | ✅ |
| silent | last_hit > 30d or (hits=0 + created > 7d) | 💤 |
| endangered | meets decay delete/demote criteria | ⚠ |

```
[review] {N} entries found:

| # | tag | tier | scope | hits | age | summary | stage |
|---|-----|------|-------|------|-----|---------|-------|
| 1 | constraint | critical | Auth | 5 | 30d | Thresholds... | ✅ |
| 2 | rationale | memo | Auth | 0 | 15d | ... | 💤 |

All ok? Or enter numbers to process (e.g. "2" or "1,3"):
```

| User Response | Action |
|--------------|--------|
| all ok / ok / 没问题 | exit |
| Number(s) | → Step 3 with selected entries |

---

## Step 3: Process

Model: sonnet

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
