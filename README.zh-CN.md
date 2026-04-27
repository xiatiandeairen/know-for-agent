<h1 align="center">know</h1>

<p align="center">
  <strong>给 CLAUDE.md 加上写入纪律，阻止低熵规则堆积。</strong>
</p>

<p align="center">
  一个 <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a> 插件，两个命令：<code>learn</code> 经 5 道 gate 过滤后把知识结构化写入 CLAUDE.md，<code>write</code> 把对话讨论转成版本化文档。
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

`CLAUDE.md` 是存放项目知识的正确位置——但没有写入纪律，它会退化成一堆不改变 AI 行为的低熵规则。同时，设计讨论的结论在会话结束后就消失了。

| 没有 know | 有 know |
|:---|:---|
| AI 反复违反它"知道"的约束 | 每条 entry 在写入前经过 5 道熵过滤 |
| CLAUDE.md 被显而易见的规则塞满 | gate 拒绝模型已知的规则，噪声进不来 |
| 讨论出的设计结果随会话消失 | `/know write` 一条命令生成结构化文档 |
| 文档格式不统一、内容浅薄 | 模板 + 检查清单 + 充分性检查保证质量 |

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/install.sh | bash
```

需要 `git`。安装后重启 Claude Code。

<details>
<summary>卸载</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/uninstall.sh | bash
```
</details>

## 使用

```bash
/know learn     # 从当前对话中 gate 过滤并持久化知识
/know write     # 将讨论结果生成结构化的版本化文档
```

### learn 工作原理

`learn` 对每条知识候选跑 5 stage pipeline：

1. **detect** — 扫描最近 ≤20 轮对话，分类为 `[纠正]`（用户纠正 AI，快速进入候选）或 `[捕捉]`（AI 自主捕捉，需完整 gate 验证）
2. **gate** — 5 道从粗到细的过滤：信息熵 → 复用 → 可触发 → 可执行 → 失效检查。每道 gate 先给出调整方向再拒绝；目标拒绝率 ≥20%
3. **refine** — 可选加工：泛化触发场景、补充理由根因、拆分多逻辑条目
4. **locate** — 通过 `know-paths.sh` 决定写入哪个 CLAUDE.md（project / module / user 三级）
5. **write** — 产出 YAML entry，查重，用户确认，追加写入

写入目标文件的 `## know` YAML block：

```yaml
- when: 改 webhook handler 时
  must: 必须先验签再解 body — 防伪造
  how: HMAC-SHA256(env.WEBHOOK_SECRET, raw_body) 比对 X-Sig；见 src/webhook/verify.ts
  until: webhook 提供商改用 mTLS
```

知识由 Claude Code 嵌套 CLAUDE.md 加载机制自动激活，无运行时检索层。

### write 工作原理

`write` 从对话推断文档类型和路径，高风险类型强制充分性检查，按模板填充内容，预览后写入：

```bash
/know write               # 从上下文推断类型
/know write arch          # 指定类型
/know write decision payment-method   # 指定类型 + 名称
```

## 文档类型

10 种类型，每种都有模板 + 检查清单 + 更新规则：

| 类型 | 路径 | 描述 |
|------|------|------|
| roadmap | `docs/roadmap.md` | 产品愿景、版本规划、里程碑 |
| capabilities | `docs/capabilities.md` | 跨版本能力清单 |
| ops | `docs/ops.md` | 发布策略、反馈 SLA |
| marketing | `docs/marketing.md` | 目标受众、核心信息、推广渠道 |
| prd | `docs/requirements/{name}/prd.md` | 问题、用户、假设、验收标准 |
| tech | `docs/requirements/{name}/tech.md` | 约束、架构、决策、迭代记录 |
| arch | `docs/arch/{name}.md` | 模块结构、数据流、设计决策 |
| schema | `docs/schema/{name}.md` | 接口契约、数据模型、错误码 |
| decision | `docs/decision/{name}.md` | 方案对比、影响分析 |
| ui | `docs/ui/{name}.md` | 布局、交互流、组件状态 |

**充分性检查**：高风险类型（prd / tech / arch / schema / decision / ui）——对话内容不足以填满模板时，阻止写入并建议改写父文档。

**数据置信**：所有数值必须标注来源（实测 / 估算 / 目标 / 无数据），禁止编造精确数字。

## 差异化

| | CLAUDE.md（手工）| Auto-memory | **know** |
|---|:---:|:---:|:---:|
| 写入纪律 | 无 | 无 | **5 道熵 gate 过滤** |
| 结构 | 纯文本 | 键值对 | **4 字段 YAML（when/rule/how/until）** |
| 激活方式 | 始终加载 | 始终加载 | **Claude Code 嵌套加载** |
| 文档 | 无 | 无 | **10 种类型 + 质量框架** |

## 参与贡献

欢迎贡献！请先 [开 Issue](https://github.com/xiatiandeairen/know-for-agent/issues) 讨论你想做的改动。

## 许可证

[MIT](LICENSE)
