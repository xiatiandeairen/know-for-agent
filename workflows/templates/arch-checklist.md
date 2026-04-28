# Architecture Document Checklist

## Overview

| Location | Field | Omittable |
|----------|-------|-----------|
| §1 Positioning and Boundaries | Responsibility | No |
| | Out of Scope | No (≥2 items) |
| §2 Structure and Interaction | Component Diagram | No |
| | Component Table | No (≥2 rows) |
| | Data Flow Diagram | No when ≥2 components exchange data |
| | Data Flow Table | Follows the data flow diagram |
| §3 Design Decisions | Driving Factors | No (≥2 rows) |
| | Key Choices | No (≥1 row) |
| | Constraints | No (≥2 items) |
| §4 Quality Requirements | Quality Table | No (≥2 rows) |

## Field Definitions

### §1 Positioning and Boundaries

#### Responsibility

- **Information**: The module's core responsibility
- **Format**: 1-2 sentences. "Responsible for {what it does}, providing {what capability} to {whom}"
- **Forbidden**: Feature lists; implementation details; enumeration of command/function names
- **Omit**: No
- **Data**: —
- ❌ "Responsible for steps such as detect, gate, refine, locate, write"
- ✅ "Responsible for converting conversation signals into compliant ## know YAML blocks, providing the learn pipeline with the conversion capability from raw claim to persisted entry"

#### Out of Scope

- **Information**: Explicitly excluded responsibilities to prevent boundary creep
- **Format**: List, ≥2 items. Each item "{what is not done} (→ {who is responsible})"
- **Forbidden**: Exclusions without a pointer (not stating who is responsible)
- **Omit**: No
- **Data**: —
- ❌ "Not responsible for the frontend"
- ✅ "Not responsible for knowledge extraction logic (→ learn.md workflow)"

### §2 Structure and Interaction

#### Component Diagram

- **Information**: Visualization of the relationships among the module's internal components
- **Format**: ASCII diagram, boxes + arrows, with each component annotated by a one-sentence responsibility
- **Forbidden**: Plain text replacing the diagram; Mermaid/PlantUML; omitting responsibility annotations
- **Omit**: No
- **Data**: —
- ❌ "Component A calls component B, component B calls component C"
- ✅ `[CLI entry point] --> [command router] --> [subcommand handler]` (with responsibility annotations)

#### Component Table.Responsibility

- **Information**: What the component does
- **Format**: ≤1 sentence, the subject is the component
- **Forbidden**: Multiple sentences; function-level descriptions
- **Omit**: No (≥2 rows)
- **Data**: —
- ❌ "Responsible for parsing input, validating arguments, routing requests, logging, and other tasks"
- ✅ "Parses user input and routes it to the corresponding handler"

#### Component Table.Boundary Rules

- **Information**: The component's access/invocation constraints
- **Format**: "Forbidden X" or "Must Y", multiple items separated by semicolons
- **Forbidden**: Vague words such as "try to" or "recommended"
- **Omit**: No
- **Data**: —
- ❌ "Pay attention to security"
- ✅ "Forbidden to access the storage layer directly; must query through the index"

#### Data Flow Diagram

- **Information**: Visualization of data exchange among components
- **Format**: ASCII diagram, annotating data format and direction
- **Forbidden**: Bare arrows without annotations
- **Omit**: May be omitted when fewer than 2 components exchange data
- **Data**: —
- ❌ `A --> B`
- ✅ `learn workflow --YAML block--> project CLAUDE.md --nested loading--> Claude Code context`

#### Data Flow Table.Type

- **Information**: Strength of the dependency
- **Format**: Enum: strong (unusable when missing) / weak (degrades gracefully when missing)
- **Forbidden**: Values outside the enum
- **Omit**: No
- **Data**: —

#### Data Flow Table.Description

- **Information**: The specific content being transferred
- **Format**: 1 sentence
- **Forbidden**: "Has data transfer"; interface signatures
- **Omit**: No
- **Data**: —

### §3 Design Decisions

#### Driving Factors.Factor

- **Information**: What drove the architectural design
- **Format**: 1 sentence. A specific business requirement / technical constraint / quality requirement
- **Forbidden**: "Very important", "needs to be considered"
- **Omit**: No (≥2 rows)
- **Data**: Use quantification when available
- ❌ "Performance is very important"
- ✅ "The Claude Code plugin does not support persistent processes"

#### Driving Factors.Type

- **Information**: Category of the factor
- **Format**: Enum: business requirement / technical constraint / quality requirement
- **Forbidden**: Values outside the enum
- **Omit**: No
- **Data**: —

#### Driving Factors.Impact

- **Information**: The concrete impact on the architecture
- **Format**: 1 sentence, an architecture-level constraint or decision
- **Forbidden**: "Needs to be considered"; code-level descriptions
- **Omit**: No
- **Data**: —
- ❌ "The architecture needs to take this into account"
- ✅ "All state must be persisted to files; cannot rely on memory"

#### Key Choices.Decision

- **Information**: An architecture-level selection point
- **Format**: 1 sentence describing the decision question
- **Forbidden**: Code-level selection (→ tech)
- **Omit**: No (≥1 row)
- **Data**: —

#### Key Choices.Rejected Alternative

- **Information**: Alternatives considered but not chosen
- **Format**: Specific alternative name
- **Forbidden**: Omitting the rejected alternative
- **Omit**: No
- **Data**: —

#### Key Choices.Why

- **Information**: Reason for the choice + reason for rejection
- **Format**: Includes both the reason for the choice and the reason for rejection
- **Forbidden**: "Better", "more suitable"
- **Omit**: No
- **Data**: —
- ❌ "Better"
- ✅ "SQLite requires compilation dependencies; JSONL is plain text and can be grepped directly, with zero deployment dependencies"

#### Constraints

- **Information**: Hard constraints that must be obeyed
- **Format**: "Forbidden X (reason)" or "Must Y (reason)", ≥2 items
- **Forbidden**: Bare constraints without reasons; coding conventions; design preferences
- **Omit**: No
- **Data**: —
- ❌ "Cannot use a database"
- ✅ "Forbidden to introduce external database dependencies (the deployment environment is a pure file system, no database service)"

### §4 Quality Requirements

#### Attribute / Metric

- **Information**: Quality dimensions and measurable metrics
- **Format**: Attribute name + measurable metric name
- **Forbidden**: "Good performance", "low latency"
- **Omit**: No (≥2 rows)
- **Data**: —
- ❌ "Performance behavior"
- ✅ "End-to-end latency of a single learn pipeline run"

#### Target

- **Information**: Quantified target value
- **Format**: Must include a number, e.g. "<200ms" or ">=99.5%"
- **Forbidden**: "As fast as possible", "the lower the better"
- **Omit**: No
- **Data**: When measured, annotate the source; when not measured, mark "target value, pending validation"
- ❌ "As fast as possible"
- ✅ "<200ms (p95)"

## Diagram Checks

See `templates/diagram-checklist.md`. Diagram types applicable to arch: data flow diagram, dependency diagram, module structure diagram.

## Data Confidence Rules

Same as roadmap-checklist.md: measured > annotate source; estimated > annotate basis; target > "pending validation"; no data > annotate reason. No fabrication.
