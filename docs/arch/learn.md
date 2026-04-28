# Learn 架构设计

## 1. 职责

从对话中提取 claim，经 5 道 gate 筛选后结构化写入目标 CLAUDE.md 的 `## know` 段。

不负责：
- 写结构化文档（write.md workflow）
- 运行时召回（Claude Code 嵌套加载机制接管）

## 2. 管线

5 个 stage 串行，每条 claim 独立走完一次：

- detect — 从对话提取全部 claim 候选，用户取子集
- gate — 5 道闸依次过滤，任一 fail 即 reject 该 claim
- refine — 场景泛化 / 知识深化 / 颗粒度校准三维细化，可跳
- locate — 决定写入哪个 CLAUDE.md（user / project / module）
- write — 产出 YAML entry，查重，写文件

## 3. Gate 顺序（粗到细）

gate 按拒绝成本从低到高排序，越早越粗，越晚越细：

1. 信息熵 — AI 不知道这条时会得到不同结论吗？否 → reject。最粗，过滤通用编程常识。
2. 复用价值 — 能写出至少 1 个未来场景吗？否 → reject。确认不是一次性结论。
3. 可触发 — AI 在什么具体操作下应该想起这条？写不出或过宽泛 → reject。
4. 可执行 — 仅凭这条 entry，AI 能完成动作吗？技术类写不出 how → reject。
5. 失效 — 能写出"什么时候本条不再成立"吗？否 → reject（must 类必填）。

classify（分配字段 must / should / avoid / prefer）在信息熵之前执行，决定字段名，不是过滤闸。

## 4. 写入格式

entry 写入目标文件的 `## know` YAML block：

```yaml
- when: {触发场景}
  must: {claim} — {理由}   # 或 should / avoid / prefer
  how: {操作指引}           # 仅技术类必填
  until: {失效条件}         # must 必填，其余选填
```

## 5. 关键约束

- claim 独立过 gate：一条 fail 不影响其余
- 无 `## know` 段时追加到文件末尾；段已存在则 append 到 list 末尾
- 发现语义重复条目时停止，不覆盖已有 entry
- 不自动 commit
