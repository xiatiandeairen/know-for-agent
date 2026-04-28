<h1 align="center">know</h1>

<p align="center">
  <strong>给 CLAUDE.md 写入纪律——阻止低熵规则堆积。</strong>
</p>

<p align="center">
  一个 <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a> 插件。两个命令：<code>/know learn</code> 经 gate 过滤后写入 CLAUDE.md；<code>/know write</code> 把对话讨论转成版本化文档。
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

## 为什么

|                       | CLAUDE.md（手工）| Auto-memory | **know**                                |
| --------------------- | :--------------: | :---------: | :-------------------------------------: |
| 写入纪律              | 无               | 无          | **5 道 entropy gate 过滤**              |
| 结构                  | 纯文本           | 键值对      | **4 字段 YAML（when/rule/how/until）**  |
| 激活方式              | 始终加载         | 始终加载    | **Claude Code 嵌套加载**                |
| 文档模板              | —                | —           | **10 种类型 + 充分性 gate**             |

## 你能得到什么

每条 entry 的每个字段都承载信息：

```yaml
- when: 改 webhook handler 时
  must: 必须先验签再解 body — 防伪造
  how: HMAC-SHA256(env.WEBHOOK_SECRET, raw_body) 比对 X-Sig；见 src/webhook/verify.ts
  until: webhook 提供商改用 mTLS
```

每条 candidate 走 5 道 gate，从粗到细——**信息熵 → 复用 → 可触发 → 可执行 → 失效**。目标拒绝率 ≥20%。大部分"规则"是噪声，过不了。

更长的产出由 `/know write` 按模板填充——**10 种类型**：roadmap、capabilities、prd、tech、arch、schema、decision、ui、ops、marketing。高风险类型先过充分性 gate；所有数值必须标来源（`实测` / `估算` / `目标` / `无数据`）。

## 使用

```bash
/know learn                            # 对当前对话过 gate，幸存条目追加到 CLAUDE.md
/know write                            # 从对话推断文档类型
/know write arch                       # 指定类型
/know write decision payment-method    # 指定类型 + 名称
```

激活由 Claude Code 嵌套 CLAUDE.md 加载机制承担——无运行时检索层。

## 安装

把这段粘给 Claude Code：

> 帮我安装 `know` Claude Code 插件，仓库地址 `https://github.com/xiatiandeairen/know-for-agent`：
> 1. 把仓库 clone 到 `~/.claude/plugins/know`
> 2. 在 `~/.claude/settings.json` 中加 `extraKnownMarketplaces.know = { source: { source: "directory", path: "~/.claude/plugins/know" } }`，并设置 `enabledPlugins["know@know"] = true`
> 3. 重启 Claude Code

需要 `git`。

<details>
<summary>卸载</summary>

把这段粘给 Claude Code：

> 帮我卸载 `know` Claude Code 插件：删除 `~/.claude/plugins/know`，从 `~/.claude/settings.json` 删除 `extraKnownMarketplaces.know` 和 `enabledPlugins["know@know"]`，重启 Claude Code。

</details>

## 许可证

[MIT](LICENSE)——欢迎通过 [issues](https://github.com/xiatiandeairen/know-for-agent/issues) 贡献。
