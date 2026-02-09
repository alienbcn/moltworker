# Web Browser Search Integration - README

## Overview

This integration adds intelligent web search capabilities to JASPER using a dual-strategy approach:

1. **Primary Method**: Brave Search API (fast, efficient for text-based searches)
2. **Fallback Method**: Playwright Browser Automation (for JavaScript-heavy sites and visual content)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    JASPER Agent                         │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │  Web Browser Search Decision     │
        │  - Check BRAVE_API_KEY           │
        │  - Determine site complexity     │
        └──────────────────────────────────┘
                           │
         ┌─────────────────┴──────────────────┐
         │                                    │
         ▼                                    ▼
┌─────────────────┐                 ┌──────────────────┐
│  Brave API      │                 │  Playwright MCP  │
│  (Fast: 1-2s)   │                 │  (Slower: 5-10s) │
│  - Text search  │                 │  - Full browser  │
│  - News/prices  │                 │  - JavaScript    │
│  - 10k/month    │                 │  - Screenshots   │
└─────────────────┘                 └──────────────────┘
```

## Installation

The integration is automatically configured when the container starts. The following components are installed:

1. **Playwright**: Browser automation library (v1.58.2)
2. **@playwright/mcp**: Model Context Protocol server for Playwright
3. **Chromium**: Headless browser for rendering
4. **System Dependencies**: Libraries needed for headless operation

### Manual Installation (Development)

```bash
# Install dependencies
npm install

# Install Playwright browsers
npx playwright install chromium

# Test the integration
node skills/web-browser-search/scripts/basic-test.js
```

## Configuration

### Environment Variables

- `BRAVE_SEARCH_API_KEY` (optional): Enables Brave API as primary search method
  - Get your key at: https://api.search.brave.com/
  - Free tier: 2,000 queries/month
  
### OpenClaw Configuration

The MCP server is automatically configured in `openclaw.json`:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp"],
      "env": {}
    }
  },
  "browser": {
    "enabled": true,
    "defaultProfile": "openclaw",
    "headless": true,
    "profiles": {
      "openclaw": {
        "cdpPort": 18800,
        "color": "#FF4500"
      }
    }
  }
}
```

## Usage

### From OpenClaw Agent

The skill is automatically available to JASPER through OpenClaw's MCP integration:

```javascript
// Example: Agent decides search strategy automatically
User: "What's the current ETH price on Coinbase?"

Agent workflow:
1. Check if BRAVE_SEARCH_API_KEY is set
2. Try Brave API first
3. If result incomplete, fallback to Playwright
4. Navigate to coinbase.com
5. Extract current price from rendered page
6. Return result with timestamp
```

### Direct Script Usage

```bash
# Search with Brave API (requires BRAVE_SEARCH_API_KEY)
export BRAVE_SEARCH_API_KEY="your-key-here"
node skills/web-browser-search/scripts/browser-search.js "search query"

# Use Playwright directly (no API key needed)
node skills/web-browser-search/scripts/browser-search.js "https://example.com"

# Take a screenshot
node skills/web-browser-search/scripts/browser-search.js "https://example.com" --screenshot

# Wait for specific content
node skills/web-browser-search/scripts/browser-search.js "crypto prices" --wait-selector ".price-table"
```

## Testing

### Basic Smoke Test (No Network)

```bash
node skills/web-browser-search/scripts/basic-test.js
```

Expected output:
```
✅ SUCCESS: Playwright is working correctly!

Browser automation capabilities verified:
  ✓ Browser launch
  ✓ Page creation
  ✓ Content rendering
  ✓ JavaScript evaluation
  ✓ Screenshot capture
```

### Full Integration Test (Requires Network)

```bash
node skills/web-browser-search/scripts/test-search.js
```

This test:
1. Tests Brave API (if key is set)
2. Tests Playwright browser automation
3. Navigates to google.com
4. Extracts page title
5. Takes a screenshot

## Performance

| Method | Latency | Use Case |
|--------|---------|----------|
| Brave API | 1-2s | Text search, news, prices |
| Playwright | 5-10s | JavaScript sites, visual content |

## Costs

### Brave API
- Free tier: 2,000 queries/month
- Paid: ~$5/month for 10,000 queries
- Rate limit: 30 queries/minute

### Playwright
- Included in container compute costs
- Memory: ~512 MB per browser instance
- No per-query charges

## Security

### Vulnerabilities Fixed

- **Playwright < 1.55.1**: SSL certificate verification issue
  - **Status**: Fixed in Playwright 1.58.2 ✅

### Sandboxing

- Browser runs in Cloudflare Sandbox container
- No persistent storage
- No access to host filesystem (except /root/clawd)
- Network egress limited to HTTP/HTTPS
- Downloads disabled by default

### Security Best Practices

1. Always use latest Playwright version
2. Run browser with `--no-sandbox` only in trusted environments (container)
3. Validate and sanitize all user inputs before navigation
4. Set reasonable timeouts to prevent hanging
5. Monitor memory usage to prevent DoS

## Troubleshooting

### Browser fails to launch

```bash
# Check Playwright installation
npx playwright --version

# Reinstall browsers
npx playwright install chromium

# Check system dependencies
ldd $(which chromium)
```

### Page load timeouts

1. Increase timeout in script
2. Check site blocking headless browsers
3. Try different user-agent

### Out of memory

1. Reduce concurrent browser instances
2. Close browsers after use
3. Monitor: `ps aux | grep chromium`

### Network errors

In sandboxed environment without network:
- Use basic-test.js instead of test-search.js
- Full integration tests will only work when deployed

## Examples

### Example 1: News Search
```
User: "What happened today in AI?"
→ Brave API → Fast results → 1-2s response
```

### Example 2: Dynamic Content
```
User: "Get current ETH price from Coinbase"
→ Brave API (cached data)
→ Fallback to Playwright
→ Navigate, render, extract
→ "$3,245.67 as of 2026-02-09"
```

### Example 3: Form Interaction
```
User: "Search GitHub for 'OpenClaw'"
→ Playwright directly
→ Fill search form
→ Wait for results
→ Extract top 3 repos
```

## Future Enhancements

- [ ] Browser session reuse (keep-alive)
- [ ] Smart caching with TTL
- [ ] Parallel search (Brave + Playwright simultaneously)
- [ ] Proxy rotation for rate limit avoidance
- [ ] Cost optimization dashboard
- [ ] A/B testing for search quality

## Support

For issues or questions:
1. Check `/root/openclaw-startup.log` for startup errors
2. Check `/root/openclaw-supervisor.log` for runtime errors
3. Use debug routes: `/_admin/debug/health`
4. Review SKILL.md for detailed documentation

## License

Apache 2.0 (same as parent project)
