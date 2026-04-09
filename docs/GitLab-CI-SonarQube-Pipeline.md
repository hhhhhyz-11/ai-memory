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
│     - mvn clean verify sonar:sonar       │
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
│     - 路径: 项目名/日期/sonar-report-xxx  │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  6. MR 评论                               │
│     - 质量门状态 / 问题统计 / 评级        │
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
    │ 状态 = OK？             │
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
│  - PUT /merge 合并        │
└────────┬────────────────┘
         │
         ▼
   MR 合并完成 ✅
```

### 2.2 Master 流水线（半自动模式）

```
开发者发起 PR (release/xxx → master)
         │
         ▼
┌─────────────────────────┐
│    GitLab CI 触发       │
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
│  - 点击 "Play" 按钮      │
│  - 检查 MR 状态           │
│  - PUT /merge 合并        │
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

```
SOURCE = feature/login-page
TARGET = uat
 → ✅ 通过

SOURCE = fix-bug
TARGET = uat
 → ❌ 退出，不允许合并至 uat
```

#### SonarQube 扫描参数

| 参数 | 说明 |
|------|------|
| `sonar.projectKey` | uat 对应 `bike-server-uat`，master 对应 `bike-server-master` |
| `sonar.pullrequest.key` | MR 的 IID |
| `sonar.pullrequest.branch` | 源分支名 |
| `sonar.pullrequest.base` | 目标分支名 |
| `sonar.qualitygate.wait=true` | 阻塞等待质量门结果 |

> **关键**：增量扫描通过 `pullRequest` 参数实现，SonarQube 会自动对比源分支与目标分支的差异代码。

---

### 3.2 获取指标说明

扫描完成后，通过 SonarQube REST API 拉取以下数据：

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

#### PDF 报告渲染

- 使用 **Python Jinja2** 模板 + **WeasyPrint** 生成 PDF
- 包含：质量门状态、问题统计、Bug 详情（前10条）、漏洞详情（前10条）、异味详情（前20条）
- 字体：`Noto Sans CJK SC`（思源黑体）

---

### 3.3 自动合并说明（.merge_logic）

#### 合并前置条件

```bash
MR 状态检查 API: GET /api/v4/projects/:id/merge_requests/:iid
```

| 字段 | 要求 |
|------|------|
| `state` | 必须为 `opened` |
| `merge_status` | 必须为 `can_be_merged` |

两个条件同时满足才会执行合并，否则流水线失败。

#### 合并 API

```bash
PUT /api/v4/projects/:id/merge_requests/:iid/merge
```

#### UAT vs Master 合并策略

| 场景 | 合并方式 | 说明 |
|------|---------|------|
| `merge-uat` | 自动 | scan-uat 成功后自动触发 |
| `merge-master` | 手动 | 需 GitLab UI 点击 "Play" 按钮 |

> **注意**：`merge-master` 设置了 `when: manual`，即使 scan-master 成功也不会自动合并，需负责人确认后手动触发。

---

### 3.4 自动 MR 评论说明

流水线在两个时机自动评论 MR：

#### 时机一：SonarQube 扫描完成后

评论内容包含：
- 质量门状态（✅通过 / ❌未通过）
- 新增问题统计（Bugs / Vulnerabilities / Code Smells）
- 质量评级（可靠性 A/B/C... / 安全性 / 可维护性）
- 覆盖率百分比
- SonarQube 分析页面链接

#### 时机二：PDF 生成上传后

评论内容：
- PDF 下载链接（MinIO 地址）

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

#### MinIO 连接配置

| 参数 | 值 |
|------|-----|
| Host | 192.168.0.180:9000 |
| Bucket | sonar-reports |
| 访问密钥 | `MINIO_ACCESS_KEY`（CI Variables） |
| 私密密钥 | `MINIO_SECRET_KEY`（CI Variables） |

#### 文件存储路径规则

```
sonar-reports/
└── bike-server/                      ← 项目名
    └── 2026-04-09/                  ← 日期
        └── sonar-report-bike-server-mr42.pdf   ← MR编号
```

#### Bucket 权限

- `mc anonymous set download`：公开下载权限（无需认证即可访问链接）

#### 钉钉通知

PDF 链接会附加在钉钉通知消息中，方便直接在钉钉里点击下载。

---

## 四、关键变量说明

| 变量名 | 说明 |
|--------|------|
| `SONAR_HOST` | SonarQube 地址 |
| `GITLAB_HOST` | GitLab 地址 |
| `MINIO_HOST` | MinIO 地址 |
| `SONAR_PROJECT_MASTER` | Master 分支对应项目 Key |
| `SONAR_PROJECT_UAT` | UAT 分支对应项目 Key |
| `SONAR_MASTER` | Master 项目 Token（SonarQube） |
| `SONAR_UAT` | UAT 项目 Token（SonarQube） |
| `MERGE_TOKEN` | GitLab 合并用 Personal Access Token |
| `MINIO_ACCESS_KEY` | MinIO 访问密钥 |
| `MINIO_SECRET_KEY` | MinIO 私密密钥 |
| `DINGTALK_WEBHOOK` | 钉钉自定义机器人 Webhook |

---

## 五、流水线完整执行流程

### 5.1 完整时序（以 MR 合并至 UAT 为例）

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
    ├─ 分支规则校验（feature/hotfix?）
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

### 5.2 Master 分支特殊性

| 对比项 | UAT | Master |
|--------|-----|--------|
| 合并触发 | 自动（scan 成功后立即） | 手动（点击 Play 按钮） |
| scan job | scan-uat | scan-master |
| merge job | merge-uat | merge-master |
| 分支规则 | feature/ 或 hotfix/ | release/ |

---

## 六、注意事项

1. **Token 保密**：所有 Token 均存储在 GitLab CI Variables 中，流水线内不可见
2. **质量门失败不合并**：即使 scan 成功，若质量门判定为 ERROR，`merge-uat` 不会执行
3. **PDF 临时文件**：artifacts 设置 10 分钟过期，合并完成后及时下载
4. **SonarQube Token**：每个项目（master/uat）有独立 Token，不可混用
5. **MinIO 公开访问**：设置了 anonymous download，需确认内网环境可访问

---

*文档生成时间：2026-04-09*
