# Marketing Update Rules

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
| §1 Target Audience | User Persona | immutable |
| | Active Platforms | immutable |
| | Decision Factors | immutable |
| §2 Core Message | One-line Pitch | immutable |
| | Differentiation | immutable |
| §3 Promotion Channels | Channel row (existing) | updatable |
| | Channel row (new) | append-only |
| §4 Communication Cadence | Cadence entry | append-only |
| §5 Impact Measurement | Metric.Target | data refresh |
| | Metric.Review Checkpoint | data refresh |
| | Metric row (new) | append-only |

## Field Change Rules

### §1 Target Audience

#### User Persona

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the positioning is confirmed (a positioning change requires a new document)
- **Trigger**: —
- **Check**: The diff must not contain changes to this field

#### Active Platforms

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying the confirmed list of platforms
- **Trigger**: —
- **Check**: The diff must not contain changes to this field

#### Decision Factors

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying the confirmed decision factors
- **Trigger**: —
- **Check**: The diff must not contain changes to this field

### §2 Core Message

#### One-line Pitch

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Rewording after the positioning is confirmed
- **Trigger**: —
- **Check**: The diff must not contain changes to this field
- ❌ Rewriting the pitch because the wording feels weak
- ✅ Keep the original pitch; create a new marketing plan when the positioning shifts substantially

#### Differentiation

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying the confirmed differentiation description
- **Trigger**: —
- **Check**: The diff must not contain changes to this field

### §3 Promotion Channels

#### Channel row (existing)

- **Change Type**: updatable
- **Allowed**: Updating strategy descriptions; adjusting priority
- **Forbidden**: Deleting existing channel rows
- **Trigger**: Strategy refinement; priority adjustment
- **Check**: Row count only grows; priority remains within the P0/P1/P2 enum
- ❌ Deleting an underperforming channel row
- ✅ Lowering the priority of an underperforming channel from P0 to P2

#### Channel row (new)

- **Change Type**: append-only
- **Allowed**: Adding new channel rows
- **Forbidden**: —
- **Trigger**: A new channel opportunity is found
- **Check**: New rows satisfy the format constraints

### §4 Communication Cadence

#### Cadence entry

- **Change Type**: append-only
- **Allowed**: Adding new communication actions
- **Forbidden**: Deleting or modifying existing entries
- **Trigger**: New communication plans
- **Check**: New entries match the "{YYYY.MM.DD} — {action}" format
- ❌ Deleting an unexecuted communication action
- ✅ Appending a follow-up communication action

### §5 Impact Measurement

#### Metric.Target / Metric.Review Checkpoint

- **Change Type**: data refresh
- **Allowed**: estimated → measured; updating target values after a retrospective
- **Forbidden**: Replacing measured with estimated; lowering a confirmed target
- **Trigger**: Real data is now available, or a retrospective has completed
- **Check**: New values annotate their source

#### Metric row (new)

- **Change Type**: append-only
- **Allowed**: Adding new metric rows
- **Forbidden**: Deleting existing metric rows
- **Trigger**: A new measurement dimension is identified
- **Check**: New rows satisfy the format constraints

## Operating Procedure

### Create a Marketing Plan

1. Fill in all fields of §1–§5
2. §1 Active Platforms ≥2 items, Decision Factors ≥2 items
3. §2 Differentiation ≥2 items
4. §3 Promotion Channels ≥2 rows
5. §4 Communication Cadence ≥3 items
6. §5 Impact Measurement ≥2 rows

### Strategy Adjustment

1. §3 Channel rows can update strategy and priority
2. §4 Append new communication actions
3. §5 Refresh metric target values

### Retrospective Update

1. §5 Refresh actual-impact data
2. §4 Append follow-up communication plans

## Validation Rules

1. **§1–§2 immutable** — The diff must not contain changes to §1 Target Audience or §2 Core Message
2. **§3 only grows** — Channel row count only grows
3. **§4 only grows** — Communication cadence entries only grow
4. **§5 data refresh annotates source** — When updating target / review checkpoint, annotate the source
5. **Priority enum** — §3 priority can only be P0/P1/P2
