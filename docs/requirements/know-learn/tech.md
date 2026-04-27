# /know learn 技术方案

## 1. 背景

### 技术约束

- 知识存储：markdown + YAML block，无私有 JSONL，与 Claude Code 嵌套加载兼容
- 路径解析：通过 know-paths.sh 统一解析（project-claude-md / user-claude-md / module 三级）
- 写入格式：`## know` YAML block，4 字段（when / must|should|avoid|prefer / how / until）
- 模块独立：learn 与 write 互不调用，通过 SKILL.md 路由分发

### 前置依赖

- `scripts/know-paths.sh` — 路径解析 CLI — 已完成
- `workflows/learn.md` — 5 stage pipeline 定义 — 已完成

## 2. 方案

### 文件/模块结构

- `skills/know/SKILL.md` — 意图路由，/know learn 入口
- `workflows/learn.md` — 5 stage pipeline：detect → gate → refine → locate → write
- `scripts/know-paths.sh` — 路径解析（project-claude-md / user-claude-md）

### 核心流程

1. detect — 从最近 ≤20 轮对话中分类提取 claim 候选：A 类（用户纠正，直接进候选）/ B 类（AI 捕捉，需强化信息熵验证）；用户取子集
2. gate — 5 道从粗到细依次过滤：信息熵 → 复用 → 可触发 → 可执行 → 失效；每道：Q 驱动评估 → 给出调整方向 → 用户确认 → 重跑一次 → 仍 fail → reject
3. refine — 3 个可选加工维度：场景泛化（when 更通用）、知识深化（补理由根因）、颗粒度校准（多逻辑拆分）
4. locate — 脚本解析候选路径，默认 project；user 级需要真实跨项目证据；module 级指向具体代码目录
5. write — 产出 YAML entry → 查重（`## know` block 中语义重合检测）→ 用户确认 → Edit 追加到目标文件末尾

### 写入格式

```yaml
- when: {触发场景}
  must: {claim} — {理由}   # 或 should / avoid / prefer
  how: {操作指引}           # 仅技术类必填
  until: {失效条件}         # must 必填，其余选填
```

写入位置：目标 CLAUDE.md 的 `## know` YAML block 末尾；段不存在时追加到文件末尾。

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 存储格式 | markdown + YAML block | JSONL 需私有 CLI，markdown 与 Claude Code 嵌套加载原生兼容，git 可 diff |
| gate 顺序 | 大漏斗→小漏斗（信息熵最宽，可执行最窄） | 成本最低的粗筛先过，节省后续精细判断开销 |
| A 类 bypass 信息熵 | 纠正类直接进候选 | 用户纠正本身即证明 AI 会犯错，信息熵验证冗余 |
| user level 升级门槛 | 要求真实跨项目证据 | "理论上成立"不够，防止过度泛化污染用户级知识库 |
| 调整前不 reject | gate 先给调整方向，reject 是最后手段 | 直接 reject 浪费有价值但表述不准确的知识 |

## 4. 迭代记录

### 2026-04-27

- 完整重写：从旧 JSONL+know-ctl.sh 架构迁移到 markdown+YAML block 架构
- 5 stage pipeline（detect/gate/refine/locate/write）替代旧 8 步流程
- 新增 A/B 类 claim 分类 + refine stage（场景泛化/知识深化/颗粒度校准）
- 移除 tiers、know-ctl.sh、.know/entries、decay 等已下线组件

### 2026-04-15

- 重构 Step 1 Detect（旧版本）

### 2026-04-10

- learn 管线端到端跑通（旧版本，基于 know-ctl.sh + JSONL）
