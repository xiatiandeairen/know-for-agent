# 图表检查清单

<!-- 共享资源。tech/arch/schema/ui 的 checklist 和 validate 步骤引用此文件。
     write pipeline Step 5.5 Validate 对每个触发条件逐项检查。 -->

## 触发规则

逐条检查。满足触发条件 → 文档中必须包含对应图表。不满足 → 跳过。

### 数据流图

- **when**: ≥2 个组件之间有数据传递
- **action**: ASCII 流向图，标注数据格式和传递方向
- **适用**: tech, arch
- **格式**: `组件A --{数据格式}--> 组件B`，每条流向独立一行
- **禁止**: 无标注的裸箭头；省略数据格式
- ❌ `A --> B`
- ✅ `know-ctl --JSONL--> triggers.jsonl --grep--> recall`

### 依赖图

- **when**: ≥3 个模块存在依赖关系
- **action**: ASCII 依赖拓扑，标注强/弱依赖
- **适用**: arch
- **格式**: `模块A ==(强)==> 模块B` 或 `模块A --(弱)--> 模块B`
- **禁止**: 不区分强弱依赖；循环依赖不标注
- ❌ `A -> B -> C`
- ✅ `SKILL.md ==(强)==> know-ctl.sh --(弱)--> events.jsonl`

### 时序图

- **when**: 存在异步交互，或 ≥3 步跨组件调用链
- **action**: ASCII 时序图，标注调用方→被调用方→返回
- **适用**: tech, schema
- **格式**: 竖向时间轴，每行 `调用方 -> 被调用方: {动作}` 或 `被调用方 --> 调用方: {返回}`
- **禁止**: 省略返回值；不标注异步/同步
- ❌ 只画调用不画返回
- ✅
```
User -> CLI: /know learn
CLI -> know-ctl: append '{json}'
know-ctl --> CLI: "Appended: {summary}"
CLI --> User: [persisted] {summary}
```

### 状态图

- **when**: 存在生命周期或状态机（≥3 个状态）
- **action**: ASCII 状态转移图，标注触发条件
- **适用**: tech
- **格式**: `状态A --{触发条件}--> 状态B`，每条转移独立一行
- **禁止**: 省略触发条件；遗漏终态
- ❌ `created -> running -> done`
- ✅ `created --activate--> running --end--> completed` / `running --cancel--> cancelled`

### ER/数据模型图

- **when**: ≥3 个相关实体，或 ≥2 个表/结构有关联关系
- **action**: ASCII 实体关系图，标注关系类型和基数
- **适用**: tech, schema
- **格式**: `实体A }|--|| 实体B : {关系描述}` 或简化为 `实体A 1--N 实体B`
- **禁止**: 不标注基数（1:1/1:N/N:M）；遗漏关键外键
- ❌ `User - Order`
- ✅ `User 1--N Order : places` / `Order N--N Product : contains`

### 模块结构图

- **when**: ≥3 个子模块/层次
- **action**: ASCII 树形或分层图，标注职责边界
- **适用**: arch
- **格式**: 树形缩进，每项附 1 句话职责
- **禁止**: 只列名字不标职责
- ❌
```
know/
  scripts/
  workflows/
```
- ✅
```
know/
  scripts/         # CLI 命令实现
    know-ctl.sh    # 12 个子命令的入口
  workflows/       # 管线流程定义
    learn.md       # 知识提取 8 步管线
    write.md       # 文档生成 7 步管线
```

### 交互流程图

- **when**: 用户操作有分支路径（≥2 个分支）
- **action**: ASCII 流程图，标注触发→响应→分支
- **适用**: ui
- **格式**: 每步 `[触发] → {响应} → [下一步 | 分支A / 分支B]`
- **禁止**: 省略分支条件；只画主路径不画异常路径

### 布局草图

- **when**: 有页面/界面设计
- **action**: ASCII 区域划分图
- **适用**: ui
- **格式**: 用 `+---+` 框线划分区域，每个区域标注名称和优先级
- **禁止**: 用文字描述替代草图

## 校验规则

Step 5.5 Validate 检查：

1. **逐条触发检查** — 遍历所有图表类型，满足 when 条件的必须有对应图表
2. **图表有标注** — 每个图的连线/箭头/节点都有文字标注
3. **图文一致** — 图中的组件/实体名与正文描述一致
4. **缺失报告** — 满足触发但无图表 → 报告缺失，要求补充或标注"待补充（原因）"
