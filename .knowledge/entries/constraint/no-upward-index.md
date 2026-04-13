# 文档树状向下索引，不回指父级

roadmap→prd→tech 形成树状索引。每层只向下链接子文档，不回指父级。

## Why

互相索引造成循环引用，结构不清晰。树状单向索引让层级关系一目了然。

## How to check

tech 文档中不应出现链接到 prd 的 markdown link。prd 中不应出现链接到 roadmap 的 link。
