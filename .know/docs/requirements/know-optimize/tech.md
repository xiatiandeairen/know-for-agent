# know optimize 技术方案

<!-- 核心问题: 怎么实现、做到哪了？ -->

## 1. 背景

M3 要闭合"数据 → 发现问题 → 调整 → 验证改善"环。M1 metrics 有数据，M2 lifecycle 有历史，但缺少"看完该做什么"的引导。

技术约束：
- 建议逻辑嵌入 cmd_metrics 末尾，不新增命令
- review 排序改为生命阶段优先，改 review.md 指令
- 不新增数据收集点

## 2. 方案

### metrics 建议（cmd_metrics 末尾追加）

在 6 个指标输出后，逐条检查阈值，生成建议列表：

```bash
# 建议生成逻辑
suggestions=()
if hit_pct < 50 && total > 0:
    nohit=$((total - hit_count))
    new_pct=$((hit_count * 100 / hit_count))  # 假设清理所有 hits=0
    suggestions+=("命中率 ${hit_pct}%: ${nohit} 条知识从未命中，运行 /know review 清理 → 预计命中率 100%")
if decay_pct > 30:
    suggestions+=("衰减率 ${decay_pct}%: 存入质量需关注，检查 learn filter 规则")
if defensive_hits == 0 && total > 0:
    suggestions+=("防御次数 0: 无 active:defensive 命中，检查 constraint 类知识或 scope 推断")
if scope_pct < 50 && total_scopes > 0:
    suggestions+=("覆盖率 ${scope_pct}%: 多数 scope 未被查询，检查 recall scope 推断规则")
if stale_count > 0:
    suggestions+=("过期文档 ${stale_count} 个: 运行 /know write 更新标记的文档")
if doc_pct < 100 && milestone_count > 0:
    suggestions+=("文档覆盖 ${doc_pct}%: ${uncovered} 个里程碑缺 PRD")

# 输出
if len(suggestions) == 0:
    echo "✅ 所有指标健康，无需操作"
else:
    echo "--- 建议 ---"
    for s in suggestions: echo "• $s"
```

### review 智能排序（review.md Step 2）

替换原排序规则为生命阶段优先：

1. ⚠ 濒危 — 符合 decay 条件
2. 💤 沉默 — hits=0 + created > 7d，或 last_hit > 30d
3. 🆕 新建 — created < 7d + hits=0
4. ✅ 活跃 — last_hit < 30d

同阶段内按 age 降序。

### 文件变更

| 操作 | 文件 | 说明 |
|------|------|------|
| modify | scripts/know-ctl.sh | cmd_metrics 末尾追加建议生成 |
| modify | workflows/review.md | Step 2 排序规则改为生命阶段优先 |

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 建议位置 | metrics 输出末尾 | 看完数据立刻看到行动，不需要额外命令 |
| 阈值固定 | 硬编码 | PRD 排除自定义阈值，保持简单 |
| 预期效果 | 只对清理类建议计算 | 其他建议（检查规则）无法量化预期 |

## 4. 迭代记录

### 2026-04-14

tech 方案设计完成。
