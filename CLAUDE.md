# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

know — AI 辅助的高熵知识单元 authoring 工具 + Claude Code 生态原生载体。Claude Code plugin。

**当前状态（pivot 后）**：v1 `write` 已实现可用；v2 `learn` 体系（5 模式 + entropy gate + 5 字段元数据）规划中。运行时检索（recall / extract / review / report / decay）已下线，由 Claude Code 嵌套 CLAUDE.md 加载机制接管。

入口仅 `/know learn` + `/know write`。Roadmap 见 `docs/roadmap.md`，pivot 前迭代史归档在 `docs/milestones/history.md`。

## Architecture

```
skills/know/SKILL.md          ← Skill 入口：仅 routing + conventions（最小常驻上下文）
workflows/                     ← Pipeline 定义，按需加载
  learn.md                       v2 重写中（旧 v7 版本待重构为 5 模式）
  write.md                       v1 文档撰写流程（沿用，保留中）
docs/
  templates/                   ← write 用文档模板 + 检查清单
  roadmap.md                     v2 路线图
  capabilities.md / marketing.md / ops.md   产品文档（待 v2 实现进行时回填）
  arch/ decision/ requirements/  历史决策与架构记录
  milestones/history.md          pivot 前 v1-v7 / M1-M15 迭代归档
tests/
  capability/write/            ← write 能力 fixtures（保留）
scripts/                       ← 空。v2 计划无运行时脚本依赖
```

## Key Design Decisions

- **存储**：markdown bullet + HTML 注释嵌入 5 字段元数据（id/created/updated/tag/strict?），与 Claude Code 原生加载兼容；无私有 JSONL，无 events.jsonl。
- **入口**：仅 `learn` + `write`，砍掉 recall / extract / review / report / decay。
- **激活**：由 Claude Code 嵌套 CLAUDE.md 加载机制承担，know 不做运行时检索。
- **learn 5 模式**：N 新增 / U 修改 / D 删除 / E 行为复盘（融合 evolution skill）/ F 流程内嵌（inline 注释 `// @know:flow=...` 或结构化 log）。
- **6 类知识 × 3 级 level**：A 结构性 / B 决策 / C 教训 / D 方法论 / E AI 偏好 / F 数据流业务流；level = user / project / module。
- **写入纪律**：entropy gate 三问（≥ 20% 拒绝率为目标），低熵 / 缺上下文的条目宁可拒绝。
- **write 沿用 v1**：10 种文档类型 + 模板 + sufficiency gate + 数据置信规则；高风险类型（prd/tech/arch/schema/decision/ui）通过问题驱动的 sufficiency gate。
- **数据置信**：所有数值必须标注来源（实测 / 估算 / 目标 / 无数据）。
- **Milestone 文档**：§1 目标 + §2 计划（不可变）→ §3 任务追踪 → §4 结果（不可变）。

## Pivot 后清理状态

deep clean 已完成：删除 `PIPELINES.md` / `workflows/{extract,review,report}.md` / `docs/triggers.jsonl` / `docs/schema/` / `scripts/{know-ctl.sh,know-env.sh,lib/}` / `tests/{capability/{learn,recall,recall-pipeline},unit}/`。`workflows/learn.md` 与 `workflows/write.md` 仍保留旧 v7 引用（如 `triggers.jsonl`），由 v2 实现 sprint 重写时清理。
