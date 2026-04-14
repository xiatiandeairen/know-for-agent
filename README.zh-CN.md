<p align="center">
  <h1 align="center">know-for-agent</h1>
  <p align="center">
    AI Agent 的项目知识编译器 — 持久化隐性知识，编写结构化文档，追踪知识健康度。
  </p>
</p>

<p align="center">
  <a href="#安装">安装</a> •
  <a href="#快速开始">快速开始</a> •
  <a href="#工作原理">工作原理</a> •
  <a href="#架构">架构</a> •
  <a href="#参与贡献">参与贡献</a>
</p>

<p align="center">
  <a href="https://github.com/xiatiandeairen/know-for-agent/actions/workflows/ci.yml"><img src="https://github.com/xiatiandeairen/know-for-agent/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/xiatiandeairen/know-for-agent/releases"><img src="https://img.shields.io/github/v/release/xiatiandeairen/know-for-agent?include_prereleases" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
</p>

<p align="center">
  <a href="README.md">English</a> | <b>中文</b>
</p>

---

## 这是什么？

**know-for-agent** 是一个 [Claude Code 插件](https://docs.anthropic.com/en/docs/claude-code)，为 AI Agent 提供持久化的项目记忆。它解决三个问题：

1. **重复犯错** — AI Agent 跨会话反复犯同样的错。Know 记录隐性知识，通过 recall 机制在错误发生前阻止。
2. **设计成果丢失** — 讨论结果留在对话里，会话结束就消失。Know 将其写成结构化的版本化文档。
3. **知识质量盲区** — 无法知道存储的知识是否有用。Know 提供指标、生命周期追踪和优化建议。

## 安装

**一键安装**（需要 [jq](https://jqlang.github.io/jq/download/) 和 git）：

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/install.sh | bash
```

安装后重启 Claude Code。完成 — `/know learn` 在任何项目中都可用了。

**卸载：**

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/uninstall.sh | bash
```

> 卸载后项目中的 `.know/` 数据会保留。如需清理请手动删除。

## 快速开始

```bash
# 从当前对话中提取知识
/know learn

# 将讨论结果写成结构化文档
/know write

# 审计和维护知识条目
/know review

# 查看质量指标 + 优化建议
know-ctl metrics

# 检查模板-文档一致性
know-ctl check

# 运行自动化自测
know-ctl self-test
```

## 工作原理

### 三条流水线

| 流水线 | 方向 | 用途 |
|--------|------|------|
| **Learn** | 对话 → .know/ | 记录隐性知识，减少未来犯错 |
| **Write** | 对话 → .know/docs/ | 将讨论结果转为结构化文档 |
| **Review** | .know/ → 用户 | 审计条目，含生命周期阶段和指标 |

### Recall — 自动错误预防

在操作代码前，Agent 自动查询匹配的知识条目。`active:defensive` 条目阻止违反已知约束的操作。`active:directive` 条目建议最佳实践。

### 存储结构

```
.know/
├── index.jsonl              # 知识条目 — 通过 jq 过滤
├── entries/                 # 详情文件（仅 critical 级别）
│   ├── rationale/           #   为什么选这个，不选那个
│   ├── constraint/          #   什么不能做
│   ├── pitfall/             #   已知陷阱及根因
│   ├── concept/             #   核心逻辑、算法、流程
│   └── reference/           #   外部工具指南
├── metrics.json             # 聚合指标数据
├── events.jsonl             # 生命周期事件日志
└── docs/                    # 结构化文档
    ├── v{n}/                #   项目级版本化
    └── requirements/        #   需求/功能级
```

### 两级体系

| 级别 | 名称 | 详情文件 | 衰减 |
|------|------|----------|------|
| 1 | critical | ≤ 220 tokens | 180 天无命中 → 降级 |
| 2 | memo | 仅摘要 | 30 天无命中 → 删除 |

### 文档模板（9 种）

| 类型 | 用途 |
|------|------|
| roadmap | 产品愿景 + 里程碑进度追踪 |
| prd | 需求进度追踪 + 验收标准 |
| tech | 技术方案 + 迭代记录（多次 sprint） |
| arch | 系统分解 + 组件协作 |
| ui | 用户交互设计 |
| schema | API/数据契约 |
| decision | 决策理由 + 备选方案 |
| ops | 运维 + 发布策略 |
| marketing | 上市推广方案 |

## 架构

```
/know (SKILL.md — 始终加载，约 250 行)
├── learn (workflows/learn.md — 按需加载)
│   ├── 信号检测（6 类，规则驱动）
│   ├── 路由拦截（5 条快速过滤规则）
│   ├── 二问评估定级
│   ├── 冲突检测（两阶段）
│   └── 写入（索引 + 条目 + 事件）
├── write (workflows/write.md — 按需加载)
│   ├── 推断参数（类型、名称、版本、父文档）
│   ├── 加载模板（9 种）
│   ├── 填充内容 + 进度字段
│   ├── 写入文件 + 更新 CLAUDE.md 索引
│   └── 级联标记 + 进度传播
└── review (workflows/review.md — 按需加载)
    ├── 生命周期阶段排序（⚠ > 💤 > 🆕 > ✅）
    ├── 指标摘要（衰减率 + 覆盖度）
    └── 逐条操作（删除 / 更新 / 保留）

scripts/know-ctl.sh（14 个命令）
├── 核心：    init, query, search, append, hit, update, delete
├── 策略：    decay
├── 指标：    stats, metrics, history
└── 质量：    self-test, check
```

## 参与贡献

欢迎贡献！请先开 Issue 讨论你想做的改动。

## 许可证

[MIT](LICENSE)
