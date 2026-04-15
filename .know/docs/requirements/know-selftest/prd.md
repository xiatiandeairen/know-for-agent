# know self-test

<!-- 核心问题: 需求到哪了、验收标准是什么？ -->

## 1. 问题

know-ctl.sh 是 know skill 的核心 CLI，承载 12 个命令（query/append/hit/delete/update/decay/stats/metrics/history/search/init/self-test）。修改后没有验证手段，bug 上线后才发现。本次会话中 PROJECT_DIR 路径解析错误导致 .knowledge/ 写到了项目上级目录，直到手动测试才发现。每次改动 know-ctl.sh 都面临回归风险。

## 2. 目标用户

开发和维护 know skill 的开发者，修改 know-ctl.sh 后需要快速验证核心功能是否正常。

| 场景 | 痛点 |
|------|------|
| 修改了路径解析逻辑 | 不知道是否影响了 append/query |
| 新增了 metrics 命令 | 不知道是否破坏了已有命令 |
| 重构了 decay 逻辑 | 不知道衰减规则是否还正确 |

当前替代方案：手动逐个命令测试 — 耗时、容易遗漏、不可重复。

## 3. 核心假设

**提供 `know-ctl self-test` 一键验证 → 开发者修改后 10 秒内知道是否有回归。**

验证方式：修改 know-ctl.sh 后运行 self-test，能捕获引入的 bug。

## 4. 方案

- **Before**: 改完 know-ctl.sh 手动测试，遗漏边界情况 → **After**: `know-ctl self-test` 自动验证核心命令的 happy path + 关键边界
- **Before**: 路径错误上线后才发现 → **After**: self-test 第一步验证路径解析，立刻发现

### 测试覆盖

| 命令 | 测试内容 |
|------|---------|
| init | 目录结构正确创建 |
| append | 条目写入 + metrics total_created 递增 + events created 事件 |
| query | scope 前缀匹配 + 过滤器 |
| hit | hits 递增 + last_hit 更新 + events hit 事件 |
| update | summary 更新 + revs 递增 + events updated 事件 |
| decay | tier 2 + hits=0 + >30d → 删除；tier 1 + hits=0 + >180d → 降级 |
| delete | 条目删除 + detail 文件清理 + events deleted 事件 |
| search | 正则匹配 summary |
| metrics | 6 个指标输出 + 建议生成 |
| history | 事件时间线查询 |
| stats | 统计输出 |

### 测试策略

- 使用临时目录（`mktemp -d`），不影响真实 .know/ 数据
- 每个测试独立：创建 → 验证 → 清理
- 输出格式：`✓ command` 或 `✗ command: error message`
- 全部通过 → exit 0；任一失败 → exit 1

### 任务

| 任务 | 文档 | 进度 |
|------|------|------|
| selftest-impl | [tech](tech.md) | 1/1 |

## 5. 验收标准

- 运行 `know-ctl self-test` → 在临时目录中执行全部测试
- 每个核心命令（11 个）有 1 个 happy path 测试
- append/hit/delete 有事件记录验证
- 路径解析有专项测试（PROJECT_DIR 指向正确目录）
- 全部通过 → 输出 `✓ All N tests passed` + exit 0
- 任一失败 → 输出 `✗ N/M tests failed` + 失败详情 + exit 1
- 测试完成后临时目录自动清理

## 6. 排除项

- 不测试 AI 行为（learn/write/review workflow 由 AI 执行，不在 self-test 范围）
- 不测试并发场景
- 不做性能测试
- 不集成 CI/CD
