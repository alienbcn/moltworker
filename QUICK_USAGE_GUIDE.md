# Quick Usage Guide

## 🚀 Running the Operational Checklist

### Step 1: Run the Main Verification Script

```bash
bash scripts/verify-operational-status.sh
```

**What happens:**
- ✅ Checks Telegram Bot configuration
- ✅ Validates CDP/Playwright setup
- ✅ Verifies email automation
- ✅ Generates `OPERATIONAL_CHECKLIST.md`

**Example Output:**

```
═══════════════════════════════════════════════════════════
           OPERATIONAL STATUS VERIFICATION                 
═══════════════════════════════════════════════════════════

📱 TELEGRAM BOT STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Token configured: 123456789:...
✓ Bot is valid and accessible
  Bot: @your_bot (Your Bot Name)
  ID: 123456789
  Checking for recent messages...
  Found recent chat ID: 987654321
  Sending confirmation message...
✓ Confirmation message sent successfully

🌐 PLAYWRIGHT/CDP SERVER STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ CDP_SECRET configured
✓ WORKER_URL: https://your-worker.workers.dev
  Testing local CDP endpoint (if running)...
  ℹ Local server not running (deploy to production to test)

📧 EMAIL AUTOMATION STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Email service configured
  Provider: MailerSend
  Target: carriertrafic@gmail.com

═══════════════════════════════════════════════════════════
                    SUMMARY                                
═══════════════════════════════════════════════════════════
✓ Telegram Bot: OPERATIONAL
✓ CDP/Playwright: CONFIGURED
✓ Email Automation: CONFIGURED

Report saved to: /tmp/OPERATIONAL_CHECKLIST.md
✓ Checklist copied to repository root
```

---

### Step 2: Review the Generated Checklist

```bash
cat OPERATIONAL_CHECKLIST.md
```

**Contains:**
- Component status (✅/⚠️/❌)
- Configuration details
- Test results
- Next action items
- Documentation links

---

### Step 3: Test Individual Components

#### Test Telegram Bot

```bash
bash scripts/send-telegram-test.sh
```

**Output:**
```
🤖 Telegram Bot Test Message Sender
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Token loaded
Fetching bot information...
✓ Bot: @your_bot (Your Bot Name)
Fetching recent messages to find chat ID...
✓ Found chat ID: 987654321
Sending test message to chat 987654321...
✓ Message sent successfully!
  Message ID: 12345
  Chat ID: 987654321
Check your Telegram chat with @your_bot to see the message.
```

#### Test CDP/Playwright Server

First, start the worker:
```bash
npm run start
```

In another terminal:
```bash
bash scripts/test-playwright-cdp.sh
```

**Output:**
```
🌐 Playwright/CDP Server Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Configuration loaded
  Worker URL: http://localhost:8787
  CDP Secret: test-cdp-s...

Test 1: Checking version endpoint...
✓ Version endpoint responding
{
  "Browser": "Chrome/120.0.6099.109",
  "Protocol-Version": "1.3",
  "User-Agent": "Mozilla/5.0...",
  "webSocketDebuggerUrl": "ws://localhost:8787/cdp/devtools/browser/..."
}

Test 2: Checking list endpoint...
✓ List endpoint responding
[]

Test 3: Testing new target creation...
✓ New target endpoint responding
{
  "targetId": "unique-target-id",
  "webSocketDebuggerUrl": "ws://localhost:8787/cdp/devtools/browser/..."
}

WebSocket URL for CDP connection:
  ws://localhost:8787/cdp/devtools/browser/unique-target-id

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ CDP Server is operational

You can now use browser automation with:
  node /root/clawd/skills/cloudflare-browser/scripts/screenshot.js https://example.com test.png
```

---

## 🎯 Common Scenarios

### Scenario 1: First-Time Setup

```bash
# 1. Clone repository
git clone https://github.com/alienbcn/moltworker.git
cd moltworker

# 2. Install dependencies
npm install

# 3. Create configuration
cp .dev.vars.example .dev.vars
nano .dev.vars  # Add your secrets

# 4. Run verification
bash scripts/verify-operational-status.sh

# 5. Review results
cat OPERATIONAL_CHECKLIST.md

# 6. Fix any issues and re-run
bash scripts/verify-operational-status.sh
```

### Scenario 2: Telegram Bot Setup

```bash
# 1. Get token from @BotFather in Telegram
# 2. Add to .dev.vars
echo "TELEGRAM_BOT_TOKEN=123456789:ABC..." >> .dev.vars

# 3. Verify configuration
bash scripts/verify-operational-status.sh

# 4. Send test message
bash scripts/send-telegram-test.sh

# 5. Check your Telegram app
# You should see a test message from your bot!
```

### Scenario 3: CDP/Playwright Setup

```bash
# 1. Generate secret
openssl rand -hex 32

# 2. Add to .dev.vars
echo "CDP_SECRET=your-generated-secret" >> .dev.vars
echo "WORKER_URL=http://localhost:8787" >> .dev.vars

# 3. Start worker
npm run start &

# 4. Test CDP server
bash scripts/test-playwright-cdp.sh

# 5. Use browser automation
node skills/cloudflare-browser/scripts/screenshot.js https://example.com test.png
```

### Scenario 4: Production Deployment

```bash
# 1. Set secrets (instead of .dev.vars)
wrangler secret put TELEGRAM_BOT_TOKEN
wrangler secret put CDP_SECRET
wrangler secret put WORKER_URL

# 2. Deploy
npm run deploy

# 3. Wait for deployment (1-2 minutes)

# 4. Test production
curl "https://your-worker.workers.dev/cdp/json/version?secret=YOUR_SECRET"

# 5. Check Telegram bot
# Send message to @your_bot
# Bot should respond
```

---

## 📊 Status Indicators

| Symbol | Meaning | Action |
|--------|---------|--------|
| ✅ | Operational | No action needed |
| ⚠️ | Not Configured | Follow setup instructions |
| ❌ | Error/Invalid | Fix configuration and retry |
| ℹ️ | Information | Additional context provided |

---

## 🔧 Troubleshooting

### Problem: "Token not found"

**Solution:**
```bash
# Check if .dev.vars exists
ls -la .dev.vars

# If not, create it
cp .dev.vars.example .dev.vars

# Add your token
echo "TELEGRAM_BOT_TOKEN=your-token" >> .dev.vars
```

### Problem: "CDP server not responding"

**Solution:**
```bash
# Make sure worker is running
npm run start

# In another terminal, test
curl http://localhost:8787/cdp/json/version?secret=YOUR_SECRET

# If still failing, check logs
npm run start 2>&1 | tee worker.log
```

### Problem: "No recent messages found"

**Solution:**
1. Open Telegram
2. Search for your bot (@your_bot_username)
3. Send any message: "hello"
4. Re-run test script
5. Or provide chat ID manually:
   ```bash
   bash scripts/send-telegram-test.sh YOUR_CHAT_ID
   ```

---

## 📚 Documentation Links

- [Main README](./README.md)
- [Scripts Documentation](./scripts/README.md)
- [Implementation Summary](./IMPLEMENTATION_SUMMARY.md)
- [Operational Checklist](./OPERATIONAL_CHECKLIST.md) (auto-generated)
- [Telegram Setup](./TELEGRAM_SETUP.md)
- [Browser Automation](./skills/cloudflare-browser/SKILL.md)

---

## 🎉 Success!

When all components are configured, you'll see:

```
═══════════════════════════════════════════════════════════
                    SUMMARY                                
═══════════════════════════════════════════════════════════
✓ Telegram Bot: OPERATIONAL
✓ CDP/Playwright: CONFIGURED
✓ Email Automation: CONFIGURED

✅ All components are configured and operational!
No immediate actions required. System is ready for production use.
```

Your Moltworker is now fully operational! 🚀
