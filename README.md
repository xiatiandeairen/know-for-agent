<h1 align="center">know</h1>

<p align="center">
  <strong>Give your CLAUDE.md authoring discipline — stop low-entropy rules from piling up.</strong>
</p>

<p align="center">
  A <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a> plugin with two commands: <code>learn</code> gates and structures knowledge into CLAUDE.md, <code>write</code> turns discussions into versioned docs.
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

`CLAUDE.md` is the right place for project knowledge — but without discipline, it degrades into a pile of low-entropy rules that don't change AI behavior. And design discussions just vanish after a session.

| Without know | With know |
|:---|:---|
| AI keeps violating constraints it "knows" | Every entry passes a 5-gate entropy filter before it's written |
| CLAUDE.md grows bloated with obvious rules | Gate rejects rules the model already knows — noise stays out |
| Design discussion results vanish after the session | `/know write` turns the conversation into a structured doc |
| Docs are thin and inconsistent | Template + checklist + sufficiency gate enforce quality |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/install.sh | bash
```

Requires `git` and `jq`. Restart Claude Code after install.

<details>
<summary>Uninstall</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/uninstall.sh | bash
```
</details>

## Usage

```bash
/know learn     # Gate and persist knowledge from the current conversation
/know write     # Turn discussion into a structured, versioned document
```

### How learn Works

`learn` runs a 5-stage pipeline on each knowledge candidate:

1. **detect** — scan the last ≤20 turns; classify as `[纠正]` (user corrected AI, fast-track) or `[捕捉]` (AI self-captured, full gate required)
2. **gate** — 5 filters from coarse to fine: entropy → reuse → triggerable → actionable → invalidation. Each gate proposes an adjustment before rejecting; target rejection rate ≥20%
3. **refine** — optional: generalize trigger scope, deepen rationale, split multi-logic entries
4. **locate** — pick target CLAUDE.md (project / module / user level) via `know-paths.sh`
5. **write** — produce YAML entry, check for duplicates, confirm, append

Every entry written to a `## know` YAML block:

```yaml
- when: editing webhook handler
  must: verify signature before parsing body — prevents forged payloads
  how: HMAC-SHA256(env.WEBHOOK_SECRET, raw_body) vs X-Sig header; see src/webhook/verify.ts
  until: webhook provider switches to mTLS
```

Knowledge is activated by Claude Code's native nested CLAUDE.md loading — no runtime retrieval layer.

### How write Works

`write` infers document type and path from the conversation, runs a sufficiency gate for high-risk types, fills a template, and previews before writing:

```bash
/know write          # infer type from context
/know write arch     # hint the type
/know write decision payment-method   # hint type + name
```

## Document Types

10 types, each with a template + checklist + update rules:

| Type | Path | Description |
|------|------|-------------|
| roadmap | `docs/roadmap.md` | Product vision, version planning, milestones |
| capabilities | `docs/capabilities.md` | Cross-version capability inventory |
| ops | `docs/ops.md` | Release strategy, feedback SLA |
| marketing | `docs/marketing.md` | Audience, messaging, channels |
| prd | `docs/requirements/{name}/prd.md` | Problem, users, hypothesis, acceptance criteria |
| tech | `docs/requirements/{name}/tech.md` | Constraints, architecture, decisions, iteration log |
| arch | `docs/arch/{name}.md` | Module structure, data flow, design decisions |
| schema | `docs/schema/{name}.md` | Interface contracts, data models, error codes |
| decision | `docs/decision/{name}.md` | Options comparison, impact analysis |
| ui | `docs/ui/{name}.md` | Layout, interaction flows, component states |

**Sufficiency gate** — for high-risk types (prd / tech / arch / schema / decision / ui): if the conversation doesn't have enough to fill the template, know blocks the write and suggests a parent document instead.

**Data confidence** — every number must cite its source: measured / estimated / target / no-data. Fabricating precise numbers is prohibited.

## How It Differs

| | CLAUDE.md (manual) | Auto-memory | **know** |
|---|:---:|:---:|:---:|
| Authoring discipline | None | None | **5-gate entropy filter** |
| Structure | Flat text | Key-value | **4-field YAML (when/rule/how/until)** |
| Activation | Always loaded | Always loaded | **Claude Code nested loading** |
| Documents | None | None | **10 types with quality framework** |

## Contributing

Contributions welcome! Please [open an issue](https://github.com/xiatiandeairen/know-for-agent/issues) first to discuss what you'd like to change.

## License

[MIT](LICENSE)
