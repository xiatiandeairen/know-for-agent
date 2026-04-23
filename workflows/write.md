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

### 1a: Type

**Input**: `hint` (optional, from `/know write <hint>`), conversation, `user_replies[]`
**Output**: `type` ∈ 10 类, `questions_asked` ∈ {0,1,2,3}
**测试**: `tests/write/type-inference.jsonl`

#### 流程

```
1. hint 合法 (∈ 10 类) → 采用 → END (q=0)
2. hint 非法且非 null → 必问一次：
     "hint '<X>' 不在 10 类，你要哪个？(推荐 <AI 从对话推断的 type>)"
   → 解析 → END (q≥1)
3. hint 为 null → 判置信度（见判据）：
   - 高        → 推 type → END (q=0)
   - 中（定组）→ 问 Q2    → 解析 → END (q=1)
   - 低 / 无信息 → 问 Q1 → Q2 → 解析 → END (q=2)
4. 用户答超范围 → 追问"10 类里哪个" → 解析（q 累加）
5. q 已 ≥ 2 且仍无有效答 → guess 最接近项，标 note=guessed → END
```

#### 置信度判据（对比示例 + 强制引证）

**10 类的典型对话长啥样（1 句示例）**：

| type | 典型示例 |
|---|---|
| roadmap | "v1 做 A/B/C，v2 扩 D，Q2 发布" |
| prd | "用户要能上传 pdf，成功率 95%" |
| tech | "用 SQLite 存，WAL 模式，按 project_id 分表" |
| arch | "recall 模块 = scope 推断 + query + rank" |
| decision | "选 JSONL 不选 SQLite，因为 diff 友好" |
| schema | "POST /api/v2/users，请求体含 name, email" |
| capabilities | "我们支持文件上传、OCR、全文搜索" |
| ui | "点击按钮后弹框，表单 3 段" |
| ops | "发布后看反馈，两周一迭代" |
| marketing | "发博客 + Twitter 推文 + 官网 landing" |

**判决规则**：

| 置信 | 判据（必须可验证） |
|---|---|
| 高 | AI 能引用**≥2 条对话原话**最像某一 type 的示例 |
| 中 | AI 能引用**≥1 条原话**最像某一大组（A/B/C）但具体 type 不清 |
| 低 | 对话里能引出原话但不聚焦到任何 type / 任何大组 |
| 无信息 | 对话几乎无文档相关素材 |

**强制**：高置信必须在内部写出引用的 2 条原话；引不出来 → 降为中。

#### Q1（3 选 1，大组分流）

```
写哪种？
  A) 计划 / 需求        (roadmap, prd)
  B) 技术方案           (tech, arch, decision, schema)
  C) 产品 / 运营介绍    (capabilities, ui, ops, marketing)
```

#### Q2（按 Q1 分支）

**Q2-A（2 选 1）**：
```
A) 项目总计划 / 版本规划          → roadmap
B) 单需求的用户故事 / 验收标准    → prd
```

**Q2-B（4 选 1）**：
```
A) 实现细节 / 数据流 / 代码设计    → tech
B) 系统架构 / 模块分解            → arch
C) 决策记录（为什么选 X 不选 Y）  → decision
D) 接口 / 数据结构规范            → schema
```

**Q2-C（4 选 1）**：
```
A) 对外功能清单                    → capabilities
B) 界面 / 交互说明                → ui
C) 运营流程 / 反馈闭环            → ops
D) 推广 / 发布方案                → marketing
```

#### 答案解析

- 合法：字母（A/B/C/D）或直接 type 名（"prd"）
- 直接说 type 名 → 跳过未问的 Q2，直接采用
- 包含"都不是/其他/没有" 或 非法 type 名（如 "runbook"）→ 视为超范围

#### 硬规则

- 所有字符串输入（hint、用户回答）先 **lowercase 规范化** 再匹配
- hint 合法 → 立即采用，不得询问
- `questions_asked ≤ 3`（含超范围追问）
- 2 轮仍无有效答 → guess + 标注 `note: guessed`，不再继续问
- Q1/Q2 选项必须完整展示，不得省略
- 置信度判定必须能举出对话原话，否则降级

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
