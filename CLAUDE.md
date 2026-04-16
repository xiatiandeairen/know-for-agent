# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

know — Project knowledge compiler for AI agents. A Claude Code plugin that persists tacit knowledge and generates structured documents. Run `/know` for help. Docs in `.know/docs/`.

## Architecture

```
skills/know/SKILL.md          ← Skill entry: routing, recall, decay, storage schema
workflows/                     ← Pipeline definitions (loaded on demand by SKILL.md)
  learn.md                       8-step knowledge extraction
  write.md                       8-step document authoring (includes sufficiency gate + validate)
  extract.md                     Code mining pipeline
  review.md                      Entry audit pipeline
  templates/                   ← Document templates + quality infrastructure
    {type}.md                    Structure template (11 types)
    {type}-checklist.md          Field specs (概览表 + 逐字段定义块)
    {type}-update.md             Change rules per field
    diagram-checklist.md         8 diagram types with when→action triggers
    sufficiency-gate.md          Question-based content gate for high-risk doc types
scripts/
  know-ctl.sh                  ← CLI: 12 subcommands (append/query/hit/decay/metrics/history/self-test/check/...)
.know/                         ← Project data (git-tracked)
  index.jsonl                    Knowledge entries (JSONL, 12 fields per entry)
  entries/{tag}/{slug}.md        Detail files (tier 1 only)
  events.jsonl                   Append-only lifecycle events
  metrics.json                   Aggregated counters
  docs/                          Structured documents (roadmap, prd, tech, arch, etc.)
  docs/milestones/               Milestone detail files (m1.md - m10.md)
```

## Key Commands

```bash
bash scripts/know-ctl.sh self-test    # Run all 24 tests in /tmp isolation
bash scripts/know-ctl.sh stats        # Show entry counts by tier/tag/scope
bash scripts/know-ctl.sh metrics      # Show learn/recall/write health indicators
bash scripts/know-ctl.sh check        # Detect template-document structure deviations
```

## Key Design Decisions

- **Storage**: JSONL + independent .md files (not SQLite) — zero dependency, git-trackable, line-level append
- **Path resolution**: `know-ctl.sh` uses `$CLAUDE_PROJECT_DIR` with `pwd` fallback (not `dirname "$0"`) to correctly resolve in plugin mode
- **Directory name**: Always `.know/` — never `knowledge/`, `know/`, or variants
- **Template quality**: Each doc type has 3 files (template + checklist + update rules). Write pipeline validates against checklist + diagram triggers after authoring.
- **Data confidence**: All numeric values must cite source (实测/估算/目标/无数据). Fabricating precise numbers is prohibited.
- **Document sufficiency**: High-risk types (prd/tech/arch/schema/decision/ui) pass question-based gate before creation. Insufficient content → downgrade to parent document.
- **Milestone structure**: §1 目标 + §2 计划 (immutable after start) → §3 任务追踪 (PRD-based) → §4 结果 (filled once on completion, also immutable)
