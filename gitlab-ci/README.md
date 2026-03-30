# GitLab CI SonarQube 流水线

## 📁 目录结构

```
gitlab-ci/
├── .gitlab-ci.yml      # 完整流水线配置
├── Dockerfile.sonar    # SonarQube CI 镜像构建
└── README.md           # 本文件
```

## 🚀 功能特性

| 功能 | 说明 |
|------|------|
| **SonarQube 增量扫描** | 仅扫描 MR 新增代码，支持多分支配置 |
| **分支门禁规则** | uat 仅允许 feature/hotfix 分支合并；master 仅允许 release 分支合并 |
| **PDF 分析报告** | 自动生成中文 PDF，包含 Bug、漏洞、异味详情 |
| **MR 自动评论** | 扫描结果自动同步到 MR 评论区 |
| **质量门检查** | 未通过 Quality Gate 则阻止合并 |
| **自动合并** | uat 分支：扫描通过后自动合并；master 分支：手动触发合并 |
| **MinIO 存储** | PDF 报告上传至 MinIO 文件服务器 |
| **钉钉通知** | 质量门未通过时发送钉钉通知 |

## 🔧 前置要求

### 1. CI/CD 变量（GitLab Settings → CI/CD → Variables）

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `SONAR_MASTER` | master 分支 SonarQube Token | sqp_xxx |
| `SONAR_UAT` | uat 分支 SonarQube Token | sqp_xxx |
| `MERGE_TOKEN` | 具有 Merge 权限的 GitLab PAT | glpat-xxx |
| `DINGTALK_WEBHOOK` | 钉钉群机器人 WebHook | https://oapi.dingtalk.com/robot/send?access_token=xxx |
| `MINIO_ACCESS_KEY` | MinIO 用户名 | minioadmin |
| `MINIO_SECRET_KEY` | MinIO 密码 | minioadmin |

### 2. SonarQube 项目配置

在 SonarQube 中分别为 master 和 uat 分支创建项目：

| 项目 Key | 分支 |
|----------|------|
| `bike-server-master-12.0.12` | master |
| `bike-server-uat-12.0.12` | uat |

### 3. CI 镜像

```bash
docker build -f Dockerfile.sonar -t sonar-ci:20260323 .
```

镜像包含：Maven 3.9.6 + Java 11、Python 3 + WeasyPrint、MinIO Client、Jinja2

## 📦 使用方式

在项目根目录创建 `.gitlab-ci.yml`：

```yaml
include:
  - local: '.gitlab-ci.yml'
  # 或远程引用：
  # - remote: 'https://raw.githubusercontent.com/hhhhhyz-11/ai-memory/main/gitlab-ci/.gitlab-ci.yml'
```

## 🔀 分支规则

| 目标分支 | 源分支规则 | 合并方式 |
|----------|-----------|---------|
| `uat` | feature/*、hotfix/* | 自动合并 |
| `master` | release/* | 手动合并 |

## 📊 流水线阶段

```
analysis (scan-uat / scan-master)  →  merge (merge-uat / merge-master)
     │                                         │
     ├─ SonarQube 增量扫描                      ├─ 检查 MR 状态
     ├─ 生成 PDF 报告                           ├─ 执行合并
     ├─ 上传 MinIO                              └─ 失败则钉钉通知
     ├─ MR 评论区同步
     └─ 质量门检查
```

## 🐛 已知问题

- `featrue/` 分支名拼写错误（应为 `feature/`），SonarQube projectKey 和分支名需保持一致时注意修改
