# PRD Checklist

## Overview

| Location | Field | Omittable |
|----------|-------|-----------|
| §1 Problem | Pain Point | No |
| | Impact Scope | No |
| | Why Now | No |
| §2 Target Users | Role | No |
| | Scenario | No |
| | Before | No |
| | After | No |
| §3 Core Hypothesis | Hypothesis | No |
| | Validation Method | No |
| §4 Plan | Before→After | No (≥1 item) |
| | Task Tracking Table | No (≥1 row) |
| §5 Acceptance Criteria | Acceptance Item | No (≥3 items) |
| §6 Exclusions | Exclusion Item | No (≥2 items) |

## Field Definitions

### §1 Problem

#### Pain Point

- **Information**: The concrete difficulty users encounter
- **Format**: 1-3 sentences. The subject is the user/agent; describe phenomena, not what is missing
- **Forbidden**: "Lack of X", "no Y"; technical-implementation reasons; internal-architecture limitations
- **Omit**: No
- **Data**: —
- ❌ "The system lacks self-test capability"
- ✅ "After modifying payment-webhook signature-verification logic, there is no way to verify whether a regression has been introduced; mistakenly allowed requests are only discovered after release"

#### Impact Scope

- **Information**: How many people / scenarios are affected and how often
- **Format**: Quantified description. Include the affected group + frequency
- **Forbidden**: Non-quantified descriptions such as "many users" or "significant impact"
- **Omit**: No
- **Data**: When measured, use measured and annotate the source; when not measured, mark "estimated" + derivation basis
- ❌ "Significant impact"
- ✅ "Every modification of webhook signature-verification logic (estimated: 2-3 times per week) faces regression risk and affects all payment callback chains"

#### Why Now

- **Information**: Triggering event + consequence of not doing it
- **Format**: 1-2 sentences. Includes a specific triggering event
- **Forbidden**: "Important so we do it first", "high priority"
- **Omit**: No
- **Data**: —
- ❌ "This requirement is very important"
- ✅ "In this session, a PROJECT_DIR path-resolution error wrote data into the wrong directory and was only discovered through manual testing"

### §2 Target Users

#### Role

- **Information**: Who will use it
- **Format**: "{qualifier}'s {role name}"
- **Forbidden**: Unqualified generic names ("developer", "user")
- **Omit**: No
- **Data**: —
- ❌ "Developer"
- ✅ "Claude Code users using the know skill"

#### Scenario

- **Information**: When use is triggered
- **Format**: A specific trigger scenario
- **Forbidden**: "Daily use", "during development"
- **Omit**: No
- **Data**: —
- ❌ "During daily development"
- ✅ "After modifying webhook signature-verification logic, the user needs to verify that core cases have no regression"

#### Before

- **Information**: The pain before use
- **Format**: Specific behavior + outcome, quantified
- **Forbidden**: "Low efficiency", "poor experience"
- **Omit**: No
- **Data**: When measured, use measured; when not measured, mark "estimated"
- ❌ "Very low efficiency"
- ✅ "Manually checks command by command; takes a long time and is prone to missing edge cases"

#### After

- **Information**: The state after use
- **Format**: Symmetric with Before, quantified improvement
- **Forbidden**: No corresponding relationship with Before
- **Omit**: No
- **Data**: Same as Before
- ❌ "Efficiency greatly improved"
- ✅ "A single command verifies all core functionality, completing in 8-12s"

### §3 Core Hypothesis

#### Hypothesis

- **Information**: What will happen after doing it
- **Format**: 1 causal sentence "do X → users will Y"
- **Forbidden**: Multiple hypotheses mixed together; technical-solution descriptions
- **Omit**: No
- **Data**: —
- ❌ "Experience will be better after optimization"
- ✅ "Provide a contract test suite → developers can verify there is no regression with a single command after modifying signature-verification logic"

#### Validation Method

- **Information**: How to know the hypothesis holds
- **Format**: An executable check + decision condition
- **Forbidden**: "Test it and see", "see how it goes"
- **Omit**: No
- **Data**: —
- ❌ "See how it goes"
- ✅ "Intentionally introduce a bug into the signature computation; the contract test should catch the exception in the signature-verification stage"

### §4 Plan

#### Before→After

- **Information**: How the user experience changes
- **Format**: Each item "Before: {now} → After: {then}", behavior change from the user's perspective. ≥1 item
- **Forbidden**: Implementation descriptions; internal data structures; file paths
- **Omit**: No
- **Data**: —
- ❌ "Add a contract test suite covering signature, replay, timeout, and other scenarios"
- ✅ "Before: manually check command by command after a change → After: run a single command to automatically verify all core functionality"

#### Task Tracking Table

- **Information**: Task progress at the tech dimension
- **Format**: Table, each row Task | Tech | Status | Notes. ≥1 row
- **Forbidden**: Deleting existing rows; regressing the status
- **Omit**: No
- **Data**: —

### §5 Acceptance Criteria

#### Acceptance Item

- **Information**: How to know it is done
- **Format**: Each item "user does X → should see Y". ≥3 items. Cover core scenarios + key edge cases. Each item independently verifiable
- **Forbidden**: Unit-test cases; code-coverage numbers; internal-interface assertions
- **Omit**: No
- **Data**: —
- ❌ "Contract test works correctly"
- ✅ "Developer runs `npm run test:contract` → should see all 6 core cases PASS, taking <30s"

### §6 Exclusions

#### Exclusion Item

- **Information**: What is not done and where the boundary is
- **Format**: "Not supported: X ({reason})" or "X deferred to v{N} ({reason})". ≥2 items. Only list things easily mistaken as in scope
- **Forbidden**: Bare exclusions without reasons; tech debt or refactoring plans
- **Omit**: No
- **Data**: —
- ❌ "Not supported for now"
- ✅ "Cross-project consistency checks not supported (currently only single-project use is required)"

## Data Confidence Rules

Same as roadmap-checklist.md: measured > annotate source; estimated > annotate basis; target > "pending validation"; no data > annotate reason. No fabrication.
