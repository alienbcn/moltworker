#!/bin/bash
# Cloudflare Worker Deployment Verification Script
# Usage: ./verify-deployment.sh

set -e

WORKER_NAME="moltbot-sandbox"

echo "🔍 Cloudflare Worker Deployment Verification"
echo "============================================="
echo ""

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
    echo "❌ wrangler CLI not found. Install with: npm install -g wrangler"
    exit 1
fi

echo "✅ wrangler CLI found"
echo ""

# Check secrets
echo "📋 Checking secrets configuration..."
echo "-----------------------------------"
wrangler secret list 2>&1 | head -20

echo ""
echo "⚠️  IMPORTANT: Verify these secrets exist:"
echo "  1. ANTHROPIC_API_KEY (or OPENAI_API_KEY)"
echo "  2. TELEGRAM_BOT_TOKEN"
echo ""

# Check if we can tail logs
echo "📡 Attempting to tail worker logs..."
echo "-----------------------------------"
echo "Press Ctrl+C to stop after 10 seconds"
echo ""

timeout 10 wrangler tail --format pretty 2>&1 || true

echo ""
echo "✅ Verification complete!"
echo ""
echo "🔧 Next steps if bot not responding:"
echo "  1. Verify ANTHROPIC_API_KEY in Cloudflare Dashboard"
echo "  2. Send test message to bot: @your_bot"
echo "  3. Check logs above for errors"
echo "  4. If needed, add DEBUG_ROUTES=true and visit /debug/health"
