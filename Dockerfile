FROM docker.io/cloudflare/sandbox:0.7.0

# Install Node.js 22 (required by OpenClaw) and rsync (for R2 backup sync)
# The base image has Node 20, we need to replace it with Node 22
# Using direct binary download for reliability
ENV NODE_VERSION=22.13.1
RUN ARCH="$(dpkg --print-architecture)" \
    && case "${ARCH}" in \
         amd64) NODE_ARCH="x64" ;; \
         arm64) NODE_ARCH="arm64" ;; \
         *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; \
       esac \
    && apt-get update && apt-get install -y xz-utils ca-certificates rsync \
    && curl -fsSLk https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && node --version \
    && npm --version

# Install Playwright system dependencies for headless browser
# These are required for Chromium, Firefox, and WebKit to run in headless mode
RUN apt-get update && apt-get install -y \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    libatspi2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm globally
RUN npm install -g pnpm

# Install Playwright and Playwright MCP server globally
# These are needed for browser automation via MCP
# Using latest Playwright 1.58.2 which fixes SSL certificate verification vulnerability
RUN npm install -g playwright@1.58.2 @playwright/mcp@0.0.64 \
    && npx playwright install chromium --with-deps

# Install OpenClaw (formerly clawdbot/moltbot)
# Pin to specific version for reproducible builds
RUN npm install -g openclaw@2026.2.3 \
    && openclaw --version

# Create OpenClaw directories
# Legacy .clawdbot paths are kept for R2 backup migration
RUN mkdir -p /root/.openclaw \
    && mkdir -p /root/clawd \
    && mkdir -p /root/clawd/skills

# Copy startup script
# Build cache bust: 2026-02-09-v29-playwright-mcp-integration
COPY start-openclaw.sh /usr/local/bin/start-openclaw.sh
RUN chmod +x /usr/local/bin/start-openclaw.sh && echo "Build: 2026-02-09-v29-playwright"

# Copy custom skills
COPY skills/ /root/clawd/skills/

# Copy Jasper identity and personality (NEW - 70% → 100%)
COPY IDENTITY.md /root/clawd/IDENTITY.md
COPY SOUL.md /root/clawd/SOUL.md
COPY TOOLS.md /root/clawd/TOOLS.md

# Copy system reporting script
COPY scripts/send-system-report.sh /usr/local/bin/send-system-report.sh
RUN chmod +x /usr/local/bin/send-system-report.sh

# Set working directory
WORKDIR /root/clawd

# Expose the gateway port
EXPOSE 18789
