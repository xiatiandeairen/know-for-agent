# extract — 代码知识挖掘

## Progress

Steps: 6
Names: Scope, Scan, Extract, Filter, Confirm, Write

共享定义（schema / scope / 输出标记）见 SKILL.md。

---

## Step 1: Scope

Model: sonnet

从对话上下文推断要扫描的文件：

| 优先级 | 来源 | 方法 |
|--------|------|------|
| P1 | 最近的工具调用 | 本会话最近 10 次 Read/Edit 路径，去重 |
| P2 | 对话中提及 | 用户显式提到的文件路径 |
| P3 | Fallback | 询问用户：`[extract] No files detected in conversation. Provide path or glob:` |

```
[extract] step: scope
Scan scope:
- src/auth/middleware.ts
- src/auth/session.ts
- src/config/index.ts

Correct? (add/remove files, or confirm)
```

[STOP:confirm] 用户确认或调整 scope。

**限制**：
- 每次最多 10 个文件。超过则按对话相关度排序取前 10，剩余另行记录。
- 二进制/生成文件自动排除。

---

## Step 2: Scan

Model: opus

逐个读取 scope 内文件，识别**代码本身无法直接说明**的知识——即「what」背后的「why」。

### 5 类目标知识

| 类型 | 关注点 | 示例 |
|------|--------|------|
| Design decisions | 为什么用这个模式、这个拆分、这个 wrapper | "用 pub/sub 而非直调以解耦" |
| Implicit constraints | 约定强制但编译器不管的规则 | "所有 handler 处理前必须调用 validate()" |
| Non-obvious dependencies | 顺序、初始化、耦合 | "SessionStore 必须先于 AuthMiddleware 初始化" |
| Configuration rules | 必须保持同步的配置组合 | "TIMEOUT_MS 必须 < RETRY_INTERVAL_MS" |
| Defensive patterns | 针对已知失败模式的防御 | "重试带退避，因上游限流 100 req/s" |

### 扫描原则

- 不复述代码表面已显示的内容
- 聚焦「为何这样写」与「不知道这点会出什么问题」
- 每个文件最多 3 条。超出则按影响排序（引发错误 > 浪费时间），取前 3。

输出：内部列表 `{file, knowledge_item, likely_tag}`，不展示给用户。

---

## Step 3: Extract

Model: opus

将每条知识转成 claim，覆盖四要素：

- **Conclusion**：核心结论
- **Reason**：为何重要
- **Scope**：影响范围
- **Risk**：不知道会怎样

正式字段：

| 字段 | 来源 |
|------|------|
| tag | 由知识类型推断（参 learn.md Step 5a 规则） |
| scope | 文件路径转模块记法（如 `src/auth/middleware.ts` → `auth.middleware`） |
| summary | ≤80 字符，`{conclusion} — {key reason}` |

示例：
- `Retry must use idempotency key — webhook delivery may be duplicated`
- `Worker should start before subscription binding — early events may be missed`

若 Step 2 无收获 → `[extract] No extractable knowledge found in scanned files.` → 退出。

---

## Step 4: Filter

Model: sonnet

应用 learn.md Step 3 过滤规则，额外加一条：

| 条件 | 动作 |
|------|------|
| **Code-obvious**——开发者读此文件 30 秒内可自行理解，无需外部上下文 | DROP |

比 learn 的 "code-derivable" 更严，因为 extract 从代码起步，"不可推导" 的门槛更高。

### 通常 KEEP

- 原因在代码表面看不到
- 容易重复犯错
- 涉及外部系统、时序、顺序、幂等、配置耦合
- 即使单文件也有长期保护价值

过滤后进入 Step 5（v7 无独立 tier 分级；strict 仅对 rule 有效，在 Write 步骤决定）。

```
[skipped] {summary}
Reason: {drop reason}
```

---

## Step 5: Confirm [STOP:choose]

Model: sonnet

若 0 条存活 → `[extract] All items filtered (code-obvious or low impact).` → 退出。

```
[extract] step: confirm
Found {N} knowledge items from {M} files:

1. [{tag}] {summary}
   Source: {file_path}
2. [{tag}] {summary}
   Source: {file_path}

Persist? [all / select numbers / skip]
```

---

## Step 6: Write

Model: sonnet

对每条入选 claim 执行 learn.md Step 4-9（v7）：

1. **Generate**（learn.md Step 4）：tag 已定；算 strict（若 tag=rule）、scope、summary。ref 默认指向源文件带行号（`src/file:42`）。`source: "extract"`。
2. **Conflict**（learn.md Step 5）：查重。
3. **Challenge**（learn.md Step 6）：5 条对抗性提问。
4. **Level**（learn.md Step 7）：extract 默认 project（源文件属项目本地）。
5. **Confirm**（learn.md Step 8）：用户复核最终条目。
6. **Write**（learn.md Step 9）：`know-ctl append --level project` 追加到 triggers.jsonl。

```
[persisted] {scope} :: {summary} (project, strict={bool|null}, ref={file:line})
```

---

## Completion

- 所有入选 claim 均已处理
- 每条已持久化条目：index 行有效 + detail 文件（若 critical）
- 每条 claim 用户都看到 `[persisted]` 或 `[skipped]`

## Recovery

| 错误 | 处置 |
|------|------|
| 文件读取失败 | 跳过该文件继续；末尾汇报 |
| 所有文件被排除（二进制/生成） | `[extract] No scannable files in scope.` → 退出 |
| 批量中单条 claim 失败 | 跳过继续；末尾汇报跳过数 |
| 冲突检查失败 | 视作无冲突，进入 confirm |
