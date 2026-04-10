# retrieve — Context Injection

Surface the right knowledge at the right time with minimal token cost.

---

## Step 1: Trigger

| Trigger | When | Scope Source |
|---------|------|-------------|
| `/know` | User invokes without args | `project` |
| `/know <scope>` | User specifies scope | User input |
| Read/Edit file | AI opens a file | File path extraction |
| Task description | User describes a task | Keyword extraction |
| Decision point | AI generates multiple candidates or modifies interfaces | Current working scope |

**De-duplication**: Same scope is only triggered once per session. Track triggered scopes in conversation state.

---

## Step 2: Resolve Scope Keypath

### From file path

Use scope resolution rules defined in SKILL.md → Scope Resolution from File Path.

Priority: project-specific rules (P1) → industry-standard directories (P2) → language conventions (P3) → generic fallback (P4) → filename (P5).

Example mappings:
```
src/auth/middleware/jwt.ts        → auth.middleware
packages/scoring/engine.py       → scoring
lib/utils/helpers.rb              → utils
cmd/server/main.go                → server
crates/parser/src/lib.rs          → parser
src/mac/Packages/LoppyMetrics/    → LoppyMetrics
```

### From task description

AI infers the most relevant scope from the task description. Use `know-ctl stats` to see existing scopes as reference:

```bash
# [RUN] List all unique scopes for reference
bash "$KNOW_CTL" stats
```

Select the scope that best matches the task's domain. Prefer specific scopes over broad ones. If no existing scope matches, use `project`.

### From user input

`/know LoppyMetrics` → scope = `LoppyMetrics`
`/know LoppyMetrics.DataEngine` → scope = `LoppyMetrics.DataEngine`

---

## Step 3: Query Index

```bash
# [RUN] Scope prefix match, exclude expired 备忘 entries
bash "$KNOW_CTL" query "<scope>"
```

The script handles:
- Scope prefix matching (including `project` wildcard)
- Array scope intersection
- 备忘 (tier 2) expiry filtering (hits=0 + created > 30d)

### Zero Results Handling

If query returns 0 entries:
1. Try parent scope (e.g. `LoppyMetrics.DataEngine` → `LoppyMetrics`)
2. If still 0, try `project` scope
3. If still 0, output: `> [retrieved] 范围: {scope} | 无匹配条目`

---

## Step 4: Sort

Apply multi-key sort to query results:

```
1. tm: active:defensive > active:directive > passive
2. tier: 1 (重要) > 2 (备忘)
3. hits: descending (frequently used first)
4. updated: descending (recent first)
```

---

## Step 5: Truncate by Entry Limit

| Trigger | Max Entries |
|---------|-------------|
| `/know` | 10 |
| `/know <scope>` | 10 |
| Read/Edit file | 3 |
| Task description | 5 |
| Decision point | 3 |

Take top N from sorted results. Discard the rest.

---

## Step 6: Output

### Explicit trigger (`/know`, `/know <scope>`)

Display full retrieval list:

```
> [retrieved] 范围: LoppyMetrics | 4 条

[active:defensive|T1] 阈值只在 PressureLevel 定义，禁止硬编码数字
[active:defensive|T1] 使用 Combine 而非 AsyncStream — 无堆栈信息，背压弱
[passive|T2] DataEngine 单例在测试 target 间泄漏状态 — 用协议注入
[passive|T2] Panel bunny 使用 Canvas 实时绘制，非帧动画
```

For 重要 (tier 1) `active` entries: auto-expand detail file via Read tool (`$ENTRIES_DIR/{path}`).

For 重要 (tier 1) `passive` + 备忘 (tier 2): summary only. User can request detail explicitly.

### Implicit trigger (Read/Edit, task, decision point)

Silent injection — do not display retrieval list. Instead, incorporate retrieved knowledge directly into reasoning and responses.

Behavior by trigger mode:
- `active:defensive` → Check current action against constraint/pitfall before proceeding
- `active:directive` → Apply recommended approach from rationale/concept
- `passive` → Available as background context, used only when relevant

---

## Step 7: Update Hits

For each entry included in output (explicit) or consumed (implicit):

```bash
# [RUN]
bash "$KNOW_CTL" hit "<path-or-summary-hash>"
```

Increments `hits` by 1, updates `updated` to today. Feeds into decay policy.
