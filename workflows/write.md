# write — Document Authoring

## Progress

Steps: 8
Names: Resolve, Sufficiency, Confirm, Template, Fill, Write, Validate, Progress

Shared definitions (output blocks, paths) → SKILL.md.

---

## Document Types

### Path Resolution (single source of truth)

All steps reference this table for path generation. `DOCS = docs` (project root).

| Type | Level | Full Path | Example |
|------|-------|-----------|---------|
| roadmap | 项目单文件 | `DOCS/roadmap.md` | `docs/roadmap.md` |
| capabilities | 项目单文件 | `DOCS/capabilities.md` | `docs/capabilities.md` |
| ops | 项目单文件 | `DOCS/ops.md` | `docs/ops.md` |
| marketing | 项目单文件 | `DOCS/marketing.md` | `docs/marketing.md` |
| arch | 项目目录 | `DOCS/arch/{topic}.md` | `docs/arch/know-ctl.md` |
| ui | 项目目录 | `DOCS/ui/{topic}.md` | `docs/ui/index-page.md` |
| schema | 项目目录 | `DOCS/schema/{topic}.md` | `docs/schema/jsonl-index.md` |
| decision | 项目目录 | `DOCS/decision/{topic}.md` | `docs/decision/storage-format.md` |
| prd | 需求 | `DOCS/requirements/{req}/prd.md` | `docs/requirements/know-learn/prd.md` |
| tech | 需求 | `DOCS/requirements/{req}/tech.md` | `docs/requirements/know-learn/tech.md` |

Variables:
- `{req}` — requirement slug, kebab-case (e.g. `know-learn`)
- `{topic}` — topic slug, kebab-case (e.g. `jsonl-index`)

### Hierarchy

roadmap → prd → tech. Tree-style downward indexing only, no back-references. All other types are independent.

### Progress Tracking

roadmap tracks PRD progress in milestone table. PRD tracks tech progress in task table (§4 方案). Tech tracks iterations in §4 迭代记录.

### Versioning

All docs are single files, git manages history. Roadmap contains all versions as `### v{n}` sections within `## 2. 版本规划`. New version = append new section + update `## 3. 当前版本`. Milestone numbering restarts from M1 per version.

---

## Step 1: Resolve

Model: opus

Parse entry point and infer all parameters in one pass.

```
/know write          → infer all params from conversation
/know write <hint>   → hint assists type/name inference
```

Conversation has <3 substantive messages → warn insufficient context, ask user to point to specific content.

### 1a: Type Inference

Determine the document type from user input and conversational context.

**Signature**
- Input: `hint` (optional string from `/know write <hint>`), `conversation` (the session transcript), `user_replies[]` (user responses to clarifying prompts)
- Output: `type ∈ {roadmap, prd, tech, arch, decision, schema, ui, capabilities, ops, marketing}`, or `abort` when two consecutive responses are invalid
- Validation fixture: `tests/write/type-inference.jsonl`

#### Decision procedure

```
1. If hint resolves to a valid type (case-insensitive match against the 10 types):
     → accept and return.

2. Otherwise, apply the inference check below:
     2a. Check passes for exactly one type        → return that type.
     2b. Check passes for all types in one group  → ask Q2 for that group.
     2c. Check fails, or passes across groups     → ask Q1, then Q2.

3. If the user's reply fails to map to a valid type:
     → present the full list of 10 types for explicit selection.
     → a second invalid reply terminates the step with `abort`.
```

#### Inference check

Ask this question internally against each type's exemplar:

> 如果把完整对话替换成该 type 的 exemplar，一个新读者是否还能还原出同一份写作意图？

- 仅对某一 type 答 **yes** → 2a（返回该 type）
- 对某组（A/B/C）内所有 type 答 yes，无法再窄 → 2b（问该组 Q2）
- 所有 type 都答 no，或跨组都 yes → 2c（从 Q1 开始问）

**示例**

| 对话片段 | 最接近的 exemplar | 判决 |
|---|---|---|
| "recall 用 SQLite，WAL 模式，按 project_id 分表" | tech: "采用 SQLite 存储；启用 WAL 模式；按 project_id 分表" | 2a → `tech` |
| "聊了方案，但还没定画架构还是记录选型" | arch / decision（B 组内） | 2b → 问 Q2-B |
| "零散想法，涉及版本规划、UI 风格、上线节奏" | 跨 A/C 组，无单一最近者 | 2c → 问 Q1 |

#### Type catalog (reference exemplars)

`Inference check` 对照的锚点。

| Type | Exemplar |
|---|---|
| roadmap | "v1 交付 A/B/C；v2 扩展 D；Q2 发布" |
| prd | "用户可上传 pdf；上传成功率目标 95%" |
| tech | "采用 SQLite 存储；启用 WAL 模式；按 project_id 分表" |
| arch | "recall 模块由 scope 推断、query、rank 三段构成" |
| decision | "选用 JSONL 而非 SQLite，因其 diff 友好" |
| schema | "POST /api/v2/users 接口请求体包含 name、email" |
| capabilities | "系统支持文件上传、OCR、全文检索" |
| ui | "点击按钮触发弹窗；表单分三段" |
| ops | "发布后收集反馈；两周一次迭代" |
| marketing | "通过博客、Twitter、官网 landing 多渠道推广" |

#### Clarifying prompts

**Q1 — top-level group**

```
你要写哪类文档？
  A) 计划 / 需求         (roadmap, prd)
  B) 技术方案            (tech, arch, decision, schema)
  C) 产品 / 运营介绍     (capabilities, ui, ops, marketing)
```

**Q2 — by group**

| Branch | Options |
|---|---|
| Q2-A | A) 项目总计划 / 版本规划 → `roadmap`  ·  B) 单需求的用户故事 / 验收标准 → `prd` |
| Q2-B | A) 实现细节 / 数据流 → `tech`  ·  B) 系统架构 / 模块分解 → `arch`  ·  C) 决策记录 → `decision`  ·  D) 接口 / 数据结构 → `schema` |
| Q2-C | A) 对外功能清单 → `capabilities`  ·  B) 界面 / 交互 → `ui`  ·  C) 运营流程 → `ops`  ·  D) 推广方案 → `marketing` |

#### Reply parsing

- **Accepted forms** — a letter (`A`/`B`/`C`/`D`) or an explicit type name (e.g. `prd`).
- An explicit type name short-circuits pending Q2 and is adopted directly.
- Any other reply — including `其他`, `都不是`, unknown words, or type names outside the catalog — is treated as invalid.

#### Hard rules

- Normalize all string inputs to lowercase before matching.
- A valid `hint` is adopted without further prompting.
- An invalid reply triggers exactly one fallback prompt listing all 10 types; a second invalid reply terminates with `abort`. No inference or guessing is permitted after this point.
- Clarifying prompts must display the full option set; never abbreviate.
- Step 2a returns a type only if the `Inference check` yields **yes for exactly one** type. Any broader match downgrades to 2b/2c.

### 1b: Name/Topic

| Level | Rule |
|-------|------|
| Project single (roadmap, capabilities, ops, marketing) | No name needed |
| Project directory (arch, ui, schema, decision) | Extract `{topic}` → kebab-case slug |
| Requirement (prd, tech) | Extract `{req}` → kebab-case slug |

**Default**: name unextractable → ask user.

### 1c: New or Update

File exists → `mode=update`. File absent → `mode=create`.

Roadmap is always a single file. New version = `mode=update` (append `### v{n+1}` section to § 2, update § 3).

### 1d: Parent

| Type | Parent |
|------|--------|
| prd | roadmap |
| tech | prd |
| others | none |

**Missing parent**: prd without roadmap → proceed, note absence. tech without prd → [STOP:choose] `A) Continue without parent  B) Create PRD first`

**PRD milestone association**: infer which roadmap milestone the PRD belongs to from conversation context. Ambiguous → ask user to specify milestone number.

---

## Step 1.5: Sufficiency Gate

Model: sonnet

Gate: document type is prd/tech/arch/schema/decision/ui (high-risk types). Other types → skip.

```bash
# [RUN]
cat "{project_root}/workflows/templates/sufficiency-gate.md"
```

Find the question group for this document type. Answer each question yes/no based on conversation content.

| Result | Condition | Action |
|--------|-----------|--------|
| 充足 | 全部 yes | 正常继续 Step 2 |
| 降级 | 任一 no | 提示降级选项 [STOP:choose] |
| 拒绝 | 全部 no | 提示补充信息 |

```
[write] 充分性检查: {type}
- ✅ Q1: {问题} — {判定依据}
- ❌ Q2: {问题} — {不满足原因}
建议: A) 补充信息后重新创建  B) 降级为 {降级目标}
```

User chooses B → switch type/path to degraded target, re-enter Step 1 with new type.

---

## Step 2: Confirm [STOP:confirm]

Model: sonnet

Resolve full path from Path Resolution table, then show:

```
[write] Inferred from conversation:
Type: arch | Path: docs/arch/know-ctl.md | Mode: create | Parent: none
Correct?
```

Multiple types → [STOP:choose] list with `[1 / 2 / both]`. Both → sequential from Step 3.

**Parameter correction**: user changes type → re-infer name/topic. User changes name → no re-inference needed.

---

## Step 3: Template

Model: sonnet

Load template using project root from Script Paths (→ SKILL.md):

```bash
# [RUN]
cat "{project_root}/workflows/templates/{type}.md"
```

**Default**: template missing → fallback: `# {Title}` / `## Overview` / `## Details` / `## Open Questions`.

---

## Step 4: Fill

Model: opus

### Create mode

1. Scan full conversation for content matching this document type
2. Organize into template sections as structured prose
3. Follow each section's `<!-- INCLUDE/EXCLUDE -->` guide
4. Each section: ≥3 sentences; if insufficient → `TBD — {what's missing}`
5. Preserve technical accuracy; do not fabricate unstated details
6. Ambiguities → prefix with `Open question:`
7. Code examples and tables: quote directly from conversation
8. Cross-references: paths relative to project root. Match user's language for content.

#### Progress fields (create mode)

| Type | Field | Rule |
|------|-------|------|
| roadmap | 里程碑.进度 | Count existing PRDs linked to this milestone. Format: `完成数/总数` |
| roadmap | 里程碑.需求 | Link to each PRD under this milestone. `—` if none yet |
| roadmap | 里程碑编号 | Each version starts from M1 |
| prd | §4 方案.任务表 | List each tech doc as one row. Progress = `完成数/总数` |
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
| H1 title | Project: `{项目名} {文档类型}`, Directory: `{主题名} {文档类型}`, Requirement: `{用户入口}`, Tech: `{需求名} 技术方案` |
| No existing section discussed | Warn "对话未涉及已有内容，是否要新增 section？" [STOP:choose] A) Add B) Cancel |

#### Update mode for tech

1. §2 方案: update as understanding deepens (overwrite)
2. §3 关键决策: append new rows to existing table
3. §4 迭代记录: prepend new entry (newest first) with today's date. Never overwrite existing entries.

---

## Step 5: Write [STOP:confirm]

Model: sonnet

### Preview

Use the full path resolved in Step 2.

**Content check**: filled content covers <30% of template sections →

```
[write] Insufficient content for {type}, missing:
- {section 1}
- {section 2}
Continue with missing sections marked TBD?
```

**Create mode**:
```
[write] Preview: docs/requirements/know-learn/tech.md

{full document content}

Write?
```

**Update mode** — changed sections as diff:
```
[write] Update preview: docs/roadmap.md

## {Section A}
- {old content summary}
+ {new content summary}

Write?
```

User confirms → write. User requests edits → adjust, re-display.

### Write

**Create mode**:

```bash
# [RUN] Create parent directory from resolved path
mkdir -p "$(dirname "{resolved_path}")"
```

Write file using Write tool to the resolved path.

File already exists in create mode → switch to update mode (re-enter Step 4 with `mode=update`).

```
[written] docs/requirements/know-learn/tech.md
```

**Update mode**:

Use Edit tool to replace each changed section individually.

For tech docs: prepend new entry to §4 迭代记录.

```
[written] docs/roadmap.md (updated 2 sections)
```

---

## Step 5.5: Validate

Model: sonnet

Gate: checklist file exists for this document type (`templates/{type}-checklist.md`). No checklist → skip.

```bash
# [RUN]
cat "{project_root}/workflows/templates/{type}-checklist.md"
```

Validate the written document against the checklist:

1. **Structure**: every required field present, no extra/missing columns
2. **Language**: each field meets its language constraint (check ❌/✅ patterns)
3. **Data confidence**: every numeric value has a valid source
   - Has real data → value + source citation
   - Has estimate → value + "估算" + basis
   - Has target only → value + "目标值，待验证"
   - Cannot estimate → "无数据（{reason}）"
   - **Fabricated precise numbers with no source → FAIL**
4. **Completeness**: non-optional fields are filled (not placeholder text)
5. **Diagrams**: if checklist references `diagram-checklist.md`, load it and check each when→action trigger against the document content. Missing diagram for a satisfied trigger → FAIL

```bash
# [RUN] only if checklist contains "diagram-checklist.md" reference
cat "{project_root}/workflows/templates/diagram-checklist.md"
```

**Any failure** → list violations, fix in the document, re-preview changed sections.

```
[validate] {type} checklist: {passed}/{total} checks passed
{list of violations if any}
```

No violations → proceed silently to Step 6.

---

## Step 6: Progress

Model: sonnet

After writing a child document, update progress in its parent:

| Written type | Parent update |
|-------------|---------------|
| tech | Update parent PRD §4 方案 task table progress column |
| prd | Update parent roadmap milestone table progress as `完成PRD数/总PRD数` |

Progress update uses Edit tool on the parent document. Only update the progress field.

**Parent not found** → skip silently. **No parent relationship** (all types except prd/tech) → skip.

```
[progress] {parent path} updated ({progress value})
```

---

## Completion

- Document written to correct path
- Progress propagated to parent (if applicable)
- User saw `[written]` confirmation

## Recovery

| Error | Recovery |
|-------|----------|
| Write tool fails | Show error path and message. Do not retry silently. |
| File already exists in create mode | Switch to update mode (re-enter Step 4). |

## Examples

### Parameter confirmation

```
[write] Inferred from conversation:
Type: prd | Path: docs/requirements/know-write/prd.md | Mode: create | Parent: roadmap
Correct?
```

```
[write] Inferred from conversation:
Type: ui | Path: docs/ui/index-page.md | Mode: create | Parent: none
Correct?
```
