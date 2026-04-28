# {requirement name}

<!-- Core question: where does this requirement stand and what are the acceptance criteria?
     Positioning: requirement-level definition + progress tracking
     Out of scope: product-wide planning (→ roadmap), technical solution (→ tech), system architecture (→ arch)
     Field spec: see templates/prd-checklist.md
     Change rules: see templates/prd-update.md
     Data confidence: measured values annotate source; derived values annotate "estimated" + basis; targets annotate "target value, pending validation"; values that cannot be estimated annotate "no data ({reason})". No fabrication.
     Structure locked: do not add or remove sections, do not add or remove table columns. Only fill in values. -->

## 1. Problem

<!-- Why this requirement is worth building. Answers "is it worth doing". 3 fixed fields. -->

### Pain Point

<!-- The concrete difficulty the user encounters.
  - Format: 1-3 sentences. Subject is the user/agent; describe the phenomenon, not the missing capability.
  - Forbidden: "lacks X" / "doesn't have Y"; technical-implementation reasons; internal architectural limitations
  - ❌ "the system lacks self-test capability"
  - ✅ "after changes to the payment-webhook signature-verification logic, there is no way to verify whether a regression has been introduced; incorrectly accepted requests are only discovered after release" -->

{concrete user-perspective difficulty}

### Impact Scope

<!-- How many people/scenarios are affected, how often.
  - Format: quantified description. Includes affected population + frequency.
  - Forbidden: "many users" / "significant impact"
  - Data: when measured, use measured values; without measurement, annotate "estimated"
  - ❌ "significant impact"
  - ✅ "every change to the webhook signature-verification logic (estimated: 2-3 times per week) carries regression risk, affecting all payment callback chains" -->

{quantified impact scope and frequency}

### Why Now

<!-- Triggering event. Why not next version.
  - Format: 1-2 sentences. Includes triggering event + consequence of not doing it.
  - Forbidden: "important so do it first" / "high priority"
  - ❌ "this requirement is very important"
  - ✅ "in this session, a signature-calculation bug caused some legitimate callbacks to be rejected, only discovered when a customer reported it" -->

{triggering event + consequence of not doing it}

## 2. Target Users

<!-- Who it is for. Answers "who will use it".
  - Format: table, ≥1 row
  - Role: "{qualifier} {role name}". Forbidden: generic role names without qualifiers.
  - Scenario: when usage is triggered. Forbidden: "daily use".
  - Before: pain felt before use, quantified. Forbidden: "low efficiency".
  - After: state after use, symmetric to Before. Forbidden: "high efficiency".
  - EXCLUDE: internal system component names, data models -->

| Role | Scenario | Before | After |
|------|----------|--------|-------|
| {qualified role} | {trigger scenario} | {pre-use pain, quantified} | {post-use state, quantified} |

## 3. Core Hypothesis

<!-- What will happen after building it. Answers "which hypothesis is being validated".
  - Hypothesis: 1 cause-and-effect sentence ("did X → user will Y"). Forbidden: multiple hypotheses mixed together.
  - Validation method: an executable check, with a decision criterion. Forbidden: "test it and see".
  - EXCLUDE: technical solution, implementation details
  - ❌ Hypothesis: "the experience will be better after optimization" / Validation: "see how it goes"
  - ✅ Hypothesis: "providing a contract test suite → developers can verify with one command that no regressions are introduced after changing signature-verification logic" / Validation: "deliberately introduce a signature-calculation bug; the contract test catches it" -->

- **Hypothesis**: {did X → user will Y}
- **Validation method**: {executable check + decision criterion}

## 4. Plan

<!-- What to do (not how to do it). Answers "how the user experience changes".
  - Before→After: one sentence per change point, user-perspective behavior change.
  - ROWS: ≥1
  - Forbidden: operation flow diagrams, interaction details, internal data structures, storage formats, algorithms, file paths
  - ❌ "add a contract test suite covering signature/replay/timeout scenarios"
  - ✅ "Before: manually run each command after changes → After: run one command to automatically verify all core features" -->

- **Before**: {what the user has to do now} → **After**: {what the user only has to do afterwards}

### Task Tracking

<!-- Track at tech granularity. One PRD may correspond to multiple tech docs.
  - Task: task name
  - Tech: link to the tech doc "[{plan name}]({path})", "—" if no tech
  - Status: not started | in progress | done | shelved
  - Notes: "done" or "has leftover items: {specifics}"
  - ROWS: ≥1
  - Forbidden: deleting existing rows; reverting status
  - ❌ Notes: "in progress"
  - ✅ Notes: "has leftover items: insufficient edge-case coverage" -->

| Task | Tech | Status | Notes |
|------|------|--------|-------|
| {task name} | [{plan name}]({tech path}) | {enum status} | {done/has leftover items: specifics} |

## 5. Acceptance Criteria

<!-- What counts as done. Answers "acceptance criteria".
  - Format: each item "user does X → should see Y". Cover core scenarios + key edges.
  - ROWS: ≥3
  - Each item must be independently verifiable
  - Forbidden: unit test cases, code coverage, internal interface assertions
  - ❌ "contract test works correctly"
  - ✅ "the developer runs `npm run test:contract` → should see all 6 core cases PASS, taking <30s" -->

- {user does X → should see Y}

## 6. Exclusions

<!-- What is not done. Answers "where is the boundary".
  - Format: "does not support X ({reason})" or "X postponed to v{N} ({reason})"
  - ROWS: ≥2
  - Only list items that could easily be mistaken as in scope
  - Forbidden: bare exclusions without reason; technical debt, refactor plans
  - ❌ "not supported for now"
  - ✅ "does not support cross-project consistency check (single-project usage is sufficient for now)" -->

- {exclusion} ({reason})
