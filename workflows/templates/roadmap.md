# {project name} Product Roadmap

<!-- Core question: where does the product stand and where is it heading next?
     Positioning: product-level strategy doc + progress tracking
     Out of scope: details of a single requirement (→ PRD), technical solution (→ tech), system architecture (→ arch)
     Structure locked: do not add or remove columns, do not change column names, do not change formatting. Only fill in values.
     Field spec: see templates/roadmap-checklist.md (each field's information purpose, language constraint, presentation, omission conditions, data requirements)
     Data confidence: when measured, use measured values and annotate source; derived values annotate "estimated" + basis; targets annotate "target value, pending validation"; values that cannot be estimated annotate "no data ({reason})". No fabrication of precise numbers. -->

## 1. Product Vision

### Product Essence

<!-- 3 fixed fields, presented as a list. 1-2 sentences each.
  - Positioning: what the product is, defined in one sentence (❌ "a knowledge management tool" ✅ "a project-knowledge compiler for AI coding assistants")
  - Motivation: why this product exists, the triggering driver (❌ "the market needs it" ✅ "AI agents lose implicit knowledge across sessions, leading to repeated mistakes; existing solutions cannot manage knowledge in layers")
  - Long-term vision: the terminal state once the product matures (❌ "to become the best tool" ✅ "AI agents work in a project like an experienced team member: aware of history, respectful of constraints, and not repeating the same mistakes")
  - EXCLUDE: feature lists, technical implementation, version plan -->

- **Positioning**: {what the product is, defined in one sentence}
- **Motivation**: {why this product exists, core triggering driver}
- **Long-term vision**: {description of the terminal state once the product matures}

### Value System

<!-- 3 fixed tiers, neither addable nor removable. Progresses from immediate to long-term.
  - Immediate value: the direct benefit gained from each use (❌ "improves efficiency" ✅ "the agent automatically retrieves relevant knowledge before modifying code, avoiding known mistakes")
  - Cumulative value: the compounded gain from continued use (❌ "gets better over time" ✅ "project knowledge keeps accumulating; hit rate rises as entries grow; onboarding cost for new members keeps decreasing")
  - Strategic value: the long-term impact on how work is done (❌ "very valuable" ✅ "from 'starting over every time' to 'experience handed down'; AI collaboration is upgraded from stateless conversation to memory-bearing continuous collaboration")
  - Metric: a concrete quantifiable metric + target value (❌ "good results" ✅ "context-rebuild time (target: 15min → <1min), regression bug rate (target: reduced by >50%)")
  - EXCLUDE: technical implementation details -->

| Tier | Value | Metric |
|------|-------|--------|
| **Immediate value** | {direct benefit gained per use} | {concrete metric + target value, multiple separated by commas} |
| **Cumulative value** | {compounded gain from continued use} | {concrete trend metric + target value} |
| **Strategic value** | {long-term impact on how work is done} | {concrete long-term metric + target value} |

### Core Problem

<!-- ROWS: ≥2. The fundamental problems the product solves.
  - Problem: user-perspective pain point (❌ "lack of knowledge management" ✅ "AI repeats known mistakes in new sessions")
  - Occurrence frequency: quantified frequency (❌ "often" ✅ "every new session, daily 5-20 times")
  - Per-occurrence cost: the cost each time it happens (❌ "wastes time" ✅ "10-30 minutes re-exploring + introduced regression risk")
  - Reach: the affected user scale or scenario breadth (❌ "many people" ✅ "all developers using AI assistants to maintain medium-to-large projects")
  - Existing workaround: how users currently address it (❌ "no good solution" ✅ "manually maintain CLAUDE.md; once entries inflate, token cost becomes uncontrollable")
  - EXCLUDE: product feature descriptions, technical limitations -->

| Problem | Occurrence Frequency | Per-Occurrence Cost | Reach | Existing Workaround |
|---------|----------------------|---------------------|-------|---------------------|
| {user-perspective pain point} | {quantified frequency} | {quantified cost} | {affected scale} | {current approach and its shortfall} |

### Target Users

<!-- ROWS: ≥1. One row per user group. The core is to express the before→after value gap.
  - Role: concrete role (❌ "developer" ✅ "independent developer using Claude Code")
  - Typical scenario: when they use it (❌ "daily development" ✅ "maintaining a medium-to-large project across sessions, needing the AI to remember project constraints")
  - Before: state before use, quantified pain (❌ "low efficiency" ✅ "spends 15 minutes per new session rebuilding context; key constraints are still missed")
  - After: state after use, quantified gain (❌ "high efficiency" ✅ "the agent automatically retrieves relevant knowledge; context-rebuild time approaches 0")
  - Estimated efficiency gain: quantified ROI (❌ "significant improvement" ✅ "saves 10-15 minutes per session; regression bugs reduced by >50%")
  - EXCLUDE: internal users, system components -->

| Role | Typical Scenario | Before | After | Estimated Efficiency Gain |
|------|------------------|--------|-------|--------------------------|
| {concrete role} | {usage scenario} | {pre-use pain, quantified} | {post-use state, quantified} | {quantified ROI} |

### Competitive Comparison

<!-- ROWS: ≥3 (this product + ≥2 competitors/alternatives). Compare product-level positioning, not technical detail.
  - Solution: concrete product name (❌ "other tools" ✅ "Cursor Rules")
  - Positioning: product definition (one sentence)
  - Target users: who it is for
  - Core features: user-perspective key capabilities (3-5 items, comma-separated)
  - Strengths: the most prominent 1-2 strengths
  - Limitations: the most evident 1-2 limitations
  - EXCLUDE: technical implementation details (storage, protocol, architecture) -->

| Solution | Positioning | Target Users | Core Features | Strengths | Limitations |
|----------|-------------|--------------|---------------|-----------|-------------|
| **{this product}** | {positioning} | {users} | {feature list} | {strengths} | {limitations} |
| {competitor} | {positioning} | {users} | {feature list} | {strengths} | {limitations} |

## 2. Version Plan

### Version Summary Table

<!-- A global view of all versions. Quickly scan the product evolution.
  - Version: v{n}, append code name if any (e.g. "v1 — closed-loop validation"), version number only if no code name
  - Core direction: the strategic focus of this version (❌ "feature polish" ✅ "validate end-to-end closed-loop feasibility")
  - Core-metric delta: the most significantly rising and falling metrics in this version (❌ "metrics improved" ✅ "↑ knowledge entries 0→15, learn gate rejection rate 0→18%; ↓ context-rebuild time 15min→<5min")
  - Status: planned | in development | in beta | released | archived
  - Period: start and end dates (YYYY.MM.DD - YYYY.MM.DD or TBD)
  - Milestones: the milestone-number range included (M{a}-M{b})
  - EXCLUDE: per-version details (→ each version-detail card) -->

| Version | Core Direction | Core-Metric Delta | Status | Period | Milestones |
|---------|----------------|-------------------|--------|--------|------------|
| v{n} | {strategic focus} | ↑ {metric with largest rise}; ↓ {metric with largest fall} | {enum status} | {start-end dates} | M{a}-M{b} |

### Version Details

<!-- One subsection per version, answering 5 decision questions + core metrics. 8 fixed fields, neither addable nor removable.
  - Strategic intent: why this version exists, its relation to the product vision (❌ "polish features" ✅ "validate the core hypothesis: can AI agents reduce cross-session mistakes via persistent knowledge")
  - Input/output: estimated input (headcount/time) vs. expected return (❌ "modest input" ✅ "input 4 days of dev → expected to save 10-15 minutes of context rebuild per session")
  - Priority rationale: why now, prerequisites (❌ "important so do it first" ✅ "core closed loop is unvalidated; later versions are meaningless without it; no prerequisites")
  - Risks and dependencies: factors that could block (❌ "small risk" ✅ "depends on the stability of the Claude Code plugin mechanism; risk: JSONL performance with many entries is unvalidated")
  - Success metric: quantifiable success criteria (❌ "users are satisfied" ✅ "knowledge entries ≥10, [correction] claims captured ≥3 times, ≥1 week of continuous use without blockers")
  - Core value: the user value delivered by this version, may be multiple (❌ "better experience" ✅ "1. first time knowledge can be auto-captured/retrieved\n2. first time docs can be generated from conversation")
  - User coverage: the target user range and how they are reached (❌ "has users" ✅ "author dogfood")
  - Core metric: full metric table, listing all key metrics' delta vs. the previous version
    - Columns: metric | previous-version value | this-version value | delta
    - ROWS: ≥3, covering newly added and inherited key metrics for this version
    - Delta column: ↑/↓ + concrete number or percentage (❌ "some improvement" ✅ "↑ 23pp")
    - For the first version, fill the "previous-version value" with baseline or N/A -->

#### v{n} — {code name}

- **Strategic intent**: {why this version exists, its relation to the product vision}
- **Input/output**: {estimated input vs. expected return}
- **Priority rationale**: {why now, whether prerequisites are met}
- **Risks and dependencies**: {blocking factors, dependencies, identified risks}
- **Success metric**: {quantifiable success criteria}
- **Core value**: {user value delivered by this version, may be multiple}
- **User coverage**: {target user range}
- **Core metric** ({previous version} → v{n}):

| Metric | {previous version} | v{n} | Delta |
|--------|--------------------|------|-------|
| {metric name} | {previous-version value} | {this-version value} | {↑/↓ value} |

## 3. Milestones

<!-- A cumulative record of all milestones. Numbering is continuous and cross-version.
     The summary table is here; details are split out into independent files: docs/milestones/m{n}.md
     Structure locked: summary-table columns are fixed. The detail-file structure is in templates/milestone.md -->

<!-- ROWS: ≥2
  - #: M{n}, globally incrementing, linked to the detail file
  - Core direction: the strategic intent of this milestone (❌ "foundational setup" ✅ "validate end-to-end feasibility of the learn pipeline")
  - Goal achievement: objective outcome description. If achieved, write the result data; if not fully achieved, write result + reason.
    (❌ "feature usable" ✅ "end-to-end working, extraction accuracy 80%")
    (❌ "partially completed" ✅ "all 10 document types supported, but content quality is uneven — templates lack content-filling constraints")
  - Status: not started | in progress | in acceptance | done | shelved
  - Completion date: YYYY-MM-DD or —
  - EXCLUDE: engineering task breakdown, code-level TODOs, requirement links (in the detail file) -->

| # | Core Direction | Goal Achievement | Status | Completion Date |
|---|----------------|------------------|--------|-----------------|
| [M{n}](milestones/m{n}.md) | {strategic intent} | {objective outcome, append reason if not met} | {enum status} | {date} |
