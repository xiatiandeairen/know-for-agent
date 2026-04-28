# {requirement name} Technical Solution

<!-- Core question: how is it implemented and how far has it gotten?
     Positioning: technical solution + implementation progress tracking (refined across multiple sprint iterations)
     Out of scope: product requirement (→ PRD), system architecture (→ arch), interface contract (→ schema)
     Structure locked: do not add or remove sections, do not change section names, do not change formatting. Only fill in values.
     Field spec: see templates/tech-checklist.md (each field's information purpose, language constraint, presentation, omission conditions, data requirements)
     Data confidence: when measured, use measured values and annotate source; derived values annotate "estimated" + basis; targets annotate "target value, pending validation"; values that cannot be estimated annotate "no data ({reason})". No fabrication of precise numbers. -->

## 1. Background

### Technical Constraints

<!-- ≥1 item. Hard limits affecting solution choice. One sentence each; subject is system/environment/platform; describe the constraint, not the requirement.
  - Format: unordered list, each item "{constraint subject}: {constraint content}"
  - EXCLUDE: product vision, user persona (→ PRD); business rules (→ PRD §4)
  - Forbidden: "needs X" / "requires Y" (those are requirements, not constraints); generic descriptions without a subject
  - ❌ "needs to support large files"
  - ✅ "Claude Code hook: stdout cap of 10KB per call, truncated above that"
  - ❌ "needs cross-platform compatibility"
  - ✅ "runtime environment: macOS/Linux shell; Windows compatibility is not guaranteed" -->

- {constraint subject}: {constraint content}

### Prerequisites

<!-- Tasks/modules/external conditions that must be completed first. One sentence each. Write "none" if no dependencies.
  - Format: unordered list, each item "{dependency} — {status: done|in progress|not started}"
  - EXCLUDE: technical constraints (placed above)
  - Forbidden: disguising technical constraints as dependencies; bare lists with no status annotation
  - ❌ "need to set up the framework first"
  - ✅ "learn workflow gate-stage definition — done"
  - ❌ "depends on a database"
  - ✅ "## know YAML block schema field alignment — in progress" -->

- {dependency} — {status}

## 2. Solution

<!-- High-level technical design, refined across sprints. Answers "how to implement".
     This section contains 3 sub-blocks: file/module structure (required), core flow (required), data model (optional).
     EXCLUDE: function signatures, algorithm pseudocode, complete interface definitions (→ schema) -->

### File/Module Structure

<!-- Required. Tree or table; annotate each item's responsibility (one sentence).
  - Format: tree (indented list) or table (file/module | responsibility)
  - Forbidden: listing only file names without responsibility; writing implementation details into responsibility descriptions
  - ❌ "workflows/learn.md" (no responsibility)
  - ✅ "workflows/learn.md — defines the learn pipeline flow, chained by the 5 stages in order"
  - ❌ "utils.sh — contains parse_json function, extracts the .name field via jq..." (implementation detail)
  - ✅ "utils.sh — common utility functions (JSON parsing, path handling)" -->

{tree or table}

### Core Flow

<!-- Required. The step sequence for the critical path.
  - Format: numbered step list "1. {action subject} → {action} → {output}", ≥3 steps
  - Forbidden: expanding implementation details for each step; replacing the step list with a natural-language paragraph
  - ❌ "first parse the args, then call the function to handle, finally output the result" (paragraph)
  - ✅ "1. SKILL.md parses subcommand → routes to workflow\n2. workflow executes each stage in order → produces intermediate results\n3. write to CLAUDE.md ## know block → persist to disk" -->

1. {action subject} → {action} → {output}
2. {action subject} → {action} → {output}
3. {action subject} → {action} → {output}

### Data Model

<!-- Optional. List only public, interface-level structure definitions. Omit the entire section when there are no public data structures.
  - Format: table "field | type | purpose", one row per field
  - Forbidden: internal private structures; runtime temporary variables
  - ❌ list local variables inside functions
  - ✅ "| id | string | unique entry identifier, UUID v4 |" -->

| Field | Type | Purpose |
|-------|------|---------|
| {field name} | {type} | {purpose} |

## 3. Key Decisions

<!-- Technical selections and rationale, accumulated after each sprint. Answers "why it is done this way".
  - ROWS: ≥1. Append-only; existing rows must not be modified.
  - Decision column: 1 sentence describing the decision point (❌ "storage" ✅ "knowledge-entry persistence format")
  - Choice column: the final choice (❌ "we used a better option" ✅ "JSONL file")
  - Why column: must include the rejected alternative and reason for rejection (❌ "good performance" ✅ "SQLite introduces a binary dependency; JSONL is plain text, can be tracked in git, and has zero dependencies")
  - Boundary: implementation-level selections go here; strategic/architectural decisions use the decision template
  - EXCLUDE: product-direction decisions -->

| Decision | Choice | Why |
|----------|--------|-----|
| {decision point} | {choice} | {reason, including rejected alternative: "X not chosen because Y"} |

## 4. Iteration Log

<!-- What was implemented in each sprint. Append-only; new entries go at the top; existing entries must not be modified.
  - Each entry: date heading (### YYYY-MM-DD) + content
  - Content format: unordered list, each item "{what was done} ({key change})"
  - Forbidden: bare content without a date; modifying historical entries; replacing the list with a paragraph
  - ❌ "did a lot of optimizations and improvements"
  - ✅ "- added unit tests for the learn gate stage (covers information-entropy / reuse / triggerability gates)"
  - ❌ "refactored the code"
  - ✅ "- refactored the learn flow (split detect → gate → refine into three stages; the original single step → 3 independent stages)" -->

### {YYYY-MM-DD}

- {what was done} ({key change})
