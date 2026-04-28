# Tech Checklist

## Overview

| Location | Field | Omittable |
|----------|-------|-----------|
| §1 Background | Technical Constraints | No (≥1 item) |
| | Prerequisites | No (write "none" when no dependencies) |
| §2 Solution | File / Module Structure | No |
| | Core Flow | No (≥3 steps) |
| | Data Structure | May be omitted (when no public structure) |
| §3 Key Decisions | Decision Row | No (≥1 row) |
| §4 Iteration Log | Iteration Item | No (≥1 item) |

## Field Definitions

### §1 Background

#### Technical Constraints

- **Information**: Hard limits that affect solution choice
- **Format**: Unordered list, each item "{constraint subject}: {constraint content}", ≥1 item
- **Forbidden**: "Need X", "require Y" (those are requirements, not constraints); subject-less generic descriptions; product vision / user persona
- **Omit**: No
- **Data**: —
- ❌ "Need to support large files"
- ✅ "Claude Code hook: single stdout limit 10KB, truncated when exceeded"

#### Prerequisites

- **Information**: Tasks / modules / external conditions that must be completed first
- **Format**: Unordered list, each item "{dependency} — {status: completed | in progress | not started}". When there are no dependencies, write "none"
- **Forbidden**: Disguising technical constraints as dependencies; bare lists without status annotations
- **Omit**: No (write "none" when no dependencies)
- **Data**: —
- ❌ "Need to set up the framework first"
- ✅ "learn workflow gate stage definitions — completed"

### §2 Solution

#### File / Module Structure

- **Information**: The files / modules involved in the implementation and their respective responsibilities
- **Format**: Tree (indented list) or table (file/module | responsibility); each item annotated with a one-sentence responsibility
- **Forbidden**: Listing only file names without responsibilities; embedding implementation details (function names, algorithms) into the responsibility description
- **Omit**: No
- **Data**: —
- ❌ "workflows/learn.md" (no responsibility)
- ✅ "workflows/learn.md — learn pipeline flow definition; chains the 5 stages in order"

#### Core Flow

- **Information**: The execution order of the critical path
- **Format**: Numbered step list "{action subject} → {action} → {output}", ≥3 steps
- **Forbidden**: Expanding implementation details for each step; using natural-language paragraphs in place of a step list
- **Omit**: No
- **Data**: —
- ❌ "First parse the arguments, then call a function to process, finally output the result"
- ✅ "1. SKILL.md parses the subcommand → routes to the workflow\n2. workflow executes each stage sequentially → produces intermediate results\n3. Write to CLAUDE.md ## know block → persist to disk"

#### Data Structure

- **Information**: Data-structure definitions at the public-interface level
- **Format**: Table "Field | Type | Purpose", one field per row
- **Forbidden**: Internal private structures; runtime temporary variables; function-local variables
- **Omit**: May be omitted (when no public data structure, omit the entire section)
- **Data**: —
- ❌ Listing a function-internal `local tmp_file` variable
- ✅ "| id | string | unique entry identifier, UUID v4 |"

### §3 Key Decisions

#### Decision Row

- **Information**: Technical-selection points, the chosen option, and the reason for the choice
- **Format**: Table row "Decision | Choice | Why", ≥1 row. The Why column must include the rejected alternatives and the rejection reasons
- **Forbidden**: The Why column missing rejected alternatives; decision descriptions that are too generic ("storage" → should be "knowledge-entry persistence format"); product-direction decisions
- **Omit**: No
- **Data**: —
- ❌ "| Storage | JSONL | Good performance |"
- ✅ "| Knowledge-entry persistence format | JSONL | SQLite introduces a binary dependency; JSONL is plain text, can be tracked by git, and has no dependencies |"

### §4 Iteration Log

#### Iteration Item

- **Information**: What each sprint implemented
- **Format**: Date heading (### YYYY-MM-DD) + unordered list, each item "{what was done} ({key change})". Newest first, ≥1 item
- **Forbidden**: Bare content without a date; using paragraphs in place of a list; modifying existing items
- **Omit**: No
- **Data**: —
- ❌ "Did a lot of optimizations and improvements"
- ✅ "### 2026-04-15\n- Added unit tests for the learn gate stage (covering the information-entropy / reuse / triggerability gates)"

## Diagram Checks

See `templates/diagram-checklist.md`. Diagram types applicable to tech: data flow diagram, sequence diagram, state diagram, ER / data model diagram.

## Data Confidence Rules

Same as roadmap-checklist.md: measured > annotate source; estimated > annotate basis; target > "pending validation"; no data > annotate reason. No fabrication.
