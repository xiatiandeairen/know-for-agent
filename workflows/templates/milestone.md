# M{n} — {core direction}

<!-- Milestone detail file. Plan and outcome are separated; the plan is immutable, the outcome is back-filled with real data.
     Path: docs/milestones/m{n}.md
     Field spec: see templates/milestone-checklist.md
     Change rules: see templates/milestone-update.md
     Data confidence: measured values annotate source; derived values annotate "estimated" + basis; targets annotate "target value, pending validation"; values that cannot be estimated annotate "no data ({reason})". No fabrication.
     Structure locked: do not add or remove sections, do not add or remove table rows. Only fill in values. -->

## 1. Goal

<!-- Filled at planning time. Once the milestone has started, this section is immutable. -->

### Definition of Done

<!-- What it means for this milestone to be "done"; must be a deliverable state.
  - Format: 1-2 sentences. Describe the terminal state, not the process.
  - Forbidden: percentage progress; process descriptions ("first develop X then test Y"); "basically done" / "mostly done"
  - ❌ "experience optimization done"
  - ✅ "the learn pipeline is end-to-end runnable from conversation-signal detection → confirmation → write, with no manual intervention required" -->

{terminal-state description}

### Value Target

<!-- What the user gains once it is achieved. Aligned with the "value target" in roadmap §3 summary table.
  - Format: 1 sentence. The subject is the user, not the product/system.
  - Forbidden: "the system supports..." / "the product provides..." style descriptions where the product is the subject
  - ❌ "the system supports a metric viewing feature"
  - ✅ "users can capture and reuse project knowledge in conversation via /know learn and /know write" -->

{user-perspective value}

### Key Hypothesis

<!-- The core uncertainty this milestone is meant to eliminate.
  - Hypothesis: 1 cause/condition sentence. Type: technical feasibility | user acceptance | business value
  - Validation method: a concrete, executable validation action + decision criterion
  - For an engineering-delivery milestone with no core hypothesis, fill in "this is an engineering-delivery milestone; no core hypothesis to validate"
  - Forbidden: abstract descriptions like "validate the technical solution"; descriptions without a decision criterion such as "give it a test"
  - ❌ Hypothesis: "validate whether the technical solution is feasible" / Validation method: "run a test"
  - ✅ Hypothesis: "AI can accurately recognize implicit-knowledge signals worth capturing from conversation" / Validation method: "run the learn pipeline during know project development conversations and check the accuracy across 10 extractions" -->

- **Hypothesis**: {core uncertainty, 1 cause/condition sentence}
- **Type**: {technical feasibility | user acceptance | business value}
- **Validation method**: {concrete validation action + decision criterion}

## 2. Plan

<!-- Filled at planning time. Once the milestone has started, this section is immutable (risks may be appended). -->

### Planned Deliverables

<!-- What is planned to be produced. Must be visible, testable artifacts.
  - Format: list, each item "{type}: {concrete artifact}". Type: code | doc | data | tool. ≥1 item.
  - Forbidden: abstract descriptions ("optimized the flow" / "improved the experience")
  - ❌ "optimized the knowledge extraction flow"
  - ✅ "code: learn workflow 5 stages (detect/gate/refine/locate/write)" -->

- {type}: {concrete artifact, verifiable}

### Go/No-Go Criteria

<!-- Go / No-Go decision conditions. 5 fixed dimensions, neither addable nor removable. At planning time, fill only the criterion column.
  - Format: one quantifiable pass condition per dimension
  - When a dimension does not apply, fill in "not applicable to this milestone"
  - Forbidden: non-quantifiable descriptions like "good quality" / "high performance"
  - Data: numbers in conditions annotate basis (industry standard / team agreement / experience)
  - ❌ "quality acceptable"
  - ✅ "extraction accuracy >80% (≥8 out of 10 learn runs accurate)" -->

| Dimension | Criterion |
|-----------|-----------|
| Functional completeness | {quantifiable pass condition} |
| Quality | {quantifiable pass condition} |
| Performance and stability | {quantifiable pass condition} |
| Security | {quantifiable pass condition} |
| Maintainability | {quantifiable pass condition} |

### Estimated Effort

<!-- Estimated resource cost.
  - Format: "{time} {headcount}"
  - Forbidden: "not much" / "very fast" / "modest effort"
  - ❌ "modest effort"
  - ✅ "1 day full-time development" -->

{estimated time and headcount}

### Decision Path

<!-- The milestone is essentially a decision node. At planning time, define the actions for pass/fail.
  - Pass: concrete action + resource flow
  - Fail: concrete response strategy
  - Forbidden: "continue development" / "try again" / "move to next step"
  - ❌ Pass: "go to next step" / Fail: "keep optimizing"
  - ✅ Pass: "enter M2 write-pipeline development; the knowledge base produced by learn provides the data foundation for write" / Fail: "investigate the blocking points in the learn pipeline; do not start write yet" -->

- **Pass**: {action and resource allocation upon meeting criteria}
- **Fail**: {response strategy when criteria are not met}

### Risks

<!-- Factors that could block. New risks may be appended during development; risks may be marked as eliminated, but identified items must not be deleted.
  - Format: "Dependencies: {item}; Risks: {item}"
  - When there are no risks, fill in "no identified risks"
  - Forbidden: "risk is small" / "essentially no dependencies"
  - ❌ "risk is small"
  - ✅ "Dependencies: stability of the Claude Code plugin mechanism; Risks: AI signal-detection accuracy is unknown" -->

{risks and dependencies}

## 3. Task Tracking

<!-- Track tasks at PRD granularity. One PRD may correspond to multiple tech docs; linking the PRD is sufficient.
  - Task: task name
  - PRD: link to PRD doc "[{requirement name}]({path})", "—" if no PRD
  - Status: not started | in progress | done | shelved
  - Notes: "done" or "has leftover items: {specifics}". For in-progress tasks write the current blocker or next step.
  - ROWS: ≥1
  - Forbidden: deleting existing rows; reverting status
  - ❌ Notes: "in progress" (duplicates the status, no information)
  - ✅ Notes: "has leftover items: tag classification accuracy lacks quantitative data" -->

| Task | PRD | Status | Notes |
|------|-----|--------|-------|
| {task name} | [{requirement name}]({prd path}) | {enum status} | {done/has leftover items: specifics} |

## 4. Outcome

<!-- Filled in after the milestone is completed/shelved. Leave this section empty for an unfinished milestone.
     All values must annotate source. No fabrication. -->

### Actual Deliverables

<!-- What was actually produced. Compare against §2 planned deliverables.
  - Format: same as planned deliverables
  - Items planned but not delivered: annotate "not delivered ({reason})"
  - Items added beyond plan: annotate "added beyond plan"
  - Forbidden: abstract descriptions that cannot be compared against planned deliverables ("completed the main features")
  - ❌ "completed the main features"
  - ✅ "code: all 5 stages of learn implemented ✓ / doc: workflows/learn.md ✓ / data: 12 entries captured in the project CLAUDE.md ## know block ✓" -->

- {type}: {concrete artifact}

### Hypothesis-Validation Conclusion

<!-- Validation result of §1 key hypothesis.
  - Conclusion: holds | does not hold | partially holds
  - Data: must include data + source. If no data, annotate "no data ({reason})".
  - When §1 has no hypothesis, fill in "not applicable".
  - Forbidden: bare conclusions without data ("validated"); fabricated data
  - ❌ Conclusion: "holds" / Data: "accuracy 80%" (no source)
  - ✅ Conclusion: "holds" / Data: "8 out of 10 learn runs extracted accurately (know project measured), 2 had tag deviations but correct content" -->

- **Conclusion**: {holds/does not hold/partially holds}
- **Data**: {supporting data + source, or "no data ({reason})"}

### Go/No-Go Assessment

<!-- Score against §2 Go/No-Go criteria, dimension by dimension. Copy the criterion column from §2 verbatim; do not modify.
  - Score: 5 = fully meets | 4 = mostly meets | 3 = partially meets | 2 = clearly insufficient | 1 = not started | N/A = not applicable
  - Description: objective achievement description, must include data or verifiable facts. Forbidden: "okay" / "essentially fine".
  - Leftover: concrete unfinished items + destination (which version/milestone resolves them). "—" if none.
  - ❌ Description: "okay, basically meets the requirement"
  - ✅ Description: "measured 5-15s end-to-end, no timeouts (10 learn-operation timings in the know project)"
  - ❌ Leftover: "tag accuracy needs improvement"
  - ✅ Leftover: "locate three-level decision accuracy needs improvement → handled together when v3 introduces cross-project evidence self-check" -->

| Dimension | Criterion (copied from §2) | Score | Description | Leftover |
|-----------|----------------------------|-------|-------------|----------|
| Functional completeness | {§2 criterion} | {1-5/N/A} | {objective description + data} | {leftover item + destination, or —} |
| Quality | {§2 criterion} | {1-5/N/A} | {objective description + data} | {leftover item + destination, or —} |
| Performance and stability | {§2 criterion} | {1-5/N/A} | {objective description + data} | {leftover item + destination, or —} |
| Security | {§2 criterion} | {1-5/N/A} | {objective description + data} | {leftover item + destination, or —} |
| Maintainability | {§2 criterion} | {1-5/N/A} | {objective description + data} | {leftover item + destination, or —} |

### Actual Effort

<!-- How much resource was actually spent. Compare against §2 estimated effort. Explain large deviations.
  - Format: "{actual value} (estimated: {§2 value})"
  - Forbidden: "roughly as expected"
  - ❌ "roughly as expected"
  - ✅ "actual 2 days (estimated 1 day); debugging the path-resolution bug took 1 extra day" -->

{actual time and headcount} (estimated: {§2 estimated value})

### Decision Outcome

<!-- The final decision that was made. Compare against §2 decision path.
  - Format: "{pass/fail/partial pass} → {actual action}"
  - Forbidden: "kept developing"
  - ❌ "kept developing"
  - ✅ "pass → enter M2 write-pipeline development; the knowledge base produced by learn provides the data foundation for write" -->

{decision outcome}

