# PRD Update Rules

## Change Types

| Type | Meaning |
|------|---------|
| **immutable** | Once written, never modified |
| **append-only** | Only new entries can be added; existing ones cannot be modified |
| **data refresh** | Existing values may be replaced with more accurate data |
| **updatable** | Content can be modified, but with constraints |

## Overview

| Location | Field | Change Type |
|----------|-------|-------------|
| §1 Problem | Pain Point | immutable |
| | Impact Scope | data refresh |
| | Why Now | immutable |
| §2 Target Users | Role (row) | append-only |
| | Role / Scenario (column value) | immutable |
| | Before / After | data refresh |
| §3 Core Hypothesis | Hypothesis | immutable |
| | Validation Method | immutable |
| §4 Plan | Before → After | append-only |
| | Task Tracking.Whole row | append-only |
| | Task Tracking.Status | updatable |
| | Task Tracking.Notes | updatable |
| §5 Acceptance Criteria | Acceptance entry | append-only |
| §6 Exclusions | Exclusion entry | append-only |

## Field Change Rules

### §1 Problem

#### Pain Point

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the requirement is confirmed
- **Trigger**: —
- **Check**: The diff must not contain changes to this field
- ❌ Rewriting because the pain point description feels weak
- ✅ Keep the original pain point; record newly discovered pain points by creating a new PRD

#### Impact Scope

- **Change Type**: data refresh
- **Allowed**: estimated → measured; more precise scope description
- **Forbidden**: Replacing measured with estimated
- **Trigger**: Real data is now available
- **Check**: New values annotate their source

#### Why Now

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the fact
- **Trigger**: —
- **Check**: —

### §2 Target Users

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
- **Trigger**: Real feedback after the requirement ships
- **Check**: Annotate the source

### §3 Core Hypothesis

#### Hypothesis / Validation Method

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the requirement is confirmed (do not amend the hypothesis because validation failed)
- **Trigger**: —
- **Check**: —
- ❌ Rewriting the hypothesis to a validated version after validation fails
- ✅ Keep the original hypothesis and write "did not hold" in the milestone §4 conclusion

### §4 Plan

#### Before → After

- **Change Type**: append-only
- **Allowed**: Adding new change points
- **Forbidden**: Deleting or modifying existing change points
- **Trigger**: Requirement scope expansion (user confirmation required)
- **Check**: New entries satisfy the format constraints

#### Task Tracking.Whole row

- **Change Type**: append-only
- **Allowed**: Adding new task rows
- **Forbidden**: Deleting existing rows
- **Trigger**: The requirement is broken down into a new tech task
- **Check**: New rows satisfy the format constraints

#### Task Tracking.Status

- **Change Type**: updatable
- **Allowed**: Forward-only transition: not started → in progress → done; or any → shelved
- **Forbidden**: Reverting (done → in progress)
- **Trigger**: Task progress changes
- **Check**: No reverting
- ❌ done → in progress
- ✅ in progress → done

#### Task Tracking.Notes

- **Change Type**: updatable
- **Allowed**: Updating to "done" or "leftover items: {content}"
- **Forbidden**: Deleting existing leftover-item descriptions
- **Trigger**: Task completion or leftovers found
- **Check**: —

### §5 Acceptance Criteria

#### Acceptance entry

- **Change Type**: append-only
- **Allowed**: Adding new acceptance entries
- **Forbidden**: Deleting or modifying existing entries (do not lower the bar because it was not met)
- **Trigger**: A new acceptance scenario is identified
- **Check**: New entries satisfy the format constraints
- ❌ Deleting an entry after acceptance fails
- ✅ Keep the original entry and score it honestly in the milestone Go/No-Go Assessment

### §6 Exclusions

#### Exclusion entry

- **Change Type**: append-only
- **Allowed**: Adding new exclusions
- **Forbidden**: Deleting existing exclusions
- **Trigger**: A new boundary is clarified
- **Check**: New entries include a reason

## Operating Procedure

### Create a PRD

1. Fill in all fields of §1–§6
2. §4 Task Tracking at least 1 row (status: not started)
3. §5 Acceptance Criteria at least 3 entries
4. §6 Exclusions at least 2 entries
5. Sync the roadmap milestone summary table (if linked)

### Task Progress Update

1. §4 Task tracking status moves forward
2. §4 Notes update completion info

### Requirement Scope Expansion

1. §4 Append new change points to Before → After
2. §4 Append a new row to Task Tracking
3. §5 Append a new entry to Acceptance Criteria (if needed)
4. Execute after user confirmation

## Validation Rules

1. **Immutable fields unchanged** — The diff must not contain changes to §1 Pain Point / Why Now or §3 Hypothesis / Validation Method
2. **Status moves forward only** — Task tracking status cannot revert
3. **Append-only fields only grow** — Acceptance Criteria / Exclusions / Before → After row counts only grow
4. **Data refresh annotates source** — When updating Impact Scope / Before / After, annotate the source
5. **Acceptance criteria cannot be lowered** — Existing entries cannot be deleted or loosened
