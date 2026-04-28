# {{project name}} Capability Overview

<!-- Data confidence: measured > annotate source > estimated > annotate basis > target > annotate "pending validation" > no data > annotate reason. No fabrication. -->
<!-- Structure locked: section order and field structure are immutable. Only fill content within the existing framework. -->

<!-- Core question: what can the product do right now?
     Positioning: a snapshot of the cross-version capability inventory
     Out of scope: version planning (→ roadmap), individual requirement details (→ prd), technical solution (→ tech) -->

## 1. Capability Inventory

<!-- All user-perceivable capabilities. Answers "what it can do".
  - One capability per row, ROWS ≥3
  - Capability: a user-perspective capability name. ❌ "data processing module" ✅ "bulk data import"
  - Description: one sentence from the user's perspective
  - Status: available | experimental | planned (enum, not customizable)
  - Version: v{n} format
  - EXCLUDE: internal implementation details, technical architecture, command parameters, module names -->

| Capability | Description | Status | Version |
|------------|-------------|--------|---------|
| **{{capability name}}** | {{one-sentence user-perspective description}} | {{available/experimental/planned}} | v{{n}} |
| **{{capability name}}** | {{one-sentence user-perspective description}} | {{available/experimental/planned}} | v{{n}} |
| **{{capability name}}** | {{one-sentence user-perspective description}} | {{available/experimental/planned}} | v{{n}} |

## 2. Coverage

<!-- Product boundaries. Answers "what cannot be done".
  - EXCLUDE: schedule and roadmap (→ roadmap) -->

### Known Limitations

<!-- ≥2 items, format: "{limitation} ({impact})" -->

- {{limitation}} ({{impact}})
- {{limitation}} ({{impact}})

### Uncovered Scenarios

<!-- ≥2 items, format: "{scenario} ({reason})" -->

- {{scenario}} ({{reason}})
- {{scenario}} ({{reason}})
