# Capability Inventory Checklist

## Overview

| Location | Field | Omittable |
|----------|-------|-----------|
| §1 Capability Inventory | Capability | No (≥3 rows) |
| | Description | No |
| | Status | No |
| | Version | No |
| §2 Coverage | Known Limitations | No (≥2 items) |
| | Uncovered Scenarios | No (≥2 items) |

## Field Definitions

### §1 Capability Inventory

#### Capability

- **Information**: The user-perceivable capability name
- **Format**: An action/feature name from the user's perspective, not an internal module name
- **Forbidden**: Internal module names ("data processing module"); piling up technical terminology; implementation details
- **Omit**: No
- **Data**: —
- ❌ "Data processing module"
- ✅ "Bulk data import"

#### Description

- **Information**: What this capability does
- **Format**: 1 sentence, from the user's perspective, describing the effect the capability provides
- **Forbidden**: Technical implementation descriptions; multiple sentences; internal architecture terminology
- **Omit**: No
- **Data**: —
- ❌ "Incrementally processes JSON data via a streaming parser"
- ✅ "Upload a CSV/JSON file and it is automatically parsed and written into the project"

#### Status

- **Information**: The current availability of this capability
- **Format**: Enum: available | experimental | planned
- **Forbidden**: Custom status values ("in development", "in testing", "beta")
- **Omit**: No
- **Data**: —
- ❌ "In beta testing"
- ✅ "experimental"

#### Version

- **Information**: The version this capability belongs to
- **Format**: v{n}, where n is a positive integer
- **Forbidden**: Version numbers without the v prefix; semantic version numbers (v1.2.3)
- **Omit**: No
- **Data**: —
- ❌ "1.0" / "v1.2.3"
- ✅ "v1"

### §2 Coverage

#### Known Limitations

- **Information**: Known boundaries of the product capability
- **Format**: "{limitation} ({impact})", ≥2 items
- **Forbidden**: Bare limitations without impact descriptions; technical-debt descriptions
- **Omit**: No
- **Data**: —
- ❌ "Concurrency not supported"
- ✅ "Single-import limit of 1000 rows (larger inputs require batching)"

#### Uncovered Scenarios

- **Information**: Use cases the product explicitly does not cover
- **Format**: "{scenario} ({reason})", ≥2 items
- **Forbidden**: Bare scenarios without reasons; future plans (→ roadmap)
- **Omit**: No
- **Data**: —
- ❌ "Multi-tenant"
- ✅ "Cross-organization data sharing (current architecture is single-tenant by design)"

## Data Confidence Rules

Measured > annotate source; estimated > annotate basis; target > "pending validation"; no data > annotate reason. No fabrication.
