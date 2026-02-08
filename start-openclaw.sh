#!/bin/bash
# Startup script for OpenClaw in Cloudflare Sandbox
# This script:
# 1. Restores config from R2 backup if available
# 2. Runs openclaw onboard --non-interactive to configure from env vars
# 3. Patches config for features onboard doesn't cover (channels, gateway auth)
# 4. Starts the gateway with supervisor for auto-restart on failure
#
# Enhanced with:
# - Robust error handling
# - Telegram connectivity validation
# - Process supervisor with auto-restart
# - Improved logging
# - Health checks

set -o pipefail
trap 'echo "[ERROR] Script failed at line $LINENO"' ERR

LOG_FILE="/root/openclaw-startup.log"
SUPERVISOR_LOG="/root/openclaw-supervisor.log"

log_info() {
    local msg="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $msg" | tee -a "$LOG_FILE"
}

log_error() {
    local msg="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $msg" | tee -a "$LOG_FILE" >&2
}

log_info "=== OpenClaw Startup ==="

if pgrep -f "openclaw gateway" > /dev/null 2>&1; then
    log_info "OpenClaw gateway is already running, verifying health..."
    if curl -s http://localhost:18789/health > /dev/null 2>&1; then
        log_info "Gateway is healthy, exiting."
        exit 0
    else
        log_error "Gateway process exists but not responding, killing and restarting..."
        pkill -9 -f "openclaw gateway" || true
        sleep 2
    fi
fi

CONFIG_DIR="/root/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
BACKUP_DIR="/data/moltbot"

log_info "Config directory: $CONFIG_DIR"
log_info "Backup directory: $BACKUP_DIR"

mkdir -p "$CONFIG_DIR"
mkdir -p "$(dirname $LOG_FILE)"

# ============================================================
# RESTORE FROM R2 BACKUP
# ============================================================

should_restore_from_r2() {
    local R2_SYNC_FILE="$BACKUP_DIR/.last-sync"
    local LOCAL_SYNC_FILE="$CONFIG_DIR/.last-sync"

    if [ ! -f "$R2_SYNC_FILE" ]; then
        log_info "No R2 sync timestamp found, skipping restore"
        return 1
    fi

    if [ ! -f "$LOCAL_SYNC_FILE" ]; then
        log_info "No local sync timestamp, will restore from R2"
        return 0
    fi

    R2_TIME=$(cat "$R2_SYNC_FILE" 2>/dev/null)
    LOCAL_TIME=$(cat "$LOCAL_SYNC_FILE" 2>/dev/null)

    log_info "R2 last sync: $R2_TIME"
    log_info "Local last sync: $LOCAL_TIME"

    R2_EPOCH=$(date -d "$R2_TIME" +%s 2>/dev/null || echo "0")
    LOCAL_EPOCH=$(date -d "$LOCAL_TIME" +%s 2>/dev/null || echo "0")

    if [ "$R2_EPOCH" -gt "$LOCAL_EPOCH" ]; then
        log_info "R2 backup is newer, will restore"
        return 0
    else
        log_info "Local data is newer or same, skipping restore"
        return 1
    fi
}

# Check for backup data in new openclaw/ prefix first, then legacy clawdbot/ prefix
if [ -f "$BACKUP_DIR/openclaw/openclaw.json" ]; then
    if should_restore_from_r2; then
        log_info "Restoring from R2 backup at $BACKUP_DIR/openclaw..."
        cp -a "$BACKUP_DIR/openclaw/." "$CONFIG_DIR/" && log_info "Config restored" || log_error "Failed to restore config"
        cp -f "$BACKUP_DIR/.last-sync" "$CONFIG_DIR/.last-sync" 2>/dev/null || true
        log_info "Restored config from R2 backup"
    fi
elif [ -f "$BACKUP_DIR/clawdbot/clawdbot.json" ]; then
    # Legacy backup format — migrate .clawdbot data into .openclaw
    if should_restore_from_r2; then
        log_info "Restoring from legacy R2 backup at $BACKUP_DIR/clawdbot..."
        cp -a "$BACKUP_DIR/clawdbot/." "$CONFIG_DIR/" && log_info "Legacy config restored" || log_error "Failed to restore legacy config"
        cp -f "$BACKUP_DIR/.last-sync" "$CONFIG_DIR/.last-sync" 2>/dev/null || true
        # Rename the config file if it has the old name
        if [ -f "$CONFIG_DIR/clawdbot.json" ] && [ ! -f "$CONFIG_FILE" ]; then
            mv "$CONFIG_DIR/clawdbot.json" "$CONFIG_FILE"
        fi
        log_info "Restored and migrated config from legacy R2 backup"
    fi
elif [ -f "$BACKUP_DIR/clawdbot.json" ]; then
    # Very old legacy backup format (flat structure)
    if should_restore_from_r2; then
        log_info "Restoring from flat legacy R2 backup at $BACKUP_DIR..."
        cp -a "$BACKUP_DIR/." "$CONFIG_DIR/" && log_info "Flat legacy config restored" || log_error "Failed to restore flat config"
        cp -f "$BACKUP_DIR/.last-sync" "$CONFIG_DIR/.last-sync" 2>/dev/null || true
        if [ -f "$CONFIG_DIR/clawdbot.json" ] && [ ! -f "$CONFIG_FILE" ]; then
            mv "$CONFIG_DIR/clawdbot.json" "$CONFIG_FILE"
        fi
        log_info "Restored and migrated config from flat legacy R2 backup"
    fi
elif [ -d "$BACKUP_DIR" ]; then
    log_info "R2 mounted at $BACKUP_DIR but no backup data found yet"
else
    log_info "R2 not mounted, starting fresh"
fi

# Restore workspace from R2 backup if available (only if R2 is newer)
# This includes IDENTITY.md, USER.md, MEMORY.md, memory/, and assets/
WORKSPACE_DIR="/root/clawd"
if [ -d "$BACKUP_DIR/workspace" ] && [ "$(ls -A $BACKUP_DIR/workspace 2>/dev/null)" ]; then
    if should_restore_from_r2; then
        log_info "Restoring workspace from $BACKUP_DIR/workspace..."
        mkdir -p "$WORKSPACE_DIR"
        cp -a "$BACKUP_DIR/workspace/." "$WORKSPACE_DIR/" && log_info "Workspace restored" || log_error "Failed to restore workspace"
        log_info "Restored workspace from R2 backup"
    fi
fi

# Restore skills from R2 backup if available (only if R2 is newer)
SKILLS_DIR="/root/clawd/skills"
if [ -d "$BACKUP_DIR/skills" ] && [ "$(ls -A $BACKUP_DIR/skills 2>/dev/null)" ]; then
    if should_restore_from_r2; then
        log_info "Restoring skills from $BACKUP_DIR/skills..."
        mkdir -p "$SKILLS_DIR"
        cp -a "$BACKUP_DIR/skills/." "$SKILLS_DIR/" && log_info "Skills restored" || log_error "Failed to restore skills"
        log_info "Restored skills from R2 backup"
    fi
fi

# ============================================================
# ONBOARD (only if no config exists yet)
# ============================================================
if [ ! -f "$CONFIG_FILE" ]; then
    log_info "No existing config found, running openclaw onboard..."

    AUTH_ARGS=""
    if [ -n "$CLOUDFLARE_AI_GATEWAY_API_KEY" ] && [ -n "$CF_AI_GATEWAY_ACCOUNT_ID" ] && [ -n "$CF_AI_GATEWAY_GATEWAY_ID" ]; then
        log_info "Using Cloudflare AI Gateway for authentication"
        AUTH_ARGS="--auth-choice cloudflare-ai-gateway-api-key \
            --cloudflare-ai-gateway-account-id $CF_AI_GATEWAY_ACCOUNT_ID \
            --cloudflare-ai-gateway-gateway-id $CF_AI_GATEWAY_GATEWAY_ID \
            --cloudflare-ai-gateway-api-key $CLOUDFLARE_AI_GATEWAY_API_KEY"
    elif [ -n "$ANTHROPIC_API_KEY" ]; then
        log_info "Using Anthropic API for authentication"
        AUTH_ARGS="--auth-choice apiKey --anthropic-api-key $ANTHROPIC_API_KEY"
    elif [ -n "$OPENAI_API_KEY" ]; then
        log_info "Using OpenAI API for authentication"
        AUTH_ARGS="--auth-choice openai-api-key --openai-api-key $OPENAI_API_KEY"
    else
        log_error "No AI provider configured. Set ANTHROPIC_API_KEY, OPENAI_API_KEY, or Cloudflare AI Gateway variables"
        exit 1
    fi

    if openclaw onboard --non-interactive --accept-risk \
        --mode local \
        $AUTH_ARGS \
        --gateway-port 18789 \
        --gateway-bind lan \
        --skip-channels \
        --skip-skills \
        --skip-health 2>&1 | tee -a "$LOG_FILE"; then
        log_info "Onboard completed successfully"
    else
        log_error "Onboard failed"
        exit 1
    fi
else
    log_info "Using existing config at $CONFIG_FILE"
fi

# ============================================================
# CREATE AGENT AUTH-PROFILES
# ============================================================
# OpenClaw agents need auth-profiles.json to access providers
# This is created by openclaw onboard, but we also ensure it exists
# with the correct provider keys from environment variables

if [ -n "$ANTHROPIC_API_KEY" ] || [ -n "$OPENAI_API_KEY" ] || [ -n "$CLOUDFLARE_AI_GATEWAY_API_KEY" ]; then
    AGENT_DIR="/root/.openclaw/agents/main/agent"
    mkdir -p "$AGENT_DIR"

    log_info "Creating agent auth-profiles..."
    node << 'EOFAUTH' 2>&1 | tee -a "$LOG_FILE"
const fs = require('fs');
const authPath = '/root/.openclaw/agents/main/agent/auth-profiles.json';

let authProfiles = {};

// Anthropic
if (process.env.ANTHROPIC_API_KEY) {
    authProfiles.anthropic = {
        primary: {
            apiKey: process.env.ANTHROPIC_API_KEY
        }
    };
}

// OpenAI
if (process.env.OPENAI_API_KEY) {
    authProfiles.openai = {
        primary: {
            apiKey: process.env.OPENAI_API_KEY
        }
    };
}

// Cloudflare AI Gateway
if (process.env.CLOUDFLARE_AI_GATEWAY_API_KEY && process.env.CF_AI_GATEWAY_ACCOUNT_ID) {
    authProfiles['cloudflare-ai-gateway-api-key'] = {
        primary: {
            apiKey: process.env.CLOUDFLARE_AI_GATEWAY_API_KEY
        }
    };
}

if (Object.keys(authProfiles).length > 0) {
    fs.writeFileSync(authPath, JSON.stringify(authProfiles, null, 2));
    console.log('Agent auth-profiles created with keys:', Object.keys(authProfiles).join(', '));
} else {
    console.warn('No AI provider keys found in environment');
}
EOFAUTH
fi

# ============================================================
# PATCH CONFIG (channels, gateway auth, trusted proxies)
# ============================================================
# openclaw onboard handles provider/model config, but we need to patch in:
# - Channel config (Telegram, Discord, Slack)
# - Gateway token auth
# - Trusted proxies for sandbox networking
# - Base URL override for legacy AI Gateway path
log_info "Patching OpenClaw configuration..."
node << 'EOFPATCH' 2>&1 | tee -a "$LOG_FILE"
const fs = require('fs');

const configPath = '/root/.openclaw/openclaw.json';
console.log('Patching config at:', configPath);
let config = {};

try {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (e) {
    console.log('Starting with empty config');
}

config.gateway = config.gateway || {};
config.channels = config.channels || {};

// Gateway configuration
config.gateway.port = 18789;
config.gateway.mode = 'local';
config.gateway.trustedProxies = ['10.1.0.0'];

if (process.env.OPENCLAW_GATEWAY_TOKEN) {
    config.gateway.auth = config.gateway.auth || {};
    config.gateway.auth.token = process.env.OPENCLAW_GATEWAY_TOKEN;
}

if (process.env.OPENCLAW_DEV_MODE === 'true') {
    config.gateway.controlUi = config.gateway.controlUi || {};
    config.gateway.controlUi.allowInsecureAuth = true;
}

// Legacy AI Gateway base URL override:
// ANTHROPIC_BASE_URL is picked up natively by the Anthropic SDK,
// so we don't need to patch the provider config. Writing a provider
// entry without a models array breaks OpenClaw's config validation.

// AI Gateway model override (CF_AI_GATEWAY_MODEL=provider/model-id)
// Adds a provider entry for any AI Gateway provider and sets it as default model.
// Examples:
//   workers-ai/@cf/meta/llama-3.3-70b-instruct-fp8-fast
//   openai/gpt-4o
//   anthropic/claude-sonnet-4-5
if (process.env.CF_AI_GATEWAY_MODEL) {
    const raw = process.env.CF_AI_GATEWAY_MODEL;
    const slashIdx = raw.indexOf('/');
    const gwProvider = raw.substring(0, slashIdx);
    const modelId = raw.substring(slashIdx + 1);

    const accountId = process.env.CF_AI_GATEWAY_ACCOUNT_ID;
    const gatewayId = process.env.CF_AI_GATEWAY_GATEWAY_ID;
    const apiKey = process.env.CLOUDFLARE_AI_GATEWAY_API_KEY;

    let baseUrl;
    if (accountId && gatewayId) {
        baseUrl = 'https://gateway.ai.cloudflare.com/v1/' + accountId + '/' + gatewayId + '/' + gwProvider;
        if (gwProvider === 'workers-ai') baseUrl += '/v1';
    } else if (gwProvider === 'workers-ai' && process.env.CF_ACCOUNT_ID) {
        baseUrl = 'https://api.cloudflare.com/client/v4/accounts/' + process.env.CF_ACCOUNT_ID + '/ai/v1';
    }

    if (baseUrl && apiKey) {
        const api = gwProvider === 'anthropic' ? 'anthropic-messages' : 'openai-completions';
        const providerName = 'cf-ai-gw-' + gwProvider;

        config.models = config.models || {};
        config.models.providers = config.models.providers || {};
        config.models.providers[providerName] = {
            baseUrl: baseUrl,
            apiKey: apiKey,
            api: api,
            models: [{ id: modelId, name: modelId, contextWindow: 131072, maxTokens: 8192 }],
        };
        config.agents = config.agents || {};
        config.agents.defaults = config.agents.defaults || {};
        config.agents.defaults.model = { primary: providerName + '/' + modelId };
        console.log('AI Gateway model override: provider=' + providerName + ' model=' + modelId + ' via ' + baseUrl);
    } else {
        console.warn('CF_AI_GATEWAY_MODEL set but missing required config (account ID, gateway ID, or API key)');
    }
}

// Telegram configuration - IMPROVED WITH VALIDATION
// Overwrite entire channel object to drop stale keys from old R2 backups
// that would fail OpenClaw's strict config validation (see #47)
if (process.env.TELEGRAM_BOT_TOKEN) {
    const token = process.env.TELEGRAM_BOT_TOKEN.trim();
    
    // Validate token format: should be digits:alphanum (more permissive pattern)
    const tokenRegex = /^\d+:[A-Za-z0-9_\-]+$/;
    if (!tokenRegex.test(token)) {
        console.warn('WARNING: Telegram bot token format may be invalid.');
        console.warn('Expected format: DIGITS:ALPHANUMERIC_AND_DASH');
        console.warn('Got: ' + token);
        console.warn('Proceeding anyway - OpenClaw will validate further...');
    }
    
    const dmPolicy = process.env.TELEGRAM_DM_POLICY || 'pairing';
    config.channels.telegram = {
        botToken: token,
        enabled: true,
        dmPolicy: dmPolicy,
    };
    if (process.env.TELEGRAM_DM_ALLOW_FROM) {
        config.channels.telegram.allowFrom = process.env.TELEGRAM_DM_ALLOW_FROM.split(',').map(s => s.trim());
    } else if (dmPolicy === 'open') {
        config.channels.telegram.allowFrom = ['*'];
    }
    console.log('Telegram configured with dmPolicy: ' + dmPolicy + ', token: ' + token.substring(0, 10) + '...');
}

// Discord configuration
// Discord uses a nested dm object: dm.policy, dm.allowFrom (per DiscordDmConfig)
if (process.env.DISCORD_BOT_TOKEN) {
    const dmPolicy = process.env.DISCORD_DM_POLICY || 'pairing';
    const dm = { policy: dmPolicy };
    if (dmPolicy === 'open') {
        dm.allowFrom = ['*'];
    }
    config.channels.discord = {
        token: process.env.DISCORD_BOT_TOKEN,
        enabled: true,
        dm: dm,
    };
    console.log('Discord configured');
}

// Slack configuration
if (process.env.SLACK_BOT_TOKEN && process.env.SLACK_APP_TOKEN) {
    config.channels.slack = {
        botToken: process.env.SLACK_BOT_TOKEN,
        appToken: process.env.SLACK_APP_TOKEN,
        enabled: true,
    };
    console.log('Slack configured');
}

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
console.log('Configuration patched successfully');
EOFPATCH

# ============================================================
# SETUP CRON JOBS FOR SYSTEM REPORTING & HEARTBEAT
# ============================================================
log_info "Setting up cron jobs for system monitoring..."

# Ensure scripts are executable
chmod +x /root/send-system-report.sh 2>/dev/null || true

# Remove any existing cron entry to avoid duplicates
crontab -r 2>/dev/null || true

# Create new crontab with system report job (every hour at 0 minutes)
# Also add a heartbeat every 30 minutes (for uptime tracking)
CRONTAB_ENTRY=$(cat <<'EOFCRON'
# Jasper System Health Reporting (every hour)
0 * * * * /root/send-system-report.sh >> /root/system-report.log 2>&1

# Heartbeat logging (every 30 minutes) - lightweight status check
*/30 * * * * echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Heartbeat" >> /root/heartbeat.log

# Gateway health check (every 5 minutes)
*/5 * * * * curl -s http://localhost:18789/health > /dev/null && echo "gateway-ok" || echo "gateway-down" >> /root/gateway-errors.log
EOFCRON
)

# Install crontab
echo "$CRONTAB_ENTRY" | crontab - 2>/dev/null || {
    log_error "Failed to install crontab, continuing without cron jobs..."
}

log_info "✓ Cron jobs configured:"
log_info "  - System report: every hour"
log_info "  - Heartbeat: every 30 minutes"
log_info "  - Health check: every 5 minutes"

# Start cron daemon if available
if command -v cron &>/dev/null || command -v crond &>/dev/null; then
    pkill -f "(cron|crond)" 2>/dev/null || true
    sleep 1
    
    # Try to start cron daemon
    if command -v cron &>/dev/null; then
        cron &
        log_info "Cron daemon started"
    elif command -v crond &>/dev/null; then
        crond &
        log_info "Crond daemon started"
    fi
fi

# ============================================================
# SUPERVISOR FUNCTION - Restart gateway if it crashes
# ============================================================
start_gateway_with_supervisor() {
    local attempt=1
    local max_attempts=5
    local retry_delay=10
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Gateway startup attempt $attempt/$max_attempts..."
        
        # Remove old lock files
        rm -f /tmp/openclaw-gateway.lock 2>/dev/null || true
        rm -f "$CONFIG_DIR/gateway.lock" 2>/dev/null || true
        
        local gateway_cmd="openclaw gateway --port 18789 --verbose --allow-unconfigured --bind lan"
        
        if [ -n "$OPENCLAW_GATEWAY_TOKEN" ]; then
            log_info "Starting gateway with token auth..."
            gateway_cmd="$gateway_cmd --token $OPENCLAW_GATEWAY_TOKEN"
        else
            log_info "Starting gateway with device pairing..."
        fi
        
        log_info "Dev mode: ${OPENCLAW_DEV_MODE:-false}"
        log_info "Executing: $gateway_cmd"
        
        # Run the gateway and capture any errors
        if $gateway_cmd 2>&1 | tee -a "$LOG_FILE"; then
            log_info "Gateway exited successfully"
            return 0
        else
            local exit_code=$?
            log_error "Gateway crashed with exit code: $exit_code"
            
            if [ $attempt -lt $max_attempts ]; then
                log_info "Waiting ${retry_delay} seconds before retry..."
                sleep $retry_delay
                attempt=$((attempt + 1))
            else
                log_error "Max retry attempts reached. Gateway failed to start."
                return 1
            fi
        fi
    done
}

# ============================================================
# START GATEWAY
# ============================================================
log_info "=== Starting OpenClaw Gateway ==="
log_info "Gateway will be available on port 18789"
log_info "Standard output and errors logged to: $LOG_FILE"

# Start supervisor
start_gateway_with_supervisor
