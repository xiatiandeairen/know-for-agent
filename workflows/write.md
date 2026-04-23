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

### 1b: Name Inference

Produce the slug that completes the document path for types that need one.

**Signature**
- Input: `type` (from 1a), `conversation`, `name_hint` (optional), `user_replies[]`
- Output: `name` (kebab-case string) or `null` (for types that do not require a name); `abort` on two consecutive invalid replies
- Validation fixture: `tests/write/name-inference.jsonl`

**Name requirement by type**

| Type | Needs name? | Path |
|---|---|---|
| roadmap, capabilities, ops, marketing | no | `docs/<type>.md` |
| arch, ui, schema, decision | yes (topic) | `docs/<type>/<name>.md` |
| prd, tech | yes (req) | `docs/requirements/<name>/<type>.md` |

#### Decision procedure

```
1. If type does not require a name                     → return null.
2. If name_hint is provided                            → normalize, return.
3. Otherwise, infer a slug from the conversation:
     3a. Conversation contains a clear topic/requirement phrase → normalize, return.
     3b. No clear phrase                                         → ask the user.
4. If the user's reply is invalid:
     → ask once more; a second invalid reply terminates with `abort`.
```

#### Kebab-case normalization

- Lowercase.
- Replace spaces, underscores, dots, slashes with `-`.
- Strip any character outside `[a-z0-9-]`.
- Collapse consecutive `-`; trim leading/trailing `-`.
- Reject if the result is empty.

#### Invalid replies

A reply is invalid if, after normalization, it is empty, or if it matches any of: `不知道`, `随便`, `skip`, `idk`, `-`.

#### Hard rules

- Return `null` only when the type does not require a name; never null for types that do.
- `name_hint` is adopted after normalization without further prompting.
- Inference in 3a requires an explicit noun phrase (e.g. `recall pipeline`, `cache layer`); do not invent a slug from tangential references.
- An invalid reply triggers exactly one fallback prompt; a second invalid reply aborts.

### 1c: Mode Inference

Decide whether this invocation creates a new file or updates an existing one.

**Signature**
- Input: `type`, `name`, resolved `path`
- Output: `mode ∈ {create, update}`; `abort` if the user declines both options when the path is taken
- Validation fixture: `tests/write/mode-inference.jsonl`

#### Decision procedure

```
1. File at resolved path does not exist           → mode = create.
2. File exists and type is roadmap                → mode = update (new version = new section).
3. File exists (other types) → [STOP:choose]:
     A) Update the existing file                  → mode = update.
     B) Pick a different name                     → re-enter Step 1b.
     C) Cancel                                    → abort.
```

#### Hard rules

- Never silently overwrite an existing file; rule 3 is mandatory.
- Roadmap's "new version" is modeled as an update, not a create (the file is a single source across versions).

### 1d: Parent Inference

Resolve the parent document required for progress propagation.

**Signature**
- Input: `type`, `name`, project layout
- Output: `parent_path` (string) or `null`; may prompt the user when ambiguous
- Validation fixture: `tests/write/parent-inference.jsonl`

#### Parent map

| Type | Parent |
|---|---|
| prd | roadmap (`docs/roadmap.md`) |
| tech | prd (`docs/requirements/<name>/prd.md`) |
| all others | none |

#### Decision procedure

```
1. Type has no parent                                      → return null.
2. Parent file exists                                      → return its path.
3. type=prd and roadmap is missing                         → proceed, note absence.
4. type=tech and prd is missing → [STOP:choose]:
     A) Continue without parent                            → return null.
     B) Create PRD first                                   → redirect to /know write prd.
5. type=prd and the target milestone is ambiguous           → ask the user for a milestone number.
```

#### Hard rules

- A missing parent never blocks the current step silently; rules 3–5 make absence explicit.
- `abort` is not produced here; the user's redirect choices are downstream concerns.

---

## Step 1.5: Sufficiency Gate

Model: sonnet

Verify the conversation contains enough material to author a quality document.

**Signature**
- Input: `type`, `conversation`
- Output: `verdict ∈ {pass, degrade, reject}` plus a list of unsatisfied questions
- Gate: only runs when `type ∈ {prd, tech, arch, schema, decision, ui}`; other types pass through
- Validation fixture: `tests/write/sufficiency.jsonl`

#### Decision procedure

```
1. If type is not high-risk                               → verdict = pass.
2. Load the question group for this type from
   templates/sufficiency-gate.md. For each question,
   answer yes/no using the conversation.
3. All yes                                                → verdict = pass.
4. Any yes and any no                                     → verdict = degrade.
5. All no                                                 → verdict = reject.
```

#### Output template

```
[write] Sufficiency check: {type}
  ✅ Q1: {question} — {supporting quote}
  ❌ Q2: {question} — {what is missing}
  ...
Verdict: {pass | degrade | reject}
```

On `degrade` or `reject`, present **[STOP:choose]**:

- **A) Supplement the conversation** → user adds context, re-run this step.
- **B) Degrade to {suggested_type}** → re-enter Step 1 with the new type.
- **C) Cancel** → abort.

#### Hard rules

- Each question must be answered with a verbatim quote or an explicit "not present" statement; no paraphrased reasoning.
- The suggested degrade target is the type's lowest-risk neighbor (e.g. `tech → decision`, `prd → capabilities`). If the user selects B, always re-run Step 1 so the new type re-derives its name, mode, and parent.

---

## Step 2: Confirm [STOP:confirm]

Model: sonnet

Present the resolved parameters in one block and block until the user confirms or edits them.

**Signature**
- Input: `{type, name, mode, path, parent}` from Step 1
- Output: confirmed parameter set, or re-entry into an earlier step

#### Display format

```
[write] Inferred from conversation
  Type:   {type}
  Name:   {name or "—"}
  Path:   {resolved path}
  Mode:   {create | update}
  Parent: {parent path or "none"}
Correct? (yes / change <field>=<value>)
```

#### Decision procedure

```
1. User confirms                        → proceed to Step 3.
2. User changes `type`                  → re-enter Step 1a with the new type; re-derive name, mode, parent.
3. User changes `name`                  → re-enter Step 1c only; mode and parent follow.
4. User changes `mode` or `path`        → accept directly, no re-inference.
5. Step 1 produced multiple candidates  → [STOP:choose] `1 | 2 | both`; `both` runs Steps 3–6 sequentially per type.
```

#### Hard rules

- Never skip this step; confirmation is required even when inference was high-confidence.
- Field-level edits must not trigger full re-inference unless the changed field is upstream in the dependency chain (`type → name → mode → parent`).

---

## Step 3: Template

Model: sonnet

Load the template associated with the chosen type.

**Signature**
- Input: `type`
- Output: template text (structured markdown with section headers and INCLUDE/EXCLUDE hints)

#### Procedure

```bash
# [RUN]
cat "{project_root}/workflows/templates/{type}.md"
```

#### Fallback

If the template file does not exist, synthesize a minimal skeleton:

```markdown
# {Title}
## Overview
## Details
## Open Questions
```

#### Hard rules

- Template files are the single source of truth for document structure; this step never modifies them.
- The fallback skeleton is used only when a template is genuinely absent; never substitute the fallback when a template exists but looks incomplete.

---

## Step 4: Fill

Model: opus

Compose the document body by mapping conversation content and triggers onto the template.

**Signature**
- Input: `template`, `conversation`, `triggers` (both `docs/triggers.jsonl` and the user-level file), `existing_doc` (update mode only)
- Output: fully populated markdown ready for preview

#### Create mode

```
1. Load triggers from docs/triggers.jsonl and $XDG_CONFIG_HOME/know/triggers.jsonl.
2. For each template section:
     2a. Collect relevant conversation quotes and matching triggers.
     2b. Honor the section's <!-- INCLUDE / EXCLUDE --> hints.
     2c. Produce structured prose; preserve code/tables verbatim from source.
     2d. Insufficient evidence for a section → write "TBD — {what is missing}".
3. Prefix any ambiguity with `Open question:`.
4. Cross-references use project-root–relative paths; content language follows the user's.
5. Apply progress fields (see table) before handing off.
```

#### Triggers as evidence

- `tag=insight` entries are reference material; cite by summary, do not copy verbatim.
- `tag=rule` entries must be respected in sections that cover the same scope (e.g. a PRD cannot contradict a rule about authentication).
- `tag=trap` entries enter the `Open Questions` section or the relevant "risks" subsection when in scope.

#### Progress fields (create mode)

| Type | Field | Rule |
|---|---|---|
| roadmap | 里程碑.进度 | `完成数/总数` over PRDs linked to the milestone |
| roadmap | 里程碑.需求 | Link each PRD; `—` when empty |
| roadmap | 里程碑编号 | Versions restart from M1 |
| prd | §4 方案.任务表 | One row per tech doc; progress = `完成数/总数` |
| tech | §4 迭代记录 | Seed an entry with today's date and sprint summary |

#### Update mode

```
1. Read the existing document in full.
2. Identify every section the conversation discusses; output the list.
3. For each listed section, regenerate from conversation content using the
   create-mode quality rules.
4. Leave untouched sections byte-identical.
5. Add any template section that is missing from the document; populate
   with content or `TBD` as appropriate.
6. Repair or remove broken relative paths only inside touched sections.
7. If no existing section is discussed → [STOP:choose] A) add new section B) cancel.
```

#### Update rules per type

| Type | Section | Rule |
|---|---|---|
| tech | §2 方案 | Overwrite as understanding deepens |
| tech | §3 关键决策 | Append new rows; never rewrite existing ones |
| tech | §4 迭代记录 | Prepend today's entry; never overwrite history |

#### H1 title conventions

| Scope | Title |
|---|---|
| Project single | `{项目名} {文档类型}` |
| Project directory | `{主题名} {文档类型}` |
| Requirement (prd) | `{用户入口}` |
| Requirement (tech) | `{需求名} 技术方案` |

#### Hard rules

- Fabricated details are forbidden; missing evidence must produce TBD or an Open question, never a plausible invention.
- Create mode writes every template section exactly once; update mode touches only sections the conversation explicitly discusses.
- Triggers may be referenced but never copied verbatim; the trigger remains the source of truth.

---

## Step 5: Write [STOP:confirm]

Model: sonnet

Present a preview, collect confirmation, then materialize the document on disk.

**Signature**
- Input: filled document (from Step 4), resolved path, mode
- Output: file written at the resolved path; user edits may loop back through preview

#### Preview

**Create mode** — show the full document:

```
[write] Preview: {path}

{full document content}

Write? (yes / edit <section>)
```

**Update mode** — show a diff for touched sections only:

```
[write] Update preview: {path}

## {Section}
- {old}
+ {new}

Write? (yes / edit <section>)
```

#### TBD threshold

When the filled document contains `TBD` in more than 3 sections, add this line above the confirmation prompt:

```
[write] {n} sections marked TBD: {list}. Still write?
```

The user must confirm explicitly to proceed; editing a section removes it from the TBD list.

#### Write operation

```bash
# [RUN] create parent directory
mkdir -p "$(dirname "{resolved_path}")"
```

- **Create mode** → write the file with the Write tool.
- **Update mode** → apply each changed section with the Edit tool; tech docs additionally prepend an entry to `§4 迭代记录`.

```
[written] {path}
[written] {path} (updated {n} sections)
```

#### Hard rules

- Preview is mandatory; no silent writes.
- The "file exists in create mode" path is a Step 1c concern; by the time Step 5 runs, mode has already been resolved.
- User edits requested at the preview prompt loop back through preview until the user issues a final `yes` or cancels.

---

## Step 5.5: Validate

Model: sonnet

Verify the written document against the type's checklist.

**Signature**
- Input: written document path, `type`
- Output: `pass` or `fail` with a list of violations; up to 3 repair rounds

**Gate**: only runs when `templates/{type}-checklist.md` exists; otherwise skip.

#### Procedure

```bash
# [RUN]
cat "{project_root}/workflows/templates/{type}-checklist.md"
```

```
For each check in the checklist, verify the document meets it:
  1. Structure    — required sections/fields present, no extras.
  2. Language     — fields meet their language constraint (✅/❌ patterns).
  3. Data         — every numeric value cites a source (see below).
  4. Completeness — non-optional fields are real content, not placeholders.
  5. Diagrams     — if the checklist references diagram-checklist.md, run it.

On violations:
  → list them, repair the document, re-run Step 5 preview.
  → max 3 repair rounds; on the 4th attempt, emit the current document with
    an explicit "[validate] forced through, {n} checks unresolved" notice.
```

#### Data confidence rule

Every numeric value in the document must cite its source:

| Source | Output form |
|---|---|
| Real measurement | value + citation |
| Estimate | value + `估算` + basis |
| Target only | value + `目标值，待验证` |
| None available | `无数据（{reason}）` |

A precise number without a source **always fails**; no exceptions.

#### Output

```
[validate] {type} checklist: {passed}/{total} passed
  ✅ {check}
  ❌ {check} — {violation}
```

```bash
# [RUN] only when the checklist references diagram-checklist.md
cat "{project_root}/workflows/templates/diagram-checklist.md"
```

#### Hard rules

- A missing checklist means the step is skipped, not passed with zero checks.
- The 3-round repair cap prevents infinite loops; after the cap, the document ships with a visible unresolved count so the user can decide.
- Data confidence is non-negotiable: fabricated numbers must fail even if every other check passes.

---

## Step 6: Progress Propagation

Model: sonnet

Propagate the child document's status to its parent's progress tracker.

**Signature**
- Input: written document's `type` and `path`
- Output: parent document edited in place, or a silent skip

#### Update rules

| Written type | Parent | Field |
|---|---|---|
| tech | parent PRD | `§4 方案` task table — progress column |
| prd | roadmap | milestone table — `完成PRD数/总PRD数` |
| all others | — | skip |

#### Decision procedure

```
1. Type has no parent                   → skip silently.
2. Parent file not found                → skip silently.
3. Parent found → Edit only the progress field using the Edit tool.
```

#### Output

```
[progress] {parent_path} updated ({new value})
```

#### Hard rules

- Only touch the progress field; do not rewrite neighboring content.
- Silent skip is the only valid non-update outcome; never create a parent here — parent creation is Step 1d's concern.

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
