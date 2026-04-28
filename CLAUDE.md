# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

know — an AI-assisted authoring tool for high-entropy knowledge units, plus a native carrier for the Claude Code ecosystem. Claude Code plugin.

**Current status**: Both pipelines have landed, with no runtime script dependencies; all paths are inlined inside the workflow files. `learn` runs 5 stages (detect → gate → refine → locate → write); `write` runs 5 stages / 9 steps (infer → gate → confirm → draft → write). Runtime retrieval (recall / extract / review / report / decay) has been retired; the Claude Code nested CLAUDE.md loading mechanism takes over that role.

The entry commands are only `/know learn` + `/know write`.

## Architecture

```
skills/know/SKILL.md          ← Skill entry point: routing + conventions only (minimal resident context)
workflows/
  learn.md                       learn pipeline (5 stages / 15 steps)
  write.md                       write pipeline (5 stages / 9 steps, 10 document types)
  templates/                     templates + checklists used by write
docs/
  roadmap.md                     roadmap
  marketing.md                   promotion materials
  arch/                          architecture records (includes know.md system architecture)
  decision/                      key decision records
tests/
  unit/                          workflow structure unit tests (test-learn-stages / test-write-stages)
```

## Key Design Decisions

- **Storage**: knowledge is written to the `## know` YAML block inside CLAUDE.md (4 fields: when / must|should|avoid|prefer / how / until), compatible with Claude Code's native loading; no private JSONL, no events.jsonl.
- **Entry**: only `learn` + `write`; recall / extract / review / report / decay have been cut.
- **Activation**: handled by the Claude Code nested CLAUDE.md loading mechanism; know does not perform runtime retrieval.
- **5 learn gates**: information entropy → reuse → triggerability → actionability → invalidation, from coarse to fine; each gate offers a revision direction before rejecting, targeting a rejection rate ≥20%.
- **claim classification**: `[correction]` (user correcting AI) bypasses the information-entropy gate; `[capture]` (AI capturing autonomously) must pass the full gate set.
- **Three locate levels**: user (requires real cross-project evidence; "theoretically applicable" is not enough) / module (has a specific code directory) / project (default). Priority is user > module > project; paths are inlined in the learn workflow.
- **write inherits v1**: 10 document types + templates + sufficiency gate + data confidence rules; high-risk types (prd/tech/arch/schema/decision/ui) go through a question-driven sufficiency gate.
- **Data confidence**: every numeric value must annotate its source (measured / estimated / target / no data).
