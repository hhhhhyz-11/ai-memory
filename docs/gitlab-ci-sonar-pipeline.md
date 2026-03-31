# GitLab CI SonarQube 流水线说明

## 流水线概述

这个流水线用于在 MR 合并前自动执行 SonarQube 代码质量扫描，并通过质量门后自动合并 MR。

```
┌─────────────┐  ┌──────────────┐  ┌────────────┐  ┌─────────┐
│ 代码提交  │ -> │ Sonar 扫描  │ -> │ 质量门检查 │ -> │ 自动合并 │
└─────────────┘  └──────────────┘  └────────────┘  └─────────┘
```


## 核心概念解释

### 1. `.sonar_task_template` - 模板定义

```yaml
# 定义一个模板（注意开头是 . 表示隐藏模板）
.sonar_task_template:
stage: sonar_and_merge
image: sonar-ci:20260323
variables:
MAVEN_OPTS: "-Dmaven.repo.local=/maven-repo/repository"
...
script:
- 这里是脚本内容
artifacts:
paths:
- quality-gate.txt
- sonar-report.pdf
```

**作用**：
- 相当于定义一个"公共模板"，包含所有重复的配置
- 开头 `.` 表示隐藏，不会作为独立的 job 执行
- 其他 job 可以"继承"这个模板，避免代码重复


### 2. `extends` - 继承模板

```yaml
# UAT 任务继承模板
sonar-and-merge-uat:
extends: .sonar_task_template  # ← 继承上面的模板
only:
refs:
- merge_requests
variables:
- $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "uat"

# Master 任务继承模板
sonar-and-merge-master:
extends: .sonar_task_template  # ← 继承上面的模板
when: manual
only:
refs:
- merge_requests
variables:
- $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "master"
```

**作用**：
- `extends` 表示继承/复用 `.sonar_task_template` 的所有配置
- 只需要写不同的部分（触发规则、执行方式）
- 类似编程中的"继承"概念


### 3. 如何判断使用哪个任务？

GitLab CI 通过 **变量过滤** 来决定触发哪个 job：

```yaml
sonar-and-merge-uat:
extends: .sonar_task_template
only:
refs:
- merge_requests
variables:
- $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "uat"  # ← 只有目标是 uat 才触发

sonar-and-merge-master:
extends: .sonar_task_template
when: manual
only:
refs:
- merge_requests
variables:
- $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "master" # ← 只有目标是 master 才触发
```

**判断逻辑**：

```
┌─────────────────────────────────────────────────────────┐
│          MR 创建/更新             │
│       (merge_requests 事件触发)          │
└─────────────────────┬───────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────┐
│      判断目标分支变量                │
│   $CI_MERGE_REQUEST_TARGET_BRANCH_NAME        │
└─────────────────────┬───────────────────────────────────┘
│
┌───────────┴───────────┐
│            │
▼            ▼
┌─────────────┐    ┌─────────────┐
│ target=uat │    │ target=master│
└──────┬──────┘    └──────┬──────┘
│           │
▼           ▼
┌─────────────┐    ┌─────────────┐
│执行 sonar- │    │执行 sonar-  │
│and-merge-  │    │and-merge-  │
│uat     │    │master    │
└─────────────┘    └─────────────┘
```

| 目标分支 | 触发的 Job | 执行方式 |
|---------|-----------|---------|
| `uat` | `sonar-and-merge-uat` | **自动**（默认 `on_success`） |
| `master` | `sonar-and-merge-master` | **手动**（`when: manual`） |


### 4. `when: manual` - 手动触发

```yaml
sonar-and-merge-master:
extends: .sonar_task_template
when: manual  # ← 告诉 GitLab 这是手动任务
...
```

- 看到 `when: manual`，GitLab 会在 UI 上显示 ⏸️ 小手图标
- 必须用户手动点击"Play"按钮才会执行
- 用于生产分支（master）需要人工确认的场景


## 完整执行流程

### 1️⃣ 触发阶段

```
MR 创建/更新
│
▼
判断 $CI_MERGE_REQUEST_TARGET_BRANCH_NAME
│
├─ uat  ──▶ 自动执行 sonar-and-merge-uat
│
└─ master ──▶ 等待手动点击 sonar-and-merge-master
```

### 2️⃣ 分支校验（脚本内）

```bash
# 同分支合并跳过
if [ "$SOURCE" = "$TARGET" ]; then
exit 0
fi

# master 分支校验
if [ "$TARGET" = "master" ] && [[ ! "$SOURCE" =~ ^release/ ]]; then
echo "❌ 禁止合并"
exit 1
fi

# uat 分支校验
if [ "$TARGET" = "uat" ] && [[ ! "$SOURCE" =~ ^feature/ ]] && [[ ! "$SOURCE" =~ ^hotfix/ ]]; then
echo "❌ 禁止合并"
exit 1
fi
```

| 目标分支 | 允许的源分支前缀 |
|---------|-----------------|
| `master` | `release/` |
| `uat` | `feature/` 或 `hotfix/` |

### 3️⃣ SonarQube 扫描

```bash
mvn clean verify sonar:sonar \
-Dsonar.projectKey=$SONAR_PROJECT_KEY \
-Dsonar.pullrequest.key=$CI_MERGE_REQUEST_IID \
-Dsonar.pullrequest.branch=$SOURCE \
-Dsonar.pullrequest.base=$TARGET \
-Dsonar.qualitygate.wait=true
```

### 4️⃣ 质量门检查

```bash
curl -s -u $TOKEN: "$SONAR_HOST/api/qualitygates/project_status?projectKey=$KEY&pullRequest=$IID"
```

返回：
- ✅ `OK` - 继续流程
- ❌ `ERROR` - 发送失败通知，退出

### 5️⃣ 生成 PDF 报告

Python + WeasyPrint 生成中文 PDF，包含：
- 项目信息、MR 信息
- 质量门状态
- 新增问题统计（Bug/漏洞/异味）
- 详细问题列表

### 6️⃣ 上传到 MinIO

```bash
mc cp sonar-report.pdf minio/$MINIO_BUCKET/$FILE_NAME
```

生成可访问的 PDF 链接。

### 7️⃣ MR 评论 & 自动合并

```bash
# 发送 MR 评论（包含统计和质量门状态）
curl -X POST ... "$GITLAB_HOST/.../merge_requests/$IID/notes"

# 发送 PDF 链接
curl -X POST ... "$GITLAB_HOST/.../merge_requests/$IID/notes"

# 质量门通过后自动合并
curl -X PUT ... "$GITLAB_HOST/.../merge_requests/$IID/merge"
```


## 流程图

```
┌─────────────────────────────────────────────────────────────────┐
│          GitLab CI Pipeline             │
├─────────────────────────────────────────────────────────────────┤
│                                 │
│ [MR 创建/更新]                         │
│   │                             │
│   ▼                             │
│ [判断目标分支变量]                       │
│ $CI_MERGE_REQUEST_TARGET_BRANCH_NAME             │
│   │                             │
│   ├──────────────┬──────────────────┐            │
│   ▼       ▼         ▼            │
│ ┌─────────┐  ┌─────────┐    ┌─────────┐         │
│ │ target= │  │target= │    │ target= │         │
│ │ uat  │  │ master │    │ 其他  │         │
│ └────┬────┘  └────┬────┘    └────┬────┘         │
│    │       │         │            │
│    ▼       ▼ (需手动点击)   ▼            │
│ ┌─────────┐  ┌─────────┐    ┌─────────┐         │
│ │ 自动执行 │  │ 等待手动 │    │ 不执行  │         │
│ │ .sona.. │  │ .sona.. │    │     │         │
│ └────┬────┘  └────┬────┘    └─────────┘         │
│    │       │                     │
│    ▼       ▼                     │
│ ┌─────────────────────────────────────────┐         │
│ │     .sonar_task_template      │         │
│ │ 1. 分支规则校验             │         │
│ │ 2. Maven 编译 + Sonar 扫描       │         │
│ │ 3. 质量门检查             │         │
│ │ 4. 问题统计 & 评级           │         │
│ │ 5. 生成 PDF 报告           │         │
│ │ 6. 上传 MinIO             │         │
│ │ 7. MR 评论 + 自动合并         │         │
│ └────────────────────┬────────────────────┘          │
│            │                     │
│      ┌──────────┴──────────┐               │
│      ▼           ▼               │
│    质量门通过       质量门失败             │
│      │           │               │
│      ▼           ▼               │
│   自动合并 MR      钉钉通知 + 退出           │
│                                 │
└─────────────────────────────────────────────────────────────────┘
```


## 所需变量

需要在 GitLab CI/CD 变量中配置：

| 变量名 | 说明 | 示例 |
|-------|------|------|
| `SONAR_HOST` | SonarQube 地址 | `http://192.168.0.47:9000` |
| `SONAR_MASTER` | master 项目 Token | `xxx` |
| `SONAR_UAT` | uat 项目 Token | `xxx` |
| `MERGE_TOKEN` | 有合并权限的 GitLab PAT | `glpat-xxx` |
| `GITLAB_HOST` | GitLab 地址 | `http://192.168.0.43:8080` |
| `MINIO_HOST` | MinIO 地址 | `192.168.0.180:9000` |
| `MINIO_ACCESS_KEY` | MinIO AccessKey | `xxx` |
| `MINIO_SECRET_KEY` | MinIO SecretKey | `xxx` |
| `MINIO_BUCKET` | MinIO 桶名 | `sonar-reports` |
| `DINGTALK_WEBHOOK` | 钉钉 webhook | `https://oapi.dingtalk.com/...` |


## 常见问题

### Q: 为什么 master 分支要手动触发？
A: master 是生产分支，手动触发更安全，避免误操作。

### Q: 同分支合并会怎样？
A: 会直接跳过流水线 (`exit 0`)，避免重复执行。

### Q: 质量门失败会怎样？
A: 流水线失败，不会合并，并发送钉钉通知。

### Q: PDF 报告在哪里看？
A: 上传到 MinIO 后，链接会发在 MR 评论里。

### Q: extends 和 include 有什么区别？
A: 
- `extends`: 继承模板，YAML 原生功能
- `include`: 引入外部文件，模块化


## 任务定义完整对照

| 属性 | 说明 | uat 任务 | master 任务 |
|-----|------|---------|------------|
| `extends` | 继承模板 | `.sonar_task_template` | `.sonar_task_template` |
| `when` | 执行方式 | `on_success`（默认） | `manual` |
| `only` | 触发条件 | `merge_requests` | `merge_requests` |
| `variables` | 变量过滤 | `target == "uat"` | `target == "master"` |

