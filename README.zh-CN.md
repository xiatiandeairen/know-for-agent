<h1 align="center">know</h1>

<p align="center">
  <strong>你的 AI Agent 总是犯同样的错。这个工具解决它。</strong>
</p>

<p align="center">
  一个 <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a> 插件，为 AI Agent 提供持久化的结构化项目记忆 — 让一次会话中学到的教训永远不会被遗忘。
</p>

<p align="center">
  <a href="https://github.com/xiatiandeairen/know-for-agent/actions/workflows/ci.yml"><img src="https://github.com/xiatiandeairen/know-for-agent/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/xiatiandeairen/know-for-agent/releases"><img src="https://img.shields.io/github/v/release/xiatiandeairen/know-for-agent?include_prereleases&label=version" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
</p>

<p align="center">
  <a href="README.md">English</a> | <b>中文</b>
</p>

---

## 问题

AI 编程助手在会话之间会遗忘一切。它们重复同样的错误、丢失设计决策、无视已经学到的教训 — 即使有 `CLAUDE.md` 和 auto-memory。

| 没有 know | 有 know |
|:---|:---|
| AI 第 3 次犯同样的架构错误 | `[recall]` 在错误发生前自动触发 |
| "当时为什么选了 X 不选 Y？" — 没人记得 | rationale 条目按模块自动检索 |
| 讨论出的设计结果随会话消失 | 结构化文档持久化在 `.know/docs/` |

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/install.sh | bash
```

需要 `jq` 和 `git`。安装后重启 Claude Code。

<details>
<summary>卸载</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/uninstall.sh | bash
```

项目中的 `.know/` 数据会保留，如需清理请手动删除。
</details>

## 使用

三个命令，就这些。

```bash
/know learn     # 从当前对话中提取并持久化知识
/know write     # 将讨论结果写成结构化的版本化文档
/know review    # 审计已存储的知识 — 删除过期的，更新过时的
```

### Recall 如何工作

Know 不只是存储知识 — 它会**主动使用**。在 Agent 修改代码前，自动按模块作用域查询相关条目：

- **`active:defensive`** — 阻止违反已知约束的操作
- **`active:directive`** — 在 Agent 猜测前建议已验证的方案
- **`passive`** — 仅在 Agent 即将重复已知错误时浮出上下文

## 存储什么

Know 捕获的是代码和 git 历史**无法表达**的知识：

| 标签 | 捕获内容 | 示例 |
|------|---------|------|
| `rationale` | 为什么选 X 不选 Y | "选 JSONL 不选 SQLite — 恢复更简单，无二进制依赖" |
| `constraint` | 什么不能做 | "禁止在 PressureLevel 枚举外硬编码阈值" |
| `pitfall` | 已知陷阱 + 根因 | "DataEngine 单例在测试间泄漏状态" |
| `concept` | 核心逻辑、算法 | "压力评分使用三级加权平均" |
| `reference` | 外部集成 | "HealthKit 需要后台模式 entitlement" |

每个条目都有作用域（按模块）、级别（critical/memo）、并在不再有用时自动衰减。

## 差异化

| | CLAUDE.md | Auto-memory | **know** |
|---|:---:|:---:|:---:|
| 范围 | 全局规则 | 个人偏好 | **项目知识** |
| 结构 | 纯文本 | 键值对 | **标签化、作用域化、分级** |
| 检索 | 始终加载 | 始终加载 | **按作用域按需检索** |
| 生命周期 | 手动维护 | 手动维护 | **自动衰减 + 指标** |
| 限制 | ~200 行 | ~200 行 | **无硬性限制** |

## 存储结构

```
.know/
├── index.jsonl          # 所有条目 — 用 jq 过滤
├── entries/             # 详情文件（仅 critical 级别）
│   ├── rationale/
│   ├── constraint/
│   ├── pitfall/
│   ├── concept/
│   └── reference/
├── metrics.json         # 质量指标
├── events.jsonl         # 生命周期事件
└── docs/                # 结构化文档（9 种模板）
    ├── v{n}/            #   roadmap, decision, arch, ops, marketing
    └── requirements/    #   prd, tech, ui, schema
```

## 参与贡献

欢迎贡献！请先 [开 Issue](https://github.com/xiatiandeairen/know-for-agent/issues) 讨论你想做的改动。

## 许可证

[MIT](LICENSE)
