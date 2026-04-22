# review — Knowledge Audit

## Progress

Steps: 4
Names: Load, Display, Process, KeywordAudit

Shared definitions (schema, decay, output markers) → SKILL.md.

---

## Step 1: Load

Model: sonnet

```
/know review                      → scope = "project", level = both
/know review <scope>              → scope = argument, level = both
/know review --level user         → scope = "project", level = user only
/know review <scope> --level user → scope = argument, level = user only
```

```bash
# [RUN] pass-through --level to know-ctl; omitted = both levels merged
bash "$KNOW_CTL" query "{scope}" {--level {level} if provided}
```

0 results → `[review] No entries found.` → exit.

Each result carries `_level` field. Display the level in the table (see Step 2).

Parse each result line, compute age in days from `created` field.

---

## Step 2: Display [STOP:choose]

Model: sonnet

Pre-display: show review summary from metrics:

```bash
# [RUN]
bash "$KNOW_CTL" metrics 2>/dev/null | grep -E "命中率|防御次数"
```

Sort by lifecycle stage (most actionable first), then age desc within each stage:

1. `[silent]` — no hit yet, candidate for pruning
2. `[new]` — recently added, not yet validated
3. `[active]` — has hit events

### Lifecycle stage (v7)

Compute per entry from **events.jsonl** (hits are derived, no stored field):

- Count hit events for this entry (match by summary in events where `level` matches `_level`)
- Age = today − `created`

| Stage | Condition | Label |
|-------|-----------|-------|
| new | age < 7d AND hit_count = 0 | `[new]` |
| active | hit_count > 0 | `[active]` |
| silent | hit_count = 0 AND age ≥ 7d | `[silent]` |

Note: v7 decay is no-op; no `[endangered]` stage (decay 重做后可能恢复)。

### Display should highlight

- Duplicate entries (similar summary/scope)
- Outdated entries (ref 指向已删除的 docs 段)
- Scope too wide or too narrow
- Unclear summary
- Wrong strict value (rule 应硬但标 soft，或反之)
- Mergeable entries

```
[review] {N} entries found:

| # | level | tag | strict | scope | ref | hits | age | summary | stage |
|---|-------|-----|--------|-------|-----|------|-----|---------|-------|
| 1 | project | rule | ⚠ hard | Auth.session | docs/decision/auth.md#refresh | 5 | 30d | session 过期必须刷新... | [active] |
| 2 | user | insight | — | methodology.general | — | 0 | 15d | 单一来源原则... | [silent] |

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
Tag: {tag} | Strict: {strict or "—"} | Ref: {ref or "—"} | Hits: {hits} | Age: {age}d
Action? A) Delete  B) Update  C) Merge  D) Keep
```

### A) Delete

Only delete clearly low-value, outdated, duplicate entries with no preservation reason. Do not aggressively clean the knowledge base.

```bash
# [RUN]
bash "$KNOW_CTL" delete "{summary_keyword}" --level {entry._level}
```

Output: `[review] Deleted: {summary}`

### B) Update

User describes change → re-generate summary → show updated entry [STOP:confirm] → on confirm:

```bash
# [RUN]
bash "$KNOW_CTL" update "{old_summary_keyword}" '{"summary":"{new_summary}"}' --level {entry._level}
```

Updatable fields: summary, scope, tag, strict (rule only), ref.

Output: `[review] Updated: {new_summary}`

### C) Merge

When two entries are complementary (same topic, different angle):

1. User selects target entry to merge into
2. Combine summaries — keep the clearer one, append missing context
3. If both have ref pointing to different docs, keep the one user selects; other's content can be referenced in a separate anchor
4. Delete the source entry

```bash
# [RUN]
bash "$KNOW_CTL" update "{target_keyword}" '{"summary":"{merged_summary}"}' --level {target._level}
bash "$KNOW_CTL" delete "{source_keyword}" --level {source._level}
```

Output: `[review] Merged into: {merged_summary}`

### D) Keep

Output: `[review] Kept: {summary}`

After all processed: `[review] Done: {deleted} deleted, {updated} updated, {merged} merged, {kept} kept`

---

## Step 4: Keyword Vocabulary Audit（同义词归并）

Model: sonnet

Run after Step 3 finishes. Purpose: 词表健康治理——发现同义词、拼写变体、过泛词并建议合并。

```bash
# [RUN] 拉当前词表
bash "$KNOW_CTL" keywords
```

输出每个 keyword 用使用次数。Claude 扫词表找**合并候选**：

| 模式 | 例子 | 建议行动 |
|---|---|---|
| 同义词 | `webhook`, `webhook-handler`, `web-hook` | 合并到最精简词（`webhook`）|
| 单复数 | `worker`, `workers` | 合并到单数 |
| 拼写变体 | `auth`, `authentication` | 保留更完整的 |
| 过泛词 | `code`, `bug`, `file` | 建议删除（无区分度）|
| 低频孤词 | 仅 1 条 trigger 用 | review 是否值得保留 |

每个合并建议呈现给用户：

```
[review] keyword audit:
  webhook (5), webhook-handler (1) → merge to 'webhook'?  [y/N]
  worker (8), workers (2) → merge to 'worker'?  [y/N]
  code (3) → remove as overly generic?  [y/N]
```

用户选 `y` 后批量执行：

```bash
# [RUN] 对每条含旧 keyword 的 trigger 替换
bash "$KNOW_CTL" update "<keyword-in-summary>" '{"keywords":[<新 keywords 数组>]}' --level <L>
```

Output: `[review] keyword audit: {N} merged, {M} removed`

**治理节奏**：建议每 20-30 条新 trigger 后跑一次，或 `/know report` 发现词表膨胀时跑。

---

## Completion

- All selected entries processed with `[review]` confirmation each
- triggers.jsonl consistent with actions taken (v7: no detail files)

## Recovery

| Error | Recovery |
|-------|----------|
| `know-ctl delete/update` fails | Show error, skip entry, continue next |
| User cancels mid-process | Already-processed entries kept, remaining skipped |
