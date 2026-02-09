#!/usr/bin/env node
/**
 * Web Browser Search - Playwright Implementation
 * 
 * This script uses Playwright to search the web when Brave API is unavailable
 * or when dealing with JavaScript-heavy sites that require rendering.
 * 
 * Usage:
 *   node browser-search.js "search query"
 *   node browser-search.js "https://example.com" --extract-text
 */

import { chromium } from 'playwright';

const SEARCH_ENGINE = 'https://www.google.com/search';
const USER_AGENT = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36';
const TIMEOUT = 30000; // 30 seconds
const VIEWPORT = { width: 1280, height: 720 };

/**
 * Main function to perform web search with Playwright
 */
async function browserSearch(query, options = {}) {
  const {
    extractText = true,
    takeScreenshot = false,
    screenshotPath = '/tmp/search-screenshot.png',
    headless = true,
    waitForSelector = null,
  } = options;

  let browser = null;
  const startTime = Date.now();
  
  try {
    console.error(`[Playwright] Launching browser (headless: ${headless})...`);
    browser = await chromium.launch({
      headless,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--disable-gpu',
        '--no-first-run',
        '--no-zygote',
        '--single-process',
        '--disable-extensions',
      ],
    });

    const context = await browser.newContext({
      userAgent: USER_AGENT,
      viewport: VIEWPORT,
      locale: 'es-ES',
    });

    const page = await context.newPage();
    
    // Set default timeout
    page.setDefaultTimeout(TIMEOUT);
    
    // Determine if query is a URL or search term
    const isUrl = query.startsWith('http://') || query.startsWith('https://');
    const targetUrl = isUrl ? query : `${SEARCH_ENGINE}?q=${encodeURIComponent(query)}`;
    
    console.error(`[Playwright] Navigating to: ${targetUrl}`);
    await page.goto(targetUrl, { waitUntil: 'domcontentloaded' });
    
    // Wait for specific selector if provided
    if (waitForSelector) {
      console.error(`[Playwright] Waiting for selector: ${waitForSelector}`);
      await page.waitForSelector(waitForSelector, { timeout: TIMEOUT });
    } else {
      // Wait a bit for dynamic content to load
      await page.waitForTimeout(2000);
    }

    const result = {
      url: page.url(),
      title: await page.title(),
      timestamp: new Date().toISOString(),
      loadTimeMs: Date.now() - startTime,
    };

    // Extract text content
    if (extractText) {
      console.error('[Playwright] Extracting text content...');
      
      // For Google search results, extract specific elements
      if (!isUrl && targetUrl.includes('google.com/search')) {
        const searchResults = await page.evaluate(() => {
          const results = [];
          const resultDivs = document.querySelectorAll('div.g, div[data-sokoban-container]');
          
          for (let i = 0; i < Math.min(resultDivs.length, 10); i++) {
            const div = resultDivs[i];
            const titleEl = div.querySelector('h3');
            const linkEl = div.querySelector('a');
            const snippetEl = div.querySelector('div[data-sncf], div.VwiC3b, span.aCOpRe');
            
            if (titleEl && linkEl) {
              results.push({
                title: titleEl.textContent.trim(),
                url: linkEl.href,
                snippet: snippetEl ? snippetEl.textContent.trim() : '',
              });
            }
          }
          
          return results;
        });
        
        result.searchResults = searchResults;
        result.resultCount = searchResults.length;
      } else {
        // For other pages, extract main text content
        const textContent = await page.evaluate(() => {
          // Remove script and style elements
          const scripts = document.querySelectorAll('script, style, nav, footer, header');
          scripts.forEach(el => el.remove());
          
          // Get text from main content area or body
          const main = document.querySelector('main, article, #content, .content, body');
          return main ? main.innerText.trim().slice(0, 5000) : '';
        });
        
        result.textContent = textContent;
        result.textLength = textContent.length;
      }
    }

    // Take screenshot if requested
    if (takeScreenshot) {
      console.error(`[Playwright] Taking screenshot: ${screenshotPath}`);
      await page.screenshot({
        path: screenshotPath,
        fullPage: false,
      });
      result.screenshot = screenshotPath;
    }

    console.error(`[Playwright] Search completed in ${result.loadTimeMs}ms`);
    return result;
    
  } catch (error) {
    console.error(`[Playwright] Error: ${error.message}`);
    throw error;
    
  } finally {
    if (browser) {
      console.error('[Playwright] Closing browser...');
      await browser.close();
    }
  }
}

/**
 * Command-line interface
 */
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: node browser-search.js "query" [options]');
    console.error('');
    console.error('Options:');
    console.error('  --extract-text       Extract text content (default: true)');
    console.error('  --screenshot         Take a screenshot');
    console.error('  --screenshot-path    Path for screenshot (default: /tmp/search-screenshot.png)');
    console.error('  --visible            Run in non-headless mode');
    console.error('  --wait-selector      CSS selector to wait for');
    console.error('');
    console.error('Examples:');
    console.error('  node browser-search.js "OpenClaw AI assistant"');
    console.error('  node browser-search.js "https://example.com" --screenshot');
    console.error('  node browser-search.js "crypto prices" --wait-selector ".price-table"');
    process.exit(1);
  }

  const query = args[0];
  const options = {
    extractText: !args.includes('--no-extract-text'),
    takeScreenshot: args.includes('--screenshot'),
    screenshotPath: args.includes('--screenshot-path') 
      ? args[args.indexOf('--screenshot-path') + 1]
      : '/tmp/search-screenshot.png',
    headless: !args.includes('--visible'),
    waitForSelector: args.includes('--wait-selector')
      ? args[args.indexOf('--wait-selector') + 1]
      : null,
  };

  try {
    const result = await browserSearch(query, options);
    
    // Output result as JSON to stdout
    console.log(JSON.stringify(result, null, 2));
    process.exit(0);
    
  } catch (error) {
    const errorResult = {
      error: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString(),
    };
    
    console.log(JSON.stringify(errorResult, null, 2));
    process.exit(1);
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export { browserSearch };
