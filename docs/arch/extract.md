# Extract 架构设计

## 1. 定位与边界

### 职责

负责从源码（而非对话）中挖掘隐性知识（注释、硬编码常量、错误处理模式等）并写入知识库，为冷启动或代码回补知识提供入口。

### 不负责

- 从对话提取知识（→ learn.md workflow）
- 源码的事实正确性判断（只挖掘，不修复）
- 二进制 / 非文本文件分析
- 对已有 entry 的增量更新（会走 Conflict 步骤合并，但不主动更新）

## 2. 结构与交互

### 组件图

```
[入口]                        [扫描]
  /know extract [path/glob]     Step 1 Locate files
  命中文件集合                   Step 2 Scan patterns
                                 （注释 / 常量 / 错误 / TODO / 约束）
                                        │
                                        ▼
[筛选与结构化]                [Level 决策 + 持久化]
  Step 3 Filter (noise)          Step 4 Confirm with user
  Step 3 Classify (tag)          Step 5 Write
  Step 3 Summary                 know-ctl append --level project
  source="extract"               （extract 默认 project）
```

### 组件表

| 组件 | 职责 | 边界规则 |
|---|---|---|
| Locate | 按 glob 收集候选文件 | 禁止扫非文本；必须支持 `.gitignore` 风格排除 |
| Scan patterns | 按模式识别候选知识（约束型注释 / 幻数 / 异常分支等） | 禁止臆造候选；必须每条附源文件位置 |
| Filter & Classify | 过滤低信号 + 分配 tag | 禁止承接 learn 的 Challenge 职责（extract 质量次一级）|
| 持久化 | 经用户确认后 append，`source="extract"` | 禁止默认写 user（源码是项目级事实）；必须带行号到 summary |

### 数据流

```
path/glob --Locate--> file 集
file --Scan patterns--> 候选（含文件位置）
候选 --Filter+Classify--> claim 集（tag/summary 初步）
claim --用户 Confirm--> approved 集
approved --know-ctl append --level project --source=extract--> index.jsonl
```

| 来源 | 目标 | 数据格式 | 类型 | 说明 |
|---|---|---|---|---|
| 文件系统 | Scan | 源码文本 | 强 | 无源码无 candidate |
| Scan | Filter | (文件, 行号, 模式, 摘要) | 强 | 位置信息必须保留到 entry summary |
| Confirm | 持久化 | 选中 claim 列表 | 强 | 用户挑选决定最终写入 |
| 持久化 | know-ctl append | JSON + level=project | 强 | source 字段标记来源便于 review |

## 3. 设计决策

### 驱动因素

| 因素 | 类型 | 对架构的影响 |
|---|---|---|
| 老项目冷启动时对话量为 0 | 业务需求 | 必须支持从源码挖掘知识补空 |
| 源码注释 / 常量往往编码约束 | 业务需求 | 必须识别约束型注释模式 |
| extract 信号密度低于 learn | 质量要求 | 必须用户逐条 Confirm，不自动入库 |
| 源码 = 项目级事实 | 业务需求 | 默认 level=project；user 级不适用 |

### 关键选择

| 决策 | 选择 | 被拒方案 | 为什么 |
|---|---|---|---|
| 触发方式 | 用户主动 `/know extract` | 后台自动扫描 | 源码挖掘噪声高，需用户在场判断 |
| 文件范围 | 用户给 path/glob | 全仓库扫 | 全仓库代价高且多数文件无知识；用户圈定更精确 |
| Level 默认 | project（不接受 user） | 可选 | 源码反映项目事实；不该污染跨项目 user 库 |
| 去 Challenge | 只过一遍 Filter，不跑 5 问 | 与 learn 同强度 | 源码事实明确度通常高于对话信号，过严会误删 |

### 约束

- 禁止 extract 默认 level 为 user（`source="extract"` 必定写入 project）
- 禁止扫描非文本文件（binary / 图片）
- 必须在 summary 中附带源文件路径 + 行号（便于后续回溯）
- 必须经用户 Confirm 才能 append（禁止自动入库）

## 4. 质量要求

| 属性 | 指标 | 目标 |
|---|---|---|
| 候选准确率 | Scan 识别的候选中用户 Confirm 的比例 | >50%（目标值，待验证） |
| 扫描耗时 | 单次 extract 执行耗时 | <30s（1000 文件内；目标值，待验证） |
| 位置完整 | entry summary 含文件 + 行号的比例 | 100%（必须） |
| 遗漏率 | 源码含约束但未识别的比例 | 目标值，待验证（缺乏真值集） |
