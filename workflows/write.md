# write — Document Authoring

Take conversation discussion results and write them as structured, versioned documents to the project `.know/docs/` directory.

---

## Path Constants

```
DOCS_DIR        = .know/docs/
TEMPLATES_DIR   = workflows/templates/
CLAUDE_MD       = CLAUDE.md          # project root
```

## Document Types

9 types across 3 levels:

### Project version level (under `.know/docs/v{n}/`)

| Type | Path | Description |
|------|------|-------------|
| roadmap | `v{n}/roadmap.md` | Product roadmap — single file |
| arch | `v{n}/arch.md` | Architecture — single file |
| ops | `v{n}/ops.md` | Operations — release, feedback, iteration — single file |
| marketing | `v{n}/marketing.md` | Marketing — promotion, content strategy, launch plan — single file |
| schema | `v{n}/schema/{topic}.md` | All API/interface specs — directory, multiple files by topic |
| decision | `v{n}/decision/{topic}.md` | ADR records — directory, multiple files by topic |

### Requirement level (under `.know/docs/requirements/{requirement}/`)

| Type | Path | Description |
|------|------|-------------|
| prd | `prd.md` | Product requirements — single file |

### Feature level (under `.know/docs/requirements/{requirement}/{feature}/`)

| Type | Path | Description |
|------|------|-------------|
| tech | `tech.md` | Technical design — single file |
| ui | `ui.md` | UI/interaction design — single file |

### Hierarchy

```
project version: roadmap / arch / schema / ops / marketing / decision
requirement:     requirements/{name}/prd.md
feature:         requirements/{name}/{feature}/tech.md / ui.md
```

Roadmap references requirements. Requirements and features are always current (no versioning).

---

## Step 1: Trigger

```
/know write          # AI infers everything from conversation
/know write <hint>   # With hint (e.g. "product requirements", "tech design", feature name)
```

---

## Step 2: Infer Document Parameters

Extract parameters from conversation context + hint:

### 2a: Document Type

| Signal in Conversation | Inferred Type |
|----------------------|---------------|
| Feature list, priorities, timeline, milestones | roadmap |
| System boundary, module decomposition, infrastructure | arch |
| Release plan, feedback loop, iteration | ops |
| Promotion, content strategy, launch plan, marketing copy | marketing |
| Endpoint, request/response, protocol, schema, interface spec | schema |
| "Decided to", trade-off analysis, option comparison | decision |
| User stories, acceptance criteria, requirements, scope | prd |
| System design, data model, sequence diagram, implementation plan | tech |
| Wireframe, layout, interaction flow, component spec | ui |

If hint is provided, match hint against type names and descriptions first.

### 2b: Name / Topic

**Project-level single files** (roadmap, arch, ops, marketing): no name needed — path is determined by type alone.

**Project-level directory types** (schema, decision): extract topic from conversation. Normalize to lowercase kebab-case slug (e.g. `jsonl-index`, `storage-choice`).

**Requirement level** (prd): extract requirement name. Normalize to lowercase kebab-case slug (e.g. `know-write`).

**Feature level** (tech, ui): extract requirement name + feature name. Both normalized to lowercase kebab-case slug (e.g. requirement `know-write`, feature `write-workflow`).

### 2c: New or Update

**Project-level docs**: check if the target file exists inside any `v*/` directory.
- File exists → update (new version of the project)
- File missing → new document (v1 if no `v*/` directory exists yet)

**Requirement/feature docs**: these live outside version directories and are always overwritten in place (single source of truth, no versioning).

### 2d: Parent Relationship

If type is `prd` → look for related `roadmap` doc.
If type is `tech` or `ui` → look for related `prd` doc.
`arch`, `decision`, `ops`, `marketing`, and `schema` have no required parent.

### Parent Document Missing

If the expected parent document does not exist:
- prd without roadmap → proceed, note in output: "Related roadmap not yet created"
- tech/ui without prd → warn user and ask:
  ```
  [write] Related PRD not found ({expected path})
  A) Continue without parent link
  B) Create PRD first, then write current document
  ```

---

## Step 3: Confirm Parameters

Show all inferred parameters in one confirmation block and wait for user confirmation.

**Project-level docs** — include version. Run version check first:

```bash
# [RUN] Check existing version directories
ls -d .know/docs/v*/ 2>/dev/null | sort -V | tail -1
```

| Result | Action |
|--------|--------|
| No `v*/` directories | Default to v1 |
| Latest is `v{n}/` | Default to v{n+1}, let user confirm or change |

```
[write] Inferred from conversation, please confirm:

Type: arch
Version: v2 (current latest v1, creating v2)
Parent: none

Correct?
```

**Requirement docs**:

```
[write] Inferred from conversation, please confirm:

Type: prd
Requirement: know-write
Parent: roadmap (v1/roadmap.md)

Correct?
```

**Feature docs**:

```
[write] Inferred from conversation, please confirm:

Type: tech
Requirement: know-write
Feature: write-workflow
Parent: prd (requirements/know-write/prd.md)

Correct?
```

If multiple interpretations exist (e.g. conversation covers both PRD and tech design), present choices:

```
[write] Conversation contains multiple document types:
1. requirements/know-write — prd
2. requirements/know-write/write-workflow — tech

Which to write? [1 / 2 / both]
```

Both → process sequentially, each following full pipeline from Step 4.

---

## Step 4: Load Template

```bash
# [RUN] Load document template
cat workflows/templates/{type}.md
```

If template file missing → use minimal default structure:

```markdown
# {Title}

## Overview

## Details

## Open Questions
```

---

## Step 5: Extract and Fill Content

Using the loaded template as structure guide:

1. Scan full conversation for content relevant to this document type
2. Organize extracted content into template sections
3. Write complete, structured prose — not conversation fragments
4. Ensure all template sections are addressed (mark as "TBD" if no conversation content covers it)
5. Do NOT include frontmatter — metadata lives in CLAUDE.md index

Content quality rules:
- **Follow each section's INCLUDE/EXCLUDE guide** in template comments (`<!-- -->`). Only extract conversation content that falls within the section's INCLUDE scope; actively filter out content matching EXCLUDE criteria, even if discussed in conversation
- Each template section must contain at least 2-3 complete sentences; if conversation lacks content for a section, keep the section header and write "TBD — {reason}" as content
- Do NOT paste conversation fragments as-is; rewrite all content as standalone, readable prose
- Code examples and tables from conversation may be quoted directly
- Technical accuracy preserved from conversation; do not infer or fabricate details not discussed
- Ambiguities or open questions called out explicitly with "Open question:" prefix
- Cross-references to related docs where applicable (use relative paths)
- Match user's language for document content (Chinese conversation → Chinese document)

**Update mode** (when overwriting an existing document):

Before generating content, read the existing document and the corresponding template, then check:

1. **Structure compliance** — existing sections must match template structure. Missing sections → add. Extra sections not in template → evaluate whether to keep or remove
2. **Content accuracy** — facts, numbers, descriptions must match current implementation. Outdated content → update based on conversation context and current code state
3. **Reference integrity** — all relative paths (`requirements/...`, `v1/...`) and cross-references must point to existing files. Broken references → fix or remove
4. **Title convention** — H1 title must follow the template naming rule for its document level

Fix all issues found; do not carry forward known errors from the existing document.

---

## Step 6: Preview

Wait for user confirmation before proceeding. Display complete document for review:

```
[write] Preview: .know/docs/v{n}/arch.md

{full document content in markdown}

Write?
```

For requirement/feature docs:

```
[write] Preview: .know/docs/requirements/{requirement}/prd.md
```

User confirms → Step 7.
User requests edits → adjust content, re-display preview.

---

## Step 7: Write Document

```bash
# [RUN] Create directory if needed and write document

# Project-level single file:
mkdir -p .know/docs/v{n}
# Write tool: .know/docs/v{n}/roadmap.md   (or arch.md / ops.md / marketing.md)

# Project-level directory type:
mkdir -p .know/docs/v{n}/schema
# Write tool: .know/docs/v{n}/schema/{topic}.md

# Requirement:
mkdir -p .know/docs/requirements/{requirement}
# Write tool: .know/docs/requirements/{requirement}/prd.md

# Feature:
mkdir -p .know/docs/requirements/{requirement}/{feature}
# Write tool: .know/docs/requirements/{requirement}/{feature}/tech.md
#          or .know/docs/requirements/{requirement}/{feature}/ui.md
```

```
[written] .know/docs/v{n}/arch.md
```

---

## Step 8: Update CLAUDE.md Document Index

### Index format

The document index lives in project CLAUDE.md under `## Know` → `### 文档索引`:

```markdown
## Know

### 文档索引

#### v1
- [know 产品路线图](.know/docs/v1/roadmap.md) | 2026-04-10
- [know 架构设计](.know/docs/v1/arch.md) | 2026-04-10

#### Requirements
- [know-write](.know/docs/requirements/know-write/prd.md) | 2026-04-10 ← roadmap
  - [tech](.know/docs/requirements/know-write/tech.md) | 2026-04-10 ← prd
```

### Update procedure

1. Read current CLAUDE.md
2. If `## Know` section missing → create it with `### 文档索引`, `#### v1` and `#### Requirements` headers
3. For project-level docs → find or create the `#### v{n}` section header, add/update entry
4. For requirement docs → find or create `#### Requirements`, add/update entry for `{requirement}`
5. For feature docs → find the `{requirement}` entry under `#### Requirements`, add/update indented sub-entry

**Display title rule**:
- Project-level docs: read the document's first line (`# xxx`), use `xxx` as the display title
- Requirement docs: use the requirement slug as display title (e.g. `know-write`), not the document H1
- Feature docs: use `{type}` as display title (e.g. `tech`, `ui`)

**Title naming convention** (must match template):
- Project-level single file: `# {项目名} {文档类型}` (e.g. `# know 产品路线图`)
- Project-level directory type: `# {主题名} {文档类型}` (e.g. `# JSONL 索引 接口规范`)
- Requirement: `# {用户入口}` (e.g. `# /know learn`)
- Feature: `# {需求名} {文档类型}` (e.g. `# /know learn 技术方案`)

**Version section order**: newer versions appear AFTER older versions (`#### v1` then `#### v2`).

**Duplicate handling**: if an entry with the same file path already exists, update the link text and date in place using Edit tool; do not add a new line.

**Feature ordering**: append new features after existing ones under the same requirement.

**Date annotation**: every entry ends with ` | YYYY-MM-DD` (today's date).

**Parent annotation**: requirement/feature entries that have a parent add ` ← {parent type}` after the date.

Entry formats:

**Project-level single file:**
```
- [{H1 title}](.know/docs/v{n}/roadmap.md) | YYYY-MM-DD
```

**Project-level directory type:**
```
- [{H1 title}](.know/docs/v{n}/schema/{topic}.md) | YYYY-MM-DD
```

**Requirement:**
```
- [{requirement}](.know/docs/requirements/{requirement}/prd.md) | YYYY-MM-DD ← roadmap
```

**Feature (indented under requirement):**
```
  - [{feature} / tech](.know/docs/requirements/{requirement}/{feature}/tech.md) | YYYY-MM-DD ← prd
```

```
[index] CLAUDE.md document index updated
```

---

## Step 9: Confirmation

```
[written] .know/docs/v{n}/arch.md
[index] CLAUDE.md updated
```

For requirement/feature docs:

```
[written] .know/docs/requirements/{requirement}/prd.md
[index] CLAUDE.md updated
```

---

## Edge Cases

### Conversation lacks sufficient content

If conversation does not contain enough material to fill more than 30% of template sections:

```
[write] Insufficient content for {type}/{name}, missing sections:
- {missing section 1}
- {missing section 2}

Continue (missing sections marked "TBD")?
```

### CLAUDE.md does not exist

Create CLAUDE.md with `## Know` section containing `### 文档索引` with `#### v1` and `#### Requirements` headers.

### Writing multiple documents from one conversation

Process each document through the full pipeline (Step 4-9) sequentially. Share the confirmation at the end:

```
[write] Batch complete:
1. .know/docs/requirements/know-write/prd.md
2. .know/docs/requirements/know-write/write-workflow/tech.md
[index] CLAUDE.md updated
```

### Version conflict

If `v{n}/` already contains the target file when writing (race condition or stale check):

```bash
# Re-check existing version directories
ls -d .know/docs/v*/ 2>/dev/null | sort -V | tail -1
```

Ask user again whether to update in place or increment version. Do not overwrite without confirmation.
