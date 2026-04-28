# Decision Checklist

## Overview

| Location | Field | Omittable |
|----------|-------|-----------|
| §1 Background | Triggering Event | No |
| | Constraints | No (≥1 item) |
| | Decision Scope | No |
| §2 Decision | Outcome | No |
| | Core Reasoning | No |
| §3 Alternatives | Alternative | No (≥2 alternatives) |
| | Each alternative.Pros | No (≥2 items) |
| | Each alternative.Cons | No (≥2 items) |
| §4 Impact | Positive Impact | No (≥1 item) |
| | Negative Impact | No (≥1 item) |
| | Follow-up Actions | No (≥1 item) |
| §5 Status | Status | No |
| | Decision Date | No |
| | Decision Maker | No |

## Field Definitions

### §1 Background

#### Triggering Event

- **Information**: What event made the decision necessary
- **Format**: 1-2 sentences. Includes the specific event and time context
- **Forbidden**: Empty phrases such as "we need to decide" or "it's time for a decision"
- **Omit**: No
- **Data**: —
- ❌ "We need to decide on a technical solution"
- ✅ "During v2 development, the order list query takes >3s with 1000+ records, blocking the user pagination experience"

#### Constraints

- **Information**: Restrictions that must be obeyed when making the decision
- **Format**: List, ≥1 item. Each item = constraint content + source
- **Forbidden**: Constraints without a source ("must be fast")
- **Omit**: No
- **Data**: —
- ❌ "Performance must be good"
- ✅ "Order list query latency <1s (from PRD acceptance criteria)"

#### Decision Scope

- **Information**: What this decision addresses and what it does not
- **Format**: 1 sentence. Make the boundary explicit
- **Forbidden**: Vague scope ("related issues")
- **Omit**: No
- **Data**: —
- ❌ "Solve performance-related issues"
- ✅ "Decides only the indexing approach for order queries; does not cover restructuring of the order write flow"

### §2 Decision

#### Outcome

- **Information**: What was finally decided
- **Format**: "We decided: {outcome}", 1 sentence
- **Forbidden**: Vague outcomes ("leaning toward", "possibly")
- **Omit**: No
- **Data**: —
- ❌ "We are leaning toward Option A"
- ✅ "We decided: keep JSONL storage and add an inverted index file to accelerate queries"

#### Core Reasoning

- **Information**: Why this alternative was chosen
- **Format**: 1-2 sentences. Tied to the constraints or to the key differences from the alternatives
- **Forbidden**: Empty phrases such as "after weighing the options" or "after consideration"
- **Omit**: No
- **Data**: —
- ❌ "After consideration, we chose Option A"
- ✅ "The inverted index meets the <1s latency constraint and does not require introducing external dependencies, with the lowest implementation cost"

### §3 Alternatives

#### Alternative

- **Information**: All alternatives that were considered
- **Format**: ≥2 alternatives. Each alternative includes pros (≥2) and cons (≥2)
- **Forbidden**: Listing only 1 alternative (no comparative value); fewer than 2 pros or cons (insufficient analysis)
- **Omit**: No
- **Data**: —

#### Each alternative.Pros

- **Information**: The advantages of this alternative
- **Format**: List, ≥2 items. Each item is specific and verifiable
- **Forbidden**: Information-free descriptions such as "good", "fast", "simple"
- **Omit**: No
- **Data**: Attach quantified data when available
- ❌ "Good performance"
- ✅ "Query latency <100ms (estimated based on SQLite benchmarks)"

#### Each alternative.Cons

- **Information**: The disadvantages of this alternative
- **Format**: List, ≥2 items. Each item is specific and verifiable
- **Forbidden**: Information-free descriptions such as "not great", "risky"
- **Omit**: No
- **Data**: Attach quantified data when available
- ❌ "Somewhat complex"
- ✅ "Introduces a SQLite dependency, increasing installation complexity (requires compiling a native module)"

### §4 Impact

#### Positive Impact

- **Information**: The benefits this decision brings
- **Format**: List, ≥1 item. Concrete impact on the system / team / user
- **Forbidden**: Information-free descriptions such as "better", "faster"
- **Omit**: No
- **Data**: —
- ❌ "Better performance"
- ✅ "Order list query latency drops from >3s to <1s, meeting the interaction-experience requirement"

#### Negative Impact

- **Information**: Costs or risks this decision brings
- **Format**: List, ≥1 item. List honestly
- **Forbidden**: "No negative impact" (every decision has trade-offs)
- **Omit**: No
- **Data**: —
- ❌ "Basically no negative impact"
- ✅ "The inverted index must stay in sync with JSONL, increasing maintenance cost on writes"

#### Follow-up Actions

- **Information**: What needs to be tracked after the decision
- **Format**: List, ≥1 item. Each item assignable to a specific person
- **Forbidden**: Action-free empty phrases
- **Omit**: No
- **Data**: —
- ❌ "Continue to follow up later"
- ✅ "Design the data structure and synchronization mechanism of the inverted index in the tech document"

### §5 Status

#### Status

- **Information**: The stage of the decision
- **Format**: Enum: proposed | accepted | deprecated | superseded
- **Forbidden**: Values outside the enum
- **Omit**: No
- **Data**: —

#### Decision Date

- **Information**: The date the decision was made
- **Format**: YYYY-MM-DD
- **Forbidden**: Vague dates
- **Omit**: No
- **Data**: —

#### Decision Maker

- **Information**: Who made the decision
- **Format**: A specific person's name or role
- **Forbidden**: "The team", "everyone"
- **Omit**: No
- **Data**: —

## Data Confidence Rules

Same as roadmap-checklist.md: measured > annotate source; estimated > annotate basis; target > "pending validation"; no data > annotate reason. No fabrication.
