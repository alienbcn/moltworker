#!/bin/bash
# Test Playwright/CDP Server Connectivity
# Verifies that the CDP endpoint is accessible and working

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🌐 Playwright/CDP Server Test${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get configuration
if [ ! -f .dev.vars ]; then
    echo -e "${RED}Error: .dev.vars file not found${NC}"
    exit 1
fi

CDP_SECRET=$(grep "^CDP_SECRET=" .dev.vars | cut -d'=' -f2 | tr -d ' "'"'" || echo "")
WORKER_URL=$(grep "^WORKER_URL=" .dev.vars | cut -d'=' -f2 | tr -d ' "'"'" || echo "http://localhost:8787")

if [ -z "$CDP_SECRET" ]; then
    echo -e "${RED}Error: CDP_SECRET not configured in .dev.vars${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Configuration loaded${NC}"
echo "  Worker URL: $WORKER_URL"
echo "  CDP Secret: ${CDP_SECRET:0:10}..."
echo ""

# Test 1: Version endpoint
echo "Test 1: Checking version endpoint..."
VERSION_URL="${WORKER_URL}/cdp/json/version?secret=${CDP_SECRET}"

VERSION_RESULT=$(curl -s -m 10 "$VERSION_URL" 2>&1 || echo '{"error":"failed"}')

if echo "$VERSION_RESULT" | grep -q -i "browser\|protocol\|webSocketDebuggerUrl"; then
    echo -e "${GREEN}✓ Version endpoint responding${NC}"
    echo "$VERSION_RESULT" | jq '.' 2>/dev/null || echo "$VERSION_RESULT"
else
    echo -e "${YELLOW}⚠ Version endpoint not responding${NC}"
    echo "  URL: $VERSION_URL"
    echo "  Response: $VERSION_RESULT"
    echo ""
    echo "Possible issues:"
    echo "- Worker is not running (use 'npm run start' for local)"
    echo "- CDP_SECRET doesn't match"
    echo "- WORKER_URL is incorrect"
    echo ""
    echo "To test locally:"
    echo "  1. In one terminal: npm run start"
    echo "  2. In another: bash scripts/test-playwright-cdp.sh"
fi

echo ""

# Test 2: List endpoint
echo "Test 2: Checking list endpoint..."
LIST_URL="${WORKER_URL}/cdp/json/list?secret=${CDP_SECRET}"

LIST_RESULT=$(curl -s -m 10 "$LIST_URL" 2>&1 || echo '[]')

if [ "$LIST_RESULT" = "[]" ] || echo "$LIST_RESULT" | grep -q "targetId\|devtoolsFrontendUrl"; then
    echo -e "${GREEN}✓ List endpoint responding${NC}"
    echo "$LIST_RESULT" | jq '.' 2>/dev/null || echo "$LIST_RESULT"
else
    echo -e "${YELLOW}⚠ List endpoint not responding as expected${NC}"
    echo "  Response: $LIST_RESULT"
fi

echo ""

# Test 3: Create new target
echo "Test 3: Testing new target creation..."
NEW_URL="${WORKER_URL}/cdp/json/new?secret=${CDP_SECRET}"

NEW_RESULT=$(curl -s -m 10 "$NEW_URL" 2>&1 || echo '{"error":"failed"}')

if echo "$NEW_RESULT" | grep -q "targetId\|webSocketDebuggerUrl"; then
    echo -e "${GREEN}✓ New target endpoint responding${NC}"
    echo "$NEW_RESULT" | jq '.' 2>/dev/null || echo "$NEW_RESULT"
    
    # Extract WebSocket URL for reference
    WS_URL=$(echo "$NEW_RESULT" | grep -o '"webSocketDebuggerUrl":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$WS_URL" ]; then
        echo ""
        echo "WebSocket URL for CDP connection:"
        echo "  $WS_URL"
    fi
else
    echo -e "${YELLOW}⚠ New target endpoint not responding${NC}"
    echo "  Response: $NEW_RESULT"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if echo "$VERSION_RESULT" | grep -q -i "browser"; then
    echo -e "${GREEN}✅ CDP Server is operational${NC}"
    echo ""
    echo "You can now use browser automation with:"
    echo ""
    echo "  node /root/clawd/skills/cloudflare-browser/scripts/screenshot.js https://example.com test.png"
    echo ""
    echo "Or connect via Playwright/Puppeteer using the WebSocket URL above."
else
    echo -e "${YELLOW}⚠️ CDP Server is not responding${NC}"
    echo ""
    echo "To fix:"
    echo "1. Ensure worker is running: npm run start"
    echo "2. Check CDP_SECRET is correct"
    echo "3. Verify WORKER_URL points to your worker"
    echo "4. For production, deploy first: npm run deploy"
fi
