# Capability Inventory Update Rules

## Change Types

| Type | Meaning |
|------|---------|
| **append-only** | Only new entries can be added; existing ones cannot be modified |
| **updatable** | Content can be modified, but with constraints |

## Overview

| Location | Field | Change Type |
|----------|-------|-------------|
| §1 Capability Inventory | Whole row | append-only |
| | Status | updatable |
| §2 Coverage | Known Limitations | append-only + updatable |
| | Uncovered Scenarios | append-only + updatable |

## Field Change Rules

### §1 Capability Inventory

#### Whole row

- **Change Type**: append-only
- **Allowed**: Adding new capability rows
- **Forbidden**: Deleting existing rows; modifying the capability name / description / version of an existing row
- **Trigger**: A new user-perceivable capability ships
- **Check**: New rows satisfy all column constraints in the checklist (capability = user perspective, description = one sentence, status = enum, version = v{n})
- ❌ Deleting an obsolete capability row
- ✅ Adding a new row to record a newly launched capability

#### Status

- **Change Type**: updatable
- **Allowed**: Forward-only transition: planned → experimental → available
- **Forbidden**: Reverting (available → experimental, experimental → planned)
- **Trigger**: Capability maturity changes
- **Check**: Status moves forward only
- ❌ available → experimental (capability regression)
- ✅ experimental → available (the capability stabilizes and ships)

### §2 Coverage

#### Known Limitations

- **Change Type**: append-only + updatable
- **Allowed**: Adding new limitation entries; marking resolved limitations as "resolved in v{n}"
- **Forbidden**: Deleting existing entries; modifying the description of existing limitation entries
- **Trigger**: A new limitation is found, or an existing limitation has been resolved
- **Check**: New entries match the format "{limitation} ({impact})"; resolved entries keep their original text and append the marker
- ❌ Directly deleting a resolved limitation
- ✅ "Single import capped at 1000 rows (larger imports require batching) — resolved in v2"

#### Uncovered Scenarios

- **Change Type**: append-only + updatable
- **Allowed**: Adding new scenario entries; marking covered scenarios as "resolved in v{n}"
- **Forbidden**: Deleting existing entries; modifying the description of existing scenario entries
- **Trigger**: A new uncovered scenario is identified, or an existing scenario is covered by a new version
- **Check**: New entries match the format "{scenario} ({reason})"; resolved entries keep their original text and append the marker
- ❌ Directly deleting a now-covered scenario
- ✅ "Cross-organization data sharing (current architecture is single-tenant) — resolved in v3"

## Operating Procedure

### Add a Capability

1. Append a new row to §1 Capability Inventory
2. Confirm the status is one of planned | experimental | available
3. If the new capability resolves an existing limitation / uncovered scenario in §2, mark it as "resolved in v{n}"

### Capability Status Change

1. Move the corresponding row in §1 Capability Inventory forward
2. If the status changes to "available" and resolves an existing limitation in §2, sync the marker

### Add a Limitation / Uncovered Scenario

1. Append a new entry to the corresponding subsection of §2
2. Satisfy the format constraint

## Validation Rules

1. **Capability rows only grow** — §1 row count only grows
2. **Status moves forward only** — planned → experimental → available, no reverting
3. **Existing descriptions are immutable** — Once written, the capability name / description / version / limitation description / scenario description cannot be changed
4. **Resolved-marker format** — "resolved in v{n}", original text retained
