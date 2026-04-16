# know 能力全景



## 1. 能力清单


| 能力             | 描述                | 状态  | 版本  | 需求                                        |
| -------------- | ----------------- | --- | --- | ----------------------------------------- |
| **Learn**      | 对话中检测并持久化隐性知识     | 可用  | v1  | [prd](requirements/know-learn/prd.md)     |
| **Write**      | 按模板生成结构化文档，与代码同版本 | 可用  | v1  | [prd](requirements/know-write/prd.md)     |
| **Recall**     | 编辑代码前自动提醒相关知识     | 可用  | v1  | —                                         |
| **Decay**      | 自动衰减过时知识，保持知识库精简  | 可用  | v1  | —                                         |
| **Metrics**    | 核心指标可查，数据驱动优化     | 可用  | v2  | [prd](requirements/know-metrics/prd.md)   |
| **Lifecycle**  | 知识从存入到衰减的完整轨迹可追踪  | 可用  | v2  | [prd](requirements/know-lifecycle/prd.md) |
| **Optimize**   | 基于数据调整规则，指标改善     | 可用  | v2  | [prd](requirements/know-optimize/prd.md)  |
| **Self-test**  | know-ctl 一键验证核心功能 | 可用  | v3  | [prd](requirements/know-selftest/prd.md)  |
| **Check**      | 检测模版与项目文档的结构偏差    | 可用  | v3  | [prd](requirements/know-check/prd.md)     |
| **Flow Rules** | write 关键判定点有明确规则  | 可用  | v3  | [prd](requirements/know-flowrules/prd.md) |
| **Extract**    | 从代码挖掘知识           | 可用  | v1  | —                                         |
| **Review**     | 审计知识条目质量          | 可用  | v1  | —                                         |


## 2. 覆盖范围

### 已知限制

- 单项目范围，不支持跨项目知识复用
- 知识检索依赖 scope 推断，scope 推断错误时会漏召回
- 文档模板固定 10 种，不支持自定义模板

### 未覆盖场景

- 自动修复文档不一致（只检测）
- 跨项目指标聚合
- CI/CD 集成

