# write — 文档撰写

基于对话内容生成结构化 markdown 文档。10 种 type，分三种布局（单文件、目录、需求）。

流程：参数推断 → 信息充分性检查 → 确认 → 加载 template → 填充 → 写入 → 校验 → 回写。

## 路径

```bash
KNOW_PATHS="$(git rev-parse --show-toplevel)/scripts/know-paths.sh"
DOCS=$(bash "$KNOW_PATHS" docs)
TEMPLATES=$(bash "$KNOW_PATHS" templates)
```

type 对应输出路径：
- roadmap / capabilities / ops / marketing → `$DOCS/{type}.md`
- arch / ui / schema / decision → `$DOCS/{type}/{name}.md`
- prd / tech → `$DOCS/requirements/{name}/{type}.md`

层级：roadmap → prd → tech，其余独立。roadmap 永远单文件，新版本属 update。

## Step 1 — 参数推断

推断 type、name、mode、parent。统一逻辑：hint → 自动推断 → 一次澄清 → 完整列表回退 → 终止。

### type

10 种 type：roadmap / prd / tech / arch / decision / schema / ui / capabilities / ops / marketing

推断逻辑：
1. hint 是有效 type → 直接采用；hint 存在但不在 10 种内 → 视为 null，走推断
2. 对话匹配 exemplar：唯一命中 → 采用；命中同一分组 → 细分问题；跨分组或零命中 → 大类问题再细分
3. 无效回复 → 列出全部 10 种 → 再无效 → 终止

大类问题：你想产出的属于哪一组？
- 路线 / 需求类：roadmap / prd
- 技术 / 架构类：tech / arch / decision / schema
- 能力 / 表达类：capabilities / ui / ops / marketing

Exemplars（判断对话命中 type 的锚点句）：
- roadmap："v1 交付 A/B/C；v2 扩展 D；Q2 发布"
- prd："用户可上传 pdf；上传成功率目标 95%"
- tech："采用 SQLite 存储；启用 WAL 模式；按 project_id 分表"
- arch："recall 模块由 scope 推断、query、rank 三段构成"
- decision："选用 JSONL 而非 SQLite，因其 diff 友好"
- schema："POST /api/v2/users 请求体含 name、email"
- capabilities："系统支持文件上传、OCR、全文检索"
- ui："点击按钮触发弹窗；表单分三段"
- ops："发布后收集反馈；两周一次迭代"
- marketing："通过博客、Twitter、官网 landing 多渠道推广"

### name

roadmap / capabilities / ops / marketing 不需要 name → null。

否则：
1. hint 或对话中含明确名词短语 → 归一化（小写，空格/点/斜杠转 `-`，去非 `[a-z0-9-]` 字符，trim）
2. 以上均无 → 问用户 → 无效 → 重试 1 次 → 终止

### mode

1. 目标文件不存在 → create
2. type = roadmap → update（永远单文件）
3. 目标文件存在 → 问用户：A) Update / B) 换名字（回 name 推断）/ C) 取消，等待回复

### parent

- prd → `$DOCS/roadmap.md`
- tech → `$DOCS/requirements/{name}/prd.md`
- 其他 → null

parent 缺失处理：
- prd 且 roadmap 不存在 → 继续，标注缺失
- tech 且 prd 不存在 → 问用户：A) 直接继续 / B) 先创建 PRD，等待回复
- prd 里程碑归属不明 → 询问里程碑编号

## Step 2 — 信息充分性检查

仅对高风险 type（prd / tech / arch / schema / decision / ui）运行。

1. 加载 `$TEMPLATES/sufficiency-gate.md` 的问题组
2. 每题以对话原文引用或明确 "not present" 作答
3. 全 yes → pass；混合或全 no → 问用户：A) 补充对话重跑 / B) 降级为建议 type（回 Step 1）/ C) 取消，等待回复

## Step 3 — 确认

```
[write] Inferred from conversation
  Type:   {type}
  Name:   {name or —}
  Path:   {resolved path}
  Mode:   {create | update}
  Parent: {parent or none}
Correct? (yes / change {field}={value})
```

等待用户确认。修改某字段则其下游全部重跑（type → name → mode → parent）。

## Step 4 — 加载 template

```bash
cat "$TEMPLATES/{type}.md"
```

template 不存在 → 合成 `# Title / ## Overview / ## Details / ## Open Questions`。

## Step 5 — 填充

**create 模式**：对每个 section 收集对话引文（按 summary 引用，禁止原文粘贴），遵守 `<!-- INCLUDE / EXCLUDE -->` 提示，产出结构化正文。证据不足写 `TBD — {缺失内容}`，数值标注来源（实测 / 估算 / 目标 / 无数据），不明确处以 `Open question:` 开头。交叉引用用项目根相对路径。

**update 模式**：
1. 完整读取现有文档
2. 列出对话讨论过的全部 section
3. 只重写列出的 section；其余 byte-identical
4. 补齐缺失的 template section（写内容或 TBD）
5. 只在被改动 section 内修复坏的相对路径
6. 无 section 被讨论 → 问用户：A) 新增 section / B) 取消，等待回复

**progress fields（create）**：
- roadmap 里程碑：进度（完成数/总数，按关联 PRD 统计）、需求列表（链接每个 PRD，空则 —）、编号（每版本从 M1 重置）
- prd §4 方案任务表：每个 tech 文档一行，progress = 完成数/总数
- tech §4 迭代记录：今日日期与 sprint 摘要置顶

**update 特殊规则（tech）**：
- §2 方案 → 随认知深化覆写
- §3 关键决策 → 仅追加
- §4 迭代记录 → 今日置顶，永不覆盖历史

**H1 标题**：
- 项目单文件 → `{项目名} {文档类型}`
- 项目目录 → `{主题名} {文档类型}`
- prd → `{用户入口}`
- tech → `{需求名} 技术方案`

## Step 6 — 写入

写前预览：

```
[write] Preview: {path}
{create: 完整内容 · update: 改动 section 的 diff}
Write? (yes / edit {section} / no)
```

TBD 超过 3 个 section 时，前置 `{n} sections marked TBD: {list}. Still write?`，等待二次确认。

等待用户确认后执行：
- 先创建目录：`mkdir -p "$(dirname "{path}")"`
- create → Write 工具
- update → 逐 section 用 Edit 工具；tech 的迭代记录条目置顶

```
[written] {path}
[written] {path} (updated {n} sections)
```

Write / Edit 工具失败 → 暴露错误，禁止静默重试。

## Step 7 — 校验

`$TEMPLATES/{type}-checklist.md` 不存在则跳过。

检查项：
- 必需 section 和字段齐全
- 字段满足语言约束
- 每个数字有来源标注（实测 / 估算+依据 / 目标值待验证 / 无数据+原因）
- 非可选字段含真实内容而非占位
- checklist 引用 `diagram-checklist.md` 时连带检查

违规 → 修复 → 重新预览，最多 3 轮。第 4 轮强制出文并标注 `[validate] forced through, {n} checks unresolved`。checklist 文件损坏 → 视为缺失，跳过并告警。

## Step 8 — 回写

parent 不存在或文件缺失 → 静默跳过。

否则用 Edit 工具只改 parent 的 progress 字段：
- tech 写完 → 更新 PRD `§4 方案` 任务表 progress 列
- prd 写完 → 更新 roadmap 里程碑表 `完成PRD数/总PRD数`

```
[progress] {parent_path} updated ({value})
```

parent 存在但无法编辑 → 记 `[progress] skip: {reason}` 后继续。
