# know-ctl CLI 接口规范

## 1. 概述

### 范围

know-ctl.sh 是 .know/ 知识库的 CLI 管理接口，提供知识条目的增删改查、命中追踪、衰减清理和质量度量。

### 调用方

- Claude Code agent（通过 workflow 文件中的 bash 命令调用）

### 协议类型

CLI

## 2. 数据结构

index.jsonl 中每行一条 JSON entry，结构如下：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| tag | string | 是 | 知识分类，枚举: rationale, constraint, pitfall, concept, reference |
| tier | int | 是 | 重要性层级，1 = 重要（critical），2 = 备忘（memo） |
| scope | string \| string[] | 是 | 作用域，支持前缀匹配，"project" 表示全局 |
| tm | string | 是 | 触发模式，如 "active:defensive", "passive" |
| summary | string | 是 | 一句话摘要，用于检索和展示 |
| path | string \| null | 否 | 详情文件相对路径，如 "entries/constraint/foo.md" |
| hits | int | 否 | 被命中次数，默认 0 |
| revs | int | 否 | 修订次数，默认 0 |
| last_hit | string \| null | 否 | 最近命中日期，格式 YYYY-MM-DD |
| source | string | 否 | 知识来源标识 |
| created | string | 是 | 创建日期，格式 YYYY-MM-DD |
| updated | string | 是 | 最后更新日期，格式 YYYY-MM-DD |

## 3. 接口定义

### append

- **方法**: CLI command
- **路径**: `bash know-ctl.sh append '<json>'`
- **参数**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| json | string (JSON) | 是 | 完整的 index entry JSON 字符串 |

- **响应**:

```
Appended: <summary>
```

- **错误码**:

| 错误码 | 含义 | 处理建议 |
|--------|------|---------|
| exit 1 | 缺少必填字段（tag, tier, scope, summary, updated） | 检查 JSON 是否包含全部 5 个必填字段 |
| exit 1 | JSON 解析失败 | 检查 JSON 格式是否合法 |

### query

- **方法**: CLI command
- **路径**: `bash know-ctl.sh query <scope> [--tag <tag>] [--tier <n>] [--tm <mode>]`
- **参数**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| scope | string | 是 | 作用域前缀，"project" 返回全部 |
| --tag | string | 否 | 按 tag 精确过滤 |
| --tier | int | 否 | 按 tier 精确过滤 |
| --tm | string | 否 | 按触发模式精确过滤 |

- **响应**:

```json
{"tag":"constraint","tier":1,"scope":"know.recall","summary":"...","hits":3,...}
{"tag":"rationale","tier":1,"scope":"know.learn","summary":"...","hits":1,...}
```

每行一条匹配的 JSON entry（compact 格式），无匹配时无输出。

- **错误码**:

| 错误码 | 含义 | 处理建议 |
|--------|------|---------|
| exit 1 | 未提供 scope 参数 | 传入必填的 scope 参数 |
| (空输出) | 无匹配条目 | 检查 scope 前缀是否正确 |

### hit

- **方法**: CLI command
- **路径**: `bash know-ctl.sh hit <path-or-keyword>`
- **参数**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| target | string | 是 | entry 的 path（以 "entries/" 开头）或 summary 的正则关键词 |

- **响应**:

无标准输出。副作用：匹配条目的 hits +1，updated 和 last_hit 设为当天日期，同时写入 hit 事件到 events.jsonl。

- **错误码**:

| 错误码 | 含义 | 处理建议 |
|--------|------|---------|
| exit 1 | 未提供 target 参数 | 传入 path 或关键词 |
| (静默) | 无匹配条目 | hit 不报错，但不产生实际变更，检查关键词拼写 |

## 4. 约束与规则

- append 校验 5 个必填字段：tag, tier, scope, summary, updated，缺任一则 exit 1
- 所有日期字段必须为 YYYY-MM-DD 格式
- index.jsonl 每行必须是合法的 compact JSON，不允许多行 JSON 或空行
- scope 字段支持 string 或 string[]，query 使用前缀匹配（startsWith）
- hit 的 target 参数区分两种模式：以 "entries/" 开头走 path 精确匹配，否则走 summary 正则匹配（大小写不敏感）
- decay 策略规则：tier 2 + hits=0 + 超过 30 天 → 删除；tier 1 + hits=0 + 超过 180 天 → 降级为 tier 2；tier 1 + revs>3 → 降级为 tier 2

## 5. 示例

**请求:**

```bash
bash know-ctl.sh append '{"tag":"constraint","tier":1,"scope":"know.recall","tm":"active:defensive","summary":"query 必须用 scope 前缀匹配，不能全量扫描","path":"entries/constraint/query-scope-prefix.md","hits":0,"revs":0,"last_hit":null,"source":"design-session","created":"2025-04-08","updated":"2025-04-08"}'
```

**响应:**

```
Appended: query 必须用 scope 前缀匹配，不能全量扫描
```
