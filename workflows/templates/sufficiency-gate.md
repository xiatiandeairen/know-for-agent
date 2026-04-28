# Document Sufficiency Gate

<!-- The write pipeline Step 1 loads this file after inferring the document type, and walks through the questions.
     Project single-file types (roadmap/capabilities/ops/marketing) and milestone do not apply this gate. -->

## Decision Rules

1. After inferring the document type, find the corresponding question group
2. Answer each question yes/no based on the conversation content
3. All yes → sufficient, create normally
4. Any no → prompt downgrade options
5. All no → reject creation

```
[write] sufficiency check: {type}
- ✅ {question that is satisfied}
- ❌ {question that is not satisfied} → suggested: {downgrade approach}
A) supplement information and recreate  B) downgrade to {downgrade target}
```

## Applicability

| Risk Level | Document Type | Check Required |
|------------|---------------|----------------|
| Highest | prd, tech | must check |
| High | arch, schema, decision, ui | must check |
| Low | roadmap, capabilities, ops, marketing, milestone | not checked |

## Question Groups

### prd

#### Q1: Can this requirement be described clearly independent of other requirements?

- **Decision**: the requirement has its own pain point and value, and is not a sub-feature of an existing requirement
- **no →**: merge into a new section of the existing prd
- ❌ "add a parameter to the learn pipeline" — this is a sub-feature of the learn prd
- ✅ "establish an automatic decay mechanism for knowledge entries" — an independent problem domain

#### Q2: Does the user's Before→After have a substantive behavior change?

- **Decision**: the user's operation or outcome has a perceivable change; not an internal refactor
- **no →**: downgrade to a milestone note in roadmap
- ❌ "swap JSONL for SQLite" — user behavior is unchanged; it is an internal refactor
- ✅ "after the change, one command verifies all features" — Before: manually test each one; After: verify in one click

#### Q3: Can ≥3 independently verifiable acceptance criteria be listed?

- **Decision**: from the conversation, ≥3 acceptance conditions in the form "user does X → should see Y" can be extracted
- **no →**: downgrade to a milestone note in roadmap
- ❌ only able to list "feature works correctly" — too vague, not independently verifiable
- ✅ "user submits the correct password → should redirect to home"; "submits the wrong password 5 times in a row → account should be locked for 15 minutes"; "submits the correct password during the lock window → should still be rejected"

### tech

#### Q1: Is the implementation approach non-obvious?

- **Decision**: would someone unfamiliar with the project consider different implementation alternatives
- **no →**: downgrade to a notes-column entry in the prd task tracking
- ❌ "add a --verbose flag to an existing command" — implementation is unique and obvious
- ✅ "design a knowledge-conflict detection mechanism" — has multiple alternatives (pure keyword / LLM semantic / hybrid)

#### Q2: Has at least one technical decision with trade-offs been made?

- **Decision**: a choice was made among ≥2 alternatives, with a stated reason for not picking the other
- **no →**: downgrade to a notes-column entry in the prd task tracking
- ❌ "wrote the script in bash" — no alternative comparison
- ✅ "chose JSONL over SQLite, because plain text can be tracked in git and has zero dependencies"

#### Q3: Does the core flow span collaboration across ≥2 files/modules?

- **Decision**: implementation involves collaboration across multiple files/modules, not modification within a single file
- **no →**: downgrade to a notes-column entry in the prd task tracking
- ❌ "add a stage in learn workflow" — single-file modification
- ✅ "the learn pipeline involves SKILL.md routing + workflows/learn.md flow + project CLAUDE.md write + tests/unit unit tests"

### arch

#### Q1: Does the module internally have ≥3 components with distinct responsibilities?

- **Decision**: is the module complex enough to be split into multiple sub-components with independent responsibilities
- **no →**: downgrade to tech §2 solution
- ❌ "a collection of utility functions" — no components needing distinction
- ✅ "know consists of routing layer, pipeline layer, CLI layer, and storage layer"

#### Q2: Is there a non-trivial data flow or dependency between components that needs to be explicitly managed?

- **Decision**: do components have non-trivial data-passing or call relationships between them
- **no →**: downgrade to tech §2 solution
- ❌ "several independent utility functions" — no inter-component interaction
- ✅ "SKILL.md routes to workflow → workflow chains stages in order → the final stage writes to CLAUDE.md ## know block"

### schema

#### Q1: Is there ≥1 interface that requires independently defined parameters/responses/error codes?

- **Decision**: are there structured inputs and outputs that need documentation
- **no →**: downgrade to tech §2 data model
- ❌ "a function that only accepts a string parameter" — no need for an independent interface definition
- ✅ "the payment-callback webhook accepts a complete JSON with 8 fields and 2 error codes"

#### Q2: Does the data model have ≥3 fields that require type and constraint documentation?

- **Decision**: is the data model complex enough to warrant an independent doc
- **no →**: downgrade to tech §2 data model
- ❌ "a simple object with only id and name" — 2 fields not worth it
- ✅ "the payment-callback request body has 8 fields with enum constraints and signature-validation rules"

### decision

#### Q1: Are there ≥2 alternatives worth comparing?

- **Decision**: are there real alternatives, with substantive differences between them
- **no →**: downgrade to a row in the tech §3 key-decisions table
- ❌ "JSON or YAML" — a simple preference, not worth an independent doc
- ✅ "JSONL vs SQLite vs Redis — each has different persistence/query/deployment trade-offs"

#### Q2: Does this decision impact span across modules/versions?

- **Decision**: does the impact of the decision exceed a single module or a single iteration
- **no →**: downgrade to a row in the tech §3 key-decisions table
- ❌ "which date format to choose" — narrow impact
- ✅ "storage-format selection" — affects all pipelines and future extensions

### ui

#### Q1: Is there a layout that can only be made clear by drawing it?

- **Decision**: is the layout impossible to describe accurately in words and must be visualized
- **no →**: downgrade to prd §4 Before→After
- ❌ "just one input box and one button" — words are sufficient
- ✅ "left-side navigation + right-side content + top search bar + bottom status bar, a four-region layout"

#### Q2: Does the user operation have branch paths?

- **Decision**: does the operation flow have conditional branches, rather than a linear single path
- **no →**: downgrade to prd §4 Before→After
- ❌ "click the button → show the result" — linear, no branches
- ✅ "search → with results: show the list / no results: show empty state + recommendations"
