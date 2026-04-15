# Skill 设计用原则驱动不用规则驱动
## Why
机械二元链（yes/no + explicit yes signal）在边界情况误杀或漏判。原则驱动让 AI 在低风险处发挥语义能力，高风险处要求多信号确认。
## Rejected alternatives
严格二元过滤链 — 简单场景有效，但抑制模型能力，边界情况不稳定。
## Constraints
高风险动作（删除/critical/block）仍需显式证据+用户确认，语义不能单独拍板。
