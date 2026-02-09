---
name: web-browser-search
description: Advanced web search with fallback strategy. First tries Brave Search API for fast results, then falls back to Playwright browser automation for JavaScript-heavy sites that require rendering. Use when you need current web information or when scraping dynamic content.
---

# Web Browser Search

This skill provides intelligent web search with automatic fallback:
1. **Primary**: Brave Search API - Fast, efficient for text-based searches
2. **Fallback**: Playwright browser automation - For JavaScript-heavy sites, visual content extraction, and complex interactions

## Prerequisites

- `BRAVE_SEARCH_API_KEY` environment variable (optional, for primary search)
- Playwright MCP server configured (automatic via start-openclaw.sh)
- Chromium browser installed (automatic in Dockerfile)

## Usage Patterns

### Quick Web Search
When you just need fast text-based search results:
```
User: "What are the latest news about Cloudflare Workers?"
→ Uses Brave API → Fast results in 1-2 seconds
```

### JavaScript-Heavy Sites
When the target site requires browser rendering:
```
User: "Get the current price from this crypto exchange dashboard"
→ Brave API fails or returns incomplete data
→ Falls back to Playwright → Renders page → Extracts visual content
```

### Interactive Web Scraping
When you need to interact with web pages:
```
User: "Fill out this form and submit it on example.com"
→ Uses Playwright directly → Full browser control
```

## Architecture

```
User Query
    │
    ▼
┌─────────────────────────┐
│  Try Brave Search API   │ ← Primary (fast, 1-2s)
└─────────────────────────┘
    │
    │ If fails or incomplete
    ▼
┌─────────────────────────┐
│  Try Playwright MCP     │ ← Fallback (slower, 5-10s)
│  - Launch headless      │
│  - Navigate to URL      │
│  - Wait for render      │
│  - Extract content      │
│  - Take screenshot      │
└─────────────────────────┘
    │
    ▼
   Results
```

## Scripts

### Search with Brave API
```bash
# Direct Brave Search (requires BRAVE_SEARCH_API_KEY)
curl "https://api.search.brave.com/res/v1/web/search?q=query" \
  -H "X-Subscription-Token: $BRAVE_SEARCH_API_KEY"
```

### Fallback with Playwright
```bash
# Browser-based search when Brave fails
node /root/clawd/skills/web-browser-search/scripts/browser-search.js "query"
```

### Smoke Test
```bash
# Test both methods
node /root/clawd/skills/web-browser-search/scripts/test-search.js
```

## When to Use Which Method

| Scenario | Method | Reason |
|----------|--------|--------|
| News search | Brave API | Fast, text-based, reliable |
| Price lookups | Brave API first | Usually available in meta tags |
| SPA/React sites | Playwright | Requires JavaScript rendering |
| Forms/interactions | Playwright | Needs browser automation |
| Screenshots needed | Playwright | Visual capture |
| Rate limit concerns | Brave API | More generous limits |

## Brave Search API Limits

- **Free tier**: 2,000 queries/month
- **Rate limit**: ~30 queries/minute
- **Timeout**: 10 seconds per request
- **Cost**: $1-5/month for typical usage (10k queries)

## Playwright Limits

- **Timeout**: 30 seconds per page load
- **Memory**: 512 MB per browser instance
- **Concurrent**: 1 browser instance max (single user assistant)
- **Cost**: Included in container compute costs

## Integration with OpenClaw

This skill integrates with OpenClaw's MCP framework:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-playwright"]
    }
  }
}
```

The MCP server provides these tools to the agent:
- `playwright_navigate` - Navigate to URL
- `playwright_screenshot` - Capture page
- `playwright_click` - Click elements
- `playwright_fill` - Fill forms
- `playwright_evaluate` - Run JavaScript
- `playwright_pdf` - Generate PDF

## Error Handling

The skill handles these common errors gracefully:

1. **Brave API Key Missing**: Falls back to Playwright immediately
2. **Brave API Rate Limit**: Waits and retries, or uses Playwright
3. **Playwright Timeout**: Returns partial results with error message
4. **Browser Launch Failure**: Returns clear error message
5. **Network Errors**: Retries with exponential backoff

## Examples

### Example 1: News Search
```
User: "What happened today in AI?"
Agent: [Uses Brave API]
       - Fast results from BBC, TechCrunch, ArXiv
       - 1-2 second response time
```

### Example 2: Dynamic Content
```
User: "Get the ETH price from Coinbase"
Agent: [Brave API returns old cached data]
       [Falls back to Playwright]
       - Launches browser
       - Navigates to coinbase.com
       - Waits for price to render
       - Extracts current price
       - Returns: "$3,245.67 as of 2026-02-09 08:45 UTC"
```

### Example 3: Form Interaction
```
User: "Search for 'OpenClaw' on GitHub and get top 3 results"
Agent: [Uses Playwright directly]
       - Opens github.com/search
       - Fills search box
       - Waits for results
       - Extracts top 3 repos with stars
```

## Performance Tips

1. **Prefer Brave API**: It's 5-10x faster for text searches
2. **Cache results**: Avoid re-scraping the same page
3. **Use pagination carefully**: Each page load costs time/memory
4. **Close browsers**: Always cleanup to avoid memory leaks
5. **Batch requests**: Group related searches together

## Troubleshooting

### Brave API returns 401
- Check `BRAVE_SEARCH_API_KEY` is set correctly
- Verify API key is active at https://api.search.brave.com/

### Playwright fails to launch
- Check Chromium is installed: `which chromium`
- Verify system dependencies: `ldd $(which chromium)`
- Check logs: `/root/openclaw-startup.log`

### Browser hangs on page load
- Increase timeout in script
- Check if site blocks headless browsers
- Try with different user-agent

### Out of memory
- Reduce concurrent browser instances
- Close browsers after use
- Monitor with: `ps aux | grep chromium`

## Security Notes

- Playwright runs in sandboxed container environment
- No persistent browser storage (privacy protection)
- Downloads disabled by default
- Network egress limited to HTTP/HTTPS
- No access to host filesystem beyond /root/clawd

## Future Enhancements

- [ ] Proxy rotation for rate limit avoidance
- [ ] Browser session reuse (keep-alive)
- [ ] Smart caching with TTL
- [ ] A/B testing for search quality
- [ ] Cost optimization dashboard
- [ ] Parallel search (Brave + Playwright simultaneously)
