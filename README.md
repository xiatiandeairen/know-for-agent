<p align="center">
  <h1 align="center">know-for-agent</h1>
  <p align="center">
    Knowledge compiler for AI agents — scoped retrieval and mental model correction.
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

**know-for-agent** is a [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code) that gives AI agents persistent project memory. It solves two problems:

1. **Context loss** — AI agents start every session from scratch. Know retrieves scoped knowledge so the agent has the right context immediately.
2. **Repeated errors** — AI agents make the same mistakes across sessions. Know records tacit knowledge (rationale, constraints, pitfalls) to correct the agent's mental model.

## Installation

```bash
# As a Claude Code plugin
claude plugin add know-for-agent

# Or as a git submodule
git submodule add git@github.com:xiatiandeairen/know-for-agent.git src/plugins/know
```

## Quick Start

```bash
# Retrieve project-wide knowledge
/know

# Retrieve scoped to a module
/know LoppyMetrics

# Persist knowledge from current conversation
/know learn
```

Know also triggers automatically:
- When you open a file → retrieves knowledge scoped to that module
- When you describe a task → retrieves relevant context
- When AI is about to make a decision → checks for constraints and pitfalls

## How It Works

### Two Capabilities

| Capability | Direction | Purpose |
|-----------|-----------|---------|
| **Retrieve** | .knowledge/ → AI context | Surface the right knowledge at the right time |
| **Learn** | Conversation → .knowledge/ | Record tacit knowledge to reduce future errors |

### Storage: JSONL Index + Markdown Details

```
.knowledge/
├── index.jsonl              # One entry per line — filter via jq
└── entries/                 # Detail files (tier 1/2 only)
    ├── rationale/           #   Why this, not that
    ├── constraint/          #   What must not be done
    ├── pitfall/             #   Known traps with root cause
    ├── concept/             #   Core logic, algorithms, flows
    └── reference/           #   External tool guides
```

Each index entry:

```json
{"tag":"constraint","tier":1,"scope":"LoppyMetrics","tm":"active:defensive","summary":"Thresholds only in PressureLevel, no hardcoded numbers","path":"entries/constraint/pressure-thresholds.md","hits":3,"revs":0,"created":"2026-03-15","updated":"2026-04-08"}
```

### Retrieve Pipeline

```
Trigger → Resolve scope keypath → Filter index.jsonl → Sort → Truncate → Output
```

- Scope uses dot-separated keypaths with prefix matching (`LoppyMetrics.DataEngine` matches `LoppyMetrics`)
- Active entries are injected silently; passive entries shown on explicit `/know`
- Token cost is minimal: most queries only read summaries, detail files loaded on demand

### Learn Pipeline

```
Signal detection → Claim extraction → Route interception → 3-question tier assessment
→ Entry generation → Conflict detection → User confirmation → Write
```

- 6 signal types detected: user corrections, technical choices, root causes, business logic, constraints, integrations
- 3-question assessment replaces complex scoring: derivable? → impact if missing? → reuse frequency?
- 2-phase conflict detection: keyword pre-filter (jq) → LLM similarity assessment

### Tier System

| Tier | Purpose | Detail File | Retrieval | Decay |
|------|---------|-------------|-----------|-------|
| 1 | Core knowledge | ≤ 220 tokens | Scope match → inject | 180d without hits → demote |
| 2 | Conditional knowledge | ≤ 160 tokens | Anchor match → inject | 90d without hits → demote |
| 3 | Observation pool | Summary only | Not actively retrieved | 30d without hits → delete |

## Architecture

```
/know (SKILL.md)
├── retrieve (workflows/retrieve.md)
│   ├── Scope resolution (file path / task description / user input)
│   ├── Index filtering (know-ctl.sh query)
│   ├── Priority sorting (active > passive, tier, hits, recency)
│   └── Output (silent injection or explicit list)
└── learn (workflows/learn.md)
    ├── Signal detection (6 types)
    ├── Route interception (5 fast-drop rules)
    ├── 3-question tier assessment
    ├── Conflict detection (2-phase)
    └── Write (index.jsonl + entries/)

scripts/know-ctl.sh
├── query    Filter index by scope/tag/tier/tm
├── search   Regex match against summaries
├── append   Add entry to index
├── hit      Increment retrieval counter
├── decay    Apply expiry policy
└── stats    Index summary
```

## Contributing

Contributions welcome! Please open an issue first to discuss what you'd like to change.

## License

[MIT](LICENSE)
