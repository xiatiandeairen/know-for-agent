# Tech Update Rules

## Change Types

| Type | Meaning |
|------|---------|
| **immutable** | Once written, never modified |
| **append-only** | Only new entries can be added; existing ones cannot be modified |
| **updatable** | Content can be modified, but with constraints |

## Overview

| Location | Field | Change Type |
|----------|-------|-------------|
| §1 Background | Technical Constraints | immutable |
| | Prerequisites | immutable |
| §2 Solution | File / Module Structure | updatable |
| | Core Flow | updatable |
| | Data Structure | updatable |
| §3 Key Decisions | Decision row | append-only |
| §4 Iteration Log | Iteration entry | append-only |

## Field Change Rules

### §1 Background

#### Technical Constraints

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the solution is confirmed (a constraint change means the solution's basis has changed; create a new tech document)
- **Trigger**: —
- **Check**: The diff must not contain changes to this field
- ❌ Rewriting because the constraint description feels imprecise
- ✅ Keep the original constraint; handle new constraints by creating a new tech document

#### Prerequisites

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying the dependency list after the solution is confirmed
- **Trigger**: —
- **Check**: The diff must not contain changes to this field
- ❌ Deleting a row after the dependency is satisfied
- ✅ Keep the original dependency list (with status); record dependency completion in the iteration log

### §2 Solution

#### File / Module Structure

- **Change Type**: updatable
- **Allowed**: Adding / adjusting modules during sprint iteration; updating responsibility descriptions
- **Forbidden**: Silent modification without an iteration log entry
- **Trigger**: Solution evolution during sprint implementation
- **Check**: §4 Iteration Log must contain a corresponding entry describing the change
- ❌ Silently deleting a module without mentioning it in the iteration log
- ✅ Adjusting the module split and writing in §4: "refactored module X (merged original A+B into C)"

#### Core Flow

- **Change Type**: updatable
- **Allowed**: Adjusting step order / content during sprint iteration
- **Forbidden**: Silent modification without an iteration log entry
- **Trigger**: Flow optimization during sprint implementation
- **Check**: §4 Iteration Log must contain a corresponding entry describing the change
- ❌ Quietly changing the flow steps
- ✅ Optimizing the flow and writing in §4: "learn flow changed from 4 stages to 5 stages (added refine step)"

#### Data Structure

- **Change Type**: updatable
- **Allowed**: Adding / adjusting fields during sprint iteration
- **Forbidden**: Silent modification without an iteration log entry; deleting a field that has shipped (must go through deprecation)
- **Trigger**: Structural evolution during sprint implementation
- **Check**: §4 Iteration Log must contain a corresponding entry describing the change

### §3 Key Decisions

#### Decision row

- **Change Type**: append-only
- **Allowed**: Adding new decision rows
- **Forbidden**: Modifying or deleting existing rows (the decision record is history; it must not be tampered with)
- **Trigger**: A new technical selection is made during a sprint
- **Check**: New rows satisfy the checklist format constraints (the "why" column includes the rejected alternative)
- ❌ Modifying because the previous decision rationale was poorly written
- ✅ Keep the original decision row; if overturned, append a new row recording the new decision and explaining the reason for the overturn

### §4 Iteration Log

#### Iteration entry

- **Change Type**: append-only
- **Allowed**: Adding new entries (prepend, new entries on top)
- **Forbidden**: Modifying or deleting existing entries
- **Trigger**: Each sprint completion
- **Check**: New entries have a date heading + list format
- ❌ Modifying the previous iteration's log content
- ✅ Adding a new iteration log entry on top

## Operating Procedure

### Create tech

1. Fill in §1 Background: Technical Constraints ≥1, Prerequisites listed or "none"
2. Fill in §2 Solution: File / Module Structure + Core Flow (≥3 steps) + Data Structure (if any)
3. Fill in §3 Key Decisions: ≥1 row, the "why" column includes the rejected alternative
4. Fill in §4 Iteration Log: first entry, recording the initial solution design
5. Sync the linked PRD's task-tracking table (if any)

### Sprint Iteration Update

1. §4 Iteration Log: prepend a new entry (date + list)
2. §2 Solution updated as needed (file structure / flow / data structure); each change has a corresponding §4 explanation
3. §3 Key Decisions: append new rows (if there is a new selection)
4. §1 Background untouched

### Solution Change

1. Determine the scope of the change:
   - Constraints / prerequisites changed → create a new tech document (archive the original)
   - Constraints unchanged, solution evolved → follow the sprint iteration update procedure
2. §3 Key Decisions: append a new row explaining the reason for the overturn
3. §2 Solution updated; §4 Iteration Log records the reason and content of the change

## Validation Rules

1. **Immutable fields unchanged** — The diff must not contain changes to §1 Technical Constraints / Prerequisites
2. **Append-only fields only grow** — §3 decision row count only grows; §4 iteration entries only grow
3. **Solution changes are traceable** — Any modification in §2 must have a corresponding entry in the §4 Iteration Log
4. **Decision row format complete** — Every row's "why" column must include the rejected alternative
5. **Iteration log time-ordered** — §4 entries are sorted by date in descending order (newest on top)
