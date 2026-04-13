# write — Document Authoring

## Progress

Steps: 8
Names: Trigger, Infer, Confirm, Template, Fill, Preview, Write, Index

Shared definitions (output blocks, paths) → SKILL.md.

---

## Document Types

### Project-level (`v{n}/`)

| Type | Path | Multi-file |
|------|------|:----------:|
| roadmap | `v{n}/roadmap.md` | |
| arch | `v{n}/arch.md` | |
| ops | `v{n}/ops.md` | |
| marketing | `v{n}/marketing.md` | |
| schema | `v{n}/schema/{topic}.md` | ✓ |
| decision | `v{n}/decision/{topic}.md` | ✓ |

### Requirement-level (`requirements/{req}/`)

| Type | Path |
|------|------|
| prd | `prd.md` |

### Feature-level (`requirements/{req}/{feature}/`)

| Type | Path |
|------|------|
| tech | `tech.md` |
| ui | `ui.md` |

**Hierarchy**: roadmap → prd → tech / ui. Tree-style downward indexing only, no back-references in documents.

**Progress tracking**: roadmap tracks PRD progress in milestone table. PRD tracks tech progress in task table (§4 方案). Tech tracks iterations in §4 迭代记录.

**Versioning**: project-level versions by directory (v1→v2). Requirement/feature overwrite in place.

---

## Step 1: Trigger

Model: sonnet

```
/know write          → infer all params from conversation
/know write <hint>   → hint assists type/name inference
```

**Gate**: conversation has <3 substantive messages → warn insufficient context, ask user to point to specific content.

---

## Step 2: Infer

Model: opus

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

Hint provided → match against type names first.

**Default**: ≥2 types tied → list, ask user. 0 matches → ask user.

### 2b: Name/Topic

| Level | Rule |
|-------|------|
| Project single (roadmap, arch, ops, marketing) | No name needed |
| Project directory (schema, decision) | Extract topic → kebab-case slug |
| Requirement (prd) | Extract requirement name → kebab-case slug |
| Feature (tech, ui) | Extract requirement + feature → kebab-case slugs |

**Default**: name unextractable → ask user.

### 2c: New or Update

- **Project-level**: file exists in any `v*/` → new version (v{n+1}). No `v*/` → v1.
- **Requirement/feature**: file exists → `mode=update`. File absent → `mode=create` (default).

### 2d: Parent

| Type | Parent |
|------|--------|
| prd | roadmap |
| tech, ui | prd |
| others | none |

**Missing parent**: prd without roadmap → proceed, note absence. tech/ui without prd → [STOP:choose] `A) Continue without parent  B) Create PRD first`

---

## Step 3: Confirm [STOP:confirm]

Model: sonnet

For project-level docs, detect latest version:

```bash
# [RUN]
ls -d .know/docs/v*/ 2>/dev/null | sort -V | tail -1
```

No `v*/` → v1. Latest `v{n}/` → v{n+1}.

Show all params:

```
[write] Inferred from conversation:
Type: arch | Version: v2 (latest: v1) | Parent: none
Correct?
```

Multiple types → [STOP:choose] list with `[1 / 2 / both]`. Both → sequential from Step 4.

---

## Step 4: Template

Model: sonnet

```bash
# [RUN]
cat workflows/templates/{type}.md
```

**Default**: template missing → fallback: `# {Title}` / `## Overview` / `## Details` / `## Open Questions`.

---

## Step 5: Fill

Model: opus

### Create mode

1. Scan full conversation for content matching this document type
2. Organize into template sections as structured prose
3. Follow each section's `<!-- INCLUDE/EXCLUDE -->` guide
4. Each section: ≥3 sentences; if insufficient → `TBD — {what's missing}`
5. Preserve technical accuracy; do not fabricate unstated details
6. Ambiguities → prefix with `Open question:`
7. Code examples and tables: quote directly from conversation
8. Cross-references: relative paths. Match user's language for content.

#### Progress fields (create mode)

| Type | Field | Rule |
|------|-------|------|
| roadmap | 里程碑.进度 | Count existing PRDs linked to this milestone. Format: `完成数/总数` |
| roadmap | 里程碑.需求 | Link to each PRD under this milestone. `—` if none yet |
| prd | §4 方案.任务表 | List each tech doc as one row. Progress = `完成数/总数` (count by existence of 迭代记录 entries) |
| tech | §4 迭代记录 | Add initial entry with today's date and sprint summary |

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

#### Update mode for tech

Tech docs are iteratively refined across multiple sprints. Update mode has special behavior:

1. §2 方案: update as understanding deepens (overwrite)
2. §3 关键决策: append new rows to existing table
3. §4 迭代记录: prepend new entry (newest first) with today's date and sprint summary. Never overwrite existing entries.

---

## Step 6: Preview [STOP:confirm]

Model: sonnet

**Gate**: filled content covers <30% of template sections →

```
[write] Insufficient content for {type}, missing:
- {section 1}
- {section 2}
Continue with missing sections marked TBD?
```

[STOP:confirm] User confirms → show preview. User cancels → abort.

**Create mode**:
```
[write] Preview: .know/docs/{path}

{full document content}

Write?
```

**Update mode** — changed sections as diff:
```
[write] Update preview: .know/docs/{path}

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

**Create mode**:

```bash
# [RUN]
mkdir -p .know/docs/{parent-dir}
```

Write file using Write tool to target path.

```
[written] .know/docs/{path}
```

**Update mode**:

Use Edit tool to replace each changed section individually.

For tech docs: prepend new entry to §4 迭代记录 (no separate changelog needed).

```
[written] .know/docs/{path} (updated {N} sections)
```

---

## Step 8: Index

Model: sonnet

Index location: CLAUDE.md → `## Know` → `### 文档索引`.

### Entry Format

| Level | Format |
|-------|--------|
| Project single | `- [{H1}](.know/docs/v{n}/{file}) \| YYYY-MM-DD` |
| Project directory | `- [{H1}](.know/docs/v{n}/{type}/{topic}.md) \| YYYY-MM-DD` |
| Requirement | `- [{req}](.know/docs/requirements/{req}/prd.md) \| YYYY-MM-DD` |
| Feature | `  - [{type}](.know/docs/requirements/{req}/{feature}/{type}.md) \| YYYY-MM-DD` |

### Title Convention

| Level | Pattern | Example |
|-------|---------|---------|
| Project single | `{项目名} {文档类型}` | `know 产品路线图` |
| Project directory | `{主题名} {文档类型}` | `JSONL 索引 接口规范` |
| Requirement | `{用户入口}` | `/know learn` |
| Feature | `{需求名} {文档类型}` | `/know learn 技术方案` |

### Display Title

| Level | Rule |
|-------|------|
| Project-level | Read H1 from document |
| Requirement | Use requirement slug (not H1) |
| Feature | Use type name (e.g. `tech`, `ui`) |

### Index Rules

- Version sections: chronological (`#### v1` before `#### v2`)
- Duplicate path → update in place, do not add new line
- Features → append after existing entries under same requirement
- Date → today (`YYYY-MM-DD`)
- Missing `## Know` → create with `### 文档索引`, `#### v1`, `#### Requirements`

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
Type: prd | Requirement: know-write
Correct?
```
