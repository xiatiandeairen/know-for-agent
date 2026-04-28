# write — document authoring

Generate structured markdown docs based on conversation content. 10 types in three layouts (single-file, directory, requirement).

5 stages run serially: infer → gate → confirm → draft → write.

At each stage entry, first emit two lines:

```
[write] stage X/5 — {name}
Purpose: {purpose}
```

Stage overview:

- Stage 1 infer — infer type / name / mode / parent from hint + conversation (Step 1)
- Stage 2 gate — sufficiency check; if content is insufficient, downgrade or supplement (Step 2)
- Stage 3 confirm — present the inferred result, user confirms or modifies fields (Step 3)
- Stage 4 draft — load template, fill in content (Step 4-5)
- Stage 5 write — preview, write, validate, write back to parent doc, inject index (Step 6-9)

## Stage 1: infer

```
[write] stage 1/5 — infer
Purpose: infer the four parameters type / name / mode / parent from the hint and conversation context.
```

### Step 1 — infer the four parameters

Unified logic: hint → automatic inference → one clarification → fall back to full list → terminate.

**type**

10 types: roadmap / prd / tech / arch / decision / schema / ui / capabilities / ops / marketing

Inference order:

1. hint is a valid type → use directly; hint exists but not in the 10 types → treat as null, run inference
2. Conversation matches an exemplar: single hit → use; hits within the same group → ask a fine-grained question; cross-group or no hit → ask the broad-group question, then refine
3. Invalid reply → list all 10 types → still invalid → terminate

Broad-group question: which group does what you want to produce belong to?

- roadmap / requirement: roadmap / prd
- tech / architecture: tech / arch / decision / schema
- capability / expression: capabilities / ui / ops / marketing

Exemplars (anchor sentences that signal a type hit in the conversation):

- roadmap: "v1 delivers A/B/C; v2 extends D; release in Q2"
- prd: "users can upload pdf; target upload success rate 95%"
- tech: "use SQLite for storage; enable WAL mode; shard by project_id"
- arch: "the payment module has three stages: signature verification, processing, reporting"
- decision: "chose JSONL over SQLite because it is diff-friendly"
- schema: "POST /api/v2/users request body contains name, email"
- capabilities: "the system supports file upload, OCR, full-text search"
- ui: "clicking the button triggers a modal; the form has three sections"
- ops: "collect feedback after release; iterate every two weeks"
- marketing: "promote across multiple channels — blog, Twitter, landing page"

**name**

roadmap / capabilities / ops / marketing do not need a name → null.

Otherwise:

1. hint or conversation contains an explicit noun phrase → normalize (lowercase; spaces / dots / slashes to `-`; strip non-`[a-z0-9-]` chars; trim)
2. None of the above → ask user → invalid → retry once → terminate

**mode**

1. Target file does not exist → create
2. type = roadmap → update (always single-file)
3. Target file exists → ask user: A) Update / B) rename (return to name inference) / C) cancel; wait for reply

**parent**

Document path table (relative to git root):

| type | path |
|------|------|
| roadmap | `docs/roadmap.md` |
| capabilities | `docs/capabilities.md` |
| ops | `docs/ops.md` |
| marketing | `docs/marketing.md` |
| prd | `docs/requirements/{name}/prd.md` |
| tech | `docs/requirements/{name}/tech.md` |
| arch | `docs/arch/{name}.md` |
| decision | `docs/decision/{name}.md` |
| schema | `docs/schema/{name}.md` |
| ui | `docs/ui/{name}.md` |

Hierarchy: roadmap → prd → tech; the rest are independent. roadmap is always single-file; new versions are updates.

parent mapping:

- prd → `docs/roadmap.md`
- tech → `docs/requirements/{name}/prd.md` (same name)
- others → null

Missing-parent handling:

- prd and roadmap does not exist → continue, mark as missing
- tech and prd does not exist → ask user: A) continue directly / B) create the PRD first; wait for reply
- prd milestone attribution unclear → ask for the milestone number

---

## Stage 2: gate

```
[write] stage 2/5 — gate
Purpose: for high-risk types, check whether the conversation content is sufficient to support the doc; if not, downgrade or supplement and rerun.
```

### Step 2 — sufficiency check

Run only for high-risk types (prd / tech / arch / schema / decision / ui); other types go to Stage 3 directly.

Template base directory: `workflows/templates/` (relative to plugin root).

1. Load the question groups from `workflows/templates/sufficiency-gate.md`
2. Answer each question with a verbatim quote from the conversation or an explicit "not present"
3. All yes → pass, enter Stage 3
4. Mixed or all no → ask user: A) supplement the conversation and rerun / B) downgrade to the suggested type (return to Stage 1) / C) cancel; wait for reply

---

## Stage 3: confirm

```
[write] stage 3/5 — confirm
Purpose: present the inferred result, wait for user confirmation or field modification.
```

### Step 3 — user confirmation

```
[write] Inferred from conversation
  Type:   {type}
  Name:   {name or —}
  Path:   {resolved path}
  Mode:   {create | update}
  Parent: {parent or none}
Correct? (yes / change {field}={value})
```

Modifying any field reruns everything downstream (type → name → mode → parent); after the rerun, return to Stage 2 or Stage 3.

---

## Stage 4: draft

```
[write] stage 4/5 — draft
Purpose: load the template and fill in content per mode.
```

### Step 4 — load template

Read `workflows/templates/{type}.md` (in update mode, also read `{type}-update.md`; skip if absent).

If the template does not exist → synthesize `# Title / ## Overview / ## Details / ## Open Questions`.

### Step 5 — fill in content

**create mode**: for each section, collect quotations from the conversation (cite by summary; verbatim pasting forbidden), respect `<!-- INCLUDE / EXCLUDE -->` hints, and produce structured body text. When evidence is insufficient, write `TBD — {missing content}`; annotate every numeric value with its source (measured / estimated / target / no data); start unclear points with `Open question:`. Use project-root-relative paths for cross-references.

**update mode**:

1. Read the existing doc in full
2. List every section that the conversation discussed
3. Rewrite only the listed sections; the rest byte-identical
4. Fill in any missing template sections (with content or TBD)
5. Fix broken relative paths only inside the modified sections
6. No section was discussed → ask user: A) add a new section / B) cancel; wait for reply

**progress fields (create)**:

- roadmap milestone: progress (completed / total, counted by linked PRDs), requirement list (link each PRD; — when empty), number (reset from M1 each version)
- prd §4 plan task table: one row per tech doc, progress = completed / total
- tech §4 iteration log: today's date and the sprint summary placed at the top

**update special rules (tech)**:

- §2 plan → overwritten as understanding deepens
- §3 key decisions → append-only
- §4 iteration log → today on top, never overwrite history

**H1 title**:

- project single-file → `{project name} {document type}`
- project directory → `{topic name} {document type}`
- prd → `{user entry point}`
- tech → `{requirement name} technical solution`

---

## Stage 5: write

```
[write] stage 5/5 — write
Purpose: preview the draft, write the file, validate quality, write back the parent doc's progress field, inject the doc index into the project CLAUDE.md.
```

### Step 6 — preview and write

Preview before writing:

```
[write] Preview: {path}
{create: full content · update: diff of changed sections}
Write? (yes / edit {section} / no)
```

When TBD exceeds 3 sections, prepend `{n} sections marked TBD: {list}. Still write?` and wait for a second confirmation.

After user confirmation, execute:

- First create the directory: `mkdir -p "$(dirname "{path}")"`
- create → Write tool
- update → Edit tool, section by section; tech iteration-log entries placed at the top

```
[written] {path}
[written] {path} (updated {n} sections)
```

Write / Edit tool failure → surface the error; silent retry forbidden.

### Step 7 — validate

If `workflows/templates/{type}-checklist.md` does not exist, skip.

Checks:

- All required sections and fields present
- Fields satisfy language constraints
- Every number has a source annotation (measured / estimated + basis / target value, pending validation / no data + reason)
- Non-optional fields contain real content, not placeholders
- When the checklist references `diagram-checklist.md`, run that check too

Violation → fix → preview again, up to 3 rounds. The 4th round forces the doc out and annotates `[validate] forced through, {n} checks unresolved`. Corrupted checklist file → treat as missing, skip and warn.

### Step 8 — write back parent doc

Parent does not exist or file is missing → silently skip.

Otherwise use the Edit tool to change only the parent's progress field:

- tech written → update the progress column of the §4 plan task table in `docs/requirements/{name}/prd.md`
- prd written → update the milestone table `completed PRDs / total PRDs` in `docs/roadmap.md`

```
[progress] {parent_path} updated ({value})
```

Parent exists but cannot be edited → log `[progress] skip: {reason}` and continue.

### Step 9 — index injection

Run only in create mode; skip in update mode (path unchanged).

Target: `{git root}/CLAUDE.md`. Index line format: `- {type}[/{name}]: {project-root-relative path}`.

Execute the Edit based on the target file's state:

- No `## docs` section → append a `## docs` section + this line at the end of the file
- `## docs` section exists + does not contain this line → append this line to the end of the section
- `## docs` section already contains this line → skip (idempotent)

Output:

```
[index] {git root}/CLAUDE.md updated (+ {type}[/{name}])
[index] skip: already present
```

Write failure → surface the error; silent retry forbidden.
