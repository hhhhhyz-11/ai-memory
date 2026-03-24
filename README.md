# Workspace README

## 工作区结构

```
/root/.openclaw/workspace/
├── .gitlab-ci/          # GitLab CI 配置模板
├── gitlab-mcp/         # GitLab MCP + AI 审核服务
├── docs/               # 文档
├── learnings/          # 学习总结
├── memory/             # 每日日志
└── skills/             # 技能
```

## 快速索引

| 目录 | 内容 |
|------|------|
| `.gitlab-ci/` | CI/CD 流水线配置、Dockerfile |
| `gitlab-mcp/` | MCP Server、AI 审核 Agent |
| `docs/` | 各种技术文档 |
| `learnings/` | 每日学习总结 |
| `memory/` | 每日工作日志 |
| `skills/` | OpenClaw 技能 |

## 常用命令

```bash
# 查看今日日志
cat memory/$(date +%Y-%m-%d).md

# 查看学习总结
ls learnings/

# 查看定时任务
openclaw cron list
```
