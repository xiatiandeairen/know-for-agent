# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

know — Project knowledge compiler for AI agents. A Claude Code plugin that persists tacit knowledge and generates structured documents. Run `/know` for help, `/know report` for health diagnostics. Docs in `docs/`.

## Architecture

```
skills/know/SKILL.md          ← Skill entry: routing, recall, decay, storage schema
workflows/                     ← Pipeline definitions (loaded on demand by SKILL.md)
  learn.md                       10-step knowledge extraction (includes level selection)
  write.md                       8-step document authoring (includes sufficiency gate + validate)
  extract.md                     Code mining pipeline
  review.md                      Entry audit pipeline (supports --level filter)
  templates/                   ← Document templates + quality infrastructure
    {type}.md                    Structure template (11 types)
    {type}-checklist.md          Field specs (概览表 + 逐字段定义块)
    {type}-update.md             Change rules per field
    diagram-checklist.md         8 diagram types with when→action triggers
    sufficiency-gate.md          Question-based content gate for high-risk doc types
scripts/
  know-ctl.sh                  ← CLI: 13 subcommands, all accept --level project|user
docs/                          ← Project-root documents (git-tracked)
  {type}.md                      Structured documents (roadmap, capabilities, ops, marketing)
  {type}/{topic}.md              arch, ui, schema, decision
  requirements/{req}/            prd.md, tech.md
  milestones/                    Milestone detail files (m1.md - m10.md)

$XDG_DATA_HOME/know/           ← Knowledge base (outside working tree)
  projects/{project-id}/         level=project (per-project isolated)
    index.jsonl                  Knowledge entries (JSONL, 11 fields per entry)
    entries/{tag}/{slug}.md      Detail files (tier 1 only)
    events.jsonl                 Append-only lifecycle events
    metrics.json                 Aggregated counters
  user/                          level=user (shared across projects)
    index.jsonl
    entries/{tag}/{slug}.md
    events.jsonl
    metrics.json
```

`{project-id}` = absolute project path with `/` replaced by `-`.

## Key Commands

```bash
bash scripts/know-ctl.sh self-test              # Run all tests in isolated XDG_DATA_HOME
bash scripts/know-ctl.sh stats                  # Show entry counts (both levels sectioned)
bash scripts/know-ctl.sh stats --level user     # Only user level
bash scripts/know-ctl.sh metrics                # Quality indicators (default: project)
bash scripts/know-ctl.sh check                  # Template-document structure check
bash scripts/know-ctl.sh init                   # Create both level directories; warns on legacy .know/
```

## Key Design Decisions

- **Storage split**: documents in project-root `docs/` (git-tracked, IDE/Git tools work); knowledge base in `$XDG_DATA_HOME/know/` (per-user, outside working tree)
- **Two levels**: `project` (per-project, written by default) and `user` (cross-project, shared). Read commands default to both merged; write commands default to project. `--level` overrides.
- **Path resolution**: `know-ctl.sh` uses `$CLAUDE_PROJECT_DIR` with `pwd` fallback (not `dirname "$0"`) to resolve in plugin mode. `XDG_DATA_HOME` defaults to `~/.local/share`.
- **Legacy directory**: `.know/` is not read. `init` detects it and prints manual `mv` instructions.
- **Storage format**: JSONL + independent .md files (not SQLite) — zero dependency, line-level append
- **Template quality**: Each doc type has 3 files (template + checklist + update rules). Write pipeline validates against checklist + diagram triggers after authoring.
- **Data confidence**: All numeric values must cite source (实测/估算/目标/无数据). Fabricating precise numbers is prohibited.
- **Document sufficiency**: High-risk types (prd/tech/arch/schema/decision/ui) pass question-based gate before creation. Insufficient content → downgrade to parent document.
- **Milestone structure**: §1 目标 + §2 计划 (immutable after start) → §3 任务追踪 (PRD-based) → §4 结果 (filled once on completion, also immutable)
