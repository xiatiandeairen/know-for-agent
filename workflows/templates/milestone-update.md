# Milestone Update Rules

## Change Types

| Type | Meaning |
|------|---------|
| **immutable** | Once written, never modified |
| **append-only** | Only new entries can be added; existing ones cannot be modified |
| **data refresh** | Existing values may be replaced with more accurate data |
| **updatable** | Content can be modified, but with constraints |
| **outcome fill-in** | Filled in from empty after the milestone completes; immutable once filled |

## Overview

| Location | Field | Change Type |
|----------|-------|-------------|
| §1 Goal | Definition of Done | immutable |
| | Value Target | immutable |
| | Hypothesis | immutable |
| | Hypothesis.Type | immutable |
| | Hypothesis.Validation Method | immutable |
| §2 Plan | Planned Deliverables | immutable |
| | Go/No-Go Criteria (5 dimensions) | immutable |
| | Estimated Effort | immutable |
| | Decision Path | immutable |
| | Risks | updatable |
| §3 Outcome | Actual Deliverables | outcome fill-in |
| | Hypothesis-Validation Conclusion | outcome fill-in |
| | Go/No-Go Assessment (5 dimensions) | outcome fill-in |
| | Actual Effort | outcome fill-in |
| | Decision Outcome | outcome fill-in |
| Linked Documents | PRD / Tech | updatable |

## Field Change Rules

### §1 Goal (all immutable)

#### Definition of Done

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the milestone has started
- **Trigger**: —
- **Check**: The diff must not contain changes to this field

#### Value Target

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the milestone has started
- **Trigger**: —
- **Check**: Same as above

#### Hypothesis / Type / Validation Method

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the milestone has started (do not amend the hypothesis because validation failed)
- **Trigger**: —
- **Check**: Same as above
- ❌ Rewriting the hypothesis to a validated version after validation fails
- ✅ Keep the original hypothesis and write "did not hold" in the §3 conclusion

### §2 Plan (all immutable except Risks)

#### Planned Deliverables

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the milestone has started (actual deliverables go in §3)
- **Trigger**: —
- **Check**: The diff must not contain changes to this field

#### Go/No-Go Criteria (5-dimension table)

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Lowering the bar after the fact. Scoring goes in the §3 Go/No-Go Assessment
- **Trigger**: —
- **Check**: The criteria column is copied verbatim into the §3 assessment table and must not be modified
- ❌ Lowering the bar from 80% to 60% after seeing the result fall short
- ✅ Keep the bar at 80%; fill the §3 score as 3 (partially met) and explain the actual value

#### Estimated Effort

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the fact (actual effort goes in §3)
- **Trigger**: —
- **Check**: —

#### Decision Path

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the fact (the actual decision goes in §3)
- **Trigger**: —
- **Check**: —

#### Risks

- **Change Type**: updatable
- **Allowed**: Appending new risks / dependencies; appending status annotations to identified items
- **Forbidden**: Deleting identified risks / dependencies
- **Trigger**: New risks are found during development
- **Check**: Status annotations are appended after the original text, never overwriting it
- ❌ Deleting "Risk: JSONL performance not validated"
- ✅ "Risk: JSONL performance not validated → validated, <1s with 54 entries"

### §3 Outcome (all outcome fill-in)

#### Actual Deliverables

- **Change Type**: outcome fill-in
- **Allowed**: Filling in from empty after the milestone completes
- **Forbidden**: Modifying once filled; filling in while the milestone is incomplete
- **Trigger**: Milestone completed / shelved
- **Check**: Comparable against §2 Planned Deliverables

#### Hypothesis-Validation Conclusion

- **Change Type**: outcome fill-in
- **Allowed**: Filling in from empty after the milestone completes
- **Forbidden**: Modifying once filled; fabricating conclusions without data
- **Trigger**: Milestone completed
- **Check**: Data fields must annotate their source
- ❌ "Holds" (no data)
- ✅ "Holds. 8 of 10 learn runs were accurate (measured on the know project)"

#### Go/No-Go Assessment (5-dimension table)

- **Change Type**: outcome fill-in
- **Allowed**: After the milestone completes, fill in the score / explanation / leftover columns from empty
- **Forbidden**: Modifying scores once filled; modifying the criteria column (copied from §2)
- **Trigger**: Milestone completed
- **Check**: The criteria column is consistent with §2; the explanation contains data or verifiable facts; leftovers indicate where they go

#### Actual Effort

- **Change Type**: outcome fill-in
- **Allowed**: Filling in from empty after the milestone completes
- **Forbidden**: Modifying once filled
- **Trigger**: Milestone completed
- **Check**: The format includes a comparison with the estimated value

#### Decision Outcome

- **Change Type**: outcome fill-in
- **Allowed**: Filling in from empty after the milestone completes
- **Forbidden**: Modifying once filled
- **Trigger**: Milestone completed
- **Check**: Comparable against §2 Decision Path

### Linked Documents

#### PRD / Tech

- **Change Type**: updatable
- **Allowed**: Adding new links; updating when paths change
- **Forbidden**: Deleting existing links (when a document is deleted, annotate it as "archived")
- **Trigger**: A linked document is created or moved
- **Check**: Link paths are reachable

## Operating Procedure

### Create a Milestone

1. Fill in §1 Goal (Definition of Done + Value Target + Key Hypothesis)
2. Fill in §2 Plan (Deliverables + Criteria + Effort + Decision Path + Risks)
3. Leave §3 Outcome empty
4. Fill in Linked Documents
5. Sync the roadmap §3 summary table

### Complete a Milestone

1. Fill in §3 Actual Deliverables (against §2 Planned)
2. Fill in §3 Hypothesis-Validation Conclusion (against §1 Hypothesis)
3. Fill in §3 Go/No-Go Assessment (copy the criteria column from §2; fill score / explanation / leftovers)
4. Fill in §3 Actual Effort (against §2 Estimated)
5. Fill in §3 Decision Outcome (against §2 Decision Path)
6. Sync the roadmap §3 summary table (status / outcome / date)

### Shelve a Milestone

1. §3 Decision Outcome reads "shelved → {reason} → {follow-up plan}"
2. Fill in the remaining §3 fields based on actual progress (record what was completed honestly)
3. Sync the roadmap §3 summary table (status → shelved)

## Validation Rules

1. **§1 §2 unchanged** — After the milestone has started, the diff must not contain changes to §1 / §2 fields (risk appending excepted)
2. **§3 not filled early** — While the milestone is incomplete, §3 must remain empty
3. **§3 immutable once filled** — Outcomes are never modified after being filled in
4. **Criteria column consistent** — The criteria column of the §3 Go/No-Go Assessment is verbatim identical to §2
5. **Data has source** — Every numeric value in §3 annotates its source
6. **Roadmap synced** — Milestone status changes must sync the roadmap §3 summary table
