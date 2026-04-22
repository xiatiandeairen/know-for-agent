# XDG 双层存储 决策记录

## 1. 背景

**触发事件:** know 项目运行约 1 年后积累 70+ 条目，出现两类阻塞：
1. `.know/docs/` 与 `.know/index.jsonl` 混在同一目录，文档无法被 IDE/Git 常规工具链识别（预览、diff、PR review 都要切换到非标准路径）
2. 方法论类知识（跨项目通用）无处安放——只能重复在每个项目的 `.know/` 里各存一份，或放进 CLAUDE.md 占用 token 预算

**约束:**
- 零外部依赖，继续用 JSONL + Markdown
- 兼容既有 11 字段 schema（不改字段名）
- 文档必须随项目走（git 跟踪、可 PR review）
- 知识库不应污染项目仓库

**决策范围:** 存储物理布局 + CLI 接口上的作用域维度。不涉及 schema 结构、recall 排序策略、衰减规则。

## 2. 决策

**我们决定:** 采用"项目根 `docs/` + XDG 双层知识库"布局：

- **文档**：`$PROJECT_DIR/docs/`（git 跟踪）
- **知识库 project 级**：`$XDG_DATA_HOME/know/projects/{project-id}/`（按项目 id 隔离）
- **知识库 user 级**：`$XDG_DATA_HOME/know/user/`（跨项目共享）
- CLI 引入 `--level project|user` 贯穿全部 13 个子命令
- 读类命令默认两 level 合并（输出带 `_level` 字段）；写类命令默认 project
- user 写入由 workflow 层二次确认，CLI 不拦截

docs 在项目根是"文档属于项目代码"的自然推论；XDG 是 per-user state 的标准位置。level 维度把"项目专属"与"跨项目"在物理目录上隔离，天然无冲突。

## 3. 备选方案

### 方案 A: 项目根 `docs/` + XDG 双层（选）

**优点:**
- 文档走常规项目路径，IDE / Git / PR 工具链直用
- 知识库完全脱离项目仓库，不污染 git history
- level 物理隔离，无需 schema 改动，查询/迁移/权限都简单
- CLI `--level` 参数显式，读类合并写类隔离的默认符合直觉

**缺点:**
- 旧 `.know/` 用户需手工 `mv`（设计上拒绝自动迁移：自动迁移需要知道用户意图是合并还是覆盖）
- 跨 level metrics 聚合视图未实现（P2 延后）

### 方案 B: 项目内 `.know/` 内部分层

**优点:**
- 无需重新设计存储位置
- 迁移代价小

**缺点:**
- 文档仍在非标准路径，IDE/Git 工具链不友好
- user level 知识无处安放（user 数据放每个项目的 `.know/` 会重复存）

### 方案 C: Entry 内加 `level` 字段 + 单目录共存

**优点:**
- 不动目录结构，只改 schema 与查询逻辑

**缺点:**
- user 与 project 条目共存一个文件，互相污染 git diff
- 删除 user 条目需要遍历过滤，性能和并发都变复杂
- 权限/共享/迁移没有物理边界

## 4. 影响

**正面影响:**
- 文档生产力：IDE 预览、Git diff、PR review 对 `docs/` 直接工作
- 知识复用：方法论知识写一次（user level），所有项目自动带出
- 仓库整洁：`.know/` 消失，项目树减少 1 个常驻目录
- CLI 可脚本化：`--level` 显式参数让外部工具能精准控制作用域

**负面影响:**
- 旧数据迁移：需用户手工 `mv`（READMEs 与 `init` 命令提供 copy-paste 命令）
- 上下文切换：调试时文档与知识库不在同一路径，需要切 tab
- metrics 跨 level 聚合延后，当前只能分别看

**后续行动:**
- v6 后观察 user level 的实际使用量；若 >10 条稳定使用，考虑加跨 level metrics 聚合视图
- 若 user level 形成方法论沉淀习惯，考虑将部分 CLAUDE.md 常驻内容迁到 user knowledge

## 5. 状态

**accepted**

> 决策日期: 2026-04-22
> 相关 sprint: 20260422-134413-380（实施）+ 20260422-144906-094（docs 对齐）
> 决策人: project author
