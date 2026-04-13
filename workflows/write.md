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

**Hierarchy**: roadmap → prd → tech / ui. Others (arch, decision, ops, marketing, schema) are independent.

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

| Conversation Signal | Type |
|-------------------|------|
| Priorities, milestones, timeline | roadmap |
| Module decomposition, infrastructure | arch |
| Release, feedback loop, iteration | ops |
| Promotion, content strategy, launch | marketing |
| Endpoint, request/response, protocol | schema |
| Trade-off analysis, option comparison | decision |
| User stories, acceptance criteria, scope | prd |
| Data model, sequence diagram, implementation | tech |
| Wireframe, interaction flow, component spec | ui |

Hint provided → match against type names and descriptions first.

**Default**: matches ≥2 types equally → list matched types, ask user to choose. Matches 0 → ask user to specify type.

### 2b: Name/Topic

| Level | Rule |
|-------|------|
| Project single (roadmap, arch, ops, marketing) | No name needed |
| Project directory (schema, decision) | Extract topic → kebab-case slug |
| Requirement (prd) | Extract requirement name → kebab-case slug |
| Feature (tech, ui) | Extract requirement + feature names → kebab-case slugs |

**Default**: name unextractable → ask user to provide.

### 2c: New or Update

- **Project-level**: file exists in any `v*/` → new version (v{n+1}). No `v*/` → v1.
- **Requirement/feature**: file exists → **update mode**. File absent → create mode.

**Update mode flag**: set `mode=update` for downstream steps. Create mode is default (`mode=create`).

### 2d: Parent

| Type | Parent |
|------|--------|
| prd | roadmap |
| tech, ui | prd |
| others | none |

**Missing parent**:
- prd without roadmap → proceed, note "Related roadmap not yet created"
- tech/ui without prd → [STOP:choose] `A) Continue without parent  B) Create PRD first`

---

## Step 3: Confirm [STOP:confirm]

Model: sonnet

For project-level docs, check version first:

```bash
# [RUN]
ls -d .know/docs/v*/ 2>/dev/null | sort -V | tail -1
```

No `v*/` → default v1. Latest `v{n}/` → default v{n+1}.

Show all params in one block:

```
[write] Inferred from conversation:
Type: arch | Version: v2 (latest: v1) | Parent: none
Correct?
```

Multiple types detected → [STOP:choose] list with `[1 / 2 / both]`. Both → sequential processing from Step 4.

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

1. Scan full conversation for content matching this document type
2. Organize into template sections as structured prose — not conversation fragments
3. Follow each section's `<!-- INCLUDE/EXCLUDE -->` guide in template
4. Each section: ≥3 sentences of original prose; if insufficient → `TBD — {what's missing}`
5. Preserve technical accuracy from conversation; do not fabricate or infer unstated details
6. Ambiguities → prefix with `Open question:`
7. Code examples and tables from conversation: quote directly
8. Cross-references: relative paths. Match user's language for content.

**Update mode** (`mode=update`) — targeted section update, not full rewrite:

1. Read existing document in full
2. Identify which sections the current conversation discusses (output section list)
3. Only regenerate content for those sections; untouched sections remain exactly as-is
4. For each affected section, follow the same quality rules as create mode (≥3 sentences, no fabrication)
5. Generate changelog entry: `- YYYY-MM-DD: {one-line summary of what changed}`

| Check | Action |
|-------|--------|
| Conversation discusses a section | Regenerate that section from conversation content |
| Section not discussed | **Do not touch** — preserve existing content verbatim |
| New section from template not in existing doc | Add with content from conversation or `TBD` |
| Broken relative paths in touched sections | Fix to valid paths or remove |
| H1 title | Must follow naming convention (→ Step 8 Title Convention) |

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

**Update mode** — show only changed sections as diff:
```
[write] Update preview: .know/docs/{path}

## {Section A}
- {old content summary}
+ {new content summary}

## {Section B}
- {old content summary}
+ {new content summary}

Changelog: - YYYY-MM-DD: {summary}

Write?
```

Confirms → Step 7. Requests edits → adjust content, re-display preview.

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

Use Edit tool to replace each changed section individually. Then append changelog entry at document end:

```markdown
## Changelog
- YYYY-MM-DD: {one-line summary}
```

If `## Changelog` section already exists, append new entry to it (most recent last).

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
| Requirement | `- [{req}](.know/docs/requirements/{req}/prd.md) \| YYYY-MM-DD ← roadmap` |
| Feature | `  - [{type}](.know/docs/requirements/{req}/{feature}/{type}.md) \| YYYY-MM-DD ← prd` |

### Title Convention (H1)

| Level | Pattern | Example |
|-------|---------|---------|
| Project single | `{项目名} {文档类型}` | `know 产品路线图` |
| Project directory | `{主题名} {文档类型}` | `JSONL 索引 接口规范` |
| Requirement | `{用户入口}` | `/know learn` |
| Feature | `{需求名} {文档类型}` | `/know learn 技术方案` |

### Display Title (link text)

| Level | Rule |
|-------|------|
| Project-level | Read H1 from document |
| Requirement | Use requirement slug (not H1) |
| Feature | Use type name (e.g. `tech`, `ui`) |

### Index Rules

- Version sections: chronological (`#### v1` before `#### v2`)
- Duplicate path → update in place (Edit tool), do not add new line
- Features → append after existing entries under same requirement
- Date → today (`YYYY-MM-DD`)
- Parent → ` ← {parent type}` suffix
- Missing `## Know` → create with `### 文档索引`, `#### v1`, `#### Requirements`

```
[index] CLAUDE.md updated
```

### Cascade Marking

After index update, check if the written document type has child relationships:

| Parent type | Child types |
|-------------|-------------|
| roadmap | prd |
| prd | tech, ui |

If children exist in the index, append `⚠ needs update` marker to each direct child entry:

```
- [know-learn](.know/docs/requirements/know-learn/prd.md) | 2026-04-10 ← roadmap ⚠ needs update
```

Rules:
- Only mark **direct** children, do not recurse (roadmap marks prd, not tech)
- Skip entries that already have the `⚠ needs update` marker
- Use Edit tool to append marker to each affected index line

```
[cascade] {N} downstream docs marked for update
```

### Marker Clearing

When writing a document in **update mode**, remove `⚠ needs update` from its index entry (if present).

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
