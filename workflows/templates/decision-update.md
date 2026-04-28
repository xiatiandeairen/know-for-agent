# Decision Update Rules

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
| §1 Background | Triggering Event | immutable |
| | Constraints | immutable |
| | Decision Scope | immutable |
| §2 Decision | Outcome | immutable |
| | Core Rationale | immutable |
| §3 Alternatives | Alternative | immutable |
| | Pros / Cons | immutable |
| §4 Impact | Positive Impact | updatable |
| | Negative Impact | updatable |
| | Follow-up Actions | updatable |
| §5 Status | Status | updatable |
| | Decision Date | immutable |
| | Decision Maker | immutable |

## Field Change Rules

### §1 Background

#### Triggering Event / Constraints / Decision Scope

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying the background after the decision record is created (historical facts must not be tampered with)
- **Trigger**: —
- **Check**: The diff must not contain changes to §1

### §2 Decision

#### Outcome / Core Rationale

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying a decision once it has been made (to overturn it, change the status to deprecated/superseded and create a new decision record)
- **Trigger**: —
- **Check**: The diff must not contain changes to §2
- ❌ Modifying the outcome after finding a flaw in the decision
- ✅ Changing the status to superseded and creating a new decision record

### §3 Alternatives

#### Alternative / Pros / Cons

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying the alternative analysis after the fact (the analysis at the time is a historical record)
- **Trigger**: —
- **Check**: The diff must not contain changes to §3

### §4 Impact

#### Positive Impact / Negative Impact

- **Change Type**: updatable
- **Allowed**: Appending newly discovered impacts; updating the description of an existing impact (e.g. when actual impact differs from expected)
- **Forbidden**: Deleting recorded impacts
- **Trigger**: New positive / negative impacts surface after the decision is executed
- **Check**: Entry count only grows
- ❌ Deleting a negative impact to pretend there was no cost
- ✅ Appending "Actual write performance dropped 15% (measured), worse than expected"

#### Follow-up Actions

- **Change Type**: updatable
- **Allowed**: Appending new follow-up actions; updating the completion status of an existing action
- **Forbidden**: Deleting existing actions
- **Trigger**: A new follow-up need is identified; an action is completed
- **Check**: Entry count only grows

### §5 Status

#### Status

- **Change Type**: updatable
- **Allowed**: Forward-only transition: proposed → accepted; terminal transition: accepted → deprecated | accepted → superseded
- **Forbidden**: Reverting (accepted → proposed); resurrecting from a terminal state (deprecated → accepted)
- **Trigger**: The decision is adopted, deprecated, or superseded by a new decision
- **Check**: The status transition direction is legal
- ❌ accepted → proposed (revert)
- ✅ accepted → superseded (replaced by a new decision; link the new decision document)

#### Decision Date / Decision Maker

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying historical records
- **Trigger**: —
- **Check**: The diff must not contain changes

## Operating Procedure

### Create a Decision Record

1. Fill in all fields of §1–§5
2. §1 Constraints ≥1 item
3. §3 Alternatives ≥2, each with ≥2 pros and ≥2 cons
4. §4 Positive / Negative Impact each ≥1 item, Follow-up Actions ≥1 item
5. §5 Initial status is typically proposed

### Decision Adoption

1. §5 Status moves from proposed to accepted

### Decision Deprecation / Supersession

1. §5 Status updates to deprecated or superseded
2. §4 Follow-up Actions appends a link to the new decision document (if superseded)

### Impact Update

1. §4 Append newly discovered positive / negative impacts
2. §4 Update the completion status of follow-up actions

## Validation Rules

1. **§1–§3 immutable** — The diff must not contain changes to §1 Background, §2 Decision, or §3 Alternatives
2. **§4 only grows** — Impact and follow-up action entry counts only grow
3. **§5 status transitions legal** — proposed → accepted → deprecated/superseded, no reverting
4. **Decision date / maker immutable** — The diff must not contain changes
5. **Overturn via creation** — Do not modify the original record; create a new decision record and mark the original as superseded
