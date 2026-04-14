# know self-test 技术方案

<!-- 核心问题: 怎么实现、做到哪了？ -->

## 1. 背景

know-ctl.sh 有 12 个命令，修改后无自动验证。需要 `cmd_self_test` 在临时目录中跑完所有核心命令的 happy path + 关键边界。

## 2. 方案

### 测试隔离

- `TMPDIR=$(mktemp -d)` 作为临时 PROJECT_DIR
- `CLAUDE_PROJECT_DIR=$TMPDIR` 覆盖路径解析
- 测试结束后 `rm -rf $TMPDIR`

### 测试框架（内嵌 bash）

```bash
PASS=0 FAIL=0
assert() {
    local name="$1" condition="$2"
    if eval "$condition"; then
        echo "✓ $name"; PASS=$((PASS+1))
    else
        echo "✗ $name"; FAIL=$((FAIL+1))
    fi
}
```

### 测试用例

| # | 测试 | 验证 |
|---|------|------|
| 1 | init | .know/ 目录 + index.jsonl 存在 |
| 2 | append | index.jsonl 行数 +1，metrics.json total_created +1，events.jsonl 有 created 事件 |
| 3 | query | scope 前缀匹配返回条目 |
| 4 | search | 正则匹配返回条目 |
| 5 | hit | hits +1，last_hit 更新，events.jsonl 有 hit 事件 |
| 6 | update | summary 变更，revs +1，events.jsonl 有 updated 事件 |
| 7 | delete | 条目消失，detail 文件清理，events.jsonl 有 deleted 事件 |
| 8 | decay | 构造过期 memo → 被删除，events.jsonl 有 deleted 事件 |
| 9 | stats | 输出包含 "Total:" |
| 10 | metrics | 输出包含 "命中率" + "防御次数" + "过期文档" |
| 11 | history | 返回之前操作产生的事件 |

### 文件变更

| 操作 | 文件 |
|------|------|
| modify | scripts/know-ctl.sh — 新增 cmd_self_test + dispatch |

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 测试位置 | 内嵌 know-ctl.sh | 不新增文件，一个脚本自包含 |
| 隔离方式 | mktemp + CLAUDE_PROJECT_DIR | 不碰真实数据 |
| 断言方式 | 内嵌 assert 函数 | 不依赖外部测试框架 |

## 4. 迭代记录

### 2026-04-14

tech 方案设计完成。
