# Ops Update Rules

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
| §1 Release Strategy | Release Channels | updatable |
| | Release Cadence | updatable |
| | Versioning Rule | updatable |
| §2 Feedback Loop | Whole row | append-only |
| | Channel / Category | immutable |
| | Response SLA | updatable |
| §3 Key Metrics | Whole row | append-only |
| | Metric (column value) | immutable |
| | Target | data refresh |
| | Alert Threshold | data refresh |
| §4 Incident Playbook | Whole row | append-only |
| | Scenario (column value) | immutable |
| | Response Procedure | updatable |
| | Escalation Path | updatable |

## Field Change Rules

### §1 Release Strategy

#### Release Channels

- **Change Type**: updatable
- **Allowed**: Adding new channel items; modifying existing channel descriptions; removing retired channels (annotate the retirement reason)
- **Forbidden**: Deleting a channel without a reason
- **Trigger**: A new distribution channel is added or an old channel is retired
- **Check**: Retired channels are annotated "retired ({reason})" rather than deleted directly
- ❌ Deleting a channel outright with no record
- ✅ "npm registry: stable distribution" → adding "GitHub Releases: binary distribution"

#### Release Cadence

- **Change Type**: updatable
- **Allowed**: Adjusting frequency or trigger conditions
- **Forbidden**: Changing to a description without a frequency ("on demand")
- **Trigger**: Release strategy adjustment
- **Check**: The new value still includes a frequency or trigger condition
- ❌ "Feature-driven; release on milestone completion" → "on demand"
- ✅ "Feature-driven; release on milestone completion" → "Bi-weekly fixed release; hotfix as needed"

#### Versioning Rule

- **Change Type**: updatable
- **Allowed**: Refining or adjusting the version-number rule
- **Forbidden**: Changing to a description without a concrete rule
- **Trigger**: Version-management strategy adjustment
- **Check**: The new value still describes the increment rule

### §2 Feedback Loop

#### Whole row

- **Change Type**: append-only
- **Allowed**: Adding new feedback channel rows
- **Forbidden**: Deleting existing rows
- **Trigger**: A new feedback collection channel
- **Check**: New rows satisfy all column constraints in the checklist
- ❌ Deleting an existing channel row
- ✅ Adding a new row "Discord | community discussion, usage questions | first response within 48h on weekdays"

#### Channel / Category

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying the channel name or category of an existing row
- **Trigger**: —
- **Check**: When a channel changes, add a replacement row and annotate the old row as "migrated to X"

#### Response SLA

- **Change Type**: updatable
- **Allowed**: Tightening the SLA (e.g. 48h → 24h); loosening it due to team changes (annotate the reason)
- **Forbidden**: Loosening the SLA without a reason
- **Trigger**: Team capacity changes or SLA-attainment-rate data
- **Check**: The new value must still be a concrete time quantity; loosenings annotate the reason
- ❌ "First response within 24h on weekdays" → "ASAP"
- ✅ "First response within 48h on weekdays" → "First response within 24h on weekdays"

### §3 Key Metrics

#### Whole row

- **Change Type**: append-only
- **Allowed**: Adding new metric rows
- **Forbidden**: Deleting existing rows
- **Trigger**: A new key operational metric is identified
- **Check**: New rows satisfy all column constraints in the checklist
- ❌ Deleting the "P95 response time" row
- ✅ Adding a new row "DAU | >100 | <20 for 3 consecutive days"

#### Metric (column value)

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying the metric name of an existing row
- **Trigger**: —
- **Check**: When the metric definition changes, add a replacement row

#### Target

- **Change Type**: data refresh
- **Allowed**: "target value, pending validation" → a sensible target after a measured baseline; precision improvements
- **Forbidden**: Arbitrary adjustment without data backing; loosening the target without annotating the reason
- **Trigger**: Real operational data is now available
- **Check**: The new value annotates its data source; loosened targets annotate the reason
- ❌ "<200ms" → "<500ms" (loosened with no reason)
- ✅ "<200ms (target value, pending validation)" → "<150ms (based on 30-day P95 measured at 120ms)"

#### Alert Threshold

- **Change Type**: data refresh
- **Allowed**: Tuning the threshold based on measured data
- **Forbidden**: Loosening due to frequent alerts without annotating the reason
- **Trigger**: Alert-sensitivity tuning
- **Check**: The new value annotates the basis for the adjustment
- ❌ ">500ms for 5min" → ">2000ms for 30min" (loosened out of annoyance)
- ✅ ">500ms for 5min" → ">800ms for 3min (based on 30-day false-positive analysis; old threshold had 40% false-positive rate)"

### §4 Incident Playbook

#### Whole row

- **Change Type**: append-only
- **Allowed**: Adding new incident-scenario rows
- **Forbidden**: Deleting existing rows
- **Trigger**: A new type of incident occurred or a drill found a blind spot
- **Check**: New rows satisfy all column constraints in the checklist
- ❌ Deleting an existing playbook row
- ✅ After an incident retrospective, adding "DB connection-pool exhaustion | 1. restart the pool 2. throttle / degrade | not recovered in 10min → escalate to DBA"

#### Scenario (column value)

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying the scenario description of an existing row
- **Trigger**: —
- **Check**: When the scenario description needs to be more precise, append a new row

#### Response Procedure

- **Change Type**: updatable
- **Allowed**: Optimizing steps based on an incident retrospective; supplementing missing steps
- **Forbidden**: Deleting existing steps without annotating the reason
- **Trigger**: Incident retrospective; improvements found in drills
- **Check**: After updating, the value must still be concrete operational steps
- ❌ "1. fail over 2. notify users 3. investigate root cause" → "handle"
- ✅ "1. fail over 2. notify users" → "1. fail over 2. notify users 3. investigate root cause 4. write incident report"

#### Escalation Path

- **Change Type**: updatable
- **Allowed**: Updating the role / owner upon personnel changes; adjusting time conditions based on a retrospective
- **Forbidden**: Changing to a description without a concrete role
- **Trigger**: Team personnel changes; incident retrospective
- **Check**: The new value must still include a concrete role / owner
- ❌ "15min → escalate to {CTO}" → "escalate to handle"
- ✅ "15min → escalate to Zhang San" → "15min → escalate to Li Si (Zhang San left; handed over 2024.03)"

## Operating Procedure

### Create Ops

1. Fill in all fields of §1–§4
2. §1 Release Channels at least 1 item; Release Cadence and Versioning Rule each one paragraph
3. §2 Feedback Loop at least 2 rows; SLA must be a concrete time
4. §3 Key Metrics at least 3 rows; Target and threshold must contain numbers
5. §4 Incident Playbook at least 2 rows; Escalation Path must name a concrete role / owner

### Add a Feedback Channel

1. §2 Append a new row
2. Confirm the SLA is a concrete time

### Metric Tuning

1. §3 Refresh the Target or Alert Threshold
2. Annotate the data source and the basis for the adjustment
3. Append a new row if a new metric is needed

### Incident Retrospective Update

1. §4 Append a new row if it is a new scenario
2. §4 Update the Response Procedure and/or Escalation Path if it is an existing scenario
3. §3 Append a new metric row if a metric blind spot was found

## Validation Rules

1. **Immutable fields unchanged** — The diff must not contain changes to channel names, metric names, or scenario descriptions of existing rows
2. **Append-only fields only grow** — §2 / §3 / §4 row counts only grow
3. **SLA always a concrete time** — Descriptions like "ASAP" without a time quantity are forbidden
4. **Target and threshold always have numbers** — Descriptions like "lower is better" or "alert on anomalies" without numbers are forbidden
5. **Escalation path always has a role** — Descriptions like "escalate to handle" or "find someone" without a concrete role are forbidden
6. **Data refresh annotates source** — When adjusting Target / threshold, annotate the data source and the basis for the adjustment
