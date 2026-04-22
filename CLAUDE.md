# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

know — Project knowledge compiler for AI agents. A Claude Code plugin that persists tacit knowledge and generates structured documents. Run `/know` for help, `/know report` for health diagnostics. Docs in `docs/`.

## Architecture

```
skills/know/SKILL.md          ← Skill entry: routing, recall (unified, no tier/tm), storage
workflows/                     ← Pipeline definitions (loaded on demand by SKILL.md)
  learn.md                       9-step knowledge extraction (v7: no Assess; adds strict)
  write.md                       8-step document authoring (sufficiency gate + validate)
  extract.md                     Code mining pipeline
  review.md                      Entry audit pipeline (--level filter + strict column)
  templates/                   ← Document templates + quality infrastructure
scripts/
  know-ctl.sh                  ← CLI: 14 subcommands (init/append/query/.../migrate-v7)
                                  all accept --level project|user
docs/                          ← Project knowledge (git-tracked)
  triggers.jsonl                 ← project source (8-field schema, v7)
  {type}.md                      Structured narrative docs (roadmap, capabilities, ops, marketing)
  {type}/{topic}.md              arch, ui, schema, decision
  requirements/{req}/            prd.md, tech.md
  milestones/history.md          Compressed milestone history

$XDG_CONFIG_HOME/know/         ← User source (per-user, dotfiles-git optional)
  triggers.jsonl                 ← user-level triggers (cross-project methodology)

$XDG_DATA_HOME/know/           ← Runtime (per-machine, never git)
  events.jsonl                   ← all events; each line has project_id + level fields
                                  metrics/stats derived from this
```

`project_id` = absolute project path with `/` replaced by `-`（used in event records as a field, not as a directory name in v7）.

## Key Commands

```bash
bash scripts/know-ctl.sh self-test              # Run 33+ tests in isolated XDG_CONFIG + XDG_DATA
bash scripts/know-ctl.sh stats                  # Entry counts by tag/scope/strict (both levels)
bash scripts/know-ctl.sh metrics                # Hit rate + defensive count (derived from events)
bash scripts/know-ctl.sh check                  # Template-document structure check
bash scripts/know-ctl.sh init                   # Create 3-file layout; warn on v6 data
bash scripts/know-ctl.sh migrate-v7 --dry-run   # Preview v6 → v7 migration
bash scripts/know-ctl.sh migrate-v7             # Execute migration
```

## Key Design Decisions

- **3-file storage (v7)**: project triggers in `docs/triggers.jsonl` (git); user triggers in `$XDG_CONFIG_HOME/know/triggers.jsonl` (user's dotfiles optional); runtime in single `$XDG_DATA_HOME/know/events.jsonl` (per-machine, with project_id + level fields). No per-project XDG directories.
- **Schema 8 fields**: `tag / scope / summary / strict / ref / source / created / updated`. `strict` is bool for tag=rule and null for insight/trap. `ref` points to docs/ paragraph, code file, URL, or null.
- **Tag selection priority**: trap > rule > insight (eliminates ambiguity when multiple fit).
- **Two levels**: `project` (default for writes) and `user` (cross-project). Read commands default to both merged; `--level` overrides.
- **Recall is unified**: no suggest/warn/block tiers. `tag=rule && strict=true` gets `⚠` prefix; AI infers severity from tag + strict.
- **Decay is v7 no-op**: policy redesign in next sprint. Command remains callable for pipeline compatibility.
- **metrics/stats derived**: computed from events.jsonl on each call; no aggregated caches.
- **Storage format**: JSONL + Markdown — zero dependency, line-level append, team-reviewable diffs.
- **Path resolution**: `$CLAUDE_PROJECT_DIR` with `pwd` fallback (plugin-mode safe).
- **Legacy v6 data**: `migrate-v7` converts; legacy files not auto-deleted (user confirms).
- **Document sufficiency**: High-risk types (prd/tech/arch/schema/decision/ui) pass question-based gate before creation.
- **Data confidence**: All numeric values must cite source (实测/估算/目标/无数据).
- **Milestone structure**: §1 目标 + §2 计划 (immutable) → §3 任务追踪 → §4 结果 (immutable)
