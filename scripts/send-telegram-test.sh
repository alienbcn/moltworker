#!/bin/bash
# Send test message to Telegram Bot
# Usage: ./send-telegram-test.sh [chat_id]

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🤖 Telegram Bot Test Message Sender"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get token from .dev.vars
if [ ! -f .dev.vars ]; then
    echo -e "${RED}Error: .dev.vars file not found${NC}"
    echo "Create .dev.vars with TELEGRAM_BOT_TOKEN set"
    exit 1
fi

TELEGRAM_TOKEN=$(grep "^TELEGRAM_BOT_TOKEN=" .dev.vars | cut -d'=' -f2 | tr -d ' "'"'")

if [ -z "$TELEGRAM_TOKEN" ]; then
    echo -e "${RED}Error: TELEGRAM_BOT_TOKEN not found in .dev.vars${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Token loaded${NC}"

# Get bot info
echo "Fetching bot information..."
BOT_INFO=$(curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getMe")

if echo "$BOT_INFO" | grep -q '"ok":true'; then
    BOT_USERNAME=$(echo "$BOT_INFO" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
    BOT_NAME=$(echo "$BOT_INFO" | grep -o '"first_name":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✓ Bot: @$BOT_USERNAME ($BOT_NAME)${NC}"
else
    echo -e "${RED}✗ Invalid token${NC}"
    exit 1
fi

# Get chat ID
if [ -n "$1" ]; then
    CHAT_ID="$1"
    echo "Using provided chat ID: $CHAT_ID"
else
    echo ""
    echo "Fetching recent messages to find chat ID..."
    UPDATES=$(curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates?limit=5")
    
    if echo "$UPDATES" | grep -q '"chat"'; then
        CHAT_ID=$(echo "$UPDATES" | grep -o '"chat":{"id":[0-9-]*' | grep -o '[0-9-]*$' | head -1)
        echo -e "${GREEN}✓ Found chat ID: $CHAT_ID${NC}"
    else
        echo -e "${YELLOW}⚠ No recent messages found${NC}"
        echo ""
        echo "To get a chat ID:"
        echo "1. Send any message to @$BOT_USERNAME"
        echo "2. Run this script again"
        echo ""
        echo "Or provide chat ID directly:"
        echo "  ./send-telegram-test.sh YOUR_CHAT_ID"
        exit 1
    fi
fi

# Create test message
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
MESSAGE="✅ **Operational Checklist Complete**

**Status:** All systems verified
**Time:** $TIMESTAMP
**Bot:** @$BOT_USERNAME

This is an automated test message from the Moltworker operational verification script.

Components verified:
• Telegram Bot: ✅ Operational
• Message Sending: ✅ Working
• Bot API: ✅ Accessible

Your bot is correctly configured and ready for use!"

echo ""
echo "Sending test message to chat $CHAT_ID..."

# Send message
RESULT=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": $CHAT_ID,
        \"text\": $(echo "$MESSAGE" | jq -Rs .),
        \"parse_mode\": \"Markdown\"
    }")

if echo "$RESULT" | grep -q '"ok":true'; then
    MESSAGE_ID=$(echo "$RESULT" | grep -o '"message_id":[0-9]*' | cut -d':' -f2)
    echo -e "${GREEN}✓ Message sent successfully!${NC}"
    echo "  Message ID: $MESSAGE_ID"
    echo "  Chat ID: $CHAT_ID"
    echo ""
    echo "Check your Telegram chat with @$BOT_USERNAME to see the message."
else
    ERROR=$(echo "$RESULT" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
    echo -e "${RED}✗ Failed to send message${NC}"
    echo "  Error: $ERROR"
    echo ""
    echo "Possible issues:"
    echo "- Chat ID is incorrect"
    echo "- Bot doesn't have permission to send messages"
    echo "- You need to start a conversation with the bot first"
    exit 1
fi
