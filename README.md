<p align="center">
  <h1 align="center">know-for-agent</h1>
  <p align="center">
    Knowledge compiler for AI agents — persist tacit knowledge, write structured documents, and track knowledge health.
  </p>
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  <a href="https://github.com/xiatiandeairen/know-for-agent/actions/workflows/ci.yml"><img src="https://github.com/xiatiandeairen/know-for-agent/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/xiatiandeairen/know-for-agent/releases"><img src="https://img.shields.io/github/v/release/xiatiandeairen/know-for-agent?include_prereleases" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
</p>

---

## What is this?

**know-for-agent** is a [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code) that gives AI agents persistent project memory. It solves three problems:

1. **Repeated errors** — AI agents make the same mistakes across sessions. Know records tacit knowledge and uses recall to prevent errors before they happen.
2. **Design artifacts lost** — Discussion results stay in conversations and disappear. Know writes them as structured, versioned documents.
3. **Knowledge quality blind** — No way to know if stored knowledge is useful. Know provides metrics, lifecycle tracking, and optimization suggestions.

## Installation

**One-line install** (requires [jq](https://jqlang.github.io/jq/download/) and git):

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/install.sh | bash
```

Restart Claude Code after installation. That's it — `/know learn` is now available in any project.

**Uninstall:**

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/uninstall.sh | bash
```

> Your `.know/` project data is preserved after uninstall. Delete it manually if needed.

## Quick Start

```bash
# Persist knowledge from current conversation
/know learn

# Write discussion results as structured document
/know write

# Audit and maintain knowledge entries
/know review

# View quality metrics + optimization suggestions
know-ctl metrics

# Check template-document consistency
know-ctl check

# Run automated self-test
know-ctl self-test
```

## How It Works

### Three Pipelines

| Pipeline | Direction | Purpose |
|----------|-----------|---------|
| **Learn** | Conversation → .know/ | Record tacit knowledge to reduce future errors |
| **Write** | Conversation → .know/docs/ | Turn discussion results into structured documents |
| **Review** | .know/ → User | Audit entries with lifecycle stages and metrics |

### Recall — Automatic Error Prevention

Before operating on code, the agent queries matching knowledge entries. `active:defensive` entries block operations that would violate known constraints. `active:directive` entries suggest best practices.

### Storage

```
.know/
├── index.jsonl              # Knowledge entries — filter via jq
├── entries/                 # Detail files (critical only)
│   ├── rationale/           #   Why this, not that
│   ├── constraint/          #   What must not be done
│   ├── pitfall/             #   Known traps with root cause
│   ├── concept/             #   Core logic, algorithms, flows
│   └── reference/           #   External tool guides
├── metrics.json             # Aggregated metrics data
├── events.jsonl             # Lifecycle event log
└── docs/                    # Structured documents
    ├── v{n}/                #   Project-level versioned
    └── requirements/        #   Requirement/feature level
```

### Two-Tier System

| Tier | Name | Detail File | Decay |
|------|------|-------------|-------|
| 1 | critical | ≤ 220 tokens | 180d without hits → demote |
| 2 | memo | Summary only | 30d without hits → delete |

### Document Templates (9 types)

| Type | Purpose |
|------|---------|
| roadmap | Product vision + milestone progress tracking |
| prd | Requirement progress tracking + acceptance criteria |
| tech | Technical approach + iteration records (multi-sprint) |
| arch | System decomposition + component collaboration |
| ui | User interaction design |
| schema | API/data contract |
| decision | Decision rationale + alternatives |
| ops | Operations + release strategy |
| marketing | Go-to-market messaging |

## Architecture

```
/know (SKILL.md — always loaded, ~250 lines)
├── learn (workflows/learn.md — on-demand)
│   ├── Signal detection (6 types, rule-based)
│   ├── Route interception (5 fast-drop rules)
│   ├── 2-question tier assessment
│   ├── Conflict detection (2-phase)
│   └── Write (index + entries + events)
├── write (workflows/write.md — on-demand)
│   ├── Infer parameters (type, name, version, parent)
│   ├── Load template (9 types)
│   ├── Fill content + progress fields
│   ├── Write file + update CLAUDE.md index
│   └── Cascade marking + progress propagation
└── review (workflows/review.md — on-demand)
    ├── Lifecycle stage sorting (⚠ > 💤 > 🆕 > ✅)
    ├── Metrics summary (decay rate + coverage)
    └── Per-entry action (delete / update / keep)

scripts/know-ctl.sh (14 commands)
├── Core:     init, query, search, append, hit, update, delete
├── Policy:   decay
├── Metrics:  stats, metrics, history
└── Quality:  self-test, check
```

## Contributing

Contributions welcome! Please open an issue first to discuss what you'd like to change.

## License

[MIT](LICENSE)
