---

## name: know

description: AI 辅助的高熵知识单元 authoring 工具——把对话中的隐性知识结构化沉淀为 markdown，把会话决策编译为结构化文档。

# Know

## 1. Overview

让 AI agent 累积并复用项目知识，不必每次会话重新 brief 约束 / 决策 / 历史。两类入口能力：

- **沉淀**（`learn`）— 把对话中的隐性知识结构化沉淀为 `## know` 段下的 YAML entry（4 字段：when / must|should|avoid|prefer / how / until）
- **编译**（`write`）— 按模板由对话和已有知识生成或更新结构化文档

---

## 2. Core Principles

1. **高风险保守**：不可逆或高影响的动作必须有证据并经用户确认。
2. **低风险灵活**：低影响的推断与候选使用完整模型能力，不过度保守。
3. **AI 建议，用户决定**：AI 输出作为候选，最终决策归用户。
4. **小单位沉淀，大单位组装**：知识以原子单元存储，文档由结构化组装产生。
5. **写入纪律高于数量**：低熵 / 缺上下文的条目宁可拒绝。
6. **输出对齐用户，不喧宾夺主**：匹配用户语言与节奏；工具自身不抢焦点。

---

## 3. Definitions

- **知识** — 项目可复用认知；最小形态是 markdown bullet + HTML 注释嵌入的 5 字段元数据，组装形态是 `docs/` 下的结构化文档。
- **learn** — 把对话或显式 claim 沉淀为知识单元（5 模式：N 新增 / U 修改 / D 删除 / E 行为复盘 / F 流程内嵌）。
- **write** — 按模板生成或更新结构化文档。

---

## 4. Environment

- `KNOW_PROJECT_ROOT` — 项目根目录；默认 `git rev-parse --show-toplevel` → `realpath dirname(scripts/know-paths.sh)/..`
- `KNOW_DOCS_DIR` — 结构化文档目录（write 输出落点）；默认 `$KNOW_PROJECT_ROOT/docs`
- `KNOW_TEMPLATES_DIR` — write 模板目录；默认 `$KNOW_PROJECT_ROOT/workflows/templates`

---

## 5. Runtime Behavior

### 5.1 Session 启动时输出入口指引

新会话进入项目时，提示项目进度

输出模版：

```
[know] 项目入口：CLAUDE.md（状态）/ docs/roadmap.md（路线）
```

### 5.2 使用既有 docs / 知识时输出hit提示

读取既有 docs 或知识条目辅助决策时，提示用户hit知识或者文档

输出模版：

```
[know:hit] {相对路径或 ~ 路径}:{section / 条目 id}
```

---

## 6. Knowledge Map

- **项目状态 / 架构（权威）** → 项目根 `CLAUDE.md`
- **跨项目偏好 + auto memory** → `~/.claude/CLAUDE.md` + `~/.claude/projects/{project-id}/memory/`
- **路线图 / v2 规划** → `docs/roadmap.md`
- **架构细节** → `docs/arch/*.md`（与 `CLAUDE.md` 冲突时以 `CLAUDE.md` 为准）
- **决策记录** → `docs/decision/*.md`
- **需求 PRD / 技术方案** → `docs/requirements/{name}/{prd.md,tech.md}`
- **pipeline 执行细则** → `workflows/{learn,write}.md`
- **write 模板** → `workflows/templates/{type}.md`

---

## 7. Route

**流程**

1. 首词匹配（忽略大小写）`learn|write` → 直接分派 `[route] → {pipeline}`
2. 否则按下列问题对 text + 会话上下文逐条判断，yes 即对应 pipeline 候选：
  - 用户想把经验/决策/教训沉淀下来？→ `learn`
  - 用户想产出一份结构化文档（prd/tech/arch/...）？→ `write`
   恰好一个 yes → 直接分派；两个都 yes → 呈现候选请用户选；全 no → Step 3
3. 全 no 直接问用户意图

**示例**

```
/know write arch             → [route] → write        # 首词命中
/know 沉淀下这个经验           → [route] → learn        # 单一 yes 锁定
/know 那个东西搞一下           → [route] 没看懂你要做什么，能说具体点吗？
```

Pipeline 详细定义按需加载：`workflows/learn.md`、`workflows/write.md`。