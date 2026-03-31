# 从零搭建 OpenClaw 指南

> 详细记录从零开始搭建 OpenClaw 的完整步骤，包含所有命令和配置


## 环境准备

### 1. 检查 Node.js 版本

OpenClaw 需要 **Node 22.16+**（推荐 Node 24）

```bash
node -v
```

如果版本太低或未安装，继续下一步。

### 2. 安装 Node.js

**Ubuntu / Debian:**
```bash
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**macOS (Homebrew):**
```bash
brew install node
```

**Windows (PowerShell):**
```powershell
winget install OpenJS.NodeJS.LTS
```

**或使用版本管理器 (fnm):**
```bash
# 安装 fnm
curl -fsSL https://fnm.install | bash

# 初始化 fnm（添加到 ~/.zshrc 或 ~/.bashrc）
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env)"

# 安装 Node 24
fnm install 24
fnm use 24
```


## 安装 OpenClaw

### 方法一：Installer 脚本（推荐）

**macOS / Linux / WSL2:**
```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

安装脚本会自动：
- 检测/安装 Node.js
- 安装 openclaw CLI
- 启动 onboarding 向导

### 方法二：npm 全局安装

```bash
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

**pnpm 方式:**
```bash
pnpm add -g openclaw@latest
pnpm approve-builds -g  # 批准构建脚本
openclaw onboard --install-daemon
```

### 方法三：从源码安装

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
pnpm install
pnpm ui:build
pnpm build
pnpm link --global
openclaw onboard --install-daemon
```


## 首次启动配置

### 1. 检查安装

```bash
openclaw doctor     # 检查配置问题
openclaw status     # 查看 gateway 状态
```

### 2. 启动 onboarding 向导

```bash
openclaw onboard
```

会提示设置：
- 工作空间路径
- 通道配置（Telegram/Discord/WhatsApp 等）
- 模型配置

### 3. 手动配置文件

配置文件位置：`~/.openclaw/openclaw.json`

**最小配置示例：**
```json5
{
agents: { defaults: { workspace: "~/.openclaw/workspace" } },
channels: {
telegram: {
enabled: true,
botToken: "YOUR_BOT_TOKEN",
dmPolicy: "pairing"
}
}
}
```


## 配置通道

### Telegram

1. @BotFather 创建机器人，获取 botToken
2. 配置：
```json5
{
channels: {
telegram: {
enabled: true,
botToken: "123456789:ABCdefGHIjklMNOpqrsTUVwxyz",
dmPolicy: "pairing",
groupPolicy: "allowlist",
groupAllowFrom: ["-100123456789"]
}
}
}
```

### Discord

1. Discord Developer Portal 创建应用 → Bot
2. 获取 botToken，开启 Message Content Intent
3. 配置：
```json5
{
channels: {
discord: {
enabled: true,
botToken: "YOUR_DISCORD_BOT_TOKEN",
dmPolicy: "pairing"
}
}
}
```

### WhatsApp

```json5
{
channels: {
whatsapp: {
enabled: true,
phoneNumberId: "YOUR_PHONE_NUMBER_ID",
accessToken: "YOUR_ACCESS_TOKEN",
webhookVerifyToken: "YOUR_VERIFY_TOKEN",
dmPolicy: "pairing"
}
}
}
```

### Webchat（内置）

```json5
{
channels: {
webchat: {
enabled: true,
allowFrom: ["*"]
}
}
}
```


## 配置管理命令

```bash
# 查看配置
openclaw config get agents.defaults.workspace

# 设置配置
openclaw config set agents.defaults.heartbeat.every "2h"

# 删除配置
openclaw config unset tools.web.search.apiKey

# 直接编辑
nano ~/.openclaw/openclaw.json
```

配置文件修改后自动热加载。


## 节点配对（Node）

### 1. 在目标机器安装 Node

```bash
# 方式一：installer 脚本
curl -fsSL https://openclaw.ai/install.sh | bash

# 方式二：npm
npm install -g openclaw@latest
```

### 2. 设置环境变量

```bash
# 生成 token
export OPENCLAW_GATEWAY_TOKEN="your-secure-token-here"

# 允许外部 ws 连接（可选）
export OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1
```

### 3. 启动节点配对

**节点端：**
```bash
openclaw node pair --gateway-url "ws://YOUR_GATEWAY_IP:18789"
```

**Gateway 端：**
```bash
# 查看配对请求
openclaw devices list

# 批准配对
openclaw devices approve <requestId>
```


## 常用命令汇总

```bash
# 状态
openclaw status       # gateway 状态
openclaw health       # 健康检查
openclaw doctor       # 诊断问题

# 设备/节点
openclaw devices list    # 列出配对设备
openclaw devices approve <id> # 批准设备
openclaw nodes status    # 节点状态

# 配置
openclaw onboard       # 向导配置
openclaw configure      # 配置向导
openclaw config get <path>  # 获取配置
openclaw config set <path> <value> # 设置配置

# 日志
openclaw logs        # 查看日志
openclaw logs --tail 100   # 最后100行

# Gateway
openclaw gateway restart   # 重启 gateway
openclaw dashboard      # 打开浏览器 UI

# 定时任务
openclaw cron list      # 列出任务
openclaw cron add       # 添加任务
openclaw cron run <jobId>   # 手动执行任务
```


## 访问地址

- **Control UI**: http://127.0.0.1:18789
- **Webchat**: http://127.0.0.1:18789/webchat


## 环境变量（可选）

| 变量 | 说明 |
|------|------|
| `OPENCLAW_HOME` | OpenClaw 主目录 |
| `OPENCLAW_STATE_DIR` | 状态目录 |
| `OPENCLAW_CONFIG_PATH` | 配置文件路径 |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway 认证 token |
| `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS` | 允许外部 ws 连接 |


## 常见问题

### `openclaw: command not found`

```bash
# 1. 查找 npm 全局路径
npm prefix -g

# 2. 添加到 PATH
export PATH="$(npm prefix -g)/bin:$PATH"

# 3. 写入 shell 配置
echo 'export PATH="$(npm prefix -g)/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### 配置错误导致无法启动

```bash
# 诊断问题
openclaw doctor

# 修复（自动修复）
openclaw doctor --fix

# 使用默认配置恢复
cp ~/.openclaw/openclaw.json.bak ~/.openclaw/openclaw.json
```


*文档创建: 2026-03-20*
