# know self-test 技术方案

## 1. 背景

### 技术约束

- know-ctl.sh: 12 个命令共存单文件，测试函数必须内嵌不可拆分独立脚本
- shell 环境: 测试需隔离真实 .know/ 数据，不可污染用户工作区
- 断言输出: 无外部测试框架可用，assert 逻辑需 bash 原生实现

### 前置依赖

- know-ctl.sh 全部 12 个子命令实现 — 已完成

## 2. 方案

### 文件/模块结构

| 文件/模块 | 职责 |
|-----------|------|
| scripts/know-ctl.sh `cmd_self_test` | 测试入口，在临时目录中依次执行 11 个测试用例 |
| scripts/know-ctl.sh `assert` | 内嵌断言函数，判定通过/失败并计数 |

### 核心流程

1. `cmd_self_test` → `mktemp -d` 创建临时目录 + 设置 `CLAUDE_PROJECT_DIR` → 隔离测试环境
2. 测试函数 → 依次调用 init/append/query/search/hit/update/delete/decay/stats/metrics/history → 逐条 assert 验证输出与副作用
3. `cmd_self_test` → 汇总 PASS/FAIL 计数 + `rm -rf $TMPDIR` → 输出测试报告并清理

### 数据结构

| 字段 | 类型 | 用途 |
|------|------|------|
| PASS | int | 通过的断言计数 |
| FAIL | int | 失败的断言计数 |
| TMPDIR | string | 临时测试目录路径 |

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 测试位置 | 内嵌 know-ctl.sh | 独立测试脚本需维护路径引用和 source 逻辑，内嵌零依赖自包含 |
| 隔离方式 | mktemp + CLAUDE_PROJECT_DIR 覆盖 | chroot/docker 过重且不跨平台，临时目录 + 环境变量覆盖即可隔离 |
| 断言方式 | 内嵌 assert 函数 | bats/shunit2 等外部框架引入额外依赖，内嵌 assert 足够覆盖 happy path |

## 4. 迭代记录

### 2026-04-14

- tech 方案设计完成（覆盖 11 个测试用例：init/append/query/search/hit/update/delete/decay/stats/metrics/history）
