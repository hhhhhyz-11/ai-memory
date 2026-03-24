# GitLab MCP 服务

## 概述

提供 GitLab API 能力给 AI Agent，用于代码审核自动化。

## 组件

| 文件 | 说明 |
|------|------|
| `server.py` | MCP Server，提供 GitLab API 封装 |
| `review_agent.py` | AI 代码审核 Agent |
| `docker-compose.yml` | 一键部署配置 |

## 快速部署

```bash
docker-compose up -d
```

## API 端点

- `GET /mcp/tools` - 列出可用工具
- `POST /mcp/tools/get_mr_details` - 获取 MR 详情
- `POST /mcp/tools/get_mr_changes` - 获取代码变更
- `POST /mcp/tools/comment_mr` - 添加评论
- `POST /webhook/gitlab` - Webhook 入口
