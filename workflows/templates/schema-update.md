# Schema Spec Update Rules

## Change Types

| Type | Meaning |
|------|---------|
| **immutable** | Once written, never modified |
| **append-only** | Only new entries can be added; existing ones cannot be modified |
| **updatable** | Content can be modified, but with constraints |

## Overview

| Location | Field | Change Type |
|----------|-------|-------------|
| §1 Overview | Scope | immutable |
| | Caller | immutable |
| | Protocol Type | immutable |
| §2 Data Model | Whole row | append-only |
| | Description | updatable |
| §3 Interface Definitions | Whole interface | append-only |
| | Existing interface.Parameters | append-only (optional only) |
| | Existing interface.Error codes | append-only |
| §4 Constraints and Rules | Constraint entry | append-only |
| §5 Example | Request / Response | updatable |

## Field Change Rules

### §1 Overview

#### Scope / Caller / Protocol Type

- **Change Type**: immutable
- **Allowed**: —
- **Forbidden**: Modifying after the requirement is confirmed (an overview change implies a new set of interfaces; create a new schema document)
- **Trigger**: —
- **Check**: The diff must not contain changes to any §1 field
- ❌ Changing the protocol type from CLI to REST
- ✅ Creating a separate schema document to describe the new-protocol interfaces

### §2 Data Model

#### Whole row (new field)

- **Change Type**: append-only
- **Allowed**: Adding new field rows
- **Forbidden**: Deleting existing fields (breaking change); modifying the type / required-ness of an existing field
- **Trigger**: Interface extension requires a new field
- **Check**: New rows satisfy the checklist constraints (concrete type, required = yes/no)
- ❌ Deleting an existing field; changing the type of an existing field from string to int
- ✅ Adding a new optional field row

#### Description

- **Change Type**: updatable
- **Allowed**: Making the description more precise; adding boundary conditions
- **Forbidden**: Changing the field's semantics (a description change must not alter the caller's understanding)
- **Trigger**: The description is found to be unclear
- **Check**: The semantics are consistent before and after the update
- ❌ "User ID" → "Organization ID" (semantic change)
- ✅ "User ID" → "User unique identifier, UUID v4 format" (precision improvement)

### §3 Interface Definitions

#### Whole interface (new)

- **Change Type**: append-only
- **Allowed**: Adding a complete new interface definition (method + path + parameters + response + error codes)
- **Forbidden**: Deleting an existing interface (breaking change)
- **Trigger**: The product needs a new interface
- **Check**: The new interface satisfies all checklist constraints
- ❌ Deleting a deprecated interface
- ✅ Adding a complete new interface definition section

#### Existing interface.Parameters

- **Change Type**: append-only (optional only)
- **Allowed**: Adding new optional parameters (required = no)
- **Forbidden**: Adding required parameters (breaking change); deleting existing parameters; modifying the type of an existing parameter
- **Trigger**: Interface functional extension
- **Check**: New parameters have required = no
- ❌ Adding a required = yes parameter
- ✅ Adding a required = no filter parameter

#### Existing interface.Error codes

- **Change Type**: append-only
- **Allowed**: Adding new error-code rows
- **Forbidden**: Deleting existing error codes; modifying the meaning of an existing error code
- **Trigger**: A new error scenario is identified
- **Check**: New rows satisfy the format constraints
- ❌ Deleting an existing error code
- ✅ Adding "409 | resource conflict | use conditional update or retry"

### §4 Constraints and Rules

#### Constraint entry

- **Change Type**: append-only
- **Allowed**: Adding new constraint entries
- **Forbidden**: Deleting existing constraints; loosening existing constraints
- **Trigger**: A new boundary condition or compatibility requirement is identified
- **Check**: New entries are concrete and verifiable
- ❌ Deleting the rate-limiting constraint
- ✅ Adding "Single batch operation capped at 100 items"

### §5 Example

#### Request / Response

- **Change Type**: updatable
- **Allowed**: Updating the example to reflect the current interface state; adding new examples
- **Forbidden**: Examples contradict §2 / §3 definitions
- **Trigger**: The example needs to be synced after an interface change
- **Check**: The fields / types / error codes in the example match §2 / §3
- ❌ The example uses a field not present in §2
- ✅ After a new parameter is added, update the example to demonstrate the new parameter

## Operating Procedure

### Add a Field

1. §2 Append a new row to Data Model
2. §3 Append to the relevant interface's parameter table (if needed, optional only)
3. §5 Update the example to reflect the new field

### Add an Interface

1. §3 Add a complete new interface definition section
2. §4 Append related constraints (if needed)
3. §5 Add a request / response example for this interface

### Interface Extension (adding a parameter to an existing interface)

1. §3 Append an optional parameter to the existing interface's parameter table
2. §3 Append to the existing interface's error-code table (if needed)
3. §5 Update the example

## Validation Rules

1. **§1 Overview immutable** — The diff must not contain changes to Scope / Caller / Protocol Type
2. **Fields only grow** — §2 row count only grows; the type / required-ness of existing fields is immutable
3. **New parameters must be optional** — Parameters added to an existing interface in §3 have required = no
4. **Interfaces only grow** — §3 interface count only grows
5. **Constraints only grow** — §4 entry count only grows; existing constraints cannot be loosened
6. **Example consistent with definitions** — The fields / types / error codes in §5 match §2 / §3
