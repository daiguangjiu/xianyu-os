#!/bin/bash
# V3 CloudStudio sandbox 保活脚本
# 由 launchd 每15分钟调用，ping V3 链接防止 sandbox 休眠

LOG="/tmp/keepalive_v3.log"
URLS=(
    "https://3000-30451e480cf6446b8bd5008f2562b852.e2b.ap-beijing.sandbox.cloudstudio.club/"
    "https://30451e480cf6446b8bd5008f2562b852.app.codebuddy.work/"
)

TS=$(date '+%Y-%m-%d %H:%M:%S')
for url in "${URLS[@]}"; do
    CODE=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 20 "$url" 2>/dev/null)
    echo "[$TS] $url -> HTTP $CODE" >> "$LOG"
done
# 日志超过 500 行时截断保留最后 200 行
LINES=$(wc -l < "$LOG" 2>/dev/null || echo 0)
if [ "$LINES" -gt 500 ]; then
    tail -200 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi
