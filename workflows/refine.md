# refine — Skill Description Optimization

## Progress

Steps: 3
Names: Analyze, Rewrite, Output

---

## Step 1: Analyze

Model: opus

Read the current skill description. Identify:

- Structural issues (ordering, duplication, inconsistency, uneven depth)
- Overly rigid rules that suppress model capability
- Missing sections (input/output/purpose gaps)
- Conflicting rules
- Low-quality expression (vague, colloquial, scattered)

---

## Step 2: Rewrite

Model: opus

### Must-do checklist

1. **Preserve original intent** — do not change product positioning or core design decisions
2. **Clean up overly rigid rules** — relax rules that suppress model capability or damage practicality
3. **Fix structural issues** — ordering, duplication, inconsistency, uneven depth, missing input/output/purpose in steps, conflicting rules
4. **Improve expression quality** — convert colloquial to professional, vague rules to clear actionable criteria, scattered text to structured layers, fill boundary gaps, remove low-value repetition
5. **Ensure coverage** — positioning, principles, pipelines (each step's purpose), storage format, recall/review/decay, output style, applicable boundaries

### Quality standard

| Dimension | Requirement |
|-----------|------------|
| Clarity | One glance to understand what the system does. Each pipeline's responsibility is unambiguous. |
| Consistency | Same concept = same name. No contradictions. Similar depth across pipelines. |
| Practicality | No rule overload. Leverages model strengths. Helps real engineering scenarios. |
| Executability | Model can follow it. Human can understand and maintain it. |
| Production-ready | Not a draft or scattered notes. Reads like a mature system manual. |

### Writing style

- Professional, clear, not overly academic
- High information density, structured
- No filler, no pretending to know, no empty statements
- Reads like a mature product's internal system manual combined with an executable prompt

---

## Step 3: Output

Model: sonnet

`[refine]` marker. Output the complete refined version.

If user asks for "just the prompt text" → output text only without explanation.

Otherwise, attach:
- Key changes made
- Which areas became simpler/more practical
- What was removed and why

---

## Completion

- User received a complete, production-quality skill description
- All 5 must-do checklist items addressed
- Quality standard dimensions satisfied

## Recovery

| Error | Recovery |
|-------|----------|
| Original skill description too short to refine | Ask user which aspects to expand |
| User disagrees with changes | Revert specific sections, keep rest |
