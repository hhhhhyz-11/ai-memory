#!/bin/bash
# 钉钉日报推送脚本
# 读取 daily-log 中的日志，格式化后发送

# ========== 配置区域 ==========
WEBHOOK_URL="https://oapi.dingtalk.com/robot/send?access_token=bf7c95320e0767168d3ad50bc3c5f354a0d40927b02c045286897a74e4c007a2"
LOG_DIR="/root/.openclaw/workspace/daily-log"
# ==================================

# 获取昨天的日期（日报发的是昨天的工作）
YESTERDAY=$(date -d "yesterday" "+%Y-%m-%d")
LOG_FILE="$LOG_DIR/$YESTERDAY.md"

# 如果昨天没有日志，用今天的
if [ ! -f "$LOG_FILE" ]; then
    TODAY=$(date "+%Y-%m-%d")
    LOG_FILE="$LOG_DIR/$TODAY.md"
fi

# 检查日志文件是否存在
if [ ! -f "$LOG_FILE" ]; then
    MESSAGE="【日报】$(date "+%Y-%m-%d") ($WEEKDAY)

📌 今日完成工作
（暂无记录）

🔄 未完成工作
-

⚠️ 需协调工作
-

📝 备注
-"
else
    # 读取日志内容
    CONTENT=$(cat "$LOG_FILE")
    
    # 提取各区块内容
    AI_DONE=$(sed -n '/## 🤖 AI 协助完成/,/##/p' "$LOG_FILE" | sed '1d' | sed '/^##/d' | sed '/^$/d' | sed 's/^- /• /')
    SYS_ACT=$(sed -n '/## 📊 系统活动/,/##/p' "$LOG_FILE" | sed '1d' | sed '/^##/d' | sed '/^$/d' | sed 's/^- /• /')
    TASKS=$(sed -n '/## ⏰ 定时任务/,/##/p' "$LOG_FILE" | sed '1d' | sed '/^##/d' | sed '/^$/d' | sed 's/^- /• /')
    NOTES=$(sed -n '/## 📝 备注/,/##/p' "$LOG_FILE" | sed '1d' | sed '/^##/d' | sed '/^$/d' | sed 's/^- /• /')
    
    # 格式化日报
    MESSAGE="【日报】$(date "+%Y-%m-%d") ($(date "+%A"))

📌 今日完成工作
${AI_DONE:-（暂无记录）}

🔄 未完成工作
${SYS_ACT:--}

⚠️ 需协调工作
${TASKS:--}

📝 备注
${NOTES:--}"
fi

# 发送消息
curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"$MESSAGE\"}}"

echo "日报已发送: $(date)"
