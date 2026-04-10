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

```
src/mac/Packages/{Module}/{File}.swift  → {Module}.{File}
src/mac/Packages/{Module}/Sources/...   → {Module}
src/mac/App/{SubDir}/{File}.swift       → App.{SubDir}
src/plugins/{Plugin}/{Sub}              → {Plugin}.{Sub}
```

### From task description

Extract module names or domain keywords mentioned in the task. Match against known scope values in index.jsonl:

```bash
# [RUN] List all unique scopes
bash "$KNOW_CTL" stats
```

Select the most specific matching scope.

### From user input

`/know LoppyMetrics` → scope = `LoppyMetrics`
`/know LoppyMetrics.DataEngine` → scope = `LoppyMetrics.DataEngine`

---

## Step 3: Query Index

```bash
# [RUN] Scope prefix match, exclude expired tier-3
bash "$KNOW_CTL" query "<scope>"
```

The script handles:
- Scope prefix matching (including `project` wildcard)
- Array scope intersection
- Tier-3 expiry filtering (hits=0 + created > 30d)

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
2. tier: 1 > 2 > 3
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

For tier-1 `active` entries: auto-expand detail file via `bash "$KNOW_CTL" read "<path>"` or Read tool.

For tier-1 `passive` + tier-2: summary only. User can request detail explicitly.

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
