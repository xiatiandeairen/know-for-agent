# UI Update Rules

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
| §1 Layout | ASCII sketch | updatable |
| | Region table | updatable |
| §2 Interaction Flow | Step (existing) | updatable |
| | Step (new) | append-only |
| §3 States and Styles | Component (new) | append-only |
| | Existing component.State row (new) | append-only |
| | Existing component.State row (existing) | updatable |

## Field Change Rules

### §1 Layout

#### ASCII sketch

- **Change Type**: updatable
- **Allowed**: Adjusting region layout, adding new regions, merging regions
- **Forbidden**: Deleting an existing region without a reason (the reason must be stated)
- **Trigger**: Layout iteration; adding a new functional region
- **Check**: The updated sketch is consistent with the region table
- ❌ Quietly deleting a region with no record
- ✅ Adding a sidebar region; sync the region table

#### Region table

- **Change Type**: updatable
- **Allowed**: Adding new region rows; updating the content description and priority of existing regions
- **Forbidden**: Inconsistency with the ASCII sketch
- **Trigger**: Layout change
- **Check**: Region names correspond to the ASCII sketch

### §2 Interaction Flow

#### Step (existing)

- **Change Type**: updatable
- **Allowed**: Updating the description of trigger / response / next step
- **Forbidden**: Deleting an existing step (deprecated steps are annotated "deprecated: {reason}")
- **Trigger**: Interaction adjustment
- **Check**: The updated entry still satisfies the three-element format
- ❌ Deleting an existing step
- ✅ Updating the response description of a step, or annotating "deprecated: replaced click with drag"

#### Step (new)

- **Change Type**: append-only
- **Allowed**: Adding new interaction steps
- **Forbidden**: —
- **Trigger**: A new interaction path
- **Check**: New steps satisfy the three-element format

### §3 States and Styles

#### Component (new)

- **Change Type**: append-only
- **Allowed**: Adding new components and their state tables
- **Forbidden**: —
- **Trigger**: A new UI component
- **Check**: New component state tables ≥4 rows, covering hover/disabled/loading/error

#### Existing component.State row (new)

- **Change Type**: append-only
- **Allowed**: Adding new state rows to an existing component
- **Forbidden**: —
- **Trigger**: A new state to cover is identified
- **Check**: New rows satisfy the state/trigger/visual/timing format

#### Existing component.State row (existing)

- **Change Type**: updatable
- **Allowed**: Updating the trigger / visual / timing description of an existing state
- **Forbidden**: Deleting an existing state row
- **Trigger**: Visual / interaction adjustment
- **Check**: State row count only grows
- ❌ Deleting the error state row
- ✅ Updating the visual description of the error state

## Operating Procedure

### Create a UI Document

1. §1 Draw the ASCII sketch + fill in the region table
2. §2 List ≥3 interaction-flow steps; each step contains trigger / response / next step
3. §3 List a state table for each component, ≥4 states, covering hover/disabled/loading/error

### Layout Iteration

1. §1 Update the ASCII sketch
2. §1 Sync the region table
3. §2 Append or update affected interaction steps

### Add a Component

1. §3 Append a new component state table (≥4 states)
2. §2 Append related interaction steps (if needed)

### Interaction Adjustment

1. §2 Update existing steps or append new steps
2. §3 Update the state descriptions of affected components

## Validation Rules

1. **§1 Sketch and table consistent** — Every region name in the ASCII sketch has a corresponding row in the region table
2. **§2 Three elements complete per step** — Every step contains trigger / response / next step
3. **§3 State coverage complete** — Each component covers at least hover/disabled/loading/error
4. **§3 State rows only grow** — Existing components' state row count only grows
5. **§2 Steps cannot be deleted** — Deprecated steps are annotated with a reason rather than deleted
