#!/bin/bash
# 钉钉周报推送脚本
# 读取本周每日日志，汇总发送

# ========== 配置区域 ==========
WEBHOOK_URL="https://oapi.dingtalk.com/robot/send?access_token=bf7c95320e0767168d3ad50bc3c5f354a0d40927b02c045286897a74e4c007a2"
LOG_DIR="/root/.openclaw/workspace/daily-log"
# ==================================

# 获取本周一到今天的日期
START_OF_WEEK=$(date -d "last monday" "+%Y-%m-%d")
TODAY=$(date "+%Y-%m-%d")

# 收集本周所有日志
WEEK_CONTENT=""
CURRENT_DATE="$START_OF_WEEK"
while [ "$CURRENT_DATE" != "$TODAY" ]; do
    LOG_FILE="$LOG_DIR/$CURRENT_DATE.md"
    if [ -f "$LOG_FILE" ]; then
        CONTENT=$(cat "$LOG_FILE" | sed 's/^/> /')
        WEEK_CONTENT="$WEEK_CONTENT\n$CURRENT_DATE\n$CONTENT\n"
    fi
    CURRENT_DATE=$(date -d "$CURRENT_DATE + 1 day" "+%Y-%m-%d")
done

# 今天的日志
TODAY_LOG="$LOG_DIR/$TODAY.md"
if [ -f "$TODAY_LOG" ]; then
    CONTENT=$(cat "$TODAY_LOG" | sed 's/^/> /')
    WEEK_CONTENT="$WEEK_CONTENT\n$TODAY\n$CONTENT\n"
fi

# 格式化周报
WEEK_REPORT="【周报】$(date -d "last monday" "+%Y-%m-%d") ~ $(date "+%Y-%m-%d")

一、本周工作总结:

1.【项目实施】
●

2.【运维需求】
●

3.【运维需求】
●

4.【故障处理】
●

二、下周工作计划:

问题与建议:
"

# 发送消息
curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"$WEEK_REPORT\"}}"

echo "周报已发送: $(date)"
