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
/know write <hint>   # With hint (e.g. "产品需求", "tech design", feature name)
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
- prd without roadmap → proceed, note in output: "关联 roadmap 尚未创建"
- tech/ui without prd → warn user and ask:
  ```
  > [write] 未找到关联的 PRD 文档 ({expected path})
  > A) 继续写入，跳过关联
  > B) 先创建 PRD，再写当前文档
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
> [write] 从对话中检测到以下内容，请确认:
>
> 类型: arch
> 版本: v2 (当前最新 v1，新建 v2)
> 关联: 无
>
> 是否正确? [确认 / 修改]
```

**Requirement docs**:

```
> [write] 从对话中检测到以下内容，请确认:
>
> 类型: prd
> 需求: know-write
> 关联: roadmap (v1/roadmap.md)
>
> 是否正确? [确认 / 修改]
```

**Feature docs**:

```
> [write] 从对话中检测到以下内容，请确认:
>
> 类型: tech
> 需求: know-write
> 功能: write-workflow
> 关联: prd (requirements/know-write/prd.md)
>
> 是否正确? [确认 / 修改]
```

If multiple interpretations exist (e.g. conversation covers both PRD and tech design), present choices:

```
> [write] 对话中包含多种文档内容:
> 1. requirements/know-write — prd
> 2. requirements/know-write/write-workflow — tech
>
> 写哪个? [1 / 2 / 两个都写]
```

两个都写 → process sequentially, each following full pipeline from Step 4.

---

## Step 4: Load Template

```bash
# [RUN] Load document template
cat workflows/templates/{type}.md
```

If template file missing → use minimal default structure:

```markdown
# {Title}

## 概述

## 详细内容

## 开放问题
```

---

## Step 5: Extract and Fill Content

Using the loaded template as structure guide:

1. Scan full conversation for content relevant to this document type
2. Organize extracted content into template sections
3. Write complete, structured prose — not conversation fragments
4. Ensure all template sections are addressed (mark as "待定" if no conversation content covers it)
5. Do NOT include frontmatter — metadata lives in CLAUDE.md index

Content quality rules:
- Each template section must contain at least 2-3 complete sentences; if conversation lacks content for a section, keep the section header and write "待定 — {缺失原因}" as content
- Do NOT paste conversation fragments as-is; rewrite all content as standalone, readable prose
- Code examples and tables from conversation may be quoted directly
- Technical accuracy preserved from conversation; do not infer or fabricate details not discussed
- Ambiguities or open questions called out explicitly with "开放问题:" prefix
- Cross-references to related docs where applicable (use relative paths)
- Match user's language for document content (Chinese conversation → Chinese document)

---

## Step 6: Preview

Wait for user confirmation before proceeding. Display complete document for review:

```
> [write] 预览: .know/docs/v{n}/arch.md
>
> --- 文档内容 ---
> # {Title}
> ...完整文档内容...
> --- 结束 ---
>
> 确认写入? [确认 / 修改]
```

For requirement/feature docs:

```
> [write] 预览: .know/docs/requirements/{requirement}/prd.md
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
> [written] .know/docs/v{n}/arch.md
```

---

## Step 8: Update CLAUDE.md Document Index

### Index format

The document index lives in project CLAUDE.md under `## Know` → `### 文档索引`:

```markdown
## Know

### 文档索引

#### v1
- [Roadmap](.know/docs/v1/roadmap.md)
- [架构设计](.know/docs/v1/arch.md)
- [JSONL Schema](.know/docs/v1/schema/jsonl-index.md)
- [存储方案选择](.know/docs/v1/decision/storage-choice.md)

#### Requirements
- [know-write](.know/docs/requirements/know-write/prd.md)
  - [write-workflow / tech](.know/docs/requirements/know-write/write-workflow/tech.md)
  - [write-workflow / ui](.know/docs/requirements/know-write/write-workflow/ui.md)
```

### Update procedure

1. Read current CLAUDE.md
2. If `## Know` section missing → create it with `### 文档索引`, `#### v1` and `#### Requirements` headers
3. For project-level docs → find or create the `#### v{n}` section header, add/update entry
4. For requirement docs → find or create `#### Requirements`, add/update entry for `{requirement}`
5. For feature docs → find the `{requirement}` entry under `#### Requirements`, add/update indented sub-entry

**Display title rule**: read the document's first line (`# xxx`), use `xxx` as the display title.

**Requirement display title**: use the requirement slug as display title (e.g. `know-write`), not the document H1.

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
> [index] CLAUDE.md 文档索引已更新
```

---

## Step 9: Confirmation

```
> [write] 完成
> 文档: .know/docs/v{n}/arch.md
> 索引: CLAUDE.md 已更新
```

For requirement/feature docs:

```
> [write] 完成
> 文档: .know/docs/requirements/{requirement}/prd.md
> 索引: CLAUDE.md 已更新
```

---

## Edge Cases

### Conversation lacks sufficient content

If conversation does not contain enough material to fill more than 30% of template sections:

```
> [write] 对话中关于 {type}/{name} 的内容不足，以下部分缺失:
> - {missing section 1}
> - {missing section 2}
>
> 继续写入 (缺失部分标记为"待定")? [确认 / 跳过]
```

### CLAUDE.md does not exist

Create CLAUDE.md with `## Know` section containing `### 文档索引` with `#### v1` and `#### Requirements` headers.

### Writing multiple documents from one conversation

Process each document through the full pipeline (Step 4-9) sequentially. Share the confirmation at the end:

```
> [write] 批量完成:
> 1. .know/docs/requirements/know-write/prd.md
> 2. .know/docs/requirements/know-write/write-workflow/tech.md
> 索引: CLAUDE.md 已更新
```

### Version conflict

If `v{n}/` already contains the target file when writing (race condition or stale check):

```bash
# Re-check existing version directories
ls -d .know/docs/v*/ 2>/dev/null | sort -V | tail -1
```

Ask user again whether to update in place or increment version. Do not overwrite without confirmation.
