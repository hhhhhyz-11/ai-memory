#!/bin/bash
# 钉钉月报推送脚本
# 读取本月每日日志，汇总发送
# 仅在每月倒数第2天执行

# ========== 配置区域 ==========
WEBHOOK_URL="https://oapi.dingtalk.com/robot/send?access_token=bf7c95320e0767168d3ad50bc3c5f354a0d40927b02c045286897a74e4c007a2"
LOG_DIR="/root/.openclaw/workspace/daily-log"
# ==================================

# 检查是否是倒数第2天（后天是1号）
DAY_AFTER_TOMORROW=$(date -d "+2 days" "+%d")
if [ "$DAY_AFTER_TOMORROW" != "01" ]; then
    echo "今天不是月末，无需发送月报"
    exit 0
fi

# 获取本月第一天
FIRST_DAY=$(date "+%Y-%m-01")
TODAY=$(date "+%Y-%m-%d")

# 收集本月所有日志
MONTH_CONTENT=""
CURRENT_DATE="$FIRST_DAY"
while [ "$CURRENT_DATE" != "$TODAY" ]; do
    LOG_FILE="$LOG_DIR/$CURRENT_DATE.md"
    if [ -f "$LOG_FILE" ]; then
        CONTENT=$(cat "$LOG_FILE" | sed 's/^/> /')
        MONTH_CONTENT="$MONTH_CONTENT\n$CURRENT_DATE\n$CONTENT\n"
    fi
    CURRENT_DATE=$(date -d "$CURRENT_DATE + 1 day" "+%Y-%m-%d")
done

# 今天的日志
TODAY_LOG="$LOG_DIR/$TODAY.md"
if [ -f "$TODAY_LOG" ]; then
    CONTENT=$(cat "$TODAY_LOG" | sed 's/^/> /')
    MONTH_CONTENT="$MONTH_CONTENT\n$TODAY\n$CONTENT\n"
fi

# 获取本月名称
MONTH_NAME=$(date "+%Y年%m月")

# 格式化月报
MONTH_REPORT="【月报】$MONTH_NAME

运维月报

本月关键工作:
●

关键工作实现节点:
●

未完成工作原因:
●
"

# 发送消息
curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"$MONTH_REPORT\"}}"

echo "月报已发送: $(date)"
