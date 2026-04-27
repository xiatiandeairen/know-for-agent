# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

know — AI 辅助的高熵知识单元 authoring 工具 + Claude Code 生态原生载体。Claude Code plugin。

**当前状态**：v1 `write` 已实现可用；v2 `learn` 5 stage pipeline（detect → gate → refine → locate → write）已设计完成，进入 dogfood 阶段（N 模式）。运行时检索（recall / extract / review / report / decay）已下线，由 Claude Code 嵌套 CLAUDE.md 加载机制接管。

入口仅 `/know learn` + `/know write`。Roadmap 见 `docs/roadmap.md`，pivot 前迭代史归档在 `docs/milestones/history.md`。

## Architecture

```
skills/know/SKILL.md          ← Skill 入口：仅 routing + conventions（最小常驻上下文）
workflows/                     ← Pipeline 定义，按需加载
  learn.md                       v2 learn pipeline（5 stage，N 模式可用）
  write.md                       v1 文档撰写流程（8 步，10 种文档类型）
docs/
  templates/                   ← write 用文档模板 + 检查清单（workflows/templates/）
  roadmap.md                     v2 路线图
  capabilities.md / marketing.md / ops.md   产品文档
  arch/ decision/ requirements/  架构记录与决策
  milestones/history.md          pivot 前 v1-v7 / M1-M15 迭代归档
tests/
  capability/write/            ← write 能力 fixtures
scripts/
  know-paths.sh                ← 路径解析（root/docs/templates/project-claude-md/user-claude-md），支持 env 覆盖
```

## Key Design Decisions

- **存储**：知识写入 CLAUDE.md 的 `## know` YAML block（4 字段：when / must|should|avoid|prefer / how / until），与 Claude Code 原生加载兼容；无私有 JSONL，无 events.jsonl。
- **入口**：仅 `learn` + `write`，砍掉 recall / extract / review / report / decay。
- **激活**：由 Claude Code 嵌套 CLAUDE.md 加载机制承担，know 不做运行时检索。
- **learn gate 5 道**：信息熵 → 复用 → 可触发 → 可执行 → 失效，从粗到细，每道先给调整方向再拒绝，目标拒绝率 ≥20%。
- **claim 分类**：`[纠正]`（用户纠正 AI）bypass 信息熵 gate；`[捕捉]`（AI 自主捕捉）需完整 gate。
- **locate 三级**：project（默认）/ module（有具体代码目录）/ user（需真实跨项目证据，"理论上成立"不够）。
- **write 沿用 v1**：10 种文档类型 + 模板 + sufficiency gate + 数据置信规则；高风险类型（prd/tech/arch/schema/decision/ui）通过问题驱动的 sufficiency gate。
- **数据置信**：所有数值必须标注来源（实测 / 估算 / 目标 / 无数据）。

## know

```yaml
- when: know learn gate 评估 [捕捉] 类 claim 时，内容属于通用编程/写作常识（样式偏好、格式规范、普遍最佳实践等）
  avoid: 放行此类 claim — capable model 已知这些规则，写入 CLAUDE.md 不会改变 AI 行为，只增加噪声
  until: 使用推理能力不足的模型时
```

## 清理状态

deep clean 已完成（pivot 后）：删除 `PIPELINES.md` / `workflows/{extract,review,report}.md` / `docs/triggers.jsonl` / `docs/schema/` / `scripts/{know-ctl.sh,know-env.sh,lib/}` / `tests/capability/{learn,recall,recall-pipeline}/`。`tests/unit/` 存在，含 `test-know-paths.sh`（16 cases，验证路径解析含 project-claude-md / user-claude-md）。`workflows/learn.md` 与 `workflows/write.md` 均已重写，无旧 v7 残留。
