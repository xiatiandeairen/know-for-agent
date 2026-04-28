# {{page/module name}} Interaction Design

<!-- Core question: what does this page look like and how is it operated?
     Positioning: interaction description for a single page/module (one file per page)
     Out of scope: product requirement (→ prd), technical implementation (→ tech), system architecture (→ arch) -->

## 1. Layout

<!-- Region arrangement. Answers "what it looks like".
  - INCLUDE: ASCII sketch + region description table, information hierarchy, visual emphasis
  - Reference component names from the project glossary
  - EXCLUDE: CSS implementation, component API (→ tech) -->

```
{{ASCII layout sketch}}
```

| Region | Content | Priority |
|--------|---------|----------|
| {{region name}} | {{region content description}} | {{priority}} |

## 2. Interaction Flow

<!-- Operation paths within this page. Answers "how the user operates".
  - Each step = trigger → response → next step
  - INCLUDE: operation steps, branch paths, trigger mechanism, response behavior, transition effects
  - EXCLUDE: backend processing logic, data flow (→ tech) -->

1. **Trigger:** {{user action}} → **Response:** {{system feedback}} → **Next step:** {{subsequent state}}
2. **Trigger:** {{user action}} → **Response:** {{system feedback}} → **Next step:** {{subsequent state}}
3. **Trigger:** {{user action}} → **Response:** {{system feedback}} → **Next step:** {{subsequent state}}

## 3. States and Styles

<!-- Visual presentation of each component state. Answers "what it looks like under various conditions".
  - Group by component; each component has a state table
  - Columns: state / trigger / visual / timing
  - Must cover: hover, disabled, loading, error (at least 4 states)
  - EXCLUDE: event-handling code, state-management implementation (→ tech) -->

### {{component name}}

| state | trigger | visual | timing |
|-------|---------|--------|--------|
| hover | {{trigger mechanism}} | {{visual presentation}} | {{timing/animation}} |
| disabled | {{trigger mechanism}} | {{visual presentation}} | {{timing/animation}} |
| loading | {{trigger mechanism}} | {{visual presentation}} | {{timing/animation}} |
| error | {{trigger mechanism}} | {{visual presentation}} | {{timing/animation}} |
