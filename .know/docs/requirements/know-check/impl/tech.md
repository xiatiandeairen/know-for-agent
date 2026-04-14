# know check 技术方案

<!-- 核心问题: 怎么实现、做到哪了？ -->

## 1. 背景

PRD 定义 3 个检查维度：section 数量、section 名称、CLAUDE.md 索引完整性。只检查结构不检查内容。

## 2. 方案

### 文档类型推断

从文件路径自动推断对应模版：

| 路径模式 | 模版 |
|---------|------|
| `*/prd.md` | `workflows/templates/prd.md` |
| `*/tech.md` (在 impl/ 下) | `workflows/templates/tech.md` |
| `*/roadmap.md` | `workflows/templates/roadmap.md` |
| 其他类型同理 | 文件名去 .md 匹配模版 |

### 检查逻辑

```bash
cmd_check() {
    # 1. 扫描 .know/docs/ 下所有 .md 文件
    # 2. 每个文件推断对应模版
    # 3. 比较 section 结构
    # 4. 检查 CLAUDE.md 索引覆盖
}
```

Section 提取：`grep -E '^## [0-9]+\.' file | sed 's/^## [0-9]+\. //'` 得到标题列表。

比较：模版标题集合 vs 文档标题集合，输出差异（多出/缺少）。

### 文件变更

| 操作 | 文件 |
|------|------|
| modify | scripts/know-ctl.sh — 新增 cmd_check + dispatch |

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| section 匹配 | 只比标题，忽略编号 | 编号可能因插入新 section 而偏移 |
| 索引检查 | 用 grep 搜 CLAUDE.md 中的文件路径 | 简单可靠 |

## 4. 迭代记录

### 2026-04-14

tech 方案设计完成。
