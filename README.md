<h1 align="center">know</h1>

<p align="center">
  <strong>Authoring discipline for CLAUDE.md — stop low-entropy rules from piling up.</strong>
</p>

<p align="center">
  A <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a> plugin. Two commands: <code>/know learn</code> gates lessons into CLAUDE.md; <code>/know write</code> turns discussions into versioned docs.
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

## Why

|                         | CLAUDE.md (manual) | Auto-memory | **know**                              |
| ----------------------- | :----------------: | :---------: | :-----------------------------------: |
| Authoring discipline    | none               | none        | **5-gate entropy filter**             |
| Structure               | flat text          | key-value   | **4-field YAML (when/rule/how/until)**|
| Activation              | always loaded      | always loaded | **Claude Code nested loading**      |
| Document templates      | —                  | —           | **10 types + sufficiency gate**       |

## What you get

Every entry carries weight on every field:

```yaml
- when: editing the webhook handler
  must: verify signature before parsing body — prevents forged payloads
  how: HMAC-SHA256(env.WEBHOOK_SECRET, raw_body) vs X-Sig header; see src/webhook/verify.ts
  until: provider switches to mTLS
```

Each candidate runs through 5 gates in order — **entropy → reuse → triggerable → actionable → invalidation**. Target rejection rate ≥20%. Most "rules" are noise; they don't survive.

For longer artifacts, `/know write` fills a typed template — **10 types**: roadmap, capabilities, prd, tech, arch, schema, decision, ui, ops, marketing. High-risk types pass a sufficiency gate before writing; numbers must cite source (`measured` / `estimated` / `target` / `no-data`).

## Use

```bash
/know learn                            # gate the current conversation, append surviving entries to CLAUDE.md
/know write                            # infer doc type from context
/know write arch                       # hint the type
/know write decision payment-method    # hint type + name
```

Activation is delegated to Claude Code's native nested CLAUDE.md loading — no runtime retrieval layer.

## Install

Paste this to Claude Code:

> Install the `know` Claude Code plugin from `https://github.com/xiatiandeairen/know-for-agent`:
> 1. Clone to `~/.claude/plugins/know`
> 2. In `~/.claude/settings.json`, add `extraKnownMarketplaces.know = { source: { source: "directory", path: "~/.claude/plugins/know" } }` and set `enabledPlugins["know@know"] = true`
> 3. Restart Claude Code

Requires `git`.

<details>
<summary>Uninstall</summary>

Paste to Claude Code:

> Uninstall the `know` Claude Code plugin: delete `~/.claude/plugins/know`, remove `extraKnownMarketplaces.know` and `enabledPlugins["know@know"]` from `~/.claude/settings.json`, restart Claude Code.

</details>

## License

[MIT](LICENSE) — contributions welcome via [issues](https://github.com/xiatiandeairen/know-for-agent/issues).
