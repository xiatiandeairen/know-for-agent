# know 能力全景

## 1. 能力清单

| 能力 | 描述 | 状态 | 版本 | 需求 |
|---|---|---|---|---|
| **Learn** | 对话中检测并持久化隐性知识；新增 level 引导（project/user）+ user 写入二次确认 | 可用 | v1 (v6 扩展) | [prd](requirements/know-learn/prd.md) |
| **Write** | 按模板生成结构化文档，文档位于项目根 `docs/`，与代码同版本 | 可用 | v1 (v6 路径迁移) | [prd](requirements/know-write/prd.md) |
| **Recall** | 编辑代码前自动提醒相关知识；两 level 合并扫描，结果带 `[project]`/`[user]` 标注 | 可用 | v1 (v6 扩展) | — |
| **Decay** | 自动衰减过时知识，两 level 独立运行 | 可用 | v1 (v6 扩展) | — |
| **Metrics** | 核心指标可查，数据驱动优化（当前 project 范围，跨 level 聚合延后） | 可用 | v2 | [prd](requirements/know-metrics/prd.md) |
| **Lifecycle** | 知识从存入到衰减的完整轨迹可追踪；支持两 level 事件查询 | 可用 | v2 (v6 扩展) | [prd](requirements/know-lifecycle/prd.md) |
| **Optimize** | 基于数据调整规则，指标改善 | 可用 | v2 | [prd](requirements/know-optimize/prd.md) |
| **Self-test** | know-ctl 29 项断言一键验证，覆盖两 level 隔离 | 可用 | v3 (v6 扩展) | [prd](requirements/know-selftest/prd.md) |
| **Check** | 检测模版与项目文档的结构偏差；文档源改为 `$PROJECT_DIR/docs/` | 可用 | v3 (v6 路径迁移) | [prd](requirements/know-check/prd.md) |
| **Flow Rules** | write 关键判定点有明确规则 | 可用 | v3 | [prd](requirements/know-flowrules/prd.md) |
| **Extract** | 从代码挖掘知识 | 可用 | v1 | — |
| **Review** | 审计知识条目质量；`--level` 过滤指定作用域；输出表带 level 列 | 可用 | v1 (v6 扩展) | — |
| **Dual-level Storage** | `project` / `user` 双作用域；知识库位于 `$XDG_DATA_HOME/know/`，`docs/` 位于项目根 | 可用 | v6 | [decision](decision/xdg-dual-level.md) |

## 2. 覆盖范围

### 已知限制

- 知识检索依赖 scope 推断；scope 推断错误时会漏召回
- 文档模板固定 11 种，不支持自定义模板
- 旧 `.know/` 数据不自动迁移（需用户手工 `mv`；`know-ctl init` 打印迁移命令）
- 跨 level metrics 聚合视图未实现（当前只能分别看 project / user）

### 未覆盖场景

- 自动修复文档不一致（只检测）
- 跨 user / 团队共享 user level 知识（云同步）
- CI/CD 集成
- scope 冲突解决（同名 scope 在两 level 出现时无合并策略）
