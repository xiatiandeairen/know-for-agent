# learn — knowledge capture

5 stages run serially: detect → gate → refine → locate → write. Each claim runs through once independently; one claim's failure does not block the rest.

At each stage entry, first emit two lines:

```
[learn] stage X/5 — {name}
Purpose: {purpose}
```

Stage overview:

- Stage 1 detect — extract all claim candidates from conversation, user selects a subset (Step 1)
- Stage 2 gate — 5 gates filter; any fail rejects the claim (Step 2-6)
- Stage 3 refine — refine the knowledge along multiple dimensions to raise entry quality (Step 7-9)
- Stage 4 locate — decide which CLAUDE.md to write to (Step 10)
- Stage 5 write — draft entry, dedupe, confirm, write (Step 11-15)

---

## Stage 1: detect

```
[learn] stage 1/5 — detect
Purpose: extract all claim candidates from the most recent ≤20 turns of conversation and let the user select a subset; if none found, ask the user to give one in a sentence.
```

### Step 1 — detect

Classify by source first, then scan:

**Class A (user corrected the AI's judgment)** — admit as candidate directly, no extra validation needed:

- The user pointed out the AI's output was wrong and gave the correct approach
- The user rejected the AI's plan and proposed a different direction
- The user added a constraint or premise the AI had missed

**Class B (AI captures on its own)** — list as candidate, but must pass a strengthened information-entropy check to remain:

- What technical choices were made in this conversation, with stated reasoning?
- What problems were encountered, and what lessons were drawn?
- What preferences or style requirements did the user express?

Tag Class A as `[correction]` and Class B as `[capture]`, listed together in the output.

Output template:

```
[learn] detected {N} claim candidate(s):
  1. {claim body}
  2. {claim body}
  ...
Reply with numbers (e.g. "1,3" to pick a subset / "all" for all / "none" to cancel / free text to add one)
```

Wait for the user's reply, then continue. After the user confirms the subset, Stages 2-5 run independently for each claim.

- No candidate → emit `[learn] no claim detected — please state in one sentence the knowledge to capture`, wait for user input
- Single candidate → enter Stage 2 directly, skip the selection menu

---

## Stage 2: gate

```
[learn] stage 2/5 — gate
Purpose: run the 5 gates independently for each claim; one fail rejects only that claim, not the others.
```

Each gate: pass → continue; not passed → offer a revision direction, wait for user confirmation, rerun once; still not passing → `[learn] reject: {reason}`.

Gates are ordered from broad to narrow — the earlier the gate, the wider the range it filters. Classify is not a filter gate; it runs before the gates.

### Step 2 — classify

What is the consequence of violating this claim?

- Irreversible (safety / data / monetary loss) → `must`
- Recoverable → `should`
- Triggers a pitfall → `avoid`
- Just a preference → `prefer`

Emit `[learn] selected {field} ({label})`.

### Step 3 — information entropy

**[correction] class**: pass directly, skip the information-entropy check — the correction itself proves the AI made a mistake.

**[capture] class**:

Q1: In a fresh session with only the project CLAUDE.md, in what concrete operation will the AI make what concrete error?

- Can describe a concrete error scenario → pass
- Cannot → not passed. Direction for revision: bind the claim to a scenario where the AI actually makes the mistake, then answer again. Still cannot → reject

### Step 4 — reuse

Q1: Beyond the current task, list one future scenario where this claim will be used.

- Can list one → pass (the listed item does not enter the entry)
- Cannot list → rewrite the claim into a form that transfers across tasks, then re-list. Still cannot → reject

Q2: Under what condition does this claim no longer hold? → fill into the `until` field (`must` is required; the rest are optional)

- Cannot think of one → infer change points in framework version / config flag / external service and answer again. Still cannot → reject

### Step 5 — triggerability

Q1: When editing which file, using which library, or encountering which code pattern should the AI recall this claim? → fill into the `when` field
Q2: Does this trigger description pin down a concrete file path / keyword / code pattern?

- Yes → pass
- No → not passed. Re-answer Q1 from paths, function names, and library names mentioned in the conversation

### Step 6 — actionability

Q1: Is this claim a declarative rule or does it need operational steps?

- Declarative (e.g. "answer in Chinese") → pass, omit `how`
- Needs operational steps → continue to Q2

Q2: How specifically? Where is the code / where is the doc? → fill into the `how` field

- Can write it out → pass
- Cannot → re-answer using operational steps or doc references from the conversation. Still cannot → reject

---

## Stage 3: refine

```
[learn] stage 3/5 — refine
Purpose: refine the claim along three dimensions — scenario generalization, knowledge deepening, granularity calibration — to raise entry coverage and reasoning quality.
```

Each step is a skippable refinement; if no adjustment is needed, continue directly. When a change is made, emit the adjustment for user confirmation.

### Step 7 — scenario generalization

Q1: For the trigger scenario described by `when`, what is the underlying essential operation?
Q2: What other file paths / libraries / code patterns are essentially the same scenario but not covered by the current `when`?

- Yes → propose a more general but still precise `when`, wait for user confirmation, then update
- No → skip

### Step 8 — knowledge deepening

Q1: Why does this rule hold? What is the mechanism that fires when it is violated (not just the consequence)?
Q2: Can this root cause be added to the claim's reasoning in one sentence so the AI can reason at edge cases instead of executing mechanically?

- Yes and the current reasoning is not sufficient → propose the supplemented claim wording, wait for user confirmation, then update
- Already sufficient → skip

### Step 9 — granularity calibration

Q1: How many independent "when X, do Y" logics does this claim contain?

- 1 → skip
- Multiple → split into multiple independent claims, list the split plan, wait for user confirmation; once confirmed, each one re-runs from Step 7

---

## Stage 4: locate

```
[learn] stage 4/5 — locate
Purpose: decide which CLAUDE.md to write the entry to (level: user / project / module → file path).
```

### Step 10 — locate

Judge by scope from large to small; stop on first hit:

1. **user** — is there real cross-project evidence (the AI actually made this mistake in another project, or there is concrete reason to believe it would)? yes → user. "Theoretically holds" is not enough.
2. **module** — can a concrete code directory be pointed to? yes → module
3. **else** → project

Path rules:

- user → `~/.claude/rules/know.md`
- project → `{git root}/.claude/rules/know.md`
- module → `{deepest code directory among file paths involved in the conversation}/CLAUDE.md` (infer from context, give 1-3 candidates)

The git root is inferred from the working directory in the conversation context.

Output:

```
[learn] candidate placement:
  level: {level}
  file:  {path}
  module candidate(s) (if applicable): {dir1} / {dir2} / {dir3}
Confirm / change level / change file / cancel
```

Wait for user confirmation, then enter Stage 5.

---

## Stage 5: write

```
[learn] stage 5/5 — write
Purpose: produce the YAML entry → dedupe → user confirmation → write file → suggest commit.
```

### Step 11 — format

Emit only the fields that passed the gates and were processed by refine; add no extra fields:

```yaml
- when: {triggerable artifact}
  {field}: {claim body}[ — {reasoning}]   # field ∈ must / should / avoid / prefer; reasoning optional (skip if Step 8 sufficient)
  how: {actionable artifact}              # technical-detail rules only
  until: {invalidation-check artifact}    # required for must, optional for the rest
```

Emit `[learn] entry candidate:` + YAML block.

### Step 12 — conflict

Read the `## know` YAML block of the target file (skip if absent). Overlapping `when` + overlapping content field → treated as duplicate.

If a duplicate is found:

```
[learn] near-duplicate entry already exists:
  {existing entry YAML}
This flow does not modify existing entries. Choose: skip / add anyway / cancel
```

Wait for the user's reply: `skip` (default) → terminate; `add anyway` → continue writing; `cancel` → cancel.

### Step 13 — confirm

```
[learn] about to write:
  file: {path}
  section: ## know (YAML block)
  entry:
    {YAML}
Confirm write? (yes / no / adjust some field)
```

Wait for the user's reply: `yes` → write; `no`/`cancel` → terminate; adjust wording (`when` / `how` / `until` / reasoning / claim body) → rerun Step 11 + Step 13; change classification (must↔should↔avoid↔prefer) → return to Stage 2 Step 2 and rerun.

### Step 14 — write

Execute the Edit based on the target file's state:

- File does not exist → create, with content `## know` + YAML block containing the entry
- File exists + no `## know` section → append `## know` + YAML block containing the entry to the end of the file
- `## know` section exists + no YAML block → append a new YAML block at the end of the section, leaving existing free-form content untouched
- `## know` section already has a YAML block → append the entry to the end of the list

### Step 15 — suggest-commit

```
[learn] suggested commit message:
  know: add {field} ({short when}) — {short claim}
```

Do not commit automatically.
