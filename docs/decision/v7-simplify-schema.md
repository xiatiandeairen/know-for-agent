# v7 — Schema 简化 + 3 文件存储布局 决策记录

## 1. 背景

**触发事件:** v6 完成后使用约 6 个月，命中率稳定在 2%。分析发现两类问题：

1. **Schema 复杂度未兑现价值**：11 字段包含 tier（1/2）+ tm（guard/info）形成 4-level 分级矩阵，learn workflow 每存一条需要决策 tier 和 tm，认知负担高。但数据显示命中率与分级无关——rule+guard+tier=1 和 insight+info+tier=2 的条目实际命中频率无显著差别。分级只是 noise。

2. **存储布局错位**：v6 将 project level entries 放在 `$XDG_DATA_HOME/know/projects/{id}/`（per-machine，不 git），但这些是项目资产（团队共享的约束和决策）。clone 项目后这部分知识消失，与"项目记忆"的初衷矛盾。同时 `entries/{tag}/{slug}.md` 散文件实际无人浏览（不在 docs/ 体系，IDE/Git 工具链不识别），成为孤岛。

**约束:**
- 零外部依赖，继续用 JSONL + Markdown
- 兼容 XDG 规范
- 不引入 compile 机制（延到 v8+）
- decay 策略重做延到下个 sprint

**决策范围:** entry schema 字段数和语义、物理存储布局、recall 分级逻辑。不涉及 decay 新策略、compile 机制。

## 2. 决策

**我们决定:**

1. **Schema 裁到 8 字段**：
   ```json
   {"tag","scope","summary","strict","ref","source","created","updated"}
   ```
   - 删 `tier`、`tm`、`path`
   - 新 `strict`：仅 `tag=rule` 时为 bool；其他 tag 必须 `null`
   - 新 `ref`：替代 path + doc_ref，值域 = docs 段 / 代码锚点 / URL / null
   - `hits` / `revs` 删除（从 events.jsonl 派生）

2. **3 JSONL 文件布局**：
   ```
   <project>/docs/triggers.jsonl          # project source（git）
   $XDG_CONFIG_HOME/know/triggers.jsonl   # user source（dotfiles-git 可选）
   $XDG_DATA_HOME/know/events.jsonl       # runtime, 带 project_id + level
   ```

3. **Recall 去分级**：删除 suggest/warn/block 三档，统一输出；`tag=rule + strict=true` 加 `⚠` 前缀给 AI 信号。

4. **entries/{tag}/{slug}.md 散文件删除**：tier=1 的 context 改为 `ref` 指向 docs/ 现有段落。

5. **decay 本版 no-op**：保留命令可调用性，策略在下个 sprint 重做。

## 3. 备选方案

### 方案 A：裁 schema + 3 文件（选）

**优点:**
- 认知负担显著降：字段 11→8，learn 步骤 10→9
- triggers 进项目 git：clone 即得团队触发器，修正 v6 错位
- 源与运行时按 XDG 规范分层（CONFIG vs DATA）
- events 单文件 + project_id/level 字段天然支持跨项目分析
- 孤岛散文件消除，context 在 docs/ 可浏览

**缺点:**
- 破坏性变更，需要一次性迁移（migrate-v7 承担）
- decay 重做推后
- 历史 hits/revs 字段数据丢失（从 events 重构时不全）

### 方案 B：保留 tier/tm，只搬存储位置

**优点:**
- 迁移更简单
- 保留 4-level 分级

**缺点:**
- 认知负担没降，learn 仍复杂
- 命中率 2% 证明分级无实际价值，保留是沉没成本思维

### 方案 C：加 compile 机制，trigger 全从 docs 派生

**优点:**
- 单一 source of truth，无漂移
- 完全消除"碎片 vs 体系"分类问题

**缺点:**
- 实现复杂（需扫 markdown + 解析注释 + 重编译）
- 原子事实（单句规则）强塞 docs 不自然
- 改动面过大，违反 YAGNI

## 4. 影响

**正面影响:**
- 项目 clone 即得团队触发器（v6 丢失的能力恢复）
- user triggers 放 `$XDG_CONFIG_HOME`，用户可选自己 dotfiles git
- 跨项目 metrics 聚合（v6 P2 延后项）天然实现（events 单文件 + project_id filter）
- know-ctl 代码简化（删 metrics_inc/metrics_add_scope 等约 70 行）
- 运行时 drift 风险消除（唯一 SoT 是 events）

**负面影响:**
- 一次性破坏性迁移（需要 migrate-v7 + 用户手工确认）
- legacy detail files 的内容归并到 `docs/legacy-v6-details.md` 需用户 review 后手工重组
- 历史 hits 数据不保留（从迁移起重新累积）

**后续行动:**
- v7.x：decay 新策略（基于 events 的真实活跃度而非年龄）
- v8+：考虑 compile 机制（docs annotation → trigger 自动派生）
- 观察 user level triggers 实际使用量；若 >20 条稳定沉淀，考虑提供 dotfiles 同步模板

## 5. 状态

**accepted**

> 决策日期: 2026-04-22
> 相关 sprint: 20260422-160156-242
> 决策人: project author
> 前置决策: v6（XDG + level 双层）见 `docs/decision/xdg-dual-level.md`
