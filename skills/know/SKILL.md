---

## name: know

description: AI-assisted high-entropy knowledge unit authoring tool — capture implicit knowledge from conversations into structured markdown, and compile session decisions into structured docs.

# Know

## 1. Overview

Let the AI agent accumulate and reuse project knowledge, so each session need not re-brief constraints / decisions / history. Two entry capabilities:

- **capture** (`learn`) — capture implicit knowledge from conversation into a YAML entry under the `## know` section (4 fields: when / must|should|avoid|prefer / how / until)
- **compile** (`write`) — generate or update structured docs from templates based on the conversation and existing knowledge

---

## 2. Core Principles

1. **High-risk conservative**: irreversible or high-impact actions must have evidence and user confirmation.
2. **Low-risk flexible**: low-impact inferences and candidates use the full model capability — do not over-conserve.
3. **AI suggests, user decides**: AI output is a candidate; the final decision belongs to the user.
4. **Capture in small units, assemble in large units**: knowledge is stored as atomic units; docs are produced by structured assembly.
5. **Write discipline over quantity**: low-entropy / context-poor entries should be rejected.
6. **Output aligns with the user, does not upstage**: match the user's language and pace; the tool itself does not steal focus.

---

## 3. Definitions

- **knowledge** — reusable project cognition; the minimal form is a markdown bullet plus 5-field metadata embedded in HTML comments; the assembled form is a structured document under `docs/`.
- **learn** — capture conversation or explicit claims into knowledge units (5 modes: N new / U update / D delete / E behavioral retrospective / F flow-embedded).
- **write** — generate or update structured docs from templates.

---

## 4. Session Prompts

### 4.1 Emit entry-point guidance at session start

When entering a project in a new session, prompt the project progress.

Output template:

```
[know] project entry: CLAUDE.md (status) / $DOCS/roadmap.md (roadmap)
```

### 4.2 Emit a hit prompt when using existing docs / knowledge

When reading existing docs or knowledge entries to support a decision, prompt the user that knowledge or a doc was hit.

Output template:

```
[know:hit] {relative path or ~ path}:{section / entry id}
```

### 4.3 Capture / documentation suggestion prompt

Before each turn's response, the AI asks itself 3 questions to decide whether to prompt; any `no` means do not prompt.

Decision questions (in order)

1. **New artifact** — did this turn produce a new rule / plan / decision?
2. **Reusable** — will this artifact be used again in different future sessions or tasks?
3. **Form** — single rule (<1 paragraph) → `/know learn`; full plan (≥1 section) → `/know write`

Output template:

```
[know:suggest] {≤12-char trigger reason} → /know {learn|write [type]}?
```

Exception: when already inside the `learn` / `write` pipeline → do not prompt.

---

## 5. Route

**Flow**

1. First-word match (case-insensitive) on `learn|write` → dispatch directly `[route] → {pipeline}`
2. Otherwise judge the text + session context against each question below; any `yes` makes that pipeline a candidate:
  - Does the user want to capture an experience / decision / lesson? → `learn`
  - Does the user want to produce a structured doc (prd/tech/arch/...)? → `write`
   Exactly one yes → dispatch directly; both yes → present candidates and let the user choose; all no → Step 3
3. All no → ask the user about intent directly

**Examples**

```
/know write arch             → [route] → write        # first-word hit
/know capture this lesson    → [route] → learn        # single yes locks in
/know do that thing          → [route] I don't get what you want — could you be more specific?
```

Load on demand: `workflows/learn.md`, `workflows/write.md`.
