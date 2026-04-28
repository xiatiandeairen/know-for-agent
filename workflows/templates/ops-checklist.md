# Ops Checklist

## Overview

| Location | Field | Omittable |
|----------|-------|-----------|
| §1 Release Strategy | Release Channels | No (≥1 item) |
| | Release Cadence | No |
| | Versioning Rule | No |
| §2 Feedback Loop | Channel | No |
| | Category | No |
| | Response SLA | No |
| §3 Key Metrics | Metric | No |
| | Target | No |
| | Alert Threshold | No |
| §4 Incident Playbook | Scenario | No |
| | Response Procedure | No |
| | Escalation Path | No |

## Field Definitions

### §1 Release Strategy

#### Release Channels

- **Information**: All paths through which the product reaches users
- **Format**: List, each item "{channel name}: {purpose / description}". ≥1 item
- **Forbidden**: Generic terms such as "online" or "offline"; including CI/CD implementation details
- **Omit**: No
- **Data**: —
- ❌ "Released through online channels"
- ✅ "npm registry: distribution of stable releases"

#### Release Cadence

- **Information**: How often releases happen and what triggers a release
- **Format**: 1-2 sentences. Must include a frequency or trigger condition
- **Forbidden**: Descriptions without a concrete frequency such as "regular releases" or "on-demand releases"
- **Omit**: No
- **Data**: —
- ❌ "Regular releases"
- ✅ "Feature-driven; release on milestone completion, expected to be once every 1-2 weeks"

#### Versioning Rule

- **Information**: Naming and increment rules for version numbers
- **Format**: 1-2 sentences. Specifies the conditions under which each level is bumped
- **Forbidden**: Just writing "SemVer" without expansion
- **Omit**: No
- **Data**: —
- ❌ "Semantic versioning"
- ✅ "SemVer: MAJOR for breaking changes, MINOR for new features, PATCH for bug fixes; pre-releases use the -alpha.N suffix"

### §2 Feedback Loop

#### Channel

- **Information**: Where feedback is collected
- **Format**: A specific name
- **Forbidden**: Generic terms such as "various channels" or "multiple ways"
- **Omit**: No
- **Data**: —
- ❌ "Online channels"
- ✅ "GitHub Issues"

#### Category

- **Information**: What types of feedback this channel collects
- **Format**: Enumerated feedback types, comma-separated
- **Forbidden**: "All kinds", "every type"
- **Omit**: No
- **Data**: —
- ❌ "All kinds of feedback"
- ✅ "bug report, feature request"

#### Response SLA

- **Information**: How fast users get the first response
- **Format**: A concrete time amount (with a number + time unit)
- **Forbidden**: "ASAP", "as quickly as possible", "in a timely manner"
- **Omit**: No
- **Data**: —
- ❌ "Respond as quickly as possible"
- ✅ "First response within 24h on business days"

### §3 Key Metrics

#### Metric

- **Information**: An observable metric for operational health
- **Format**: A specific metric name that can be plugged directly into a monitoring dashboard
- **Forbidden**: Non-directly-observable descriptions such as "user experience" or "system health"
- **Omit**: No
- **Data**: —
- ❌ "Whether user experience is good"
- ✅ "P95 response time"

#### Target

- **Information**: The healthy target value for this metric
- **Format**: Must include a number (with a unit)
- **Forbidden**: Numberless descriptions such as "the lower the better" or "as high as possible"
- **Omit**: No
- **Data**: When a measured baseline exists, use measured and annotate the source; when no baseline, mark "target value, pending validation"
- ❌ "The faster the better"
- ✅ "<200ms"

#### Alert Threshold

- **Information**: The specific condition that triggers an alert
- **Format**: Must include a number + trigger condition (such as duration or frequency)
- **Forbidden**: Numberless descriptions such as "alert when abnormal" or "alert when over the limit"
- **Omit**: No
- **Data**: Same as Target
- ❌ "Alert when abnormal"
- ✅ ">500ms sustained for 5min"

### §4 Incident Playbook

#### Scenario

- **Information**: A user-perceivable abnormal situation
- **Format**: Specific symptoms, from the user's perspective
- **Forbidden**: Generic terms such as "system error" or "service abnormal"
- **Omit**: No
- **Data**: —
- ❌ "System error"
- ✅ "Core service unavailable for more than 10min"

#### Response Procedure

- **Information**: Specific operating steps for the first responder
- **Format**: Numbered step list or short sentences describing concrete actions
- **Forbidden**: Step-free descriptions such as "fix" or "handle"
- **Omit**: No
- **Data**: —
- ❌ "Fix as soon as possible"
- ✅ "1. Switch to the backup service 2. Notify users with degradation messaging 3. Investigate the root cause"

#### Escalation Path

- **Information**: The escalation chain when the first responder cannot resolve the issue
- **Format**: Must name a specific role or owner + time condition
- **Forbidden**: Role-free descriptions such as "escalate" or "find someone to fix it"
- **Omit**: No
- **Data**: —
- ❌ "Escalate to the manager"
- ✅ "Not recovered in 15min → escalate to {project owner}; not recovered in 30min → escalate to {tech director}"

## Data Confidence Rules

Same as roadmap-checklist.md: measured > annotate source; estimated > annotate basis; target > "pending validation"; no data > annotate reason. No fabrication.
