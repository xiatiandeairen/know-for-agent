# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

know — AI 辅助的高熵知识单元 authoring 工具 + Claude Code 生态原生载体。Claude Code plugin。

**当前状态**：两条 pipeline 均已落地，无运行时脚本依赖，路径全部内联在 workflow 里。`learn` 5 stage（detect → gate → refine → locate → write），`write` 5 stage / 9 step（infer → gate → confirm → draft → write）。运行时检索（recall / extract / review / report / decay）已下线，由 Claude Code 嵌套 CLAUDE.md 加载机制接管。

入口仅 `/know learn` + `/know write`。

## Architecture

```
skills/know/SKILL.md          ← Skill 入口：仅 routing + conventions（最小常驻上下文）
workflows/
  learn.md                       learn pipeline（5 stage / 15 step）
  write.md                       write pipeline（5 stage / 9 step，10 种文档类型）
  templates/                     write 用模板 + 检查清单
docs/
  roadmap.md                     路线图
  marketing.md                   推广材料
  arch/                          架构记录（含 know.md 系统架构）
  decision/                      关键决策记录
tests/
  unit/                          workflow 结构单元测试（test-learn-stages / test-write-stages）
```

## Key Design Decisions

- **存储**：知识写入 CLAUDE.md 的 `## know` YAML block（4 字段：when / must|should|avoid|prefer / how / until），与 Claude Code 原生加载兼容；无私有 JSONL，无 events.jsonl。
- **入口**：仅 `learn` + `write`，砍掉 recall / extract / review / report / decay。
- **激活**：由 Claude Code 嵌套 CLAUDE.md 加载机制承担，know 不做运行时检索。
- **learn gate 5 道**：信息熵 → 复用 → 可触发 → 可执行 → 失效，从粗到细，每道先给调整方向再拒绝，目标拒绝率 ≥20%。
- **claim 分类**：`[纠正]`（用户纠正 AI）bypass 信息熵 gate；`[捕捉]`（AI 自主捕捉）需完整 gate。
- **locate 三级**：user（需真实跨项目证据，"理论上成立"不够）/ module（有具体代码目录）/ project（默认）。优先级 user > module > project，路径内联在 learn workflow。
- **write 沿用 v1**：10 种文档类型 + 模板 + sufficiency gate + 数据置信规则；高风险类型（prd/tech/arch/schema/decision/ui）通过问题驱动的 sufficiency gate。
- **数据置信**：所有数值必须标注来源（实测 / 估算 / 目标 / 无数据）。

## know

```yaml
- when: know learn gate 评估 [捕捉] 类 claim 时，内容属于通用编程/写作常识（样式偏好、格式规范、普遍最佳实践等）
  avoid: 放行此类 claim — capable model 已知这些规则，写入 CLAUDE.md 不会改变 AI 行为，只增加噪声
  until: 使用推理能力不足的模型时
```

## 清理状态

deep clean 已完成（pivot 后多轮）：删除 `PIPELINES.md` / `workflows/{extract,review,report}.md` / `scripts/{know-ctl.sh,know-paths.sh,know-env.sh,lib/}` / `install.sh` / `uninstall.sh` / `tests/capability/` / `tests/unit/test-know-paths.sh` / `docs/{triggers.jsonl,schema/,capabilities.md,ops.md,milestones/history.md,requirements/}`。`tests/unit/` 存 `test-learn-stages.sh` 与 `test-write-stages.sh`（workflow 结构断言）。`workflows/{learn,write}.md` 路径全部内联，无 `know-paths.sh` 残留。
