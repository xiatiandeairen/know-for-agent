# Roadmap Checklist

## Overview

| Location | Field | Omittable |
|----------|-------|-----------|
| §1.1 Product Essence | Positioning | No |
| | Motivation | No |
| | Long-term Vision | No |
| §1.2 Value System | Immediate Value.Value | No |
| | Immediate Value.Metric | No |
| | Cumulative Value.Value | No |
| | Cumulative Value.Metric | No |
| | Strategic Value.Value | No |
| | Strategic Value.Metric | No |
| §1.3 Core Problem | Problem | No |
| | Occurrence Frequency | When unable to estimate, fill "to be quantified (reason)" |
| | Per-occurrence Cost | When unable to estimate, fill "to be quantified (reason)" |
| | Reach | No |
| | Existing Workaround | When no existing solution, fill "no alternative" |
| §1.4 Target Users | Role | No |
| | Typical Scenario | No |
| | Before | No |
| | After | No |
| | Estimated Productivity Gain | When no early data, fill "pending validation (expected: estimate)" |
| §1.5 Competitive Comparison | Solution | No |
| | Positioning | No |
| | Target Users | No |
| | Core Features | No |
| | Strengths | No |
| | Limitations | No |
| §2.1 Version Summary | Version | No |
| | Core Direction | No |
| | Core-metric Delta | When in planning, fill "TBD" |
| | Status | No |
| | Cycle | When not started, fill "TBD" |
| | Milestones | No |
| §2.2 Version Details | Strategic Intent | No |
| | Input/Output | No |
| | Priority Rationale | No |
| | Risks and Dependencies | When no risks, fill "no identified risks or external dependencies" |
| | Success Metric | No |
| | Core Value | No |
| | User Coverage | No |
| | Core Metric Table | When in planning, fill only the target-value column |
| §3 Milestones | # | No |
| | Core Direction | No |
| | Goal Achievement | When not started, fill "—" |
| | Status | No |
| | Completion Date | When not finished, fill "—" |

## Field Definitions

### §1.1 Product Essence

#### Positioning

- **Information**: What the product is and what it provides to whom
- **Format**: 1 sentence. "A {category} for {users}"
- **Forbidden**: A pile of adjectives (powerful / advanced / smart)
- **Omit**: No
- **Data**: —
- ❌ "A powerful knowledge-management tool"
- ✅ "A project-knowledge compiler for AI coding assistants"

#### Motivation

- **Information**: Why the product is being built; what the triggering event is
- **Format**: 1-2 sentences. Must include the pain point + the inadequacy of existing solutions
- **Forbidden**: Empty phrases such as "the market needs" or "users need"
- **Omit**: No
- **Data**: —
- ❌ "The market needs a better knowledge-management solution"
- ✅ "AI agents lose implicit knowledge across sessions and repeat the same mistakes; existing solutions (CLAUDE.md) cannot manage knowledge in layers"

#### Long-term Vision

- **Information**: The terminal state once the product matures
- **Format**: 1-2 sentences. Use analogy or imagery to depict the terminal state
- **Forbidden**: Self-aggrandizement such as "the best", "leading", "the strongest"
- **Omit**: No
- **Data**: —
- ❌ "Become the best AI knowledge-management tool"
- ✅ "AI agents work in a project like an experienced team member: aware of history, respectful of constraints, and not repeating the same mistakes"

### §1.2 Value System

#### Immediate Value.Value

- **Information**: The benefit obtained directly from each use
- **Format**: 1 sentence. The subject is a behavior change of the user/agent, not a product feature
- **Forbidden**: A product feature as the subject ("our product offers...")
- **Omit**: No
- **Data**: —
- ❌ "Our product offers automatic knowledge recall"
- ✅ "Eliminates the cost of context rebuild across sessions"

#### Immediate Value.Metric

- **Information**: How to quantify the immediate gain
- **Format**: "{metric name} (target: {value})", multiple metrics comma-separated
- **Forbidden**: Bare numbers without metric names; pure descriptions without target values
- **Omit**: No
- **Data**: When measured, use measured and annotate the source; when not measured, mark "target value, pending validation"
- ❌ "Efficiency much improved"
- ✅ "/know learn rejected low-quality claim count (current measured: 2 occurrences); end-to-end duration of a single learn run (measured: <30s)"

#### Cumulative Value.Value

- **Information**: The compounding benefit from continuous use
- **Format**: 1 sentence. Emphasizes the "grows over time" property
- **Forbidden**: Static descriptions (no time dimension)
- **Omit**: No
- **Data**: —
- ❌ "The knowledge base is valuable"
- ✅ "Project-knowledge assets are continuously captured"

#### Cumulative Value.Metric

- **Information**: How to quantify the cumulative trend
- **Format**: The metric must be an observable trend (growth rate, coverage rate, etc.)
- **Forbidden**: Static metrics (no trend)
- **Omit**: No
- **Data**: When measured, use measured; when not measured, mark "target value, pending validation"
- ❌ "Number of knowledge entries"
- ✅ "Total ## know entries in CLAUDE.md (current measured: 54 entries); learn-gate rejection rate (current measured: 18%, target: ≥20%)"

#### Strategic Value.Value

- **Information**: The long-term impact of changing the way of working
- **Format**: 1 sentence. "From {old paradigm} to {new paradigm}"
- **Forbidden**: Descriptions that do not embody a paradigm shift
- **Omit**: No
- **Data**: —
- ❌ "Improves AI collaboration experience"
- ✅ "AI collaboration upgrades from stateless conversations to memory-bearing continuous collaboration"

#### Strategic Value.Metric

- **Information**: How to quantify the paradigm shift
- **Format**: May be an indirect metric
- **Forbidden**: Unobservable metrics
- **Omit**: No
- **Data**: When measured, use measured; when not measured, mark "target value, pending validation"; when not measurable, mark "no data (reason)"
- ❌ "AI becomes smarter"
- ✅ "Time to first effective collaboration in a new session (target value, pending validation: <2min); cross-session knowledge reuse rate (no data, no measurement method yet)"

### §1.3 Core Problem

#### Problem

- **Information**: The user-perspective concrete pain point
- **Format**: The subject is the user or agent. Describe the phenomenon, not what is missing
- **Forbidden**: Missing-style descriptions such as "lack of X" or "no Y"
- **Omit**: No
- **Data**: —
- ❌ "Lack of a knowledge-management tool"
- ✅ "AI repeats known mistakes in new sessions"

#### Occurrence Frequency

- **Information**: How frequently the problem occurs
- **Format**: Must include a number or frequency word (per day / per occurrence / per week)
- **Forbidden**: Non-quantified words such as "often", "frequently", "occasionally"
- **Omit**: When unable to estimate, fill "to be quantified ({reason})"
- **Data**: A basis is required (measured / industry data / reasonable derivation). When no basis, annotate the derivation method
- ❌ "Occurs frequently"
- ✅ "Every new session (estimated: 5-20 times per day, based on the author's usage frequency)"

#### Per-occurrence Cost

- **Information**: The cost of each occurrence
- **Format**: Quantified by time / money / risk
- **Forbidden**: Non-quantified descriptions such as "wastes time" or "has impact"
- **Omit**: When unable to estimate, fill "to be quantified ({reason})"
- **Data**: Same as Occurrence Frequency
- ❌ "Wastes time and energy"
- ✅ "Estimated 10-30 minutes for re-exploration + risk of introducing regression bugs (based on the author's perception, not precisely timed)"

#### Reach

- **Information**: How many people / scenarios are affected
- **Format**: Group characteristics + scale description
- **Forbidden**: Featureless descriptions such as "many people" or "many users"
- **Omit**: No
- **Data**: —
- ❌ "Many developers have this problem"
- ✅ "All developers maintaining mid-to-large projects with AI assistants"

#### Existing Workaround

- **Information**: How users solve this problem today
- **Format**: "{solution}, {limitation}". Must include the limitation
- **Forbidden**: Stating the solution without the limitation
- **Omit**: When no existing solution, fill "no alternative"
- **Data**: —
- ❌ "Use CLAUDE.md to manage it"
- ✅ "Manually maintain CLAUDE.md; once entries inflate, the token cost is uncontrollable and there is no layered retrieval"

### §1.4 Target Users

#### Role

- **Information**: Who will use the product
- **Format**: "{qualifier}'s {role name}"
- **Forbidden**: Unqualified generic names
- **Omit**: No
- **Data**: —
- ❌ "Developer"
- ✅ "Independent developer using Claude Code"

#### Typical Scenario

- **Information**: When use is triggered
- **Format**: Describes the specific trigger scenario
- **Forbidden**: Generic descriptions such as "daily use" or "during development"
- **Omit**: No
- **Data**: —
- ❌ "During daily development"
- ✅ "Maintaining a mid-to-large project across sessions, requiring the AI to remember project constraints and historical decisions"

#### Before

- **Information**: The user's pain before use
- **Format**: Specific behavior + outcome, quantified
- **Forbidden**: Behavior-free descriptions such as "low efficiency" or "poor experience"
- **Omit**: No
- **Data**: When measured, use measured; when not measured, mark "estimated"
- ❌ "Very low efficiency"
- ✅ "Spends several minutes rebuilding context every new session, and key constraints are still missed (estimated, not precisely timed)"

#### After

- **Information**: The user's state after use
- **Format**: Symmetric with Before, quantified improvement
- **Forbidden**: Descriptions with no correspondence to Before
- **Omit**: No
- **Data**: Same as Before
- ❌ "Efficiency greatly improved"
- ✅ "The agent automatically obtains relevant knowledge; known mistakes can be intercepted (verified successfully 2 times)"

#### Estimated Productivity Gain

- **Information**: ROI quantification
- **Format**: "{what is saved} {value}", multiple dimensions comma-separated
- **Forbidden**: Numberless descriptions such as "much improvement" or "significant improvement"
- **Omit**: When no early data, fill "pending validation (expected: {estimate})"
- **Data**: Distinguish measured / estimated / target and annotate the source
- ❌ "Efficiency greatly improved"
- ✅ "Pending validation (expected: saves several minutes per session, regression bugs reduced)"

### §1.5 Competitive Comparison

#### Solution

- **Information**: A specific product or alternative name
- **Format**: Official product name. The row for this product is bolded
- **Forbidden**: Generic terms such as "other tools" or "competitors"
- **Omit**: No
- **Data**: —
- ❌ "Other AI coding tools"
- ✅ "Cursor Rules"

#### Positioning

- **Information**: What this solution is
- **Format**: 1-sentence product definition, in the same format as this product's positioning
- **Forbidden**: Multi-sentence descriptions
- **Omit**: No
- **Data**: —

#### Target Users

- **Information**: Who this solution targets
- **Format**: A short role description
- **Forbidden**: Overly long descriptions
- **Omit**: No
- **Data**: —

#### Core Features

- **Information**: What this solution does
- **Format**: 3-5 feature points, comma-separated, capabilities from the user's perspective
- **Forbidden**: Implementation descriptions
- **Omit**: No
- **Data**: —

#### Strengths

- **Information**: The most prominent strengths of this solution
- **Format**: 1-2 items, objectively described
- **Forbidden**: Pejorative subjective evaluations (toward competitors); self-aggrandizement (toward this product)
- **Omit**: No
- **Data**: —
- ❌ "Much better than the others"
- ✅ "Zero dependencies, ready to use, fully controllable"

#### Limitations

- **Information**: The most obvious limitations of this solution
- **Format**: 1-2 items, objectively described
- **Forbidden**: Pejorative subjective evaluations
- **Omit**: No
- **Data**: —

### §2.1 Version Summary

#### Version

- **Information**: Version number + optional codename
- **Format**: "v{n}" or "v{n} — {codename}"
- **Forbidden**: Non-consecutive version numbers
- **Omit**: No
- **Data**: —

#### Core Direction

- **Information**: The strategic focus of this version
- **Format**: A verb-object phrase
- **Forbidden**: Empty phrases such as "feature improvements" or "experience optimization"
- **Omit**: No
- **Data**: —
- ❌ "Feature improvements"
- ✅ "Validate the feasibility of the end-to-end closed loop"

#### Core-metric Delta

- **Information**: The most significant rises and falls of metrics in this version
- **Format**: "↑ {metric} {old}→{new}; ↓ {metric} {old}→{new}"
- **Forbidden**: Fabricating precise numbers when there is no data
- **Omit**: When in planning, fill "TBD"
- **Data**: Must come from real data. When no data, annotate "to be measured"
- ❌ "↑ hit rate 47%→55%" (fabricated data)
- ✅ "↑ test coverage 0→6 commands; ↓ path-resolution bugs eliminated"

#### Status

- **Information**: Lifecycle stage of the version
- **Format**: Enum: planning | in development | internal testing | released | archived
- **Forbidden**: Values outside the enum
- **Omit**: No
- **Data**: —

#### Cycle

- **Information**: Start and end times
- **Format**: YYYY.MM.DD - YYYY.MM.DD
- **Forbidden**: Vague times ("last month", "recently")
- **Omit**: When not started, fill "TBD"
- **Data**: —

#### Milestones

- **Information**: The range of milestone numbers included
- **Format**: M{a}-M{b}
- **Forbidden**: Non-consecutive numbers
- **Omit**: No
- **Data**: —

### §2.2 Version Details

#### Strategic Intent

- **Information**: Why this version is being built
- **Format**: 1-2 sentences. Must tie to the product vision or to the conclusions of the previous version
- **Forbidden**: Empty phrases such as "improve features" or "optimize experience"
- **Omit**: No
- **Data**: —
- ❌ "Improve core features"
- ✅ "Validate the core hypothesis — whether AI agents can reduce cross-session mistakes via persistent knowledge"

#### Input/Output

- **Information**: How much is invested and what is gained back
- **Format**: "Invest {amount} → expect {amount}", quantified on both sides
- **Forbidden**: Stating only the input or only the output
- **Omit**: No
- **Data**: Use the actual value for input; annotate the output as "expected" or "measured"
- ❌ "Small input, large gain"
- ✅ "Invest 4 days of full-time development → expected to establish end-to-end knowledge access capability (gain to be quantified and validated in subsequent versions)"

#### Priority Rationale

- **Information**: Why now
- **Format**: Includes the state of prerequisites + the consequence of not doing it
- **Forbidden**: "Important so we do it first", "high priority"
- **Omit**: No
- **Data**: —
- ❌ "It is important so we do it first"
- ✅ "Without validating the core closed loop, subsequent versions are pointless; no external dependencies, can start immediately"

#### Risks and Dependencies

- **Information**: What might block progress
- **Format**: "Dependencies: {items}; risks: {items}", each item specific and trackable
- **Forbidden**: "Risks are minor", "basically no dependencies"
- **Omit**: When no risks and no dependencies, fill "no identified risks or external dependencies"
- **Data**: —
- ❌ "Risks are minor"
- ✅ "Depends on the stability of the Claude Code plugin mechanism; risk: JSONL performance not validated under large entry volumes"

#### Success Metric

- **Information**: What counts as success
- **Format**: A list of quantified conditions, comma-separated; each condition independently verifiable
- **Forbidden**: Unverifiable descriptions such as "users are satisfied" or "quality is up to standard". Post-hoc fabrication
- **Omit**: No
- **Data**: Defined upfront, must not be modified after the fact
- ❌ "Users are satisfied; quality is up to standard"
- ✅ "The learn pipeline runs end-to-end; at least 1 real [correction] claim is captured into CLAUDE.md; no blockers across ≥1 week of continuous use"

#### Core Value

- **Information**: The user value delivered by this version
- **Format**: Numbered list. Each item: "first time you can {action}" or "{capability} can {effect}"
- **Forbidden**: Content-free descriptions such as "better experience" or "stronger features"
- **Omit**: No
- **Data**: —

#### User Coverage

- **Information**: Who uses it and how to reach them
- **Format**: For internal-testing: "author dogfood"; after public release: specific channels
- **Forbidden**: Vague descriptions such as "some users are using it"
- **Omit**: No
- **Data**: —

#### Core Metric Table

- **Information**: The full delta of this version's key metrics relative to the previous version
- **Format**: Table: Metric | Previous-version Value | This-version Value | Delta | Source. ≥3 rows
- **Forbidden**: Precise numbers without a source; fabricated data
- **Omit**: When in planning, fill only the target-value column; fill the rest with "—"
- **Data**: Every numeric value must annotate its source (measured / estimated / target / no data)
- ❌ `| learn-gate rejection rate | 47% | 55% | ↑ 8pp |` (fabricated)
- ✅ `| learn-gate rejection rate | no data (no metric in v1) | 18% (measured 9/50) | new baseline | tests/unit/test-learn-stages.sh |`

### §3 Milestones Summary

#### #

- **Information**: Milestone number + detail link
- **Format**: "[M{n}](milestones/m{n}.md)", globally incrementing without reset
- **Forbidden**: Duplicate numbers; non-consecutive numbers
- **Omit**: No
- **Data**: —

#### Core Direction

- **Information**: The strategic intent of this milestone
- **Format**: A verb-object phrase
- **Forbidden**: Empty phrases such as "lay the foundation" or "feature development"
- **Omit**: No
- **Data**: —
- ❌ "Lay the foundation"
- ✅ "Validate the end-to-end feasibility of the learn pipeline"

#### Goal Achievement

- **Information**: To what extent the goal was achieved
- **Format**: When achieved, write the result data; when not fully achieved, write the result + "——" + the reason
- **Forbidden**: Data-free descriptions such as "partially complete" or "basically up to standard"; fabricated data
- **Omit**: When not started, fill "—"
- **Data**: Must be based on verifiable facts
- ❌ "Partially complete"
- ✅ "End-to-end runnable; can extract knowledge from conversations and write it — no quantified extraction-accuracy data"

#### Status

- **Information**: Progress stage
- **Format**: Enum: not started | in progress | in acceptance | completed | shelved
- **Forbidden**: Values outside the enum
- **Omit**: No
- **Data**: —

#### Completion Date

- **Information**: When it was completed
- **Format**: YYYY-MM-DD
- **Forbidden**: Vague dates
- **Omit**: When not finished, fill "—"
- **Data**: —

## Data Confidence Rules

All numeric fields must obey:

1. **Has measured data** → quote it directly and annotate the source (e.g. `tests/unit/test-learn-stages.sh`)
2. **Has reasonable derivation** → write the derived value, annotate "estimated" and the derivation basis
3. **Has a target but no data** → write the target value, annotate "target value, pending validation"
4. **Cannot estimate** → fill "no data ({reason it cannot be estimated})"
5. **Forbidden** → fabricating precise numbers and pretending they are measured. 50% real data > 100% fabricated data
