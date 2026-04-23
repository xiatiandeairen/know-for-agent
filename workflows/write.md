# write — Document Authoring

## 1. Overview

Compose a structured markdown document from conversation content and `triggers.jsonl`. Supports 10 document types across three layouts (single file, directory, requirement). Pipeline: infer parameters → confirm → fill template → preview → write → validate → propagate progress.

## 2. Core Principles

1. **Confirm before persisting.** Every path, type, and full preview requires explicit user confirmation.
2. **No fabrication.** Missing evidence becomes `TBD — {what is missing}` or `Open question:`; numbers without sources fail validation.
3. **Triggers are evidence, not content.** Reference by summary; never paste verbatim. Rules bind, insights advise, traps surface as risks.
4. **Bounded clarification.** One invalid reply triggers a single full-list fallback; a second ends with `abort`. Never guess.
5. **Template and checklist are sources of truth.** The writer fills the template and satisfies the checklist; it never silently redefines structure.
6. **Update preserves history.** Only regenerate sections the conversation discusses; append-only sections (`tech §3 决策`, `§4 迭代记录`) never overwrite.
7. **Bounded repair.** Validation loops at most three rounds before shipping with an unresolved count.

## 3. Definitions

| Term | Meaning |
|---|---|
| `type` | one of `roadmap, prd, tech, arch, decision, schema, ui, capabilities, ops, marketing` |
| `hint` | optional type string passed via `/know write <hint>` |
| `name` | kebab-case slug (topic or requirement) |
| `mode` | `create` \| `update` |
| `parent` | upstream document whose progress field is updated on completion |
| `trigger` | one entry from `docs/triggers.jsonl` or `$XDG_CONFIG_HOME/know/triggers.jsonl` |
| `exemplar` | one reference sentence per type, used as the semantic anchor in Step 1a |
| `STOP:confirm` | block until user answers yes/no |
| `STOP:choose` | block until user selects one option from a displayed list |
| `abort` | terminate the step with no file change |

## 4. Rules

### 4.1 Input handling

- All string matching is case-insensitive; normalize to lowercase first.
- A valid `hint` is adopted without prompting.
- A reply is invalid when its lowercase form is empty, matches `不知道 / 随便 / skip / idk / -`, or is not among the accepted options for the prompt.
- Invalid replies permit exactly one fallback prompt listing the full option set; a second invalid reply terminates with `abort`.

### 4.2 File safety

- Never overwrite an existing file silently. When a `create` target exists, prompt with `Update / Pick different name / Cancel`.
- Roadmap is always a single file; a new version is an `update`, not a `create`.
- `create` writes every template section exactly once; `update` touches only sections the conversation discusses.

### 4.3 Content integrity

- Forbidden: precise numbers without a cited source, fabricated details, invented cross-references.
- Required for every numeric value: one of `value + citation`, `value + 估算 + basis`, `value + 目标值，待验证`, `无数据（{reason}）`.
- Triggers may be referenced by summary; copying verbatim is forbidden.
- Append-only sections (`tech §3 关键决策`, `tech §4 迭代记录`) are never overwritten.

### 4.4 Clarification limits

- Sufficiency, mode, and inference checks each allow at most one clarifying prompt before either proceeding or aborting.
- Validation runs at most three repair rounds; on the fourth attempt the document ships with an explicit unresolved count.

## 5. Workflow

Models: `opus` for inference and composition (1a, 4); `sonnet` elsewhere.

### 5.1 Path resolution

| Type | Path |
|---|---|
| `roadmap / capabilities / ops / marketing` | `docs/<type>.md` |
| `arch / ui / schema / decision` | `docs/<type>/<name>.md` |
| `prd / tech` | `docs/requirements/<name>/<type>.md` |

Hierarchy: `roadmap → prd → tech`. All other types are independent. Roadmap versions live as `### v{n}` sections under `## 2. 版本规划`; milestone numbering restarts per version.

### 5.2 Step 1 — Parameter inference

Four substeps produce `{type, name, mode, parent}`; each step follows the pattern *hint → auto-infer → one clarifying prompt → fallback to full list → abort*.

#### 1a — `type`

```
1. hint ∈ 10 types (lowercase)                 → accept.
2. inference check against exemplars:
     one type passes                           → return it.
     one group (A/B/C) passes                  → ask Q2.
     none or multiple groups pass              → ask Q1, then Q2.
3. invalid reply → list all 10 types → second invalid → abort.
```

**Inference check.** For each type, ask: *"If I replace the conversation with this exemplar, can a reader reconstruct the same writing intent?"* Yes for exactly one type → 2a. Yes for one full group → 2b. Otherwise 2c.

**Exemplars.**

| Type | Exemplar |
|---|---|
| roadmap | "v1 交付 A/B/C；v2 扩展 D；Q2 发布" |
| prd | "用户可上传 pdf；上传成功率目标 95%" |
| tech | "采用 SQLite 存储；启用 WAL 模式；按 project_id 分表" |
| arch | "recall 模块由 scope 推断、query、rank 三段构成" |
| decision | "选用 JSONL 而非 SQLite，因其 diff 友好" |
| schema | "POST /api/v2/users 请求体含 name、email" |
| capabilities | "系统支持文件上传、OCR、全文检索" |
| ui | "点击按钮触发弹窗；表单分三段" |
| ops | "发布后收集反馈；两周一次迭代" |
| marketing | "通过博客、Twitter、官网 landing 多渠道推广" |

**Clarifying prompts.**

Q1 (3-way) — A: `roadmap, prd` · B: `tech, arch, decision, schema` · C: `capabilities, ui, ops, marketing`

Q2-A: `roadmap | prd`
Q2-B: `tech | arch | decision | schema`
Q2-C: `capabilities | ui | ops | marketing`

Accepted reply forms: a letter, or an explicit type name (short-circuits pending Q2).

#### 1b — `name`

```
1. type does not require a name                → null.
2. name_hint                                   → normalize, return.
3. conversation contains an explicit noun phrase → normalize, return.
4. otherwise → ask user → invalid reply → one retry → abort.
```

**Normalization.** lowercase → replace `[space/._/]` with `-` → strip chars outside `[a-z0-9-]` → collapse repeats → trim `-`. Empty result is invalid.

#### 1c — `mode`

```
1. file does not exist                         → create.
2. type = roadmap (always single file)         → update.
3. file exists → [STOP:choose]:
     A) Update                                 → update.
     B) Pick a different name                  → re-enter 1b.
     C) Cancel                                 → abort.
```

#### 1d — `parent`

| Type | Parent |
|---|---|
| prd | `docs/roadmap.md` |
| tech | `docs/requirements/<name>/prd.md` |
| all others | none |

```
1. no parent for this type                     → null.
2. parent exists                               → return its path.
3. prd + roadmap missing                       → proceed, note absence.
4. tech + prd missing → [STOP:choose]:
     A) Continue without parent                → null.
     B) Create PRD first                       → redirect.
5. prd with ambiguous milestone                → ask for milestone number.
```

### 5.3 Step 1.5 — Sufficiency gate

Runs only for high-risk types (`prd, tech, arch, schema, decision, ui`).

```
1. load the question group from templates/sufficiency-gate.md.
2. answer each question with a verbatim quote or explicit "not present".
3. all yes   → pass.
   mix       → degrade.
   all no    → reject.
4. on degrade / reject → [STOP:choose]:
     A) Supplement the conversation            → rerun this step.
     B) Degrade to <suggested type>            → re-enter Step 1.
     C) Cancel                                 → abort.
```

### 5.4 Step 2 — Confirm

```
[write] Inferred from conversation
  Type:   {type}
  Name:   {name or —}
  Path:   {resolved path}
  Mode:   {create | update}
  Parent: {parent or none}
Correct? (yes / change <field>=<value>)
```

Field dependency: `type → name → mode → parent`. Editing a field re-runs everything downstream of it; edits to `mode` or `path` apply directly.

### 5.5 Step 3 — Load template

```bash
cat "{project_root}/workflows/templates/{type}.md"
```

If the template is absent, synthesize `# Title / ## Overview / ## Details / ## Open Questions`.

### 5.6 Step 4 — Fill

Load both `docs/triggers.jsonl` and `$XDG_CONFIG_HOME/know/triggers.jsonl`.

**Create mode.**

```
For each template section:
  1. collect relevant conversation quotes and triggers in scope.
  2. obey <!-- INCLUDE / EXCLUDE --> hints.
  3. produce structured prose; preserve code and tables verbatim.
  4. if evidence is insufficient → "TBD — {what is missing}".
Prefix ambiguities with "Open question:".
Cross-references use project-root-relative paths; output language follows the user's.
Apply progress fields before handoff.
```

**Update mode.**

```
1. read the existing document in full.
2. list every section the conversation discusses.
3. regenerate only listed sections; all others remain byte-identical.
4. add missing template sections as content or TBD.
5. repair broken relative paths only inside touched sections.
6. if no section is discussed → [STOP:choose] A) add new section B) cancel.
```

**Progress fields (create).**

| Type | Field | Rule |
|---|---|---|
| roadmap | 里程碑.进度 | `完成数/总数` over linked PRDs |
| roadmap | 里程碑.需求 | link each PRD; `—` when empty |
| roadmap | 里程碑编号 | restart at M1 per version |
| prd | §4 方案.任务表 | one row per tech doc; progress = `完成数/总数` |
| tech | §4 迭代记录 | seed with today's date and sprint summary |

**Update rules per type.**

| Type | Section | Rule |
|---|---|---|
| tech | §2 方案 | overwrite as understanding deepens |
| tech | §3 关键决策 | append only |
| tech | §4 迭代记录 | prepend today; never overwrite history |

**H1 titles.**

| Scope | Title |
|---|---|
| Project single | `{项目名} {文档类型}` |
| Project directory | `{主题名} {文档类型}` |
| Requirement (prd) | `{用户入口}` |
| Requirement (tech) | `{需求名} 技术方案` |

### 5.7 Step 5 — Write [STOP:confirm]

Preview before writing.

```
[write] Preview: {path}
{create: full content · update: diff on touched sections}
Write? (yes / edit <section> / no)
```

If `TBD` appears in more than 3 sections, prepend `{n} sections marked TBD: {list}. Still write?` and require a second confirmation.

On `yes`:

```bash
mkdir -p "$(dirname "{path}")"
```

- `create` → Write tool.
- `update` → Edit tool per section; for `tech`, prepend the iteration entry.

```
[written] {path}
[written] {path} (updated {n} sections)
```

### 5.8 Step 5.5 — Validate

Gate: skip when `templates/{type}-checklist.md` does not exist.

```bash
cat "{project_root}/workflows/templates/{type}-checklist.md"
```

Checks:
- **Structure** — required sections/fields present.
- **Language** — fields meet their `✅/❌` language constraint.
- **Data confidence** — every numeric value has one of the four source forms (§4.3); precise numbers without sources fail.
- **Completeness** — non-optional fields contain real content, not placeholders.
- **Diagrams** — if the checklist references `diagram-checklist.md`, run it.

On violations: list, repair, re-preview. Up to three rounds; on the fourth attempt ship with `[validate] forced through, {n} checks unresolved`.

### 5.9 Step 6 — Propagate

```
1. type has no parent, or parent file missing → skip silently.
2. otherwise → Edit tool on the parent's progress field only.
```

| Written type | Parent field |
|---|---|
| tech | PRD `§4 方案` task table, progress column |
| prd | roadmap milestone table, `完成PRD数/总PRD数` |

```
[progress] {parent_path} updated ({value})
```

## 6. Examples

### High-confidence inference (Steps 1a → 5)

```
/know write
conversation: "recall 模块 = scope 推断 + query + rank; 增加 ranking weight"
→ 1a matches arch exemplar → type=arch.
→ 1b extracts "recall" from conversation → name=recall.
→ 1c docs/arch/recall.md missing → mode=create.
→ 1d no parent.
→ Confirm: Type=arch, Path=docs/arch/recall.md, Mode=create.
→ Fill → Preview → Write → Validate passes.
```

### Ambiguous, clarifies once

```
/know write
conversation: "聊了方案，但没定是画架构图还是记录选型"
→ 1a narrows to group B → ask Q2-B.
user: decision
→ type=decision. Continue as above.
```

### Update propagates to roadmap

```
/know write prd
→ 1b name=upload-flow; file exists at docs/requirements/upload-flow/prd.md.
→ 1c → Update.
→ Fill touches §4 方案 only.
→ Write preview shows diff.
→ Validate passes.
→ Step 6 edits docs/roadmap.md milestone progress column.
```

## 7. Edge Cases

| Situation | Behavior |
|---|---|
| Hint matches a name not in the catalog (`runbook`) | treat as null; proceed via inference. |
| Two consecutive invalid replies | terminate the step with `abort`. |
| Create target file exists | Step 1c presents Update / Rename / Cancel. |
| `tech` without a parent PRD | Step 1d asks Continue / Create PRD first. |
| Sufficiency rejects and user picks B | re-enter Step 1 with the degraded type; name and mode are re-derived. |
| Preview contains 4+ TBD sections | warn and require a second `yes` before writing. |
| Validator cannot clear a violation after 3 rounds | ship with `[validate] forced through, {n} unresolved`. |
| Parent exists but cannot be edited (permission, syntax) | log `[progress] skip: {reason}` and continue. |

## Recovery

| Error | Recovery |
|---|---|
| Write / Edit tool fails | surface the error; do not retry silently. |
| File exists mid-`create` | re-enter Step 1c. |
| Checklist file malformed | treat as missing; skip validation and warn. |
