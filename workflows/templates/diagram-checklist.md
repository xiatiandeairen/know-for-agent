# Diagram Checklist

<!-- Shared resource. Referenced by the checklist and validate steps for tech / arch / schema / ui.
     write pipeline Step 5.5 Validate checks each trigger condition one by one. -->

## Trigger Rules

Check each item one by one. When the trigger condition is met → the document must include the corresponding diagram. When not met → skip.

### Data Flow Diagram

- **when**: ≥2 components exchange data
- **action**: ASCII flow diagram, annotating data format and direction
- **Applicability**: tech, arch
- **Format**: `Component A --{data format}--> Component B`, one flow per line
- **Forbidden**: Bare arrows without annotations; omitting the data format
- ❌ `A --> B`
- ✅ `learn workflow --YAML block--> project CLAUDE.md --nested loading--> Claude Code context`

### Dependency Diagram

- **when**: ≥3 modules with dependency relationships
- **action**: ASCII dependency topology, annotating strong/weak dependencies
- **Applicability**: arch
- **Format**: `Module A ==(strong)==> Module B` or `Module A --(weak)--> Module B`
- **Forbidden**: Not distinguishing strong from weak dependencies; not annotating circular dependencies
- ❌ `A -> B -> C`
- ✅ `SKILL.md ==(strong)==> workflows/learn.md --(weak)--> docs/templates/`

### Sequence Diagram

- **when**: Asynchronous interaction exists, or a cross-component call chain has ≥3 steps
- **action**: ASCII sequence diagram, annotating caller → callee → return
- **Applicability**: tech, schema
- **Format**: Vertical time axis, each line `caller -> callee: {action}` or `callee --> caller: {return}`
- **Forbidden**: Omitting return values; not annotating async/sync
- ❌ Drawing only the call without the return
- ✅
```
User -> CLI: /know learn
CLI -> learn workflow: start the 5-stage pipeline
learn workflow --> CLI: "Persisted: {summary}"
CLI --> User: [persisted] {summary}
```

### State Diagram

- **when**: A lifecycle or state machine exists (≥3 states)
- **action**: ASCII state-transition diagram, annotating trigger conditions
- **Applicability**: tech
- **Format**: `State A --{trigger condition}--> State B`, one transition per line
- **Forbidden**: Omitting trigger conditions; missing terminal states
- ❌ `created -> running -> done`
- ✅ `created --activate--> running --end--> completed` / `running --cancel--> cancelled`

### ER / Data Model Diagram

- **when**: ≥3 related entities, or ≥2 tables/structures with associations
- **action**: ASCII entity-relationship diagram, annotating relationship type and cardinality
- **Applicability**: tech, schema
- **Format**: `Entity A }|--|| Entity B : {relationship description}` or simplified `Entity A 1--N Entity B`
- **Forbidden**: Not annotating cardinality (1:1/1:N/N:M); missing key foreign keys
- ❌ `User - Order`
- ✅ `User 1--N Order : places` / `Order N--N Product : contains`

### Module Structure Diagram

- **when**: ≥3 sub-modules / layers
- **action**: ASCII tree or layered diagram, annotating responsibility boundaries
- **Applicability**: arch
- **Format**: Tree indentation, each item attached with a one-sentence responsibility
- **Forbidden**: Listing names only without responsibilities
- ❌
```
know/
  skills/
  workflows/
```
- ✅
```
know/
  skills/          # Skill entry point
    know/SKILL.md  # Routing + conventions (minimal resident context)
  workflows/       # Pipeline flow definitions
    learn.md       # Knowledge-write 5-stage pipeline
    write.md       # Document-authoring 5-stage pipeline
```

### Interaction Flow Diagram

- **when**: User operations have branching paths (≥2 branches)
- **action**: ASCII flow diagram, annotating trigger → response → branches
- **Applicability**: ui
- **Format**: Each step `[trigger] → {response} → [next step | branch A / branch B]`
- **Forbidden**: Omitting branch conditions; drawing only the main path without exception paths

### Layout Sketch

- **when**: A page / interface design exists
- **action**: ASCII region-partition diagram
- **Applicability**: ui
- **Format**: Use `+---+` borders to partition regions; each region annotated with a name and priority
- **Forbidden**: Replacing the sketch with a textual description

## Validation Rules

Step 5.5 Validate checks:

1. **Per-trigger check** — iterate over all diagram types; whichever satisfies its when condition must have a corresponding diagram
2. **Diagrams have annotations** — every line / arrow / node in each diagram has a textual annotation
3. **Diagram-text consistency** — component / entity names in the diagram match the descriptions in the body
4. **Missing report** — when a trigger is satisfied but no diagram exists → report the omission and require either supplementing it or annotating "to be supplemented (reason)"
