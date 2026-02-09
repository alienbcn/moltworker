# Operational Verification Scripts

This directory contains scripts for verifying and testing the operational status of Moltworker components.

## Available Scripts

### 1. `verify-operational-status.sh`

**Main operational verification script** - Checks all major components and generates a comprehensive checklist.

```bash
bash scripts/verify-operational-status.sh
```

**What it checks:**
- ✅ Telegram Bot configuration and connectivity
- ✅ CDP/Playwright server configuration
- ✅ Email automation setup
- ✅ Generates `OPERATIONAL_CHECKLIST.md` in repository root

**Output:**
- Console report with color-coded status
- Markdown file: `OPERATIONAL_CHECKLIST.md`
- Actionable recommendations for any issues

---

### 2. `send-telegram-test.sh`

**Telegram bot test message sender** - Sends a test message to verify bot communication.

```bash
# Auto-detect chat ID from recent messages
bash scripts/send-telegram-test.sh

# Or specify chat ID directly
bash scripts/send-telegram-test.sh YOUR_CHAT_ID
```

**Prerequisites:**
- `TELEGRAM_BOT_TOKEN` set in `.dev.vars`
- At least one message sent to the bot (for auto-detection)

**What it does:**
1. Validates token with Telegram API
2. Fetches bot information
3. Gets chat ID from recent messages (or uses provided ID)
4. Sends formatted test message
5. Confirms delivery

---

### 3. `test-playwright-cdp.sh`

**CDP/Playwright server connectivity test** - Verifies browser automation endpoints.

```bash
bash scripts/test-playwright-cdp.sh
```

**Prerequisites:**
- `CDP_SECRET` set in `.dev.vars`
- `WORKER_URL` set in `.dev.vars` (defaults to `http://localhost:8787`)
- Worker running (`npm run start` for local testing)

**What it tests:**
1. `/cdp/json/version` - Browser version info
2. `/cdp/json/list` - List available targets
3. `/cdp/json/new` - Create new browser target
4. Extracts WebSocket URL for CDP connections

---

### 4. `check-telegram-detailed.sh`

**Detailed Telegram diagnostics** - Comprehensive debugging for Telegram bot issues.

```bash
bash scripts/check-telegram-detailed.sh
```

**What it checks:**
- Token validation
- Bot info from Telegram API
- Gateway process status
- Configuration file contents
- Recent logs
- Memory state

---

### 5. `send-system-report.sh`

**Automated system health reporter** - Sends hourly health reports via email.

```bash
bash scripts/send-system-report.sh
```

**Prerequisites:**
- `MAILER_SEND_API_KEY` or `SENDGRID_API_KEY` in `.dev.vars`
- `SYSTEM_REPORT_EMAIL` set (defaults to `carriertrafic@gmail.com`)

**What it reports:**
- CPU and memory usage
- Gateway health status
- Active sessions
- Recent errors
- Uptime and availability metrics

**Note:** This script is typically run by a cron job in the container, not manually.

---

## Quick Start

### Initial Setup Verification

1. **Run the main verification script:**
   ```bash
   bash scripts/verify-operational-status.sh
   ```

2. **Review the output** and follow recommendations in `OPERATIONAL_CHECKLIST.md`

3. **Configure missing components** as needed:
   - Telegram: Set `TELEGRAM_BOT_TOKEN`
   - CDP: Set `CDP_SECRET` and `WORKER_URL`
   - Email: Set `MAILER_SEND_API_KEY` and `SYSTEM_REPORT_EMAIL`

4. **Test each component:**
   ```bash
   # Test Telegram
   bash scripts/send-telegram-test.sh
   
   # Test CDP (requires worker running)
   npm run start  # in another terminal
   bash scripts/test-playwright-cdp.sh
   ```

---

## Configuration Files

All scripts read from `.dev.vars` for local development:

```bash
# Required for any functionality
ANTHROPIC_API_KEY=sk-ant-...
MOLTBOT_GATEWAY_TOKEN=your-token

# Telegram Bot
TELEGRAM_BOT_TOKEN=123456789:ABC...

# CDP/Browser Automation
CDP_SECRET=your-secret
WORKER_URL=https://your-worker.workers.dev

# Email Automation
MAILER_SEND_API_KEY=your-key
SYSTEM_REPORT_EMAIL=you@example.com
```

For production, use `wrangler secret put` instead of `.dev.vars`:

```bash
wrangler secret put TELEGRAM_BOT_TOKEN
wrangler secret put CDP_SECRET
wrangler secret put MAILER_SEND_API_KEY
```

---

## Troubleshooting

### Telegram Bot Not Responding

1. Run diagnostics:
   ```bash
   bash scripts/check-telegram-detailed.sh
   ```

2. Check token validity:
   ```bash
   curl "https://api.telegram.org/bot$TOKEN/getMe"
   ```

3. Verify gateway is running:
   ```bash
   ps aux | grep "openclaw gateway"
   curl http://localhost:18789/health
   ```

### CDP Server Not Accessible

1. Ensure worker is running:
   ```bash
   npm run start
   ```

2. Check CDP_SECRET matches:
   ```bash
   grep CDP_SECRET .dev.vars
   ```

3. Test endpoints manually:
   ```bash
   curl "http://localhost:8787/cdp/json/version?secret=YOUR_SECRET"
   ```

### Email Not Sending

1. Verify API key is set:
   ```bash
   grep MAILER_SEND_API_KEY .dev.vars
   ```

2. Test with manual run:
   ```bash
   bash scripts/send-system-report.sh
   ```

3. Check logs for errors:
   ```bash
   tail -f /root/openclaw-startup.log
   ```

---

## CI/CD Integration

These scripts can be integrated into your CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
- name: Verify Operational Status
  run: bash scripts/verify-operational-status.sh

- name: Upload Checklist
  uses: actions/upload-artifact@v3
  with:
    name: operational-checklist
    path: OPERATIONAL_CHECKLIST.md
```

---

## Security Notes

⚠️ **Never commit `.dev.vars`** - It contains sensitive API keys and tokens

- `.dev.vars` is in `.gitignore` by default
- Use `.dev.vars.example` as a template
- Production secrets should use `wrangler secret put`
- CDP_SECRET should be a strong random string: `openssl rand -hex 32`

---

## Support

For issues or questions:
- Check existing documentation: `README.md`, `AGENTS.md`
- Review logs: `wrangler tail` or `/root/openclaw-startup.log`
- Open an issue on GitHub

---

**Last Updated:** 2026-02-09
