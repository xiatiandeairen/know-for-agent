# {project name} Operations Plan

<!-- Core question: how does the product run after launch and how do we keep it healthy?
     Positioning: operations plan — the complete closed loop of release, feedback, metrics, and incidents
     Out of scope: user acquisition and outreach (→ marketing), product planning (→ roadmap), technical solution (→ tech)
     Structure locked: do not add or remove columns, do not change column names, do not change formatting. Only fill in values.
     Field spec: see templates/ops-checklist.md (each field's information purpose, language constraint, presentation, omission conditions, data requirements)
     Data confidence: when measured, use measured values and annotate source; derived values annotate "estimated" + basis; targets annotate "target value, pending validation"; values that cannot be estimated annotate "no data ({reason})". No fabrication of precise numbers. -->

## 1. Release Strategy

<!-- Answers "how it gets shipped". 3 fixed sub-fields, neither addable nor removable.
  - Release channels: all paths through which the product reaches users (❌ "online channels" ✅ "npm registry, GitHub Releases")
  - Release cadence: how often, what triggers a release (❌ "release periodically" ✅ "feature-driven, release on milestone completion, expected every 1-2 weeks")
  - Versioning rule: version-number naming rule (❌ "semantic versioning" ✅ "SemVer: MAJOR for breaking changes, MINOR for new features, PATCH for bug fixes")
  - EXCLUDE: CI/CD configuration details, build scripts, deployment commands, canary-rollout implementation -->

### Release Channels

<!-- Presented as a list. ≥1 item. Each: "{channel name}: {purpose/description}" -->

- {channel name}: {purpose/description}

### Release Cadence

<!-- 1-2 sentences. Must include either frequency or trigger condition. -->

{how often it ships, what condition triggers a release}

### Versioning Rule

<!-- 1-2 sentences. Must explain the version-number increment rule. -->

{version-number naming and increment rule}

## 2. Feedback Loop

<!-- Collection channel + classification rule + response SLA. Answers "how we listen to user voice".
  - ROWS: ≥2. One row per feedback channel.
  - Channel: concrete name (❌ "online" ✅ "GitHub Issues")
  - Classification: what kind of feedback this channel collects (❌ "various" ✅ "bug report, feature request")
  - Response SLA: must be a concrete time (❌ "ASAP" ✅ "first response within 24h on business days")
  - EXCLUDE: specific bug-handling flow, technical investigation steps -->

| Channel | Classification | Response SLA |
|---------|----------------|--------------|
| {concrete channel name} | {feedback type} | {concrete time, e.g. "first response within 24h on business days"} |
| {concrete channel name} | {feedback type} | {concrete time} |

## 3. Key Metrics

<!-- Operational health metrics + target values + alert thresholds. Answers "how we measure health".
  - ROWS: ≥3. One row per core metric.
  - Metric: a concrete observable metric name (❌ "user experience" ✅ "P95 response time")
  - Target: must include a number (❌ "the lower the better" ✅ "<200ms")
  - Alert threshold: must include a number; the concrete value that triggers an alert (❌ "alert on anomaly" ✅ ">500ms sustained for 5min")
  - EXCLUDE: code coverage, technical-debt metrics (not from an operational perspective) -->

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| {concrete metric name} | {numeric target value} | {numeric alert condition} |
| {concrete metric name} | {numeric target value} | {numeric alert condition} |
| {concrete metric name} | {numeric target value} | {numeric alert condition} |

## 4. Incident Playbook

<!-- Common incidents + response procedures + escalation paths. Answers "what to do when something goes wrong".
  - ROWS: ≥2. One row per incident scenario.
  - Scenario: a user-perceivable incident (❌ "system error" ✅ "core service unavailable for over 10min")
  - Response procedure: concrete step-by-step actions for the first responder (❌ "fix it" ✅ "1. switch to the standby service 2. notify users of degradation 3. investigate the root cause")
  - Escalation path: must name a concrete role or owner (❌ "escalate" ✅ "if not recovered in 15min → escalate to {project owner}; if not recovered in 30min → escalate to {tech director}")
  - EXCLUDE: code-level debug steps, log-query commands -->

| Scenario | Response Procedure | Escalation Path |
|----------|--------------------|-----------------|
| {user-perceivable incident} | {concrete step-by-step actions} | {escalation chain with concrete roles/owners} |
| {user-perceivable incident} | {concrete step-by-step actions} | {escalation chain with concrete roles/owners} |
