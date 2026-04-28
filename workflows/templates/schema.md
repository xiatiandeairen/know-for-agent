# {{topic name}} Interface Specification

<!-- Data confidence: measured > annotate source > estimated > annotate basis > target > annotate "pending validation" > no data > annotate reason. No fabrication. -->
<!-- Structure locked: section order and field structure are immutable. Only fill content within the existing framework. -->

<!-- Core question: what is the interface contract and how is it called?
     Positioning: contract description
     Out of scope: internal implementation (→ tech), system architecture (→ arch) -->

## 1. Overview

<!-- The scope, callers, and protocol type of the interface. Answers "what this set of interfaces does, who uses it, and which protocol".
  - EXCLUDE: internal implementation details, storage solution (in tech) -->

### Scope

<!-- 1-2 sentences describing the business scenarios the interfaces cover -->

{{business scenarios covered by the interfaces}}

### Callers

<!-- List all callers -->

- {{caller 1}}
- {{caller 2}}

### Protocol Type

<!-- Enum: REST | gRPC | CLI | file -->

{{REST/gRPC/CLI/file}}

## 2. Data Model

<!-- Core data model. Answers "what the data looks like".
  - ROWS ≥3
  - Type must be concrete (❌ "any" ✅ "string" / "int" / "string[]")
  - Required: yes/no enum
  - EXCLUDE: database table schema, ORM mapping (in tech) -->

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| {{field}} | {{concrete type}} | {{yes/no}} | {{description}} |
| {{field}} | {{concrete type}} | {{yes/no}} | {{description}} |
| {{field}} | {{concrete type}} | {{yes/no}} | {{description}} |

## 3. Interface Definitions

<!-- For each interface: method + path + params + response + errors. Answers "how to call".
  - Error-code table ROWS ≥2
  - EXCLUDE: internal validation logic, middleware configuration -->

### {{interface name}}

- **Method**: {{GET/POST/PUT/DELETE/CLI command}}
- **Path**: {{/api/v1/resource or command syntax}}
- **Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| {{parameter}} | {{type}} | {{yes/no}} | {{description}} |

- **Response**:

```json
{{response structure}}
```

- **Error codes**:

| Error Code | Meaning | Handling Recommendation |
|------------|---------|--------------------------|
| {{error code}} | {{meaning}} | {{handling recommendation}} |
| {{error code}} | {{meaning}} | {{handling recommendation}} |

## 4. Constraints and Rules

<!-- Validation rules + boundary values + compatibility requirements. Answers "what limits exist".
  - ROWS ≥2
  - EXCLUDE: implementation-level performance optimization strategies -->

- {{constraint rule 1}}
- {{constraint rule 2}}

## 5. Example

<!-- Typical call + expected response. Answers "what it looks like in actual use".
  - ≥1 complete request/response example
  - EXCLUDE: test-case code -->

**Request:**

```
{{complete request example}}
```

**Response:**

```
{{complete response example}}
```
