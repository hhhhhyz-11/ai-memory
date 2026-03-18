# SonarQube Issues 批量导出方案

> 从 SonarQube 批量导出 Issues 到 CSV，支持超大量数据

## 背景

SonarQube 页面导出 PDF 超过 10000 条限制，需要导出更多 Issues

## 解决方案

### 1. 导出 Protobuf 格式

在 SonarQube 页面手动导出项目，选择 **Protobuf** 格式，会生成 `.zip` 文件

### 2. 使用转换工具

用户提供了 `SonarPbToCsvConverter` Java 代码

#### 2.1 克隆项目

```bash
git clone git@gitlab.example.com:test-tool.git
```

#### 2.2 Maven 打包

```bash
cd test-tool
mvn clean package -DskipTests
```

#### 2.3 下载依赖

需要 `commons-csv` 依赖

### 2.4 手动测试

成功转换 19874 条 Issues

## 完整流程

1. **SonarQube 页面**：手动导出项目（Protobuf 格式）→ 生成 `.zip`
2. **Jenkins Pipeline**：调用 shell 脚本
3. **Shell 脚本**：
   - 检测 zip 文件
   - 解压
   - 删除源文件
   - 转换为 CSV
   - 输出到 csv 目录
4. **Nginx**：搭建文件服务器，提供下载入口

## 最终效果

- Jenkins 选择项目 → 执行 → 输出下载链接
- 用户可直接下载 CSV 文件

## GitLab CI 调试经验

### 问题1：CI 分成两个 stage 导致 sonar 阶段没有 .class 文件

- **现象**：`build` + `sonar` 两个 stage，sonar 阶段报错找不到编译产物
- **解决**：换回单一 job，Maven 编译和 Sonar 分析一起执行

### 问题2：sonar-scanner-cli 扫描 Java 需要指定编译产物

- **解决**：添加 `-Dsonar.java.binaries=target/classes` 参数
- **优化**：
  - `-T 2C` 并行编译
  - `-Dmaven.test.skip=true` 跳过测试
  - `-Dsonar.exclusions` 排除目录

## 定时任务修复经验

### 问题：提示词写死日期

- **现象**：提示词写死"今天是2026-03-09"，导致每次都读3月9日
- **解决**：改为"读取昨天的日志"（因为0点执行应总结前一天）

### 经验

- 定时任务 payload 里的日期不能写死，要用动态描述
- 0点执行的任务应该读取"昨天"的日志
