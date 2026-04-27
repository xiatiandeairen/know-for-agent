# Know 系统架构

## 1. 定位与边界

### 职责

两个主动触发 pipeline：
- learn — 从对话提取 claim，5 stage 筛选后写入目标 CLAUDE.md 的 `## know` YAML block
- write — 按模板从对话生成结构化 markdown 文档，存入 `docs/`

知识的运行时激活由 Claude Code 嵌套 CLAUDE.md 加载机制承担，know 不做检索。

### 不负责

- 运行时知识检索（→ Claude Code 嵌套加载机制）
- 文档内容的事实准确性（→ 对话上下文）
- 代码修改执行（→ agent Edit/Bash 工具）

## 2. 结构

### 组件

- SKILL.md 路由 — 解析 `/know` 命令分发到 learn 或 write workflow；仅路由，不含执行逻辑
- Learn pipeline — detect → gate → refine → locate → write，5 stage 串行，每条 claim 独立走完
- Write pipeline — 参数推断 → 充分性检查 → 确认 → 模板填充 → 写入 → 校验 → 回写父文档 → 索引注入

无运行时脚本：路径表全部内联在 workflow 内，learn 与 write 都不依赖 shell helper。

### 存储

知识写入 markdown 文件，git 跟踪：
- CLAUDE.md 文件（user / project / module 三级）— learn 的输出，`## know` YAML block 格式
- `docs/` 下结构化 markdown — write 的输出，按文档类型分路径

无私有 JSONL，无数据库，无运行时检索层。

### 数据流

```
对话 → /know learn → detect → gate → refine → locate → write → CLAUDE.md (## know block)
对话 → /know write → type+path 推断 → sufficiency gate → template 填充 → docs/{path}.md
```

## 3. 设计决策

- SKILL.md 仅路由，workflow 按需加载 — 上下文窗口有限，常驻内容最小化
- 知识存 markdown + YAML block — 与 Claude Code 嵌套加载原生兼容，无额外基础设施
- learn gate 5 道从粗到细 — 拒绝低熵 claim，目标拒绝率 ≥20%
- 砍 recall / extract / review / decay — 经实证 ROI 不显著，由 Claude Code 原生加载机制替代

## 4. 质量要求

- 模块独立性：learn 与 write 互不调用，通过 SKILL.md 路由分发
- 无私有依赖：bash + git，零额外运行时依赖
- 写入纪律：entropy gate 拒绝率目标 ≥20%（dogfood 30 天实测）
