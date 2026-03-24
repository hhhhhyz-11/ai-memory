# GitLab CI Templates

## 目录结构

```
gitlab/
└── sonar-mr-pipeline.yml    # SonarQube MR 审核流水线
```

## sonar-mr-pipeline.yml

包含以下功能：
- SonarQube 增量代码扫描
- 自动生成 PDF 分析报告
- MR 自动评论
- 质量门检查
- 自动合并
- 钉钉通知

### 使用方法

在项目中创建 `.gitlab-ci.yml`：

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/hhhhhyz-11/project/main/gitlab/sonar-mr-pipeline.yml'
```

或直接复制 `sonar-mr-pipeline.yml` 到项目的 `.gitlab-ci/` 目录。
