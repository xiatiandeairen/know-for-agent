# know check

## 1. 问题

模版改了但项目文档没跟上。write workflow 重构了多个模版的 section 结构，每次都要手动同步已有项目文档，遗漏了多次（tech 文档忘了删边界情况/测试用例 section）。没有工具检测模版和项目文档之间的结构偏差，只能靠人工对比。每次模版变更都面临同步遗漏风险。

## 2. 目标用户

使用 know write 的开发者，修改模版后需要确认 `docs/` 下的文档是否跟上。

场景举例：
- 改了 prd 模版加了"进度" section → 已有的 prd.md 没跟上
- 删了 tech 模版的"边界情况" → 已有的 tech 文档还留着这个 section
- 新增了 roadmap 的"需求"列 → 已有的 roadmap.md 里程碑表缺少这一列

当前替代方案：人工逐文件对比模版和项目文档的 section 结构——耗时、容易遗漏。

## 3. 核心假设

`/know check` 自动检测结构偏差 → 开发者改模版后 5 秒内知道哪些项目文档需要同步。

验证方式：改模版后运行 check，能检测出未同步的项目文档。

## 4. 方案

- **Before**: 改完模版手动对比每个项目文档 → **After**: `/know check` 自动扫描，输出偏差列表
- **Before**: 遗漏了同步直到下次使用才发现 → **After**: check 在改模版后立即发现偏差

### 检查维度

- section 数量：模版 `## N.` 数量 vs 项目文档 `## N.` 数量，不一致 → 偏差
- section 名称：模版 section 标题集合 vs 项目文档 section 标题集合，多出或缺少 → 偏差

不检查 section 内容（内容因项目而异，不属于一致性范畴）。

### 输出格式

```
=== know check ===

✗ docs/requirements/know-learn/tech.md
  模版 tech.md 有 5 sections，文档有 7 sections
  多出: ## 5. 边界情况, ## 6. 测试用例

✗ docs/roadmap.md
  模版 roadmap.md 里程碑表有 5 列，文档有 4 列
  缺少: 需求

✓ docs/requirements/know-learn/prd.md — 一致

=== 2 个偏差，1 个一致 ===
```

无偏差时：`✓ 所有文档与模版一致`

### 任务

| 任务 | 文档 | 进度 |
|------|------|------|
| check-impl | [tech](tech.md) | 0/1 |

## 5. 验收标准

- 运行 `/know check` → 扫描 `docs/` 下所有 write 生成的文档，与对应模版比较 section 结构
- 文档类型自动推断（从文件名和路径：prd.md → prd 模版，tech.md → tech 模版，roadmap.md → roadmap 模版）
- section 数量不一致 → 报告多出/缺少的 section 名
- 无偏差 → 输出 `✓ 所有文档与模版一致` + exit 0
- 有偏差 → 输出偏差列表 + exit 1

## 6. 排除项

- 不检查 section 内容（只检查结构）
- 不自动修复偏差（只报告）
- 不检查非 know 模版的文档
