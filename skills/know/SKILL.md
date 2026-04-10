---
name: know
description: Project knowledge compiler for AI agents — retrieve scoped context and persist high-value tacit knowledge to reduce exploration errors.
---

# Know

`/know [scope]` → retrieve context. `/know learn` → persist knowledge. `/know write` → write structured documents.

Three capabilities, one entry point:
- **Retrieve**: surface the right context at the right time
- **Learn**: correct the AI's mental model by recording tacit knowledge
- **Write**: turn conversation discussion results into structured documents in `docs/`

---

## Rules

- Bash commands marked `# [RUN]` must be executed with Bash tool, not described verbally.
- Wait for user at `[STOP:confirm]` (proceed only when user expresses confirmation intent) and `[STOP:choose]` (user picks one option).
- Questions that ask user to choose must always list explicit options (A/B/C). Never ask a choice question without options.
- Questions that ask user to confirm must always show the content being confirmed. Never ask "confirm?" without showing what to confirm.
- All internal markers (`[STOP:confirm]`, `[STOP:choose]`, step numbers, tier/tag/tm labels) must NEVER appear in user-facing output. Use natural language prompts instead.
- Match user's language. Chinese input → Chinese response. English input → English response. Internal docs (SKILL.md, workflows) stay in English.
- Users can skip confirmation points by expressing skip intent (go, ok, continue, 继续, 好, 可以, etc.). AI judges by intent, no specific keywords required. Skip intent → accept current output, move to next step. Discussion intent (question, objection, modification) → continue discussing.

### Output Blocks

Output blocks are user-facing formatted displays. Use `> [marker]` prefix:

| Marker | Semantics | When |
|--------|-----------|------|
| `> [retrieved]` | 检索结果展示 | retrieve 完成 |
| `> [suggest-learn]` | 检测到高价值知识，提议持久化 | learn implicit signal |
| `> [learn]` | 待确认的知识条目 | learn Step 7 |
| `> [persisted]` | 写入完成确认 | learn Step 8 |
| `> [conflict]` | 存在相似条目，需要用户决策 | learn Step 6 冲突 |
| `> [skipped]` | 路由拦截，不持久化 | learn Step 3 DROP |
| `> [write]` | 文档写入流程中的状态展示 | write 各步骤 |
| `> [written]` | 文档写入完成确认 | write Step 8 |
| `> [index]` | 索引更新确认 | write Step 9 |

**Conflict block 完整格式**:

```
> [conflict] 发现相似条目:
>
> 已有: {existing summary}
> 新增: {new summary}
>
> 请选择:
> A) 更新已有条目
> B) 保留两条
> C) 合并为一条
> D) 跳过新条目
```

**Skipped block 格式**:

```
> [skipped] {claim summary}
> 原因: {drop reason — e.g. 可从代码推导 / 属于 CLAUDE.md / 无明确结论}
```

### Path Constants

```
KNOWLEDGE_DIR=".knowledge"
INDEX_FILE=".knowledge/index.jsonl"
ENTRIES_DIR=".knowledge/entries"
DOCS_DIR=".know/docs/"
TEMPLATES_DIR="workflows/templates/"
KNOW_CTL="scripts/know-ctl.sh"
```

---

## Intent Routing [BRANCH]

| Input | Intent | Dispatch |
|-------|--------|----------|
| `/know` | Retrieve project-wide context | → `workflows/retrieve.md` (scope=project) |
| `/know <scope>` | Retrieve scoped context | → `workflows/retrieve.md` (scope=input) |
| `/know learn` | Persist knowledge from conversation | → `workflows/learn.md` |
| AI detects signal | Propose persistence | → `workflows/learn.md` (requires user consent) |
| `/know write` | Write discussion result as structured document | → `workflows/write.md` |
| `/know write <hint>` | Write document with type/name hint | → `workflows/write.md` (hint assists inference) |

<HARD-GATE>
All writes must display content and receive user confirmation before persisting.
</HARD-GATE>

---

## Storage Architecture

```
.knowledge/
├── index.jsonl              # JSONL index — one entry per line, filter via jq
└── entries/                 # Markdown detail files
    ├── rationale/           #   Why this, not that
    ├── constraint/          #   What must not be done
    ├── pitfall/             #   Known traps with root cause
    ├── concept/             #   Core logic, algorithms, flows
    └── reference/           #   External tool integration guides
```

### JSONL Schema (10 fields)

```json
{
  "tag":      "rationale|constraint|pitfall|concept|reference",
  "tier":     1|2|3,
  "scope":    "Module.Class.method",
  "tm":       "passive|active:defensive|active:directive",
  "summary":  "≤80 chars, must contain retrieval anchor terms",
  "path":     "entries/{tag}/{slug}.md|null",
  "hits":     0,
  "revs":     0,
  "created":  "YYYY-MM-DD",
  "updated":  "YYYY-MM-DD"
}
```

**Scope field**: string for single scope, JSON array for cross-module (e.g. `["LoppyMetrics", "LoppyScoring"]`). In JSONL, arrays are serialized inline: `"scope":["A","B"]`.

| Field | Filter | Sort | Output | Expand | Lifecycle |
|-------|--------|------|--------|--------|-----------|
| tag | ✓ | | | | |
| tier | ✓ | ✓ | | | |
| scope | ✓ | | | | |
| tm | ✓ | | | | |
| summary | ✓ (text match) | | ✓ | | |
| path | | | | ✓ | |
| hits | | ✓ | | | ✓ |
| revs | | | | | ✓ |
| created | | | | | ✓ |
| updated | | ✓ | | | ✓ |

### Scope Keypath

Dot-separated path supporting prefix match:

```
project                          → matches everything
LoppyMetrics                     → matches LoppyMetrics.*
LoppyMetrics.DataEngine          → matches LoppyMetrics.DataEngine.*
LoppyMetrics.DataEngine.refresh  → exact match
```

### Tier Rules

| Tier | Token Budget | Detail File | Retrieval Priority |
|------|-------------|-------------|-------------------|
| 1 | ≤ 220 tokens | required | Injected on scope match |
| 2 | ≤ 160 tokens | required | Injected on anchor match |
| 3 | — | none (summary only) | Not actively retrieved |

**Tier assignment criteria** (learn workflow):
- Tier 1 requires confirmed knowledge (verified via test, reproduction, or multi-source agreement)
- Tier 2: likely to cause errors if missing, but not yet fully confirmed
- Tier 3: worth noting but low impact if missing

**Summary rules**:
- ≤ 80 characters; if exceeds, compress to fit — never truncate mid-word
- Must contain retrieval anchor terms (module names, API names, error patterns)
- Structure: conclusion + key reason

### Decay Policy

```
tier 3 + hits=0 + created > 30d  → delete
tier 2 + hits=0 + created > 90d  → demote to tier 3
tier 1 + hits=0 + created > 180d → demote to tier 2
revs > 3 + tier 1                → demote to tier 2 (unstable)
```

---

## Pipelines

### Learn (mental model correction)

Record tacit high-value knowledge that code and git cannot express. Full spec: `workflows/learn.md`

```
Signal detection → Claim extraction → Route interception → 3-question tier assessment
→ Entry generation → Conflict detection (keyword pre-filter + LLM similarity)
→ Display and confirm → Write index.jsonl + entries/
```

### Retrieve (context injection)

Surface the right knowledge at the right time. Full spec: `workflows/retrieve.md`

```
Trigger → Resolve scope keypath → know-ctl.sh query → Sort → Truncate by entry limit
→ Output (active tier-1: expand detail; rest: summary only) → Increment hits
```

| Trigger | Scope Source | Max Entries |
|---------|-------------|-------------|
| `/know` | project | 10 |
| `/know <scope>` | user-specified | 10 |
| Read/Edit file | file path extraction | 3 |
| Task description | keyword extraction | 5 |
| Decision point | current scope | 3 |

### Write (document authoring)

Turn conversation results into structured, versioned documents. Full spec: `workflows/write.md`

```
Trigger → Infer parameters → Resolve ambiguity → Version check
→ Load template → Extract and fill → Preview and confirm → Write file
→ Update CLAUDE.md index → Done
```
