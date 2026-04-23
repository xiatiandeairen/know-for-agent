# learn — Knowledge Persistence

## 1. Overview

Turn conversational insights into persisted `trigger` entries in `triggers.jsonl`. Pipeline: collect candidates → formalize fields → resolve conflicts → confirm with user → write. Designed to prefer fewer, higher-quality entries over broad capture.

## 2. Core Principles

1. **Collect once.** A single scan produces final candidates; no multi-pass filtering.
2. **Quality over quantity.** Drop anything a reader could infer from the code itself; save only non-obvious tacit knowledge.
3. **Confirm before writing.** The user sees every entry verbatim and controls final persistence.
4. **Conflicts never silent.** Duplicates, contradictions, and mergeable overlaps must surface for user decision.
5. **Level is explicit.** Every trigger is either `project` (this repo) or `user` (cross-project); no ambiguous default.
6. **Bounded clarification.** Invalid reply → one fallback prompt → abort if still invalid.

## 3. Definitions

| Term | Meaning |
|---|---|
| `trigger` | one JSONL row with 8 fields: `tag, scope, summary, strict, ref, keywords, source, created/updated` |
| `tag` | `rule` (must/must-not), `insight` (decision/mental model), `trap` (bug/pitfall); priority when ambiguous: `trap > rule > insight` |
| `scope` | dot-separated keypath (`Auth.session`, `methodology.recall-design`); stable reusable anchor |
| `strict` | `true/false` for `rule`; must be `null` for `insight/trap` |
| `level` | `project` or `user`; determines file location |
| `candidate` | a trigger in-progress, pre-persistence |

## 4. Rules

### 4.1 Input handling

- All string matching is case-insensitive.
- `STOP:choose` blocks the pipeline; the user must pick from the displayed options.
- One invalid reply triggers a full-list fallback prompt; a second invalid reply terminates with `abort`.

### 4.2 Entry integrity

- Every candidate produces a valid 8-field entry; partial writes are forbidden.
- `rule` requires `strict ∈ {true, false}`; `insight/trap` require `strict = null`.
- `summary` is `≤ 80 chars`, formatted `{conclusion} — {reason}`.
- Scope follows: explicit file path → module/subsystem name → recurring functional domain → broad boundary → `"project"` (last resort).
- Level defaults: scope starting with `methodology.*` → `user`; project-local identifiers → `project`; ambiguous → ask.

### 4.3 Candidate quality

A candidate is dropped when any of:
- no clear conclusion or rule,
- describes transient state or one-off facts,
- is directly readable from surface code without extra why/constraint/context,
- has no foreseeable recurrence or reuse.

### 4.4 Conflict handling

| Relation | Action |
|---|---|
| unrelated | pass through |
| merge (complementary) | propose merge, `STOP:choose` |
| duplicate (same conclusion) | propose skip or merge, `STOP:choose` |
| conflict (opposing) | mandatory surface, `STOP:choose` resolves |

Semantic similarity alone never decides; also weigh scope, direction, tag, applicable range, chronology.

### 4.5 User touchpoints

- One choice block after `Collect` (select which candidates to process).
- One choice block on any conflict.
- One confirmation block before `Write`.
- No other prompts unless a step explicitly demands a fallback.

## 5. Workflow

Models: `opus` for scanning and judgment (1, 2); `sonnet` for mechanical work (3, 5).

### 5.1 Step 1 — Collect

**Input**: `conversation`, optional `"<claim>"`, `/know learn` entry point.
**Output**: `candidates[]` (≤ 5), each carrying `summary_draft` and `likely_tag`; empty when nothing qualifies.

```
1. If the entry point is /know learn "<claim>":
     → single candidate, skip scanning.
2. Otherwise scan the conversation for content that passes all four quality checks (§4.3).
3. Apply splitting: one conclusion + its direct reason = one candidate; two independent facts = two.
4. If the pool exceeds 5, rank by:
     user-corrected > converged conclusion > likely to recur > project-relevant.
   Take the top 5.
5. Present:
     [learn] step: collect
     会话价值摘要：{theme}
     关键产出：
       - {output 1}
       - {output 2}
     检测到 {N} 条可持久化知识：
       1. [{likely_tag}] {summary_draft}
       2. ...
     持久化？[all / 编号 / skip]
6. STOP:choose on selection.
```

### 5.2 Step 2 — Generate

**Input**: selected candidates.
**Output**: formal entries with `{tag, scope, strict, summary, ref, keywords, level}` per candidate.

```
For each selected candidate:
  2a tag         trap > rule > insight; ≥ 2 equally valid → ask user.
  2b scope       follow §4.2; avoid overly deep or generic paths.
  2c strict      rule only; null for insight/trap.
  2d summary     "{conclusion} — {reason}", ≤ 80 chars; rewrite until it fits.
  2e ref         optional docs path / code anchor / URL; rule+strict=true prefers a ref.
  2f keywords    5–8 kebab-case; prefer existing vocabulary (know-ctl keywords).
  2g level       methodology.* → user; project-local → project; ambiguous → STOP:choose.
```

**Keyword rules.** Lowercase, `[a-z0-9-]`, length 2–40. Reuse terms from the current vocabulary unless a genuinely new concept appears.

### 5.3 Step 3 — Conflict

**Input**: generated entries.
**Output**: entries with conflict resolution applied.

```
1. For each entry, run know-ctl search against scope keywords:
     bash "$KNOW_CTL" search "<kw1>|<kw2>"
2. Classify each candidate match: unrelated | merge | duplicate | conflict.
3. On anything not "unrelated":
     [conflict] Similar entry found:
       Existing: {summary}
       New:      {summary}
       Relation: {merge | duplicate | conflict}
       Choose:   A) Update existing  B) Keep both  C) Merge  D) Skip new
   STOP:choose decides.
```

### 5.4 Step 4 — Confirm

**Input**: resolved entries.
**Output**: final list for writing; up to 3 rounds of edits per entry.

```
For each entry:
  Display tag / scope / strict / summary / ref / keywords / level.
  Ask: confirm / edit <field>=<value> / skip / merge-with <existing>.
  After the 3rd edit round, force A) confirm current, B) cancel.
User-level entries require a second confirmation naming every affected scope.
```

### 5.5 Step 5 — Write

**Input**: confirmed entries.
**Output**: appended triggers.jsonl rows and `created` events.

```bash
TODAY=$(date +%Y-%m-%d)
bash "$KNOW_CTL" append --level {level} '{
  "tag":"{tag}","scope":"{scope}","summary":"{summary}",
  "strict":{strict_or_null},"ref":{ref_or_null},
  "keywords":{keywords_array_or_null},
  "source":"learn","created":"'"$TODAY"'","updated":"'"$TODAY"'"
}'
```

```
[persisted] {scope} :: {summary} ({level})
```

Decay runs once at pipeline entry (`know-ctl decay`; currently no-op in v7).

## 6. Examples

### Single correction captured as a rule

```
user: "你忘了 webhook 必须先验签再解 body"
→ Collect: 1 candidate, likely_tag=rule.
→ Generate: tag=rule, scope=Payment.webhook, strict=true,
   summary="webhook 必须先验签再解 body — 防注入",
   keywords=["webhook","signature-verification","security"], level=project.
→ Conflict: no match.
→ Confirm → Write.
```

### Methodology insight promoted to user level

```
conversation: discussion of benchmark double-strategy design
→ Collect: 1 candidate.
→ Generate: tag=insight, scope=methodology.benchmark,
   summary="benchmark = A 现状算法 + B 上界模拟 — 对照出天花板",
   level=user.
→ Conflict: no match.
→ Confirm → second confirmation for user level → Write.
```

### Conflict resolved by merge

```
Existing: "session 过期必须刷新 — 避免静默登出"
New:      "session 超时不要拒绝，必须刷新 — 提升留存"
→ Conflict classifies as duplicate.
→ User picks C) Merge; Step 3 consolidates into single entry; Step 5 updates.
```

## 7. Edge Cases

| Situation | Behavior |
|---|---|
| Conversation contains no qualifying material | `[learn] No high-value knowledge detected.` |
| `/know learn "<claim>"` with malformed claim | single candidate with `likely_tag=insight`; continue as normal. |
| More than 5 candidates | truncate by ranking rule (§5.1 step 4). |
| All selected candidates dropped by quality pre-check | surface `[skipped]` per candidate, exit without Write. |
| User edits push an entry past 3 rounds | force confirm-current or cancel. |
| `know-ctl append` fails | surface the error; do not retry silently. |
| User-level write missed secondary confirmation | abort that entry only; other entries proceed. |
