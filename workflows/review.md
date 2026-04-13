# review — Knowledge Audit

## Progress

Steps: 3
Names: Load, Display, Process

Shared definitions (schema, tiers, decay, output blocks, paths) → SKILL.md.

---

## Step 1: Load

Model: sonnet

```
/know review          → query all (scope = "project")
/know review <scope>  → query matching scope
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

Sort entries: tier descending (critical first), then age descending (oldest first).

```
[review] {N} entries found:

| # | tag | tier | scope | hits | age | summary |
|---|-----|------|-------|------|-----|---------|
| 1 | constraint | critical | LoppyMetrics | 5 | 30d | Thresholds defined only in PressureLevel |
| 2 | pitfall | memo | DataEngine | 0 | 45d | Singleton leaks state across test targets |

All ok? Or enter numbers to process (e.g. "2" or "1,3"):
```

| User Response | Action |
|--------------|--------|
| all ok / 没问题 / ok | → exit, no changes |
| Number(s) | → Step 3 with selected entries |

---

## Step 3: Process

Model: sonnet

For each selected entry, present:

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

```
[review] Deleted: {summary}
```

### B) Update

User describes what changed in conversation. Then:

1. Re-generate summary from user's description
2. If critical: re-generate detail file content
3. Show updated entry for confirmation [STOP:confirm]
4. On confirm:

```bash
# [RUN]
bash "$KNOW_CTL" update "{old_summary_keyword}" '{"summary":"{new_summary}"}'
```

5. If critical: overwrite detail file with new content

```
[review] Updated: {new_summary}
```

### C) Keep

```
[review] Kept: {summary}
```

Proceed to next selected entry. After all processed:

```
[review] Done: {deleted} deleted, {updated} updated, {kept} kept
```

---

## Completion

- All selected entries processed
- User saw `[review]` confirmation for each action
- Index and detail files consistent with actions taken

## Recovery

| Error | Recovery |
|-------|----------|
| `know-ctl delete` fails | Show error, skip entry, continue with next |
| `know-ctl update` fails | Show error, skip entry, continue with next |
| User cancels mid-process | Already-processed entries kept. Remaining skipped. |
