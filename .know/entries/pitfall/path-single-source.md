# Skill 文件路径不能分散定义
## Symptoms
文档生成到错误路径，目录结构不一致，`{feature}` 等变量被不同解读。
## Root cause
路径定义分散在 6 处（Document Types、Step 2b、Step 3、Step 6、Step 7、Step 8），每处写法不同，AI 自行拼接导致结果不稳定。
## Lesson
路径定义集中在一张 Path Resolution 表，所有 step 引用这张表。变量（如 `impl/`）如果是固定值就写死，不要用动态占位符。
