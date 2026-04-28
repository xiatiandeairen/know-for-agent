# Marketing Checklist

## Overview

| Location | Field | Omittable |
|----------|-------|-----------|
| §1 Target Audience | User Persona | No |
| | Active Platforms | No (≥2 items) |
| | Decision Factors | No (≥2 items) |
| §2 Core Message | One-line Pitch | No |
| | Differentiation | No (≥2 items) |
| §3 Promotion Channels | Channel Row | No (≥2 rows) |
| §4 Communication Cadence | Cadence Item | No (≥3 items) |
| §5 Impact Measurement | Metric Row | No (≥2 rows) |

## Field Definitions

### §1 Target Audience

#### User Persona

- **Information**: Who the target user is and what their pain points are
- **Format**: 1-3 sentences. Includes role characteristics + core pain points
- **Forbidden**: Featureless descriptions such as "everyone" or "broad audience"
- **Omit**: No
- **Data**: —
- ❌ "All developers"
- ✅ "Independent developers maintaining 1-3 mid-sized projects, who use AI coding assistants frequently but suffer from cross-session context loss"

#### Active Platforms

- **Information**: Where the target users get their information
- **Format**: List, ≥2 items. Each item = platform name + a brief note on user behavior on that platform
- **Forbidden**: Bare platform names without behavior descriptions
- **Omit**: No
- **Data**: —
- ❌ "Twitter"
- ✅ "Twitter/X — follows AI tooling updates and reposts practical tips"

#### Decision Factors

- **Information**: What users care about when deciding whether to adopt the product
- **Format**: List, ≥2 items. Each item = factor + why it matters
- **Forbidden**: Internal technical metrics (users do not care about the architecture)
- **Omit**: No
- **Data**: —
- ❌ "Good performance"
- ✅ "Low onboarding cost — unwilling to spend more than 10 minutes configuring an auxiliary tool"

### §2 Core Message

#### One-line Pitch

- **Information**: The core value, described in the user's language
- **Format**: 1 sentence. The subject is the benefit the user gets, not a product feature
- **Forbidden**: Technical jargon; using a product feature as the subject
- **Omit**: No
- **Data**: —
- ❌ "A JSONL-based knowledge-persistence engine"
- ✅ "Let your AI assistant remember the pitfalls in this project so it doesn't repeat the same mistakes"

#### Differentiation

- **Information**: User-perceivable differences from competitors
- **Format**: List, ≥2 items. Each item described in the user's language
- **Forbidden**: Implementation-level differences ("we use the X algorithm")
- **Omit**: No
- **Data**: —
- ❌ "Adopts a layered indexing architecture"
- ✅ "Knowledge is captured automatically, no manual document maintenance required"

### §3 Promotion Channels

#### Channel Row

- **Information**: The channels through which to reach users
- **Format**: Table, ≥2 rows. Columns: Channel | Strategy | Priority
- **Forbidden**: Priority values outside the enum
- **Omit**: No
- **Data**: —
- **Priority enum**: P0 | P1 | P2
- ❌ `| Social media | Posts | High |`
- ✅ `| Twitter/X | One use-case thread per week with before/after comparisons | P0 |`

### §4 Communication Cadence

#### Cadence Item

- **Information**: What outbound communication action to take and when
- **Format**: Numbered list, ≥3 items. Each item "{YYYY.MM.DD} — {action}"
- **Forbidden**: Vague timing ("next week", "soon"); internal deployment actions
- **Omit**: No
- **Data**: —
- ❌ "Soon — release announcement"
- ✅ "2026.05.01 — publish product introduction thread on Twitter/X"

### §5 Impact Measurement

#### Metric Row

- **Information**: Metrics that measure marketing effectiveness
- **Format**: Table, ≥2 rows. Columns: Metric | Target | Review Checkpoint
- **Forbidden**: Vague descriptions in the Target column ("growth", "improvement"); vague timing in the Review Checkpoint column
- **Omit**: No
- **Data**: Target must be a concrete number; the review checkpoint must be a concrete date (YYYY.MM.DD)
- ❌ `| Impressions | Growth | Next month |`
- ✅ `| GitHub stars | 500 | 2026.06.01 |`

## Data Confidence Rules

Same as roadmap-checklist.md: measured > annotate source; estimated > annotate basis; target > "pending validation"; no data > annotate reason. No fabrication.
