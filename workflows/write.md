# write — Document Authoring

## Progress

Steps: 8
Names: Trigger, Infer, Confirm, Template, Fill, Preview, Write, Index

Shared definitions (output blocks, paths) → SKILL.md.

---

## Document Types

### Path Resolution (single source of truth)

All steps reference this table for path generation. `DOCS = .know/docs`.

| Type | Full Path | Example |
|------|-----------|---------|
| roadmap | `DOCS/v{n}/roadmap.md` | `.know/docs/v3/roadmap.md` |
| arch | `DOCS/v{n}/arch.md` | `.know/docs/v2/arch.md` |
| ops | `DOCS/v{n}/ops.md` | `.know/docs/v1/ops.md` |
| marketing | `DOCS/v{n}/marketing.md` | `.know/docs/v1/marketing.md` |
| schema | `DOCS/v{n}/schema/{topic}.md` | `.know/docs/v2/schema/jsonl-index.md` |
| decision | `DOCS/v{n}/decision/{topic}.md` | `.know/docs/v1/decision/storage-format.md` |
| prd | `DOCS/requirements/{req}/prd.md` | `.know/docs/requirements/know-learn/prd.md` |
| tech | `DOCS/requirements/{req}/impl/tech.md` | `.know/docs/requirements/know-learn/impl/tech.md` |
| ui | `DOCS/requirements/{req}/impl/ui.md` | `.know/docs/requirements/know-write/impl/ui.md` |

Variables:
- `{n}` — version number, detected in Step 3
- `{req}` — requirement slug, kebab-case (e.g. `know-learn`)
- `{topic}` — topic slug, kebab-case (e.g. `jsonl-index`)
- `impl` — **fixed directory**, not a variable. All tech/ui docs live under `impl/`.

### Hierarchy

roadmap → prd → tech / ui. Tree-style downward indexing only, no back-references in documents.

### Progress Tracking

roadmap tracks PRD progress in milestone table. PRD tracks tech progress in task table (§4 方案). Tech tracks iterations in §4 迭代记录.

### Versioning

Project-level versions by directory (v1→v2). Each version directory is self-contained — do not include other versions' content. Milestone numbering restarts from M1 per version. Requirement/implementation docs overwrite in place.

---

## Step 1: Trigger

Model: sonnet

```
/know write          → infer all params from conversation
/know write <hint>   → hint assists type/name inference
```

Gate (auto): conversation has ≥3 substantive messages → enter. <3 → warn insufficient context, ask user to point to specific content.

---

## Step 2: Infer

Model: opus

Gate (always): runs after trigger.

### 2a: Type

| Signal | Type |
|--------|------|
| Priorities, milestones, timeline | roadmap |
| Module decomposition, infrastructure | arch |
| Release, feedback loop, iteration | ops |
| Promotion, content strategy, launch | marketing |
| Endpoint, request/response, protocol | schema |
| Trade-off analysis, option comparison | decision |
| User stories, acceptance criteria, scope | prd |
| Data model, sequence diagram, implementation | tech |
| Wireframe, interaction flow, component spec | ui |

Hint provided → match against type names first. Hint does not match any type name → ignore hint, fall back to signal-based inference.

**Default**: ≥2 types tied → list, ask user. 0 matches → ask user.

### 2b: Name/Topic

| Level | Rule |
|-------|------|
| Project single (roadmap, arch, ops, marketing) | No name needed |
| Project directory (schema, decision) | Extract `{topic}` → kebab-case slug |
| Requirement (prd) | Extract `{req}` → kebab-case slug |
| Implementation (tech, ui) | Extract `{req}` → kebab-case slug. Directory `impl/` is fixed, not inferred. |

**Default**: name unextractable → ask user.

### 2c: New or Update

- **Project-level (non-roadmap)**: same roadmap version rule applies — new capability/direction → new `v{n+1}`, in-version update → `mode=update` on current `v{n}`. Default: ask user `新建 v{n+1}` or `更新 v{n}`.
- **Requirement/implementation**: file exists → `mode=update`. File absent → `mode=create` (default).

**Roadmap version rule** — roadmap has special versioning based on change type:

| Change type | Signal | Action |
|-------------|--------|--------|
| 新增产品版本规划 | 对话包含新版本的毕业标准或里程碑 | 新建 `v{n+1}/roadmap.md`，只包含新版本内容，不夹带历史版本 |
| 当前版本内变更 | 修改里程碑进度、调整排除项、更新风险 | 原地更新当前 `v{n}/roadmap.md`（`mode=update`） |

判定后在 Step 3 展示供用户确认：`新建 v{n+1}` 或 `更新 v{n}`。

### 2d: Parent

| Type | Parent |
|------|--------|
| prd | roadmap |
| tech, ui | prd |
| others | none |

**Missing parent**: prd without roadmap → proceed, note absence. tech/ui without prd → [STOP:choose] `A) Continue without parent  B) Create PRD first`

**PRD milestone association**: when creating a PRD, infer which roadmap milestone it belongs to from conversation context. If ambiguous → ask user to specify milestone number. This determines where the PRD link appears in the roadmap milestone table.

---

## Step 3: Confirm [STOP:confirm]

Model: sonnet

Gate (always): user must confirm inferred params before proceeding.

For project-level docs, detect latest version:

```bash
# [RUN]
ls -d .know/docs/v*/ 2>/dev/null | sort -V | tail -1
```

No `v*/` → v1. Latest `v{n}/` → v{n+1}.

Resolve full path from Path Resolution table, then show:

```
[write] Inferred from conversation:
Type: arch | Path: .know/docs/v2/arch.md | Mode: create | Parent: none
Correct?
```

Multiple types → [STOP:choose] list with `[1 / 2 / both]`. Both → sequential from Step 4.

**Parameter correction**: if user changes type during confirm → re-infer name/topic (name depends on type). If user changes name → no re-inference needed for other params.

---

## Step 4: Template

Model: sonnet

Gate (always): runs after user confirms params.

Load template using project root from Script Paths (→ SKILL.md):

```bash
# [RUN]
cat "{project_root}/workflows/templates/{type}.md"
```

**Default**: template missing → fallback: `# {Title}` / `## Overview` / `## Details` / `## Open Questions`.

---

## Step 5: Fill

Model: opus

Gate (always): template loaded from Step 4.

### Create mode

1. Scan full conversation for content matching this document type
2. Organize into template sections as structured prose
3. Follow each section's `<!-- INCLUDE/EXCLUDE -->` guide
4. Each section: ≥3 sentences; if insufficient → `TBD — {what's missing}`
5. Preserve technical accuracy; do not fabricate unstated details
6. Ambiguities → prefix with `Open question:`
7. Code examples and tables: quote directly from conversation
8. Cross-references: paths relative to project root (same base as Path Resolution table, e.g. `.know/docs/requirements/know-learn/prd.md`). Match user's language for content.

#### Progress fields (create mode)

| Type | Field | Rule |
|------|-------|------|
| roadmap | 里程碑.进度 | Count existing PRDs linked to this milestone. Format: `完成数/总数` |
| roadmap | 里程碑.需求 | Link to each PRD under this milestone. `—` if none yet |
| prd | §4 方案.任务表 | List each tech doc as one row. Progress = `完成数/总数` (count by existence of 迭代记录 entries) |
| tech | §4 迭代记录 | Add initial entry with today's date and sprint summary |
| roadmap | 里程碑编号 | Each version starts from M1. Do not continue numbering from previous version. |

### Update mode (`mode=update`)

Targeted section update, not full rewrite:

1. Read existing document in full
2. Identify which sections the conversation discusses (output section list)
3. Only regenerate affected sections; untouched sections remain verbatim
4. Same quality rules as create mode per section

| Check | Action |
|-------|--------|
| Section discussed in conversation | Regenerate from conversation content |
| Section not discussed | Preserve verbatim |
| New template section not in existing doc | Add with conversation content or `TBD` |
| Broken relative paths in touched sections | Fix or remove |
| H1 title | Must follow Title Convention (→ Step 8) |
| No existing section discussed in conversation | Warn user "对话未涉及已有内容，是否要新增 section？" [STOP:choose] A) Add new content B) Cancel |

#### Update mode for tech

Tech docs are iteratively refined across multiple sprints. Update mode has special behavior:

1. §2 方案: update as understanding deepens (overwrite)
2. §3 关键决策: append new rows to existing table
3. §4 迭代记录: prepend new entry (newest first) with today's date and sprint summary. Never overwrite existing entries.

---

## Step 6: Preview [STOP:confirm]

Model: sonnet

Gate (always): filled content from Step 5 must be previewed before writing.

**Gate**: filled content covers <30% of template sections →

```
[write] Insufficient content for {type}, missing:
- {section 1}
- {section 2}
Continue with missing sections marked TBD?
```

[STOP:confirm] User confirms → show preview. User cancels → abort.

Use the full path resolved in Step 3 (from Path Resolution table).

**Create mode**:
```
[write] Preview: .know/docs/requirements/know-learn/impl/tech.md

{full document content}

Write?
```

**Update mode** — changed sections as diff:
```
[write] Update preview: .know/docs/v3/roadmap.md

## {Section A}
- {old content summary}
+ {new content summary}

## {Section B}
- {old content summary}
+ {new content summary}

Write?
```

Confirms → Step 7. Requests edits → adjust, re-display.

---

## Step 7: Write

Model: sonnet

Gate (auto): user confirmed preview in Step 6 → enter. User cancelled → abort.

Use the full path resolved in Step 3 (from Path Resolution table).

**Create mode**:

```bash
# [RUN] Create parent directory from resolved path
mkdir -p "$(dirname ".know/docs/requirements/know-learn/impl/tech.md")"
```

Write file using Write tool to the resolved path.

If target file already exists in create mode → switch to update mode (re-enter Step 5 with `mode=update`). Do not overwrite without user consent.

```
[written] .know/docs/requirements/know-learn/impl/tech.md
```

**Update mode**:

Use Edit tool to replace each changed section individually.

For tech docs: prepend new entry to §4 迭代记录 (no separate changelog needed).

```
[written] .know/docs/v3/roadmap.md (updated 2 sections)
```

---

## Step 8: Index

Model: sonnet

Gate (auto): document written successfully in Step 7 → enter.

Index location: CLAUDE.md → `## Know` → `### 文档索引`.

### Entry Format

Paths must match Path Resolution table exactly.

| Level | Format | Example |
|-------|--------|---------|
| Project single | `- [{H1}](.know/docs/v{n}/{file}) \| YYYY-MM-DD` | `- [know 产品路线图](.know/docs/v3/roadmap.md) \| 2026-04-14` |
| Project directory | `- [{H1}](.know/docs/v{n}/{type}/{topic}.md) \| YYYY-MM-DD` | `- [JSONL 索引 接口规范](.know/docs/v2/schema/jsonl-index.md) \| 2026-04-14` |
| Requirement | `- [{req}](.know/docs/requirements/{req}/prd.md) \| YYYY-MM-DD` | `- [know-learn](.know/docs/requirements/know-learn/prd.md) \| 2026-04-10` |
| Implementation | `  - [{type}](.know/docs/requirements/{req}/impl/{type}.md) \| YYYY-MM-DD` | `  - [tech](.know/docs/requirements/know-learn/impl/tech.md) \| 2026-04-10` |

### Title Convention

| Level | Pattern | Example |
|-------|---------|---------|
| Project single | `{项目名} {文档类型}` | `know 产品路线图` |
| Project directory | `{主题名} {文档类型}` | `JSONL 索引 接口规范` |
| Requirement | `{用户入口}` | `/know learn` |
| Implementation | `{需求名} {文档类型}` | `/know learn 技术方案` |

### Display Title

| Level | Rule |
|-------|------|
| Project-level | Read H1 from document |
| Requirement | Use requirement slug (not H1) |
| Implementation | Use type name (e.g. `tech`, `ui`) |

### Index Rules

- Version sections: chronological (`#### v1` before `#### v2`)
- Duplicate path → update in place, do not add new line
- Implementation docs (tech, ui) → append after existing entries under same requirement
- Date → today (`YYYY-MM-DD`)
- Missing `## Know` → create with `### 文档索引`, `#### v1`, `#### Requirements`
- Missing version section (e.g. `#### v3`) → create it after existing version sections, before `#### Requirements`

```
[index] CLAUDE.md updated
```

### Progress Propagation

After writing a child document, update progress in its parent document:

| Written type | Parent update |
|-------------|---------------|
| tech | Update parent PRD §4 方案 task table: find this tech's row, update 进度 column |
| prd | Update parent roadmap milestone table: recalculate 进度 as `完成PRD数/总PRD数` for the milestone |

Progress update uses Edit tool on the parent document. Only update the progress field, do not modify other content.

**Parent not found**: if parent document does not exist (e.g. writing tech but no prd) → skip progress propagation silently. Do not create parent.

```
[progress] {parent path} updated ({progress value})
```

### Cascade Marking

After index update, check if written type has child relationships:

| Parent type | Child types |
|-------------|-------------|
| roadmap | prd |
| prd | tech, ui |

If children exist in index, append `⚠ needs update` to each direct child entry:

```
- [know-learn](.know/docs/requirements/know-learn/prd.md) | 2026-04-10 ⚠ needs update
```

Rules:
- Only mark direct children, do not recurse
- Skip entries already marked `⚠ needs update`
- Use Edit tool to append marker

```
[cascade] {N} downstream docs marked for update
```

### Marker Clearing

When writing in update mode, remove `⚠ needs update` from its index entry (if present).

```
[index] CLAUDE.md updated (⚠ cleared)
```

---

## Completion

- Document written to correct path
- CLAUDE.md index updated with correct format, date, and parent annotation
- User saw `[written]` and `[index]` confirmations

## Recovery

| Error | Recovery |
|-------|----------|
| Write tool fails | Show error path and message. Do not retry silently. |
| CLAUDE.md malformed | Find `## Know` by content, not line number. If absent, create. |
| Index entry wrong format | Fix in place using Edit tool. |
| Version directory conflict | Re-check `v*/`, ask user: update in place or increment. |

## Examples

### Parameter confirmation

```
[write] Inferred from conversation:
Type: prd | Path: .know/docs/requirements/know-write/prd.md | Mode: create | Parent: roadmap
Correct?
```
