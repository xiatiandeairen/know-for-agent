# {module name} Architecture Design

<!-- Core question: How is this module decomposed, how do its parts collaborate, and why is it designed this way?
     Positioning: architecture description for a single module (one file per module)
     Out of scope: module-internal implementation (→ tech), interface signatures (→ schema), product requirements (→ prd)
     Field spec: see templates/arch-checklist.md
     Change rules: see templates/arch-update.md
     Data confidence: measured values annotate source; derived values annotate "estimated" + basis; targets annotate "target value, pending validation"; values that cannot be estimated annotate "no data ({reason})". No fabrication.
     Structure locked: do not add or remove sections. Only fill in values. -->

## 1. Positioning and Boundaries

<!-- What this module is and is not. Answers "where is the boundary". -->

### Responsibility

<!-- The module's core responsibility.
  - Format: 1-2 sentences. "Responsible for {what}, providing {capability} to {whom}"
  - Forbidden: feature lists; implementation details
  - ❌ "Responsible for detect, gate, refine, locate, write, validate, prepend, normalize, etc."
  - ✅ "Responsible for transforming conversation signals into compliant ## know YAML blocks, providing the learn pipeline with the conversion capability from raw claim to persisted entry" -->

{module responsibility}

### Out of Scope

<!-- Explicitly excluded responsibilities, to prevent boundary creep.
  - Format: list, ≥2 items. Each item "{what is not done} (→ {who is responsible})"
  - Forbidden: exclusions without a pointer
  - ❌ "Not responsible for the frontend"
  - ✅ "Not responsible for knowledge extraction logic (→ learn.md workflow)" -->

- {what is not done} (→ {who is responsible})

## 2. Structure and Interaction

<!-- How the module is decomposed internally and how its parts collaborate. Answers "what it looks like and how it runs". -->

### Component Diagram

<!-- A visualization of the relationships among internal components.
  - Format: ASCII diagram, using boxes and arrows. Annotate each component with a one-sentence responsibility.
  - Forbidden: pure-text replacement of the diagram; Mermaid/PlantUML; omitting per-component responsibility annotations
  - ❌ "Component A calls component B"
  - ✅
    ```
    [CLI entry point] --> [command router] --> [subcommand handler]
         parse args         dispatch              execute operation
    ``` -->

```
{ASCII component diagram}
```

### Component Table

<!-- The responsibility and boundary rule for each component.
  - ROWS: ≥2
  - Component: name matches the component diagram
  - Responsibility: ≤1 sentence. Subject is the component.
  - Boundary rule: "forbidden X" or "must Y" format. Multiple rules separated by semicolons.
  - Forbidden: multi-sentence responsibility; function-level descriptions; "try to" / "suggested"
  - ❌ Responsibility: "responsible for many things" / Boundary: "watch out for security"
  - ✅ Responsibility: "parses user input and routes to the corresponding handler" / Boundary: "forbidden to access the storage layer directly; must query through the index" -->

| Component | Responsibility | Boundary Rule |
|-----------|----------------|---------------|
| {component name} | {≤1-sentence responsibility} | {forbidden X; must Y} |

### Data Flow

<!-- The data-passing relationships among components.
  - Format: ASCII data-flow diagram + data-flow table
  - Diagram: annotate data format and direction
  - ROWS: ≥1
  - Type: enum strong (degrades gracefully when missing) / weak (degrades gracefully when missing)
  - Forbidden: bare arrows without annotation; omitting data format
  - ❌ "A --> B"
  - ✅ "learn workflow --YAML block--> project CLAUDE.md --nested loading--> Claude Code context" -->

```
{ASCII data-flow diagram}
```

| Source | Target | Data Format | Type | Description |
|--------|--------|-------------|------|-------------|
| {source component} | {target component} | {format} | {strong/weak} | {1-sentence description} |

## 3. Design Decisions

<!-- Why it is designed this way. Answers "why this decomposition, why this choice". -->

### Driving Factors

<!-- The core factors driving the architecture design.
  - Format: table, ≥2 rows. Factor + impact on the architecture.
  - Factor types: business requirement / technical constraint / quality requirement
  - Forbidden: "very important" / "needs to be considered"
  - ❌ Factor: "performance is important" / Impact: "performance must be considered"
  - ✅ Factor: "Claude Code plugin does not support persistent processes" / Impact: "all state must be persisted to files" -->

| Factor | Type | Impact on Architecture |
|--------|------|------------------------|
| {specific factor} | {business requirement/technical constraint/quality requirement} | {architectural-level constraint or decision} |

### Key Choices

<!-- Architecture-level selections and trade-offs.
  - Format: table, ≥1 row. Each row contains the rejected alternative and the reason for rejection.
  - Forbidden: stating only what was chosen without why; code-level selections (→ tech)
  - ❌ Why: "it is better"
  - ✅ Why: "SQLite needs compiled dependencies; JSONL is plain text and can be grepped directly, with zero deployment dependencies" -->

| Decision | Choice | Rejected Alternative | Why |
|----------|--------|----------------------|-----|
| {architecture decision point} | {final choice} | {rejected alternative} | {reason for choice + reason for rejection} |

### Constraints

<!-- Hard constraints that must be obeyed.
  - Format: list, ≥2 items. "forbidden X ({reason})" or "must Y ({reason})"
  - Forbidden: bare constraints without reason; coding conventions; design preferences
  - ❌ "Cannot use a database"
  - ✅ "Forbidden to introduce an external database dependency (deployment environment is a pure filesystem with no database service)" -->

- {forbidden/must} ({reason})

## 4. Quality Requirements

<!-- What standards must be met. Answers "how to measure whether the architecture is acceptable".
  - Format: table, ≥2 rows. Metrics must be quantifiable.
  - Forbidden: "good performance" / "low latency"; targets without numbers
  - Data: measured values annotate source; without measured data annotate "target value, pending validation"
  - ❌ Target: "as fast as possible"
  - ✅ Target: "<200ms (p95)" -->

| Attribute | Metric | Target |
|-----------|--------|--------|
| {quality attribute} | {measurable metric} | {target value with numbers} |
