# Interface Specification Checklist

## Overview

| Location | Field | Omittable |
|----------|-------|-----------|
| §1 Overview | Scope | No |
| | Caller | No |
| | Protocol Type | No |
| §2 Data Model | Field Table | No (≥3 rows) |
| §3 Interface Definitions | Interface | No (≥1 interface) |
| | Error-code Table | No (≥2 rows per interface) |
| §4 Constraints and Rules | Constraint Item | No (≥2 items) |
| §5 Example | Request / Response | No (≥1 group) |

## Field Definitions

### §1 Overview

#### Scope

- **Information**: The business scenarios this interface set covers
- **Format**: 1-2 sentences explaining what business this interface set serves
- **Forbidden**: Implementation descriptions; internal-architecture terminology; more than 2 sentences
- **Omit**: No
- **Data**: —
- ❌ "Provides a CQRS interface layer based on event-sourcing"
- ✅ "Provides CRUD operations on documents for the project knowledge base"

#### Caller

- **Information**: Who calls this interface set
- **Format**: List, each item is a specific caller role / system
- **Forbidden**: Unqualified descriptions such as "everyone" or "any system"
- **Omit**: No
- **Data**: —
- ❌ "All services"
- ✅ "Payment gateway (via webhook HTTP callback)"

#### Protocol Type

- **Information**: The interface communication protocol
- **Format**: Enum: REST | gRPC | CLI | file
- **Forbidden**: Custom protocol names; mixing multiple protocols (split into multiple schema documents)
- **Omit**: No
- **Data**: —
- ❌ "HTTP + WebSocket"
- ✅ "CLI"

### §2 Data Model

#### Field Table

- **Information**: Field definitions of the core data model
- **Format**: Table, each row Field | Type | Required | Description. ≥3 rows
- **Forbidden**: Vague types such as "any" / "object" / "mixed"; non-enum values in the Required column
- **Omit**: No
- **Data**: —
- ❌ Type "any", Required "optional"
- ✅ Type "string", Required "no"

### §3 Interface Definitions

#### Interface

- **Information**: The full signature of each interface
- **Format**: Each interface includes method + path + parameter table + response structure + error-code table. ≥1 interface
- **Forbidden**: Stating the method without the parameters; listing only interface names without definitions; error-code table with <2 rows
- **Omit**: No
- **Data**: —
- ❌ "POST /api/docs — create document" (no parameters, no response, no error codes)
- ✅ Full method + path + parameter table + response JSON + error-code table

#### Error-code Table

- **Information**: Errors this interface may return
- **Format**: Table, each row Error code | Meaning | Handling Suggestion. ≥2 rows per interface
- **Forbidden**: Listing the code without a handling suggestion; not listing common errors
- **Omit**: No
- **Data**: —
- ❌ "400 — parameter error" (no handling suggestion)
- ✅ "400 | required parameter missing | check whether the request body contains the name field"

### §4 Constraints and Rules

#### Constraint Item

- **Information**: Validation rules, boundary values, and compatibility requirements for the interface
- **Format**: List, ≥2 items. Each item describes a specific constraint
- **Forbidden**: Implementation-level performance-optimization strategies; vague descriptions ("within a reasonable range")
- **Omit**: No
- **Data**: —
- ❌ "Parameters must be within a reasonable range"
- ✅ "name field length 1-256 characters; only letters, digits, and hyphens allowed"

### §5 Example

#### Request / Response

- **Information**: A complete example of a typical call
- **Format**: ≥1 group of complete request + response code blocks
- **Forbidden**: Stating the request without the response; using ellipses in place of actual content; test-case code
- **Omit**: No
- **Data**: —
- ❌ Only the request, no response
- ✅ Complete request code block + corresponding response code block

## Diagram Checks

See `templates/diagram-checklist.md`. Diagram types applicable to schema: sequence diagram, ER / data model diagram.

## Data Confidence Rules

Measured > annotate source; estimated > annotate basis; target > "pending validation"; no data > annotate reason. No fabrication.
