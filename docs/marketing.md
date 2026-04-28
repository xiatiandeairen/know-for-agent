# Know 营销方案

## 1. 目标受众

Claude Code 重度用户，日常用 Claude Code 做开发，积累了大量项目经验但苦于每次新会话都要重复解释上下文。其中一部分是 skill/plugin 开发者，关注 Claude Code 生态工具链。

活跃平台：
- GitHub（Claude Code 相关 repo、Anthropic 社区）
- Twitter/X（AI 工具链讨论、Claude Code 使用技巧分享）
- Claude Code 官方 plugin marketplace（如开放）

决策因素：
- 安装是否简单（一条命令搞定，不需要额外依赖）
- 是否真的减少重复解释（对比手动维护 CLAUDE.md 的体验提升）
- 是否影响 Claude Code 正常使用（无侵入性，不改变现有工作流）

## 2. 核心信息

一句话卖点：给 CLAUDE.md 写入纪律——让 AI 记住真正值得记住的东西。

差异化：
- 比手动维护 CLAUDE.md 更省事：learn 从对话提取经验，5 道 gate 拒绝低熵规则，写入结构化 YAML entry
- 有纪律而不堆砌：entropy gate 强制每条知识有触发场景、理由、失效条件，不是越来越长的纯文本
- write 生成结构化文档：10 种类型（prd / tech / arch / decision 等）+ 模板 + sufficiency gate，文档与代码同版本 git 跟踪

## 3. 推广渠道

- GitHub README（P0）：清晰的安装说明 + learn/write 演示 + 真实使用数据
- Twitter/X（P0）：发布系列推文：问题场景 → 解决方案 → 安装体验，附带真实截图
- Claude Code plugin marketplace（P1）：上架并维护 listing（待 marketplace 开放）
- Anthropic 社区 / Discord（P1）：在相关讨论中自然提及，分享使用经验而非硬推
- 技术博客（P2）：写一篇"Claude Code 知识管理实践"长文，know 作为工具案例

## 4. 传播节奏

1. **GitHub README 优化** — 已交付（measured）：核心能力 + 安装说明 + 差异化定位
2. **Twitter/X 首发** — 主帖 + 3 条 self-reply（线程详情见 [docs/marketing-twitter.md](marketing-twitter.md)）
3. **Anthropic 社区 / GitHub Discussion 体验分享** — 首发后 21 天内择机
4. **早期用户反馈迭代** — 收集 ≥3 条具体反馈后发更新，同步推 Twitter
5. **"Claude Code 知识管理实践"长文** — Twitter 节奏跑完后再写

P0 Twitter 实操执行册见 [marketing-twitter.md](marketing-twitter.md)。

## 5. 效果衡量

| 指标 | target | 复盘节点 | 当前 |
| ---- | ---- | ---- | ---- |
| GitHub stars | 50 | 21 天后 | no-data |
| 安装数（clone）| 30 | 21 天后 | no-data |
| GitHub Issues 活跃 | ≥10（bug + feature request）| 21 天后 | no-data |
| Twitter 主帖曝光 | 5000 impressions | 主帖发出 21 天 | no-data |
| 活跃用户（持续 >2 周）| 10 | 60 天后 | no-data |

数据全部为 target，待 dogfood + 推广启动后实测填回。
