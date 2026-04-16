# Know 运营方案

## 1. 发布策略

### 发布渠道

- GitHub Releases: 主发布渠道，用户通过 `curl -fsSL .../install.sh | bash` 安装，脚本 clone 仓库到 `~/.claude/plugins/know`
- GitHub Repository (xiatiandeairen/know-for-agent): 源码托管，用户可直接 clone 或 fork

### 发布节奏

功能驱动，里程碑完成即发布。个人项目，预期 2-4 周一次。无固定发布窗口，就绪即发。

### 版本规则

SemVer: MAJOR 破坏性变更（entry 格式、SKILL.md 接口、know-ctl 命令签名），MINOR 新功能（新 pipeline、新模板），PATCH bug 修复和文档更新。当前版本 1.0.0。

## 2. 反馈闭环

| 渠道 | 分类 | 响应 SLA |
|------|------|---------|
| GitHub Issues | bug report、plugin 加载失败、数据异常 | 72h 内首次响应（个人维护者，非全职） |
| GitHub Issues | feature request、模板需求、pipeline 建议 | 7 天内首次响应，标注优先级 |
| GitHub Discussions（如开启） | 使用问题、最佳实践交流 | 尽力回复，无硬性 SLA |

## 3. 关键指标

| 指标 | 当前值 | 目标 | 报警阈值 |
|------|--------|------|---------|
| 知识条目总量 | 70 条（实测，metrics.json） | 持续增长，目标值待验证 | 连续 7 天零新增 |
| Recall 命中次数 | 2 次（实测，index.jsonl hits 字段累计） | 目标值待验证，需更多使用数据 | 连续 14 天零命中 |
| 防御性条目占比 | 约 40%（实测，tm 含 defensive 的条目约 28/70） | ≥30%（目标值，待验证） | <20% 时复查 learn pipeline 质量 |
| Plugin 加载成功率 | 无数据（缺少遥测） | >95%（目标值，待验证） | 连续 2 个 issue 报告加载失败 |
| know-ctl 脚本执行成功率 | 无数据（缺少遥测） | >99%（目标值，待验证） | 单次版本发布后出现 >3 个脚本报错 issue |

## 4. 异常预案

| 场景 | 应对措施 | 升级路径 |
|------|---------|---------|
| Plugin 加载失败（Claude Code 启动时 SKILL.md 解析出错） | 1. 用户重新运行 install.sh 覆盖安装 2. 检查 SKILL.md 语法（YAML frontmatter + Markdown） 3. 在 GitHub Issues 提供错误日志 | 用户自助恢复失败 → 在 GitHub Issue 中 @xiatiandeairen，48h 内响应 |
| know-ctl 脚本报错（bash 兼容性、路径问题） | 1. 确认 bash 版本 ≥4.0 2. 确认 .know/ 目录结构完整（index.jsonl、metrics.json、events.jsonl 存在） 3. 手动运行 `bash scripts/know-ctl.sh` 定位报错行 | 脚本问题 → GitHub Issue 附带 OS 版本和错误输出，维护者 72h 内修复 |
| 数据损坏（index.jsonl 或 entries/ 文件格式异常） | 1. 运行 `/know review` 审计条目完整性 2. 从 git history 恢复损坏文件 3. 必要时删除损坏条目，know 会在后续 learn 中重建 | 数据无法恢复 → GitHub Issue 附带损坏文件内容，维护者评估是否需要迁移脚本 |
| 版本升级后不兼容（entry 格式变更、命令签名变更） | 1. 查看 GitHub Release notes 中的 breaking changes 说明 2. 运行 install.sh 重新安装 3. 按迁移指南手动调整数据格式 | 迁移指南不足 → GitHub Issue 反馈，维护者补充迁移文档 |
