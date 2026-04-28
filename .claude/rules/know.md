# know

```yaml
- when: during know learn gate evaluation of a [capture] claim, the content is general programming/writing common sense (style preferences, formatting conventions, universal best practices, etc.)
  avoid: letting such claims through — a capable model already knows these rules; writing them into CLAUDE.md will not change AI behavior, only add noise
  until: working with a model whose reasoning ability is insufficient

- when: 编辑 README.md 或 README.zh-CN.md 时
  should: 改任一版后立即同步另一版 — 避免双语 README 内容漂移，让中文/英文读者看到的信息一致
  how: 按相同 diff 编辑另一版，保章节序、表格列、示例 1:1，仅切换语言；同步前后 wc -l 检查行数对齐
  until: 项目放弃中文 README 支持（README.zh-CN.md 删除）

- when: 写或改 README.md / README.zh-CN.md 时
  prefer: 少而精——差异化对比表早置（vs 已知替代方案）+ 具象示例（如 YAML entry）早置 + 不暴露过多实现细节（如详细 step 列表、完整文档类型表 → 折叠或删去）
```
