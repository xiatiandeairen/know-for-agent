<p align="center">
  <h1 align="center">know-for-agent</h1>
  <p align="center">
    Knowledge compiler for AI agents — persist tacit knowledge and write structured documents.
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

1. **Repeated errors** — AI agents make the same mistakes across sessions. Know records tacit knowledge (rationale, constraints, pitfalls) to correct the agent's mental model.
2. **Design artifacts lost** — Discussion results stay in conversations and disappear. Know writes them as structured, versioned documents.

## Installation

```bash
# As a Claude Code plugin
claude plugin add know-for-agent

# Or as a git submodule
git submodule add git@github.com:xiatiandeairen/know-for-agent.git src/plugins/know
```

## Quick Start

```bash
# Persist knowledge from current conversation
/know learn

# Write discussion results as structured document
/know write
```

## How It Works

### Two Capabilities

| Capability | Direction | Purpose |
|-----------|-----------|---------|
| **Learn** | Conversation → .knowledge/ | Record tacit knowledge to reduce future errors |
| **Write** | Conversation → .know/docs/ | Turn discussion results into structured documents |

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

Each index entry (two tiers: 重要/备忘):

```json
{"tag":"constraint","tier":1,"scope":"LoppyMetrics","tm":"active:defensive","summary":"Thresholds only in PressureLevel, no hardcoded numbers","path":"entries/constraint/pressure-thresholds.md","hits":3,"revs":0,"created":"2026-03-15","updated":"2026-04-08"}
```

### Learn Pipeline

```
Signal detection → Claim extraction → Route interception → 2-question tier assessment
→ Entry generation → Conflict detection → User confirmation → Write
```

- 6 signal types with rule-based filtering (must contain detection pattern keywords)
- 2-question assessment: impact if missing? → reuse frequency?
- 2-phase conflict detection: keyword pre-filter (jq) → LLM similarity assessment

### Two-Tier System

| Tier | Name | Detail File | Decay |
|------|------|-------------|-------|
| 1 | 重要 (important) | ≤ 220 tokens | 180d without hits → demote |
| 2 | 备忘 (memo) | Summary only | 30d without hits → delete |

## Architecture

```
/know (SKILL.md)
├── learn (workflows/learn.md)
│   ├── Signal detection (6 types, rule-based filtering)
│   ├── Route interception (5 fast-drop rules)
│   ├── 2-question tier assessment (重要/备忘)
│   ├── Conflict detection (2-phase)
│   └── Write (index.jsonl + entries/)
└── write (workflows/write.md)
    ├── Infer parameters (type, name, version, parent)
    ├── Confirm parameters (single confirmation)
    ├── Load template (9 types)
    ├── Extract and fill content from conversation
    └── Write file + update CLAUDE.md index

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
