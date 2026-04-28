# UI Checklist

## Overview

| Location | Field | Omittable |
|----------|-------|-----------|
| §1 Layout | ASCII Sketch | No |
| | Region Description Table | No (≥1 row) |
| §2 Interaction Flow | Step | No (≥3 steps) |
| §3 States and Styles | Component-state Table | No (≥4 states per component) |

## Field Definitions

### §1 Layout

#### ASCII Sketch

- **Information**: Region layout of the page / module
- **Format**: ASCII diagram. Use characters such as `+--+` and `|  |` to draw region borders and nesting
- **Forbidden**: CSS code; descriptions of screenshots ("refer to the design mockup")
- **Omit**: No
- **Data**: —
- ❌ "Refer to the Figma mockup"
- ✅ `+--[header]--+ | [sidebar] | [main] | +--[footer]--+`

#### Region Description Table

- **Information**: What goes in each region and its priority
- **Format**: Table, ≥1 row. Columns: Region | Content | Priority. Region names match the ASCII sketch
- **Forbidden**: Region names inconsistent with the ASCII sketch
- **Omit**: No
- **Data**: —
- ❌ `| Top block | Some stuff | High |`
- ✅ `| header | Product logo + global navigation (home / docs / settings) | High |`

### §2 Interaction Flow

#### Step

- **Information**: The user's operation path on this page
- **Format**: Numbered list, ≥3 steps. Each step = "**Trigger:** {user action} → **Response:** {system feedback} → **Next:** {subsequent state}"
- **Forbidden**: Missing any of the three elements (trigger / response / next); backend-implementation descriptions
- **Omit**: No
- **Data**: —
- ❌ "1. User clicks the button 2. Result is displayed"
- ✅ "1. **Trigger:** user clicks the search button → **Response:** the result list expands below the input box and shows loading → **Next:** once results have loaded, the list shows the matching items"

### §3 States and Styles

#### Component-state Table

- **Information**: The visual presentation of the component in various states
- **Format**: One table per component. Columns: state | trigger | visual | timing. Each table has ≥4 rows and must cover hover / disabled / loading / error
- **Forbidden**: Missing any of hover / disabled / loading / error; CSS code
- **Omit**: No
- **Data**: —
- ❌ Listing only default and hover states
- ✅ Cover at least the four states hover / disabled / loading / error

## Diagram Checks

See `templates/diagram-checklist.md`. Diagram types applicable to ui: interaction flow diagram, layout sketch.

## Data Confidence Rules

Same as roadmap-checklist.md: measured > annotate source; estimated > annotate basis; target > "pending validation"; no data > annotate reason. No fabrication.
