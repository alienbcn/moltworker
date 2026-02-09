# Agent Instructions

Guidelines for AI agents working on this codebase.

## Project Overview

This is a Cloudflare Worker that runs [OpenClaw](https://github.com/openclaw/openclaw) (formerly Moltbot/Clawdbot) in a Cloudflare Sandbox container. It provides:
- Proxying to the OpenClaw gateway (web UI + WebSocket)
- Admin UI at `/_admin/` for device management
- API endpoints at `/api/*` for device pairing
- Debug endpoints at `/debug/*` for troubleshooting

**Note:** The CLI tool and npm package are now named `openclaw`. Config files use `.openclaw/openclaw.json`. Legacy `.clawdbot` paths are supported for backward compatibility during transition.

## Project Structure

```
src/
├── index.ts          # Main Hono app, route mounting
├── types.ts          # TypeScript type definitions
├── config.ts         # Constants (ports, timeouts, paths)
├── auth/             # Cloudflare Access authentication
│   ├── jwt.ts        # JWT verification
│   ├── jwks.ts       # JWKS fetching and caching
│   └── middleware.ts # Hono middleware for auth
├── gateway/          # OpenClaw gateway management
│   ├── process.ts    # Process lifecycle (find, start)
│   ├── env.ts        # Environment variable building
│   ├── r2.ts         # R2 bucket mounting
│   ├── sync.ts       # R2 backup sync logic
│   └── utils.ts      # Shared utilities (waitForProcess)
├── routes/           # API route handlers
│   ├── api.ts        # /api/* endpoints (devices, gateway)
│   ├── admin.ts      # /_admin/* static file serving
│   └── debug.ts      # /debug/* endpoints
└── client/           # React admin UI (Vite)
    ├── App.tsx
    ├── api.ts        # API client
    └── pages/
```

## Key Patterns

### Lazy Loading Heavy Dependencies

To avoid exceeding Cloudflare Worker CPU limits during initialization, heavy dependencies should be lazy-loaded:

- **Implementation**: Use dynamic `import()` to defer loading until needed
- **Pattern**: Create separate route modules and import them only when needed

**Pattern for adding new heavy dependencies:**
```typescript
// ❌ BAD: Loads at Worker startup
import { heavyLibrary } from 'heavy-library';
export const myRoute = new Hono();
myRoute.get('/', (c) => heavyLibrary.doWork());

// ✅ GOOD: Lazy-loaded when route is accessed, with caching
// In routes/my-route.ts (this file won't load until getMyRoute() is called):
import { Hono } from 'hono';
import { heavyLibrary } from 'heavy-library';  // Safe: only loads when this module loads

const myRoute = new Hono();
myRoute.get('/', (c) => heavyLibrary.doWork());
export { myRoute };

// In routes/index.ts:
export async function getMyRoute() {
  const { myRoute } = await import('./my-route');  // Dynamic import defers loading
  return myRoute;
}

// In index.ts (main app file):
let myRouteCache: Awaited<ReturnType<typeof getMyRoute>> | null = null;
async function handleMyRouteRequest(c: Context<AppEnv>) {
  if (!myRouteCache) {
    myRouteCache = await getMyRoute();  // Heavy library only loads here, on first request
  }
  return myRouteCache.fetch(c.req.raw, c.env, c.executionCtx);
}
app.all('/my-route', handleMyRouteRequest);
app.all('/my-route/*', handleMyRouteRequest);
```

### Environment Variables

- `DEV_MODE` - Skips CF Access auth AND bypasses device pairing (maps to `OPENCLAW_DEV_MODE` for container)
- `DEBUG_ROUTES` - Enables `/debug/*` routes (disabled by default)
- See `src/types.ts` for full `MoltbotEnv` interface

### CLI Commands

When calling the OpenClaw CLI from the worker, always include `--url ws://localhost:18789`:
```typescript
sandbox.startProcess('openclaw devices list --json --url ws://localhost:18789')
```

CLI commands take 10-15 seconds due to WebSocket connection overhead. Use `waitForProcess()` helper in `src/routes/api.ts`.

### Success Detection

The CLI outputs "Approved" (capital A). Use case-insensitive checks:
```typescript
stdout.toLowerCase().includes('approved')
```

## Commands

```bash
npm test              # Run tests (vitest)
npm run test:watch    # Run tests in watch mode
npm run build         # Build worker + client
npm run deploy        # Build and deploy to Cloudflare
npm run dev           # Vite dev server
npm run start         # wrangler dev (local worker)
npm run typecheck     # TypeScript check
```

## Testing

Tests use Vitest. Test files are colocated with source files (`*.test.ts`).

Current test coverage:
- `auth/jwt.test.ts` - JWT decoding and validation
- `auth/jwks.test.ts` - JWKS fetching and caching
- `auth/middleware.test.ts` - Auth middleware behavior
- `gateway/env.test.ts` - Environment variable building
- `gateway/process.test.ts` - Process finding logic
- `gateway/r2.test.ts` - R2 mounting logic
- `gateway/sync.test.ts` - R2 backup sync logic

When adding new functionality, add corresponding tests.

## Code Style

- Use TypeScript strict mode
- Prefer explicit types over inference for function signatures
- Keep route handlers thin - extract logic to separate modules
- Use Hono's context methods (`c.json()`, `c.html()`) for responses

## Documentation

- `README.md` - User-facing documentation (setup, configuration, usage)
- `AGENTS.md` - This file, for AI agents

Development documentation goes in AGENTS.md, not README.md.

---

## Architecture

```
Browser
   │
   ▼
┌─────────────────────────────────────┐
│     Cloudflare Worker (index.ts)    │
│  - Starts OpenClaw in sandbox       │
│  - Proxies HTTP/WebSocket requests  │
│  - Passes secrets as env vars       │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│     Cloudflare Sandbox Container    │
│  ┌───────────────────────────────┐  │
│  │     OpenClaw Gateway          │  │
│  │  - Control UI on port 18789   │  │
│  │  - WebSocket RPC protocol     │  │
│  │  - Agent runtime              │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Key Files

| File | Purpose |
|------|---------|
| `src/index.ts` | Worker that manages sandbox lifecycle and proxies requests |
| `Dockerfile` | Container image based on `cloudflare/sandbox` with Node 22 + OpenClaw |
| `start-openclaw.sh` | Startup script: R2 restore → onboard → config patch → launch gateway |
| `wrangler.jsonc` | Cloudflare Worker + Container configuration |

## Local Development

```bash
npm install
cp .dev.vars.example .dev.vars
# Edit .dev.vars with your ANTHROPIC_API_KEY
npm run start
```

### Environment Variables

For local development, create `.dev.vars`:

```bash
ANTHROPIC_API_KEY=sk-ant-...
DEV_MODE=true           # Skips CF Access auth + device pairing
DEBUG_ROUTES=true       # Enables /debug/* routes
```

### WebSocket Limitations

Local development with `wrangler dev` has issues proxying WebSocket connections through the sandbox. HTTP requests work but WebSocket connections may fail. Deploy to Cloudflare for full functionality.

## Docker Image Caching

The Dockerfile includes a cache bust comment. When changing `start-openclaw.sh`, bump the version:

```dockerfile
# Build cache bust: 2026-02-06-v28-openclaw-upgrade
```

## Gateway Configuration

OpenClaw configuration is built at container startup:

1. R2 backup is restored if available (with migration from legacy `.clawdbot` paths)
2. If no config exists, `openclaw onboard --non-interactive` creates one based on env vars
3. `start-openclaw.sh` patches the config for channels, gateway auth, and trusted proxies
4. Gateway starts with `openclaw gateway --allow-unconfigured --bind lan`

### AI Provider Priority

The startup script selects the auth choice based on which env vars are set:

1. **Cloudflare AI Gateway** (native): `CLOUDFLARE_AI_GATEWAY_API_KEY` + `CF_AI_GATEWAY_ACCOUNT_ID` + `CF_AI_GATEWAY_GATEWAY_ID`
2. **Direct Anthropic**: `ANTHROPIC_API_KEY` (optionally with `ANTHROPIC_BASE_URL`)
3. **Direct OpenAI**: `OPENAI_API_KEY`
4. **Legacy AI Gateway**: `AI_GATEWAY_API_KEY` + `AI_GATEWAY_BASE_URL` (routes through Anthropic base URL)

### Container Environment Variables

These are the env vars passed TO the container (internal names):

| Variable | Config Path | Notes |
|----------|-------------|-------|
| `ANTHROPIC_API_KEY` | (env var) | OpenClaw reads directly from env |
| `OPENAI_API_KEY` | (env var) | OpenClaw reads directly from env |
| `CLOUDFLARE_AI_GATEWAY_API_KEY` | (env var) | Native AI Gateway key |
| `CF_AI_GATEWAY_ACCOUNT_ID` | (env var) | Account ID for AI Gateway |
| `CF_AI_GATEWAY_GATEWAY_ID` | (env var) | Gateway ID for AI Gateway |
| `OPENCLAW_GATEWAY_TOKEN` | `--token` flag | Mapped from `MOLTBOT_GATEWAY_TOKEN` |
| `OPENCLAW_DEV_MODE` | `controlUi.allowInsecureAuth` | Mapped from `DEV_MODE` |
| `TELEGRAM_BOT_TOKEN` | `channels.telegram.botToken` | |
| `DISCORD_BOT_TOKEN` | `channels.discord.token` | |
| `SLACK_BOT_TOKEN` | `channels.slack.botToken` | |
| `SLACK_APP_TOKEN` | `channels.slack.appToken` | |

## OpenClaw Config Schema

OpenClaw has strict config validation. Common gotchas:

- `agents.defaults.model` must be `{ "primary": "model/name" }` not a string
- `gateway.mode` must be `"local"` for headless operation
- No `webchat` channel - the Control UI is served automatically
- `gateway.bind` is not a config option - use `--bind` CLI flag

See [OpenClaw docs](https://docs.openclaw.ai/) for full schema.

## Common Tasks

### Adding a New API Endpoint

1. Add route handler in `src/routes/api.ts`
2. Add types if needed in `src/types.ts`
3. Update client API in `src/client/api.ts` if frontend needs it
4. Add tests

### Adding a New Environment Variable

1. Add to `MoltbotEnv` interface in `src/types.ts`
2. If passed to container, add to `buildEnvVars()` in `src/gateway/env.ts`
3. Update `.dev.vars.example`
4. Document in README.md secrets table

### Debugging

```bash
# View live logs
npx wrangler tail

# Check secrets
npx wrangler secret list
```

Enable debug routes with `DEBUG_ROUTES=true` and check `/debug/processes`.

## R2 Storage Notes

R2 is mounted via s3fs at `/data/moltbot`. Important gotchas:

- **rsync compatibility**: Use `rsync -r --no-times` instead of `rsync -a`. s3fs doesn't support setting timestamps, which causes rsync to fail with "Input/output error".

- **Mount checking**: Don't rely on `sandbox.mountBucket()` error messages to detect "already mounted" state. Instead, check `mount | grep s3fs` to verify the mount status.

- **Never delete R2 data**: The mount directory `/data/moltbot` IS the R2 bucket. Running `rm -rf /data/moltbot/*` will DELETE your backup data. Always check mount status before any destructive operations.

- **Process status**: The sandbox API's `proc.status` may not update immediately after a process completes. Instead of checking `proc.status === 'completed'`, verify success by checking for expected output (e.g., timestamp file exists after sync).

- **R2 prefix migration**: Backups are now stored under `openclaw/` prefix in R2 (was `clawdbot/`). The startup script handles restoring from both old and new prefixes with automatic migration.

## Telegram Bot Configuration

Telegram needs special attention since it requires external API connectivity and proper channel setup.

### Getting a Telegram Token

1. Open Telegram and search for **@BotFather**
2. Send `/start` then `/newbot`
3. Follow the prompts to create a bot
4. **Copy the token exactly** (format: `123456789:ABCdefGhIjKlMnOpqRsTuVwXyZ`)

### Setting the Token in Wrangler

```bash
# Set the token as a secret
wrangler secret put TELEGRAM_BOT_TOKEN
# Paste the token when prompted

# Verify it's set
wrangler secret list | grep TELEGRAM
```

### Telegram Configuration in Config File

The startup script automatically patches `/root/.openclaw/openclaw.json` with Telegram config:

```json
{
  "channels": {
    "telegram": {
      "botToken": "123456789:ABCdefGh...",
      "enabled": true,
      "dmPolicy": "pairing"
    }
  }
}
```

**Key fields:**
- `botToken`: From BotFather (123456789:ALPHANUMERIC)
- `enabled`: Should always be `true` if configured
- `dmPolicy`: `"pairing"` (default) or `"open"` (allow any user)
- `allowFrom`: Optional list of user IDs if using selective access

### Common Telegram Issues

**Bot doesn't respond to messages:**
1. Verify token with: `curl "https://api.telegram.org/bot<TOKEN>/getMe"`
2. Check gateway is running: `/debug/processes`
3. Verify gateway is responsive: `/debug/health`
4. Check config exists: `cat /root/.openclaw/openclaw.json | jq '.channels.telegram'`

**Token format validation:**
- Must be: `123456789:ALPHANUMERIC_WITH_DASH`
- Script now warns instead of failing on format issues
- OpenClaw will validate further at runtime

**Gateway starts but Telegram doesn't work:**
1. Check if token is valid (getMe call)
2. Verify bot has admin rights in test group
3. Ensure no firewall blocking api.telegram.org
4. Check `/root/openclaw-startup.log` for Telegram-specific errors

**Debugging steps:**
```bash
# 1. Make sure token is valid
TOKEN=$(grep TELEGRAM_BOT_TOKEN .dev.vars | cut -d= -f2)
curl "https://api.telegram.org/bot${TOKEN}/getMe"

# 2. Check if config was written correctly
cat /root/.openclaw/openclaw.json | jq '.channels.telegram'

# 3. Check gateway is running
ps aux | grep "openclaw gateway"

# 4. Check if telegram connection works
curl http://localhost:18789/health | jq '.health.telegram'

# 5. Run detailed diagnostic
./scripts/check-telegram-detailed.sh
```

### Telegram Channel Implementation Details

OpenClaw uses **polling** (not webhooks) by default, which:
- ✓ Works behind firewalls
- ✓ Works in Cloudflare Sandbox
- ✓ Simple to configure
- ⚠ Slightly higher latency (1-2 sec polling interval)

The gateway automatically:
1. Uses the token to connect to Telegram polling API
2. Polls for new messages every ~1 second
3. Routes messages to the agent engine
4. Sends agent responses back to Telegram
