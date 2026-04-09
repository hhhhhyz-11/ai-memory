# GitLab CI + SonarQube 自动化流水线说明

> 适用项目：bike-server  
> 文档日期：2026-04-09

---

## 一、流水线架构总览

### 1.1 涉及产品

| 产品 | 地址 | 用途 |
|------|------|------|
| GitLab | http://192.168.0.18:8080 | CI 调度、MR 管理 |
| SonarQube | http://192.168.0.47:9000 | 代码质量扫描、质量门禁 |
| MinIO | http://192.168.0.180:9000 | PDF 报告存储 |

### 1.2 Job 一览

| Job | 阶段 | 触发条件 | 是否自动 |
|-----|------|----------|---------|
| `scan-uat` | analysis | MR 目标分支 = uat | ✅ 全自动 |
| `merge-uat` | merge | scan-uat 成功后 | ✅ 全自动 |
| `scan-master` | analysis | MR 目标分支 = master | ✅ 全自动 |
| `merge-master` | merge | scan-master 成功后 | ❌ 手动触发 |

### 1.3 完整流水线 YAML

```yaml
stages:
  - analysis
  - merge

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=/maven-repo/repository"
  GIT_DEPTH: "0"
  SONAR_HOST: "http://192.168.0.47:9000"
  GITLAB_HOST: "http://192.168.0.18:8080"
  MINIO_HOST: "192.168.0.180:9000"
  MINIO_BUCKET: "sonar-reports"
  SONAR_PROJECT_MASTER: "bike-server-master"
  SONAR_PROJECT_UAT: "bike-server-uat"

# ============================================================
# UAT: 自动扫描 + 自动合并
# ============================================================
scan-uat:
  extends: .sonar_scan_logic
  tags:
    - yyz
  only:
    refs: [merge_requests]
    variables:
      - $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "uat"

merge-uat:
  extends: .merge_logic
  tags:
    - yyz
  dependencies: ["scan-uat"]
  only:
    refs: [merge_requests]
    variables:
      - $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "uat"

# ============================================================
# MASTER: 自动扫描 + 手动合并
# ============================================================
scan-master:
  extends: .sonar_scan_logic
  tags:
    - yyz
  only:
    refs: [merge_requests]
    variables:
      - $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "master"

merge-master:
  extends: .merge_logic
  tags:
    - yyz
  when: manual                    # ← 手动触发，不自动合并
  allow_failure: false
  dependencies: ["scan-master"]
  only:
    refs: [merge_requests]
    variables:
      - $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "master"
```

---

## 二、流水线流程图

### 2.1 UAT 流水线（自动模式）

```
开发者发起 MR (feature/xxx → uat)
         │
         ▼
┌─────────────────────────┐
│    GitLab CI 触发       │
│  scan-uat (analysis)    │
└────────┬────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  1. 分支规则校验                           │
│     feature/ 或 hotfix/ 才能合并至 uat     │
│     否则直接退出                           │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  2. SonarQube 增量扫描                    │
│     - 确定项目 Key 和 Token               │
│     - mvn clean verify sonar:sonar        │
│     - 对比增量代码（新代码）               │
│     - 等待 Quality Gate 结果              │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  3. 获取质量指标                           │
│     - BUGS / VULNERABILITY / CODE_SMELL  │
│     - 可靠性评级 / 安全评级 / 可维护性评级 │
│     - 覆盖率                               │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  4. 生成 PDF 报告                         │
│     - Python + WeasyPrint 渲染            │
│     - 包含问题详情表格                     │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  5. 上传 MinIO                           │
│     - sonar-reports 桶                    │
│     - 路径: 项目名/日期/sonar-report-xxx │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  6. MR 评论                               │
│     - 质量门状态 / 问题统计 / 评级         │
│     - PDF 下载链接                         │
└────────┬─────────────────────────────────┘
         │
         ▼
    ┌────┴────┐
    │ Quality │
    │ Gate    │
    └────┬────┘
         │
    ┌────┴────────────────────┐
    │ 状态 = OK？              │
    └────┬────────────────────┘
         │
    ┌────┴────┐          ┌────┴────┐
    │  YES   │          │   NO   │
    └────┬────┘          └────┬────┘
         │                   │
         ▼                   ▼
┌─────────────────┐  ┌──────────────────────┐
│  钉钉成功通知    │  │  钉钉失败通知        │
│  scan-uat 继续   │  │  exit 1 流水线失败   │
└────────┬────────┘  └──────────────────────┘
         │
         ▼
┌─────────────────────────┐
│  merge-uat (merge)      │
│  - 检查 MR 状态           │
│  - PUT /merge 合并       │
└────────┬────────────────┘
         │
         ▼
   MR 合并完成 ✅
```

### 2.2 Master 流水线（半自动模式）

```
开发者发起 MR (release/xxx → master)
         │
         ▼
┌─────────────────────────┐
│    GitLab CI 触发        │
│  scan-master (analysis)  │
└────────┬────────────────┘
         │
         ▼
  [后续流程同 UAT，完全一致]
         │
         ▼
┌──────────────────────────────────────┐
│  钉钉通知（质量门结果）                │
└────────┬─────────────────────────────┘
         │
    ┌────┴────┐
    │ Quality │
    │ Gate    │
    └────┬────┘
         │
    ┌────┴────┐
    │  OK?   │
    └────┬────┘
         │
    ┌────┴────┐          ┌────┴────┐
    │  YES   │          │   NO   │
    └────┬────┘          └────┬────┘
         │                   │
         ▼                   ▼
  scan-master 成功    流水线失败退出
         │
         ▼
┌─────────────────────────┐
│  merge-master (merge)   │  ← 【手动触发】
│  - GitLab UI 点击 Play   │
│  - 检查 MR 状态          │
│  - PUT /merge 合并       │
└────────┬────────────────┘
         │
         ▼
   MR 合并完成 ✅
```

---

## 三、模块详解

### 3.1 构建说明（.sonar_scan_logic）

#### 分支规则校验

| 目标分支 | 允许的源分支前缀 | 规则 |
|---------|----------------|------|
| uat | `feature/` 或 `hotfix/` | 其他分支直接退出，不扫描 |
| master | `release/` | 其他分支直接退出，不扫描 |

#### 对应流水线代码

```yaml
.sonar_scan_logic:
  stage: analysis
  image: sonar-ci:20260323
  script:
    # ---- 1. 分支规则校验 ----
    - |
      TARGET=$CI_MERGE_REQUEST_TARGET_BRANCH_NAME
      SOURCE=$CI_COMMIT_REF_NAME

      if [ "$SOURCE" = "$TARGET" ]; then
        echo "同分支合并，跳过"; exit 0
      fi

      if [ "$TARGET" = "master" ]; then
        if [[ ! "$SOURCE" =~ ^release/ ]]; then
          echo "❌ [禁止合并] 合并至 master 的源分支必须以 'release/' 开头"
          exit 1
        fi
        SONAR_PROJECT_KEY="$SONAR_PROJECT_MASTER"
        SONAR_PROJECT_TOKEN="$SONAR_MASTER"

      elif [ "$TARGET" = "uat" ]; then
        if [[ ! "$SOURCE" =~ ^feature/ ]] && [[ ! "$SOURCE" =~ ^hotfix/ ]]; then
          echo "❌ [禁止合并] 合并至 uat 的源分支必须以 'feature/' 或 'hotfix/' 开头"
          exit 1
        fi
        SONAR_PROJECT_KEY="$SONAR_PROJECT_UAT"
        SONAR_PROJECT_TOKEN="$SONAR_UAT"
      fi

    # ---- 2. SonarQube 扫描 ----
    - |
      mvn clean verify sonar:sonar \
        -Dsonar.projectKey=$SONAR_PROJECT_KEY \
        -Dsonar.host.url=$SONAR_HOST \
        -Dsonar.login=$SONAR_PROJECT_TOKEN \
        -Dsonar.pullrequest.key=$CI_MERGE_REQUEST_IID \
        -Dsonar.pullrequest.branch=$CI_COMMIT_REF_NAME \
        -Dsonar.pullrequest.base=$CI_MERGE_REQUEST_TARGET_BRANCH_NAME \
        -Dsonar.cpd.minimumLines=5 \
        -Dsonar.qualitygate.wait=true || true
```

#### SonarQube 扫描参数说明

| 参数 | 说明 |
|------|------|
| `sonar.projectKey` | uat 对应 `bike-server-uat`，master 对应 `bike-server-master` |
| `sonar.pullrequest.key` | MR 的 IID，SonarQube 用此关联到对应 MR |
| `sonar.pullrequest.branch` | 源分支名（增量代码所在分支） |
| `sonar.pullrequest.base` | 目标分支名（增量对比的基准） |
| `sonar.qualitygate.wait=true` | 阻塞等待质量门结果返回 |

> **关键**：增量扫描通过 `pullRequest` 参数实现，SonarQube 自动对比源分支与目标分支的差异代码，只统计新增问题。

---

### 3.2 获取指标说明（Quality Gate + Issues）

#### 对应流水线代码

```yaml
    # ---- 3. 获取质量门状态 ----
    - |
      SCAN_RESULT=$(curl -s -u $SONAR_PROJECT_TOKEN: \
        "$SONAR_HOST/api/qualitygates/project_status?projectKey=$SONAR_PROJECT_KEY&pullRequest=$CI_MERGE_REQUEST_IID")
      STATUS=$(echo "$SCAN_RESULT" | jq -r '.projectStatus.status // "UNKNOWN"')
      echo "$STATUS" > quality-gate.txt

    # ---- 4. 获取新增问题数量 ----
    - |
      ISSUES_BUGS=$(curl -s -u $SONAR_PROJECT_TOKEN: \
        "$SONAR_HOST/api/issues/search?componentKeys=$SONAR_PROJECT_KEY&pullRequest=$CI_MERGE_REQUEST_IID&types=BUG&newCode=true&resolved=false" \
        | jq '.total // 0')

      ISSUES_VULNS=$(curl -s -u $SONAR_PROJECT_TOKEN: \
        "$SONAR_HOST/api/issues/search?componentKeys=$SONAR_PROJECT_KEY&pullRequest=$CI_MERGE_REQUEST_IID&types=VULNERABILITY&newCode=true&resolved=false" \
        | jq '.total // 0')

      ISSUES_SMELLS=$(curl -s -u $SONAR_PROJECT_TOKEN: \
        "$SONAR_HOST/api/issues/search?componentKeys=$SONAR_PROJECT_KEY&pullRequest=$CI_MERGE_REQUEST_IID&types=CODE_SMELL&newCode=true&resolved=false" \
        | jq '.total // 0')

      echo "BUGS=$ISSUES_BUGS" > quality-stats.txt
      echo "VULNS=$ISSUES_VULNS" >> quality-stats.txt
      echo "SMELLS=$ISSUES_SMELLS" >> quality-stats.txt

    # ---- 5. 获取评级 ----
    - |
      REL_RATING=$(echo "$SCAN_RESULT" | jq -r '.projectStatus.conditions[] | select(.metricKey=="new_reliability_rating") | .actualValue // "N/A"')
      SEC_RATING=$(echo "$SCAN_RESULT" | jq -r '.projectStatus.conditions[] | select(.metricKey=="new_security_rating") | .actualValue // "N/A"')
      MAIN_RATING=$(echo "$SCAN_RESULT" | jq -r '.projectStatus.conditions[] | select(.metricKey=="new_maintainability_rating") | .actualValue // "N/A"')
      COVERAGE=$(echo "$SCAN_RESULT" | jq -r '.projectStatus.conditions[] | select(.metricKey=="new_coverage") | .actualValue // "N/A"')

      # 数值转字母评级
      RATING_MAP='{"1":"A","2":"B","3":"C","4":"D","5":"E"}'
      REL_LETTER=$(echo "$RATING_MAP" | jq -r ".\"$REL_RATING\" // \"N/A\"")
      SEC_LETTER=$(echo "$RATING_MAP" | jq -r ".\"$SEC_RATING\" // \"N/A\"")
      MAIN_LETTER=$(echo "$RATING_MAP" | jq -r ".\"$MAIN_RATING\" // \"N/A\"")
```

#### API 调用汇总

| 用途 | API 端点 |
|------|---------|
| 质量门状态 | `GET /api/qualitygates/project_status?projectKey=&pullRequest=` |
| Bug 列表 | `GET /api/issues/search?types=BUG&newCode=true&resolved=false` |
| 漏洞列表 | `GET /api/issues/search?types=VULNERABILITY&newCode=true&resolved=false` |
| 异味列表 | `GET /api/issues/search?types=CODE_SMELL&newCode=true&resolved=false` |

#### 评级换算

| 数值 | 字母 | 含义 |
|------|------|------|
| 1 | A | 优秀 |
| 2 | B | 良好 |
| 3 | C | 一般 |
| 4 | D | 较差 |
| 5 | E | 很差 |

#### PDF 报告生成代码

```python
    # ---- 6. 生成 PDF 报告（Python + WeasyPrint）----
    - |
      python3 <<'PYEOF'
      import os, json
      from datetime import datetime
      from jinja2 import Template
      from weasyprint import HTML, CSS

      # 加载 issue-details.json，渲染 Bug/漏洞/异味详情表格
      # 限制展示数量：Bug前10、漏洞前10、异味前20
      # 输出 sonar-report.pdf
      PYEOF
```

---

### 3.3 自动合并说明（.merge_logic）

#### 对应流水线代码

```yaml
.merge_logic:
  stage: merge
  image: sonar-ci:20260323
  script:
    - |
      echo "Checking MR status for !$CI_MERGE_REQUEST_IID..."

      MR_INFO=$(curl -s \
        --header "PRIVATE-TOKEN: $MERGE_TOKEN" \
        "$GITLAB_HOST/api/v4/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID")

      STATE=$(echo "$MR_INFO" | jq -r '.state')
      MERGE_STATUS=$(echo "$MR_INFO" | jq -r '.merge_status')

      if [ "$STATE" = "opened" ] && [ "$MERGE_STATUS" = "can_be_merged" ]; then
        echo "✅ 状态正常，执行合并..."
        curl -s --request PUT \
          --header "PRIVATE-TOKEN: $MERGE_TOKEN" \
          "$GITLAB_HOST/api/v4/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/merge"
      else
        echo "❌ MR 状态不可合并 (State: $STATE, Status: $MERGE_STATUS)"
        exit 1
      fi
```

#### 合并前置条件

| 字段 | 要求 |
|------|------|
| `state` | 必须为 `opened` |
| `merge_status` | 必须为 `can_be_merged` |

两个条件同时满足才会执行合并，否则流水线失败退出。

#### UAT vs Master 合并策略

| 场景 | 合并方式 | 配置 |
|------|---------|------|
| `merge-uat` | 自动 | 无特殊配置，extends .merge_logic 即可自动触发 |
| `merge-master` | 手动 | `when: manual` — 需 GitLab UI 点击 Play 按钮 |

---

### 3.4 自动 MR 评论说明

#### 对应流水线代码

**评论时机一：SonarQube 扫描完成后**

```yaml
    # ---- MR 评论：扫描结果 ----
    - |
      curl -s --request POST \
        --header "PRIVATE-TOKEN: $MERGE_TOKEN" \
        --header "Content-Type: application/json" \
        --data "{
          \"body\": \"SonarQube Quality Gate: $STATUS\\n\\n
          **新增问题统计（本次MR):**\\n
          - 新增 Bugs: $ISSUES_BUGS\\n
          - 新增 Vulnerabilities: $ISSUES_VULNS\\n
          - 新增 Code Smells: $ISSUES_SMELLS\\n\\n
          **质量评级:**\\n
          - 可靠性: $REL_LETTER\\n
          - 安全性: $SEC_LETTER\\n
          - 可维护性: $MAIN_LETTER\\n
          - 覆盖率: $COVERAGE%\\n\\n
          [查看 SonarQube 分析]($SONAR_LINK)\"}" \
        "$GITLAB_HOST/api/v4/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/notes"
```

**评论时机二：PDF 生成上传后**

```yaml
    # ---- MR 评论：PDF 链接 ----
    - |
      curl -s --request POST \
        --header "PRIVATE-TOKEN: $MERGE_TOKEN" \
        --header "Content-Type: application/json" \
        --data "{\"body\": \"## 📥 PDF 分析报告\\n\\n[📥 下载 PDF 报告]($MINIO_URL)\"}" \
        "$GITLAB_HOST/api/v4/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/notes"
```

#### 评论效果示意

```
SonarQube Quality Gate: OK

新增问题统计（本次MR）:
- 新增 Bugs: 2
- 新增 Vulnerabilities: 1
- 新增 Code Smells: 15

质量评级:
- 可靠性: A
- 安全性: B
- 可维护性: B
- 覆盖率: 65.3%

查看 SonarQube 分析

---

📥 PDF 分析报告
下载 PDF 报告
```

---

### 3.5 上传 MinIO 说明

#### 对应流水线代码

```yaml
    # ---- 7. 上传 MinIO ----
    - |
      mc alias set minio http://$MINIO_HOST $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
      mc mb minio/$MINIO_BUCKET --ignore-existing 2>/dev/null || true
      mc anonymous set download minio/$MINIO_BUCKET 2>/dev/null || true

      FILE_NAME="${CI_PROJECT_NAME}/$(date +%Y-%m-%d)/sonar-report-${CI_PROJECT_NAME}-mr${CI_MERGE_REQUEST_IID}.pdf"
      mc cp sonar-report.pdf minio/$MINIO_BUCKET/$FILE_NAME

      MINIO_URL="http://${MINIO_HOST}/${MINIO_BUCKET}/${FILE_NAME}"
      echo "MINIO_URL=$MINIO_URL" > minio-url.txt
      echo "PDF 上传成功: $MINIO_URL"
```

#### 存储路径规则

```
sonar-reports/
└── bike-server/                              ← 项目名
    └── 2026-04-09/                          ← 日期
        └── sonar-report-bike-server-mr42.pdf   ← MR编号
```

#### MinIO 连接配置

| 参数 | 值 |
|------|-----|
| Host | 192.168.0.180:9000 |
| Bucket | sonar-reports |
| 访问密钥 | `MINIO_ACCESS_KEY`（GitLab CI Variables） |
| 私密密钥 | `MINIO_SECRET_KEY`（GitLab CI Variables） |
| Bucket 权限 | `anonymous set download` — 公开下载，无需认证 |

---

## 四、关键变量说明

| 变量名 | 说明 | 来源 |
|--------|------|------|
| `SONAR_HOST` | SonarQube 地址 | 直接定义 |
| `GITLAB_HOST` | GitLab 地址 | 直接定义 |
| `MINIO_HOST` | MinIO 地址 | 直接定义 |
| `SONAR_PROJECT_MASTER` | Master 分支对应 SonarQube 项目 Key | 直接定义 |
| `SONAR_PROJECT_UAT` | UAT 分支对应 SonarQube 项目 Key | 直接定义 |
| `SONAR_MASTER` | Master 项目 Token | GitLab CI Variables |
| `SONAR_UAT` | UAT 项目 Token | GitLab CI Variables |
| `MERGE_TOKEN` | GitLab Merge 用 PAT（有 Merge 权限） | GitLab CI Variables |
| `MINIO_ACCESS_KEY` | MinIO 访问密钥 | GitLab CI Variables |
| `MINIO_SECRET_KEY` | MinIO 私密密钥 | GitLab CI Variables |
| `DINGTALK_WEBHOOK` | 钉钉自定义机器人 Webhook | GitLab CI Variables |

---

## 五、流水线完整执行流程

### 5.1 UAT 完整时序

```
1.  developer
    │
    │  创建/更新 MR：feature/login → uat
    ▼
2.  GitLab CI
    │  检测到 MR 目标分支 = uat
    │  自动调度 scan-uat
    ▼
3.  scan-uat [analysis stage]
    │
    ├─ 分支规则校验 (feature/hotfix?)
    ├─ SonarQube 增量扫描
    ├─ 获取质量指标
    ├─ 生成 PDF 报告
    ├─ 上传 MinIO
    ├─ MR 评论（扫描结果 + PDF链接）
    │
    ▼
4.  Quality Gate 判断
    │
    ├─ OK  →  钉钉成功通知  →  merge-uat 自动触发
    └─ ERROR →  钉钉失败通知  →  流水线终止
    ▼
5.  merge-uat [merge stage]
    │  检查 MR 状态（opened + can_be_merged）
    │  执行 PUT /merge
    ▼
6.  MR 合并完成
```

### 5.2 Master 流水线特殊性

| 对比项 | UAT | Master |
|--------|-----|--------|
| 合并触发 | 自动（scan 成功后立即） | 手动（GitLab UI 点击 Play） |
| scan job | scan-uat | scan-master |
| merge job | merge-uat | merge-master |
| 分支规则 | feature/ 或 hotfix/ | release/ |
| `when` 配置 |（默认 always） | `when: manual` |

---

## 六、钉钉通知说明

#### 对应流水线代码

```yaml
    # ---- 8. 钉钉通知 ----
    - |
      STATUS=$(cat quality-gate.txt)
      source quality-stats.txt
      source minio-url.txt 2>/dev/null || true

      if [ "$STATUS" != "OK" ]; then
        # 失败通知
        curl -s "$DINGTALK_WEBHOOK" \
          -H 'Content-Type: application/json' \
          -d '{
            "msgtype": "markdown",
            "markdown": {
              "title": "❌ MR 质量门未通过",
              "text": "## ❌ MR 质量门未通过\n\n**项目:** '"$CI_PROJECT_NAME"'\n\n**MR:** [!'"$CI_MERGE_REQUEST_IID"']...\n\n**质量门:** ❌ 未通过\n\n**PDF报告:** [点击下载]('"$MINIO_URL"')\n\n> 请修复问题后重新提交"
            }
          }'
        echo "Quality Gate 未通过，终止流程"
        exit 1
      else
        # 成功通知
        curl -s "$DINGTALK_WEBHOOK" \
          -H 'Content-Type: application/json' \
          -d '{
            "msgtype": "markdown",
            "markdown": {
              "title": "✅ MR 质量门通过",
              "text": "## ✅ MR 质量门通过\n\n**项目:** '"$CI_PROJECT_NAME"'\n\n**MR:** [!'"$CI_MERGE_REQUEST_IID"']...\n\n**质量门:** ✅ 通过\n\n**PDF报告:** [点击下载]('"$MINIO_URL"')\n\n> 质量达标，准备进入合并阶段"
            }
          }'
        echo "Quality Gate 通过，继续下一步"
      fi
```

---

## 七、artifacts 配置

```yaml
  artifacts:
    paths:
      - quality-gate.txt
      - sonar-report.pdf
    expire_in: 10 minutes    # ← 合并完成后及时下载
```

---

## 八、注意事项

1. **Token 保密**：所有 Token 存储在 GitLab CI Variables 中，流水线内通过环境变量引用
2. **质量门失败不合并**：即使 scan 成功，若质量门判定为 ERROR，`merge-uat` 不会执行
3. **PDF 临时文件**：artifacts 设置 10 分钟过期，合并完成后及时下载
4. **SonarQube Token**：每个项目（master/uat）有独立 Token，不可混用
5. **MinIO 公开访问**：设置了 anonymous download，需确认内网环境可访问

---

*文档生成时间：2026-04-09*
