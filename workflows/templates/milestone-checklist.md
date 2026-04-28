# Milestone Checklist

## Overview

| Location | Field | Omittable |
|----------|-------|-----------|
| §1 Goal | Definition of Done | No |
| | Value Target | No |
| | Hypothesis | When no core hypothesis, fill "engineering delivery, no core hypothesis to validate" |
| | Hypothesis.Type | Follows the hypothesis |
| | Hypothesis.Validation Method | Follows the hypothesis |
| §2 Plan | Planned Deliverables | No (≥1 item) |
| | Go/No-Go Criteria (5 dimensions) | No (when not applicable, fill "this milestone does not involve it") |
| | Estimated Effort | No |
| | Decision Path.Pass | No |
| | Decision Path.Fail | No |
| | Risks | When no risks, fill "no identified risks" |
| §3 Outcome | Actual Deliverables | For unfinished milestones, leave the entire §3 blank |
| | Hypothesis-Validation Conclusion | Follows §1 Hypothesis |
| | Go/No-Go Assessment (5 dimensions) | Leave blank when not finished |
| | Actual Effort | Leave blank when not finished |
| | Decision Outcome | Leave blank when not finished |
| Related Documents | PRD | Fill — when none |
| | Tech | Fill — when none |

## Field Definitions

### §1 Goal

#### Definition of Done

- **Information**: What terminal state "done" means for this milestone
- **Format**: 1-2 sentences. Describes the terminal state, not the process
- **Forbidden**: Percentage progress; process descriptions ("develop X then test Y")
- **Omit**: No
- **Data**: —
- ❌ "Experience optimization complete"
- ✅ "The learn pipeline runs end-to-end from conversation-signal detection → confirmation → write, with no manual intervention required"

#### Value Target

- **Information**: What the user gains once it is achieved
- **Format**: 1 sentence. The subject is the user, not the product/system
- **Forbidden**: The product as the subject ("the system supports...")
- **Omit**: No
- **Data**: —
- ❌ "The system supports metric viewing"
- ✅ "Through /know learn and /know write, users can capture and reuse project knowledge in conversation"

#### Hypothesis

- **Information**: The core uncertainty this milestone aims to eliminate
- **Format**: 1 causal or conditional sentence
- **Forbidden**: Abstract descriptions ("validate the technical solution")
- **Omit**: When no core hypothesis, fill "this milestone is an engineering delivery, no core hypothesis to validate"
- **Data**: —
- ❌ "Validate whether the technical solution is feasible"
- ✅ "AI can accurately identify capture-worthy implicit-knowledge signals from a conversation"

#### Hypothesis.Type

- **Information**: The category to which the hypothesis belongs
- **Format**: Enum: technical feasibility | user acceptance | business value
- **Forbidden**: Values outside the enum
- **Omit**: Follows the hypothesis
- **Data**: —

#### Hypothesis.Validation Method

- **Information**: How to validate this hypothesis
- **Format**: A specific executable validation action + decision condition
- **Forbidden**: Descriptions without a decision condition such as "give it a test" or "see how it goes"
- **Omit**: Follows the hypothesis
- **Data**: —
- ❌ "Test it and see"
- ✅ "Run the learn pipeline during know-project development conversations and check the extraction accuracy across 10 runs"

### §2 Plan

#### Planned Deliverables

- **Information**: What verifiable outputs are planned
- **Format**: List, each item "{type}: {specific output}". Type: code | doc | data | tool
- **Forbidden**: Abstract descriptions ("optimized the flow")
- **Omit**: No (≥1 item)
- **Data**: —
- ❌ "Optimized the knowledge extraction flow"
- ✅ "Code: learn workflow 5 stages (detect/gate/refine/locate/write)"

#### Go/No-Go Criteria (5-dimension table)

- **Information**: The pass condition for each dimension
- **Format**: Table with 5 fixed rows (functional completeness / quality / performance and stability / security / maintainability). Each row contains a quantifiable condition
- **Forbidden**: Non-quantifiable descriptions such as "good quality" or "high performance"; adding or removing dimension rows
- **Omit**: For dimensions that do not apply, fill "this milestone does not involve it"
- **Data**: For numeric values in the conditions, annotate the basis (industry standard / team agreement / experience value)
- ❌ "Quality is acceptable"
- ✅ "Extraction accuracy >80% (≥8 out of 10 learn runs accurate)"

#### Estimated Effort

- **Information**: The expected resource cost
- **Format**: "{time} {staffing}"
- **Forbidden**: Non-quantified descriptions such as "not much" or "very fast"
- **Omit**: No
- **Data**: —
- ❌ "Not a big investment"
- ✅ "1 day full-time development"

#### Decision Path.Pass

- **Information**: What to do once the criteria are met
- **Format**: Specific action + resource flow
- **Forbidden**: Information-free descriptions such as "continue developing"
- **Omit**: No
- **Data**: —
- ❌ "Move on to the next step"
- ✅ "Enter M2 write-pipeline development; the knowledge base produced by learn provides the data foundation for write"

#### Decision Path.Fail

- **Information**: What to do if the criteria are not met
- **Format**: A specific response strategy
- **Forbidden**: "Try again"
- **Omit**: No
- **Data**: —
- ❌ "Keep optimizing"
- ✅ "Investigate the blocking points in the learn pipeline; do not start write for now"

#### Risks

- **Information**: What might block progress
- **Format**: "Dependencies: {items}; risks: {items}"
- **Forbidden**: "Risks are minor"
- **Omit**: When no risks, fill "no identified risks"
- **Data**: —

### §3 Outcome

#### Actual Deliverables

- **Information**: What was actually produced
- **Format**: Same as planned deliverables. For planned items not delivered, mark "not delivered (reason)"; for unplanned additions, mark "unplanned addition"
- **Forbidden**: Descriptions that cannot be cross-checked against the planned deliverables
- **Omit**: For unfinished milestones, leave the entire §3 blank
- **Data**: —

#### Hypothesis-Validation Conclusion

- **Information**: The validation result of the §1 hypothesis
- **Format**: "{holds / does not hold / partially holds} + supporting data"
- **Forbidden**: Conclusions without data ("validation passed"); fabricated data
- **Omit**: When §1 has no hypothesis, fill "not applicable"
- **Data**: A data source must be attached. When there is no data, mark "no data (reason)"
- ❌ "Validation passed"
- ✅ "Holds. 8 out of 10 learn runs extracted accurately (measured in the know project); 2 had tag deviations but the content was correct"

#### Go/No-Go Assessment (5-dimension table)

- **Information**: Actual achievement against the §2 criteria
- **Format**: Table; copy the criteria column from §2; add Score / Notes / Leftover columns
- **Forbidden**: Modifying the criteria column (copy from §2 verbatim); notes without data; fabricated scores
- **Omit**: Leave blank when not finished
- **Data**: The Notes column must contain data or verifiable facts. The Leftover column annotates the destination (which version / milestone will resolve it)
- ❌ Notes: "OK"
- ✅ Notes: "Measured at 5-15s to complete, no timeouts observed"

#### Actual Effort

- **Information**: How many resources were actually spent
- **Format**: "{actual value} (estimated: {§2 value})". When the deviation is large, attach the reason
- **Forbidden**: "About what was expected"
- **Omit**: Leave blank when not finished
- **Data**: —
- ❌ "About what was expected"
- ✅ "Actual 2 days (estimated 1 day); debugging the path-resolution bug took an extra 1 day"

#### Decision Outcome

- **Information**: What decision was finally made
- **Format**: "{pass / fail / partial pass} → {actual action}"
- **Forbidden**: "Kept developing"
- **Omit**: Leave blank when not finished
- **Data**: —
- ❌ "Kept developing"
- ✅ "Pass → enter M2 write-pipeline development"

### Related Documents

#### PRD

- **Information**: The associated requirement document
- **Format**: "[{requirement name}]({relative path})"
- **Omit**: When there is no associated PRD, fill —

#### Tech

- **Information**: The associated technical solution
- **Format**: "[{solution name}]({relative path})"
- **Omit**: When there is no associated tech, fill —

## Data Confidence Rules

Same as roadmap-checklist.md: measured > annotate source; estimated > annotate basis; target > "pending validation"; no data > annotate reason. No fabrication.
