<h1 align="center">know</h1>

<p align="center">
  <strong>Your AI agent keeps making the same mistakes. This fixes that.</strong>
</p>

<p align="center">
  A <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a> plugin that gives AI agents persistent, structured project memory — so lessons learned in one session are never forgotten.
</p>

<p align="center">
  <a href="https://github.com/xiatiandeairen/know-for-agent/actions/workflows/ci.yml"><img src="https://github.com/xiatiandeairen/know-for-agent/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/xiatiandeairen/know-for-agent/releases"><img src="https://img.shields.io/github/v/release/xiatiandeairen/know-for-agent?include_prereleases&label=version" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
</p>

<p align="center">
  <b>English</b> | <a href="README.zh-CN.md">中文</a>
</p>

---

## The Problem

AI coding agents forget everything between sessions. They repeat the same mistakes, lose design decisions, and ignore lessons they've already learned — even with `CLAUDE.md` and auto-memory.

| Without know | With know |
|:---|:---|
| AI makes the same architectural mistake for the 3rd time | `[recall]` fires before the mistake happens |
| "Why did we choose X over Y?" — no one remembers | Rationale entry retrieved automatically by scope |
| Design discussion results vanish after the session | Structured docs persisted in `.know/docs/` |
| Generated docs are thin and inconsistent | Template + checklist + update rules enforce quality |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/install.sh | bash
```

Requires `jq` and `git`. Restart Claude Code after install.

<details>
<summary>Uninstall</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/uninstall.sh | bash
```

Your `.know/` project data is preserved. Delete it manually if needed.
</details>

## Usage

```bash
/know learn     # Extract and persist knowledge from the current conversation
/know write     # Turn discussion into a structured, versioned document
/know extract   # Mine knowledge from source code
/know review    # Audit stored knowledge — delete stale, update outdated
/know report    # 6-section health diagnostic of your knowledge base
```

### How Recall Works

Know doesn't just store knowledge — it **uses** it. Before your agent modifies code, it automatically queries relevant entries by module scope:

- **`active:defensive`** — warns or blocks operations that would violate known constraints
- **`active:directive`** — suggests proven approaches before the agent guesses
- **`passive`** — surfaces context only when the agent is about to repeat a known mistake

Every recall query is logged to `events.jsonl` for observability.

### Document Quality Framework

Every document type has a **3-file quality chain**:

| File | Purpose |
|------|---------|
| `{type}.md` | Structure template with inline field specs and ❌/✅ examples |
| `{type}-checklist.md` | Full field specification (info, format, constraints, data confidence) |
| `{type}-update.md` | Change rules per field (immutable, append-only, data-refresh, updatable) |

Additional quality infrastructure:
- **Sufficiency gate** — question-based content check blocks thin documents for high-risk types (prd, tech, arch, schema, decision, ui). Insufficient content → downgrade to parent document instead of creating garbage.
- **Diagram checklist** — 8 diagram types with when→action triggers (data flow, sequence, ER, state, etc.)
- **Data confidence rules** — every number must cite its source (measured, estimated, target, or no-data). Fabricating precise numbers is prohibited.

## What Gets Stored

Know captures the knowledge that code and git history **can't express**:

| Tag | What it captures | Example |
|-----|-----------------|---------|
| `rationale` | Why X, not Y | "Chose JSONL over SQLite — simpler recovery, no binary deps" |
| `constraint` | What must not be done | "Never hardcode thresholds outside PressureLevel enum" |
| `pitfall` | Known traps + root cause | "DataEngine singleton leaks state across test targets" |
| `concept` | Core logic, algorithms | "Pressure scoring uses 3-tier weighted average" |
| `reference` | External integrations | "HealthKit requires background mode entitlement" |

Every entry is scoped (by module), tiered (critical vs memo), and automatically decayed when no longer useful.

## How It Differs

| | CLAUDE.md | Auto-memory | **know** |
|---|:---:|:---:|:---:|
| Scope | Global rules | Personal prefs | **Project knowledge** |
| Structure | Flat text | Key-value | **Tagged, scoped, tiered** |
| Retrieval | Always loaded | Always loaded | **On-demand by scope** |
| Lifecycle | Manual | Manual | **Auto-decay + metrics** |
| Documents | None | None | **11 types with quality framework** |
| Limit | ~200 lines | ~200 lines | **No hard limit** |

## Document Types

11 types, each with template + checklist + update rules:

| Type | Level | Description |
|------|-------|-------------|
| roadmap | Project | Product vision, version planning, milestones |
| milestone | Project | Goal/plan/tracking/results (plan immutable after start) |
| capabilities | Project | Cross-version capability inventory |
| ops | Project | Release strategy, feedback SLA, incident playbook |
| marketing | Project | Audience, messaging, channels, timeline |
| prd | Requirement | Problem, users, hypothesis, acceptance criteria |
| tech | Requirement | Constraints, architecture, decisions, iteration log |
| arch | Directory | Module structure, data flow, design decisions |
| schema | Directory | Interface contracts, data models, error codes |
| decision | Directory | Options comparison, impact analysis, status tracking |
| ui | Directory | Layout, interaction flows, component states |

## Storage

```
.know/
├── index.jsonl              # Knowledge entries (12 fields per line)
├── entries/                 # Detail files (critical tier only)
│   ├── rationale/
│   ├── constraint/
│   ├── pitfall/
│   ├── concept/
│   └── reference/
├── events.jsonl             # Lifecycle + recall query events
├── metrics.json             # Aggregated counters
└── docs/                    # Structured documents
    ├── roadmap.md           #   Product roadmap
    ├── capabilities.md      #   Capability inventory
    ├── ops.md               #   Operations playbook
    ├── marketing.md         #   Marketing plan
    ├── arch/{topic}.md      #   Architecture per module
    ├── schema/{topic}.md    #   Interface specs per topic
    ├── decision/{topic}.md  #   Decision records per topic
    ├── milestones/m{n}.md   #   Milestone details
    └── requirements/{req}/  #   prd.md + tech.md per requirement
```

## Contributing

Contributions welcome! Please [open an issue](https://github.com/xiatiandeairen/know-for-agent/issues) first to discuss what you'd like to change.

## License

[MIT](LICENSE)
