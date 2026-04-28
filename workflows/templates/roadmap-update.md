# Roadmap Update Rules

## Change Types

| Type | Meaning |
|------|---------|
| **immutable** | Once written, never modified — historical-record nature |
| **append-only** | Only new rows / entries can be added; existing ones cannot be modified |
| **data refresh** | Existing values may be replaced with more accurate data |
| **updatable** | Content can be modified, but with explicit constraints |

## Overview

| Location | Field | Change Type |
|----------|-------|-------------|
| §1.1 Product Essence | Positioning | immutable |
| | Motivation | immutable |
| | Long-term Vision | immutable |
| §1.2 Value System | Value column | immutable |
| | Metric column | data refresh |
| §1.3 Core Problems | Problem (row) | append-only |
| | Problem (column value) | immutable |
| | Occurrence Frequency | data refresh |
| | Per-occurrence Cost | data refresh |
| | Reach | data refresh |
| | Existing Workaround | updatable |
| §1.4 Target Users | Role (row) | append-only |
| | Before / After | data refresh |
| | Estimated Efficiency Gain | data refresh |
| §1.5 Competitive Comparison | Whole row | append-only |
| | Solution / Positioning / Target User | immutable |
| | Core Features / Strengths / Limitations | updatable |
| §2.1 Version Summary | Whole row | append-only |
| | Version / Core Direction | immutable |
| | Core-metric delta | data refresh |
| | Status | updatable |
| | Cycle | updatable |
| | Milestones | updatable |
| §2.2 Version Details | Whole subsection | append-only |
| | Strategic Intent | immutable |
| | Input/Output | data refresh |
| | Priority Rationale | immutable |
| | Risks and Dependencies | updatable |
| | Success Metric | immutable |
| | Core Value | immutable |
| | User Coverage | updatable |
| | Core Metric Table | data refresh + append-only |
| §3 Milestones | Whole row | append-only |
| | # / Core Direction | immutable |
| | Goal-attainment Status | updatable |
| | Status | updatable |
| | Completion Date | updatable |

## Field Change Rules

### §1.1 Product Essence

#### Positioning

- **Change Type**: immutable
- **Allowed**: Rewritable only on a product pivot
- **Forbidden**: Modifying in routine updates
- **Trigger**: User explicitly requests a pivot
- **Check**: The change must be confirmed by the user beforehand and the pivot reason must be recorded

#### Motivation

- **Change Type**: immutable
- **Allowed**: Rewritable only on a product pivot
- **Forbidden**: Modifying in routine updates
- **Trigger**: User explicitly requests a pivot
- **Check**: Same as Positioning

#### Long-term Vision

- **Change Type**: immutable
- **Allowed**: Rewritable only on a product pivot
- **Forbidden**: Modifying in routine updates
- **Trigger**: User explicitly requests a pivot
- **Check**: Same as Positioning

### §1.2 Value System

#### Value column (immediate / cumulative / strategic)

- **Change Type**: immutable
- **Allowed**: Rewritable only on a pivot
- **Forbidden**: Modifying in routine updates
- **Trigger**: User explicitly requests it
- **Check**: The change must be confirmed by the user beforehand

#### Metric column (immediate / cumulative / strategic)

- **Change Type**: data refresh
- **Allowed**: "target value, pending validation" → measured value; precision improvements (estimated → measured)
- **Forbidden**: Deleting old values; replacing more accurate data with less accurate data
- **Trigger**: Measured data is now available after a new release
- **Check**: New values must annotate their source; old values are kept as a comment for comparison
- ❌ Overwriting the old value directly with no trace
- ✅ "learn gate rejection rate (currently measured: 18%, target: ≥20%)" ← contains both measured and target

### §1.3 Core Problems

#### Problem (whole row)

- **Change Type**: append-only
- **Allowed**: Adding new rows
- **Forbidden**: Deleting existing rows; modifying the problem description of an existing row
- **Trigger**: A new core problem is identified
- **Check**: New rows satisfy all column constraints in the checklist

#### Occurrence Frequency / Per-occurrence Cost / Reach

- **Change Type**: data refresh
- **Allowed**: estimated value → measured value; "pending quantification" → concrete value
- **Forbidden**: Replacing a measured value with an estimated one
- **Trigger**: Real data is now available
- **Check**: New values annotate their data source
- ❌ Changing "measured: 8 times/day on average" to "estimated: 5–20 times/day"
- ✅ Changing "estimated: 5–20 times/day" to "measured: 8 times/day on average (based on 30-day usage records)"

#### Existing Workaround

- **Change Type**: updatable
- **Allowed**: Modifying when alternatives change
- **Forbidden**: Modifying without a reason
- **Trigger**: A new competitor appears or an old solution retires
- **Check**: Explain the reason for the change

### §1.4 Target Users

#### Role (whole row)

- **Change Type**: append-only
- **Allowed**: Adding new user-group rows
- **Forbidden**: Deleting existing rows; modifying the role / scenario of an existing row
- **Trigger**: Covering a new user group
- **Check**: New rows satisfy all column constraints in the checklist

#### Before / After

- **Change Type**: data refresh
- **Allowed**: estimated → measured
- **Forbidden**: Replacing measured with estimated
- **Trigger**: Real user feedback is now available / after a release
- **Check**: Annotate the source

#### Estimated Efficiency Gain

- **Change Type**: data refresh
- **Allowed**: "pending validation (expected: X)" → "measured: Y (expected: X)"
- **Forbidden**: Deleting the original expected value
- **Trigger**: Real data is now available
- **Check**: Keep the original expected value for comparison
- ❌ "Saves 15 minutes per session" (the expected annotation has been removed)
- ✅ "Measured: ~8 minutes saved per session (expected: 10–15 minutes)"

### §1.5 Competitive Comparison

#### Whole row

- **Change Type**: append-only
- **Allowed**: Adding new competitor rows
- **Forbidden**: Deleting existing rows
- **Trigger**: A new competitor appears
- **Check**: New rows satisfy all column constraints in the checklist

#### Solution / Positioning / Target User

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying these 3 columns of an existing row
- **Trigger**: —
- **Check**: When a competitor renames or pivots, add a replacement row and annotate the old row as "renamed to X"

#### Core Features / Strengths / Limitations

- **Change Type**: updatable
- **Allowed**: Updating when competitor features change
- **Forbidden**: Modifying without a reason
- **Trigger**: A competitor releases a new version
- **Check**: Annotate the reason for the update

### §2.1 Version Summary

#### Whole row

- **Change Type**: append-only
- **Allowed**: Appending new rows
- **Forbidden**: Deleting existing rows
- **Trigger**: A new version is planned
- **Check**: A §2.2 Version Details subsection is created at the same time

#### Version / Core Direction

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying these 2 columns of an existing version
- **Trigger**: —
- **Check**: —

#### Core-metric delta

- **Change Type**: data refresh
- **Allowed**: "TBD" / "pending measurement" → measured value
- **Forbidden**: Fabricating data; modifying an existing measured value
- **Trigger**: After version release
- **Check**: Must come from real data; annotate the source

#### Status

- **Change Type**: updatable
- **Allowed**: Forward-only transition: planning → developing → internal testing → released → archived
- **Forbidden**: Reverting (released → developing); skipping levels (planning → released)
- **Trigger**: Version lifecycle progression
- **Check**: The new status must be the next enum value after the old status, or archived
- ❌ released → developing
- ✅ developing → internal testing

#### Cycle

- **Change Type**: updatable
- **Allowed**: "TBD" → actual date; the end date may be pushed back
- **Forbidden**: Modifying a start date once written
- **Trigger**: Version starts / ends
- **Check**: The start date is immutable once written

#### Milestones

- **Change Type**: updatable
- **Allowed**: Range expansion (M1-M3 → M1-M4)
- **Forbidden**: Range contraction (M1-M4 → M1-M3)
- **Trigger**: A new milestone is added within the version
- **Check**: Existing milestone numbers cannot be deleted

### §2.2 Version Details

#### Whole subsection

- **Change Type**: append-only
- **Allowed**: Appending a new subsection for a new version
- **Forbidden**: Deleting an existing subsection
- **Trigger**: A new version is planned
- **Check**: All 8 fixed fields are filled in

#### Strategic Intent

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the fact
- **Trigger**: —
- **Check**: —

#### Input/Output

- **Change Type**: data refresh
- **Allowed**: "expected X" → "measured Y (expected X)"
- **Forbidden**: Deleting the original expected value
- **Trigger**: After the version completes
- **Check**: Keep the original expected value for comparison

#### Priority Rationale

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the fact
- **Trigger**: —
- **Check**: —

#### Risks and Dependencies

- **Change Type**: updatable
- **Allowed**: Appending new risks / dependencies; appending status annotations to identified items
- **Forbidden**: Deleting identified risks / dependencies
- **Trigger**: During development
- **Check**: Status annotations are appended with "→ resolved" / "→ occurred", never overwriting the original text
- ❌ Deleting "Risk: JSONL performance not validated"
- ✅ "Risk: JSONL performance not validated → validated, <1s with 54 entries"

#### Success Metric

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the fact (do not lower the bar because it was not met)
- **Trigger**: —
- **Check**: Actual attainment goes in the core-metric table; the success metric itself is not changed

#### Core Value

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the fact
- **Trigger**: —
- **Check**: —

#### User Coverage

- **Change Type**: updatable
- **Allowed**: Expanding coverage
- **Forbidden**: Reducing existing coverage
- **Trigger**: User base grows
- **Check**: —
- ❌ "author dogfood" → "no users yet"
- ✅ "author dogfood" → "author dogfood + 3 internal-testing users"

#### Core Metric Table

- **Change Type**: data refresh + append-only
- **Allowed**: Existing-row values refresh from "no data / target" to measured; appending new metric rows
- **Forbidden**: Deleting existing rows; modifying existing measured values
- **Trigger**: Backfilling measured data after the version completes
- **Check**: Every value annotates its source

### §3 Milestone Summary

#### Whole row

- **Change Type**: append-only
- **Allowed**: Appending new rows
- **Forbidden**: Deleting existing rows
- **Trigger**: A new milestone is planned
- **Check**: A `milestones/m{n}.md` file is created at the same time

#### # / Core Direction

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying the number or core direction
- **Trigger**: —
- **Check**: Numbers are globally incrementing and not reused

#### Goal-attainment Status

- **Change Type**: updatable
- **Allowed**: "—" → outcome description; the existing description may be appended with supplementary context (separated by "——")
- **Forbidden**: Deleting an existing attainment description; tampering with an existing conclusion
- **Trigger**: When the milestone is completed / accepted
- **Check**: Appended content uses "——" as a separator and never overwrites the original text
- ❌ Changing "end-to-end pipeline working" to "basically usable"
- ✅ "end-to-end pipeline working —— extraction accuracy lacks quantified data"

#### Status

- **Change Type**: updatable
- **Allowed**: Forward-only transition: not started → in progress → in acceptance → done; or any → shelved
- **Forbidden**: Reverting from done
- **Trigger**: Milestone progression
- **Check**: "shelved" must include a reason
- ❌ done → in progress
- ✅ in progress → shelved (reason: priority adjustment, restart in v4)

#### Completion Date

- **Change Type**: updatable
- **Allowed**: "—" → YYYY-MM-DD
- **Forbidden**: Modifying a date once filled in
- **Trigger**: When the milestone completes
- **Check**: Immutable once filled in

## Operating Procedure

### Add a Version

1. §2.1 Append a new row to the summary table (status: planning, cycle: TBD, core-metric delta: TBD)
2. §2.2 Append a new subsection to Version Details (fill in all 8 fixed fields)
3. §3 Append milestone rows for this version to the milestone summary (status: not started, goal-attainment status: —, completion date: —)
4. Create `milestones/m{n}.md` for each new milestone (use the milestone template)
5. No changes to existing versions / milestones

### Version Status Progression

1. §2.1 The row's status moves forward
2. §2.1 The row's cycle gains start / end dates

### Version Completion Backfill

1. §2.1 The row: status → released, cycle gains the end date, core-metric delta is backfilled with measured data
2. §2.2 The subsection: Input/Output is backfilled with measured values (keeping expected); the core-metric table is backfilled with measured data
3. §3 The version's milestone rows: status → done, goal-attainment status backfilled with the outcome, completion date filled in
4. Update the corresponding milestone files

### Data Refresh

1. Locate the field to change
2. Confirm the new data is more accurate than the old (measured > estimated > target > no data)
3. Replace the value and annotate the source
4. Keep the old value for comparison (where applicable)

## Validation Rules

After the update, check:

1. **Immutable fields unchanged** — The diff must not contain changes to immutable fields
2. **Status moves forward only** — No reverting
3. **Append-only fields only grow** — Row counts can only grow or stay the same
4. **Data refresh annotates source** — Every new numeric value has a source annotation
5. **Synchronization complete** — When adding a version, §2 and §3 are updated together and the milestone files have been created
