# Architecture Document Update Rules

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
| §1 Positioning and Boundaries | Responsibility | immutable |
| | Out of Scope | append-only |
| §2 Structure and Interaction | Component Diagram | updatable |
| | Component Table | append-only + updatable |
| | Data Flow Diagram | updatable |
| | Data Flow Table | append-only + updatable |
| §3 Design Decisions | Driving Factors | immutable |
| | Key Choices | append-only |
| | Constraints | append-only |
| §4 Quality Requirements | Quality Table | data refresh + append-only |

## Field Change Rules

### §1 Positioning and Boundaries

#### Responsibility

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the module's responsibility is confirmed (a change of responsibility = a new module; create a new arch document)
- **Trigger**: —
- **Check**: The diff must not contain changes to this field

#### Out of Scope

- **Change Type**: append-only
- **Allowed**: Adding new exclusions
- **Forbidden**: Deleting existing items
- **Trigger**: A new boundary ambiguity is identified
- **Check**: New items include a "→ owned by whom" pointer

### §2 Structure and Interaction

#### Component Diagram

- **Change Type**: updatable
- **Allowed**: Adding new components; adjusting inter-component relationships; updating responsibility annotations
- **Forbidden**: Deleting existing components (deprecated components stay in the diagram with a "deprecated" annotation)
- **Trigger**: Module refactor / new sub-component
- **Check**: The diagram stays consistent with the component table

#### Component Table

- **Change Type**: append-only + updatable
- **Allowed**: Adding new rows; refining the responsibility / boundary rule of existing rows
- **Forbidden**: Deleting existing rows (deprecated components are annotated "deprecated"); loosening boundary rules
- **Trigger**: New component / responsibility refinement
- **Check**: Consistent with the component diagram
- ❌ Deleting a component row
- ✅ Annotating the component row as "deprecated" + adding a replacement component row

#### Data Flow Diagram / Data Flow Table

- **Change Type**: append-only + updatable
- **Allowed**: Adding new flows; updating the format / description of existing flows
- **Forbidden**: Deleting existing flows (deprecated flows are annotated "deprecated")
- **Trigger**: New data interaction
- **Check**: Diagram and table stay consistent

### §3 Design Decisions

#### Driving Factors

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying existing factors (a new driving factor = architectural evolution; append it to the key-choices table)
- **Trigger**: —
- **Check**: The diff must not contain changes to existing rows

#### Key Choices

- **Change Type**: append-only
- **Allowed**: Adding new choice rows
- **Forbidden**: Modifying existing rows; deleting historical decisions
- **Trigger**: A new selection produced by architectural evolution
- **Check**: New rows include the rejected alternative

#### Constraints

- **Change Type**: append-only
- **Allowed**: Adding new constraints; appending a "→ lifted (reason)" annotation to an existing constraint
- **Forbidden**: Deleting existing constraints
- **Trigger**: A new hard constraint is identified
- **Check**: New constraints include a reason

### §4 Quality Requirements

#### Quality Table

- **Change Type**: data refresh + append-only
- **Allowed**: Target values move from "target value, pending validation" → measured values; new metric rows
- **Forbidden**: Deleting existing rows; lowering existing targets
- **Trigger**: Measured data is now available / a new quality requirement is introduced
- **Check**: Measured values annotate their source

## Operating Procedure

### Create an Architecture Document

1. Fill in §1 Positioning and Boundaries (Responsibility + Out of Scope)
2. Fill in §2 Structure and Interaction (Component Diagram + Component Table + Data Flow)
3. Fill in §3 Design Decisions (Driving Factors + Key Choices + Constraints)
4. Fill in §4 Quality Requirements

### Architectural Evolution

1. Update §2 Component Diagram / Table (add new components or annotate as deprecated)
2. Update §2 Data Flow (add new flows)
3. Append a new row to §3 Key Choices (record the evolution decision)
4. Refresh target values in the §4 Quality Table (if measured data exists)

### Component Deprecation

1. Annotate the component as "deprecated" in the §2 Component Diagram (do not delete it)
2. Append "deprecated" to the corresponding row of the §2 Component Table
3. Append a deprecation decision row to §3 Key Choices

## Validation Rules

1. **§1 Responsibility unchanged** — The diff must not contain changes to Responsibility
2. **§3 Driving Factors unchanged** — The diff must not contain changes to existing rows
3. **Diagram/table consistency** — The Component Diagram / Data Flow Diagram match their corresponding tables
4. **Append-only fields only grow** — Component / data-flow / choice / constraint row counts only grow
5. **Annotate as deprecated, do not delete** — Do not delete components / flows directly; annotate them as "deprecated"
