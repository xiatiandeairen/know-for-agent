# review — 知识条目审计

## Progress

Steps: 4
Names: Load, Display, Process, KeywordAudit

共享定义（schema、decay、输出标记）→ SKILL.md。

---

## Step 1: Load

Model: sonnet

参数解析：

| 输入 | scope | level |
|---|---|---|
| `/know review` | `project` | both |
| `/know review <scope>` | argument | both |
| `/know review --level user` | `project` | user only |
| `/know review <scope> --level user` | argument | user only |

```bash
# [RUN] --level 透传给 know-ctl；省略即合并两个 level
bash "$KNOW_CTL" query "{scope}" {--level {level} if provided}
```

0 条结果 → 输出 `[review] No entries found.` → 退出。

每条结果带 `_level` 字段，在表格中展示（见 Step 2）。逐行解析，从 `created` 字段算出 age（天）。

---

## Step 2: Display [STOP:choose]

Model: sonnet

展示前先显示 metrics 摘要：

```bash
# [RUN]
bash "$KNOW_CTL" metrics 2>/dev/null | grep -E "命中率|防御次数"
```

按 lifecycle stage 排序（最需处理的在前），同 stage 内按 age 倒序：

1. `[silent]` — 无命中，候选清理
2. `[new]` — 刚加入，尚未验证
3. `[active]` — 有命中记录

### Lifecycle stage (v7)

每条从 **events.jsonl** 实时计算（hits 为派生字段，不存储）：

- 命中次数：events 中 `level` 匹配 `_level` 且 summary 匹配的事件数
- Age = 今天 − `created`

| Stage | 条件 | Label |
|---|---|---|
| new | age < 7d 且 hit_count = 0 | `[new]` |
| active | hit_count > 0 | `[active]` |
| silent | hit_count = 0 且 age ≥ 7d | `[silent]` |

注：v7 decay 为 no-op，暂无 `[endangered]` stage（decay 重做后可能恢复）。

### 高亮以下问题

- 重复条目（summary/scope 相近）
- 过期条目（ref 指向已删除的 docs 段）
- scope 过宽或过窄
- summary 不清晰
- strict 值错误（rule 应硬但标 soft，或反之）
- 可合并条目

```
[review] {N} entries found:

| # | level | tag | strict | scope | ref | hits | age | summary | stage |
|---|-------|-----|--------|-------|-----|------|-----|---------|-------|
| 1 | project | rule | ⚠ hard | Auth.session | docs/decision/auth.md#refresh | 5 | 30d | session 过期必须刷新... | [active] |
| 2 | user | insight | — | methodology.general | — | 0 | 15d | 单一来源原则... | [silent] |

All ok? Or enter numbers to process (e.g. "2" or "1,3"):
```

| 用户回复 | 动作 |
|---|---|
| all ok / ok / 没问题 | 退出 |
| 数字 | → Step 3 处理选中条目 |

---

## Step 3: Process

Model: sonnet

每条选中条目：

```
[review] #{N}: {summary}
Tag: {tag} | Strict: {strict or "—"} | Ref: {ref or "—"} | Hits: {hits} | Age: {age}d
Action? A) Delete  B) Update  C) Merge  D) Keep
```

### A) Delete

仅删明显低价值、过期、重复且无保留理由的条目。不激进清库。

```bash
# [RUN]
bash "$KNOW_CTL" delete "{summary_keyword}" --level {entry._level}
```

输出：`[review] Deleted: {summary}`

### B) Update

用户描述变更 → 重新生成 summary → 展示更新后条目 [STOP:confirm] → 确认后：

```bash
# [RUN]
bash "$KNOW_CTL" update "{old_summary_keyword}" '{"summary":"{new_summary}"}' --level {entry._level}
```

可更新字段：summary、scope、tag、strict（仅 rule）、ref。

输出：`[review] Updated: {new_summary}`

### C) Merge

两条互补（同主题、不同角度）时：

1. 用户选目标条目
2. 合并 summary — 保留更清晰的，补充缺失上下文
3. 若两条 ref 指向不同 docs，保留用户选择的那条；另一条内容可另起 anchor 引用
4. 删除源条目

```bash
# [RUN]
bash "$KNOW_CTL" update "{target_keyword}" '{"summary":"{merged_summary}"}' --level {target._level}
bash "$KNOW_CTL" delete "{source_keyword}" --level {source._level}
```

输出：`[review] Merged into: {merged_summary}`

### D) Keep

输出：`[review] Kept: {summary}`

全部处理完：`[review] Done: {deleted} deleted, {updated} updated, {merged} merged, {kept} kept`

---

## Step 4: Keyword Vocabulary Audit（同义词归并）

Model: sonnet

Step 3 结束后运行。目的：词表健康治理——发现同义词、拼写变体、过泛词并建议合并。

```bash
# [RUN] 拉当前词表
bash "$KNOW_CTL" keywords
```

输出每个 keyword 的使用次数。扫词表找**合并候选**：

| 模式 | 例子 | 建议行动 |
|---|---|---|
| 同义词 | `webhook`, `webhook-handler`, `web-hook` | 合并到最精简词（`webhook`）|
| 单复数 | `worker`, `workers` | 合并到单数 |
| 拼写变体 | `auth`, `authentication` | 保留更完整的 |
| 过泛词 | `code`, `bug`, `file` | 建议删除（无区分度）|
| 低频孤词 | 仅 1 条 trigger 用 | review 是否值得保留 |

每个建议呈现给用户：

```
[review] keyword audit:
  webhook (5), webhook-handler (1) → merge to 'webhook'?  [y/N]
  worker (8), workers (2) → merge to 'worker'?  [y/N]
  code (3) → remove as overly generic?  [y/N]
```

用户选 `y` 后批量执行：

```bash
# [RUN] 对每条含旧 keyword 的 trigger 替换
bash "$KNOW_CTL" update "<keyword-in-summary>" '{"keywords":[<新 keywords 数组>]}' --level <L>
```

输出：`[review] keyword audit: {N} merged, {M} removed`

**治理节奏**：每 20-30 条新 trigger 后跑一次，或 `/know report` 发现词表膨胀时跑。

---

## Completion

- 每条选中条目均有 `[review]` 确认输出
- triggers.jsonl 与实际动作一致（v7：无 detail 文件）

## Recovery

| 错误 | 处理 |
|---|---|
| `know-ctl delete/update` 失败 | 报错，跳过该条，继续下一条 |
| 用户中途取消 | 已处理条目保留，剩余跳过 |
