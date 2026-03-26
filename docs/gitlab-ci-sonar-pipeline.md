# GitLab CI SonarQube 流水线说明

## 流水线概述

这个流水线用于在 MR 合并前自动执行 SonarQube 代码质量扫描，并通过质量门后自动合并 MR。

```
┌─────────────┐    ┌──────────────┐    ┌────────────┐    ┌─────────┐
│  代码提交    │ -> │ Sonar 扫描   │ -> │ 质量门检查  │ -> │ 自动合并 │
└─────────────┘    └──────────────┘    └────────────┘    └─────────┘
```

---

## 触发条件

| 目标分支 | 触发方式 | 规则 |
|---------|---------|------|
| **uat** | 自动 | 源分支必须是 `feature/` 或 `hotfix/` 开头 |
| **master** | 手动 | 源分支必须是 `release/` 开头 |

### 分支校验逻辑

```yaml
# uat 分支校验
if [[ ! "$SOURCE" =~ ^feature/ ]] && [[ ! "$SOURCE" =~ ^hotfix/ ]]; then
  echo "❌ [禁止合并] 合并至 uat 的源分支必须以 'feature/' 或 'hotfix/' 开头"
  exit 1
fi

# master 分支校验
if [[ ! "$SOURCE" =~ ^release/ ]]; then
  echo "❌ [禁止合并] 合并至 master 的源分支必须以 'release/' 开头"
  exit 1
fi
```

---

## 流水线执行流程

### 1️⃣ 变量初始化

根据目标分支动态设置 SonarQube 项目配置：

| 目标分支 | 项目 Key | Token 变量 |
|---------|---------|-----------|
| uat | `bike-server-uat-12.0.12` | `$SONAR_UAT` |
| master | `bike-server-master-12.0.12` | `$SONAR_MASTER` |

### 2️⃣ SonarQube 扫描

```bash
mvn clean verify sonar:sonar \
  -Dsonar.projectKey=$SONAR_PROJECT_KEY \
  -Dsonar.pullrequest.key=$CI_MERGE_REQUEST_IID \
  -Dsonar.pullrequest.branch=$SOURCE \
  -Dsonar.pullrequest.base=$TARGET
```

- **增量扫描**：只分析新增/变动的代码
- **PR 模式**：结果关联到 MR

### 3️⃣ 质量门检查

```bash
curl -s -u $TOKEN: "$SONAR_HOST/api/qualitygates/project_status?projectKey=$KEY&pullRequest=$IID"
```

返回状态：
- ✅ `OK` - 通过
- ❌ `ERROR` - 未通过

### 4️⃣ 问题统计

API 调用获取新增问题数量：

| 类型 | API 参数 |
|-----|---------|
| Bug | `types=BUG&newCode=true` |
| 漏洞 | `types=VULNERABILITY&newCode=true` |
| 异味 | `types=CODE_SMELL&newCode=true` |

### 5️⃣ 生成 PDF 报告

使用 Python + WeasyPrint 生成中文 PDF 报告，包含：
- 项目信息、MR 信息
- 质量门状态
- 新增问题统计
- 详细问题列表（限制显示数量）

### 6️⃣ 上传到 MinIO

```bash
mc cp sonar-report.pdf minio/$MINIO_BUCKET/$FILE_NAME
```

生成访问链接，可用于 MR 评论。

### 7️⃣ MR 评论 & 自动合并

```bash
# 发送 MR 评论
curl -X POST ... "$GITLAB_HOST/api/v4/projects/$CI_PROJECT_ID/merge_requests/$IID/notes"

# 如果质量门通过，执行合并
curl -X PUT ... "$GITLAB_HOST/api/v4/projects/$CI_PROJECT_ID/merge_requests/$IID/merge"
```

---

## 任务定义

```yaml
# UAT - 自动执行
sonar-and-merge-uat:
  extends: .sonar_task_template
  only:
    - merge_requests
  variables:
    - $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "uat"

# Master - 手动执行
sonar-and-merge-master:
  extends: .sonar_task_template
  when: manual  # ← 手动触发
  only:
    - merge_requests
  variables:
    - $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "master"
```

### 手动 vs 自动判断

- **`when: manual`** - 需要手动点击"Play"按钮才会执行
- **`only: merge_requests`** - 只有 MR 才会触发
- **变量判断** - 根据 `$CI_MERGE_REQUEST_TARGET_BRANCH_NAME` 区分目标分支

---

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

---

## 完整流程图

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitLab CI Pipeline                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [MR 创建]                                                      │
│      │                                                         │
│      ▼                                                         │
│  [校验分支规则] ── 不符合 ──▶ 退出 (exit 1)                     │
│      │                                                         │
│      ▼                                                         │
│  [Maven 编译 + SonarQube 扫描]                                  │
│      │                                                         │
│      ▼                                                         │
│  [获取质量门状态]                                               │
│      │                                                         │
│      ├──── OK ──▶ [生成 PDF] ──▶ [上传 MinIO] ──▶ [MR 评论] ──▶ [自动合并] │
│      │                                                         │
│      └─ ERROR ──▶ [发送失败通知] ──▶ 退出 (exit 1)              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 常见问题

### Q: 为什么 master 分支要手动触发？
A: master 是生产分支，手动触发更安全，避免误操作。

### Q: 同分支合并会怎样？
A: 会直接跳过流水线 (`exit 0`)，避免重复执行。

### Q: 质量门失败会怎样？
A: 流水线失败，不会合并，并发送钉钉通知。

### Q: PDF 报告在哪里看？
A: 上传到 MinIO 后，链接会发在 MR 评论里。

---