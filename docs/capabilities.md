# know 能力全景

## 1. 能力清单

| 能力 | 描述 | 状态 | 版本 | 需求 |
|---|---|---|---|---|
| **Learn** | 对话中检测并持久化隐性知识；含 level 引导（project/user）+ user 写入二次确认 | 可用 | v1（v6 扩展） | [prd](requirements/know-learn/prd.md) |
| **Write** | 按模板生成结构化文档（11 类），文档位于项目根 `docs/`，与代码同版本 | 可用 | v1（v6 路径迁移） | [prd](requirements/know-write/prd.md) |
| **Extract** | 从代码挖掘知识 | 可用 | v1 | — |
| **Review** | 审计知识条目质量；`--level` 过滤；输出带 level 列 | 可用 | v1（v6 扩展） | — |
| **Recall** | 编辑代码前自动提醒相关知识；两 level 合并扫描，结果带 `[project]`/`[user]` 标注 | 可用 | v1（v6 扩展） | — |
| **Decay** | 自动衰减过时知识（v7 暂停：策略重做） | 暂停 | v1-v6（v7.x 重做） | — |
| **Report** | `/know report` 生成 6 段知识库健康诊断（概览 / 价值 / 召回 / 文档 / 趋势 / 行动）；消费 metrics + stats + events.jsonl | 可用 | v2 | — |
| **Dual-level Storage** | `project`（项目 git）+ `user`（XDG_CONFIG）+ runtime（XDG_DATA 单 events）三层布局；8 字段 schema | 可用 | v6（v7 简化到 3 文件） | [decision](decision/v7-simplify-schema.md) |

## 2. 开发者工具

非产品能力，为维护而存在，通过 `bash scripts/know-ctl.sh <cmd>` 调用：

- `metrics` — 命中率 / 衰减率 / 防御次数 / 覆盖率 / 文档覆盖等 6 项指标 + 建议
- `stats` — 按 tier/tag/scope 计数
- `history <keyword>` — 生命周期事件回溯（events.jsonl）
- `self-test` — 29 项断言在 `XDG_DATA_HOME=$TMPDIR` 隔离环境回归
- `check` — docs/ 与 templates/ 结构一致性检测

## 3. 覆盖范围

### 已知限制

- 知识检索依赖 scope 推断；推断错误时会漏召回
- 文档模板固定 11 种，不支持自定义
- 旧 `.know/` 不自动迁移（`know-ctl init` 检测后打印手工命令）
- 跨 level metrics 聚合视图未实现（当前分别看 project / user）

### 未覆盖场景

- 自动修复文档不一致（只检测）
- 跨用户 / 团队共享 user level 知识（云同步）
- CI/CD 集成
- scope 冲突解决（同名 scope 在两 level 并存时无合并策略）
