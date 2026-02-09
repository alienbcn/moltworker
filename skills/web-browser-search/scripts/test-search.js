#!/usr/bin/env node
/**
 * Smoke Test for Web Browser Search
 * 
 * Tests both Brave API (if available) and Playwright browser automation.
 * Validates that the browser can launch, navigate, and extract content.
 * 
 * Usage:
 *   node test-search.js
 */

import { chromium } from 'playwright';

const TEST_URL = 'https://www.google.com/search?q=google.com';
const TIMEOUT = 30000;

console.log('='.repeat(60));
console.log('Web Browser Search - Smoke Test');
console.log('='.repeat(60));
console.log('');

/**
 * Test Brave Search API
 */
async function testBraveAPI() {
  console.log('🔍 Test 1: Brave Search API');
  console.log('-'.repeat(60));
  
  const apiKey = process.env.BRAVE_SEARCH_API_KEY;
  
  if (!apiKey) {
    console.log('⚠️  BRAVE_SEARCH_API_KEY not set - skipping Brave API test');
    console.log('   This is OK - Playwright will be used as fallback');
    return { skipped: true };
  }

  try {
    console.log('   Making request to Brave Search API...');
    const response = await fetch('https://api.search.brave.com/res/v1/web/search?q=test', {
      headers: {
        'X-Subscription-Token': apiKey,
        'Accept': 'application/json',
      },
    });

    if (response.ok) {
      const data = await response.json();
      console.log(`✅ Brave API working! Found ${data.web?.results?.length || 0} results`);
      return { success: true, resultCount: data.web?.results?.length || 0 };
    } else {
      console.log(`❌ Brave API returned status ${response.status}: ${response.statusText}`);
      return { success: false, error: `HTTP ${response.status}` };
    }
  } catch (error) {
    console.log(`❌ Brave API error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Test Playwright Browser Automation
 */
async function testPlaywright() {
  console.log('');
  console.log('🌐 Test 2: Playwright Browser Automation');
  console.log('-'.repeat(60));
  
  let browser = null;
  const startTime = Date.now();
  
  try {
    console.log('   Launching Chromium (headless)...');
    browser = await chromium.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--no-first-run',
        '--no-zygote',
        '--single-process',
      ],
    });
    console.log('   ✓ Browser launched successfully');

    const context = await browser.newContext({
      viewport: { width: 1280, height: 720 },
    });

    const page = await context.newPage();
    page.setDefaultTimeout(TIMEOUT);
    
    console.log(`   Navigating to ${TEST_URL}...`);
    await page.goto(TEST_URL, { waitUntil: 'domcontentloaded' });
    console.log('   ✓ Page loaded');

    // Wait a bit for dynamic content
    await page.waitForTimeout(2000);

    const title = await page.title();
    const url = page.url();
    const loadTime = Date.now() - startTime;

    console.log(`   ✓ Page title: "${title}"`);
    console.log(`   ✓ Final URL: ${url}`);
    console.log(`   ✓ Load time: ${loadTime}ms`);

    // Try to extract some content
    const hasContent = await page.evaluate(() => {
      const body = document.body.textContent || '';
      return body.length > 100;
    });

    if (hasContent) {
      console.log('   ✓ Content extracted successfully');
    } else {
      console.log('   ⚠️  Content extraction incomplete');
    }

    // Take a screenshot
    const screenshotPath = '/tmp/smoke-test-screenshot.png';
    await page.screenshot({ path: screenshotPath });
    console.log(`   ✓ Screenshot saved: ${screenshotPath}`);

    console.log('');
    console.log('✅ Playwright test PASSED');
    
    return {
      success: true,
      title,
      url,
      loadTimeMs: loadTime,
      screenshot: screenshotPath,
    };
    
  } catch (error) {
    console.log('');
    console.log(`❌ Playwright test FAILED: ${error.message}`);
    console.error(error.stack);
    return { success: false, error: error.message };
    
  } finally {
    if (browser) {
      await browser.close();
      console.log('   ✓ Browser closed');
    }
  }
}

/**
 * Main test runner
 */
async function main() {
  const results = {
    timestamp: new Date().toISOString(),
    tests: {},
  };

  // Test 1: Brave API (optional)
  results.tests.brave = await testBraveAPI();

  // Test 2: Playwright (required)
  results.tests.playwright = await testPlaywright();

  // Summary
  console.log('');
  console.log('='.repeat(60));
  console.log('Test Summary');
  console.log('='.repeat(60));
  
  const braveStatus = results.tests.brave.skipped ? '⚠️  SKIPPED' : 
                      results.tests.brave.success ? '✅ PASSED' : '❌ FAILED';
  const playwrightStatus = results.tests.playwright.success ? '✅ PASSED' : '❌ FAILED';
  
  console.log(`Brave API:           ${braveStatus}`);
  console.log(`Playwright Browser:  ${playwrightStatus}`);
  console.log('');

  if (results.tests.playwright.success) {
    console.log('🎉 Web Browser Search is OPERATIONAL');
    console.log('');
    console.log('Next steps:');
    console.log('1. Test with: node browser-search.js "your search query"');
    console.log('2. View screenshot: open /tmp/smoke-test-screenshot.png');
    console.log('3. Use in OpenClaw agents for web scraping');
    console.log('');
    process.exit(0);
  } else {
    console.log('⚠️  Web Browser Search has issues');
    console.log('');
    console.log('Troubleshooting:');
    console.log('1. Check Playwright installation: npx playwright --version');
    console.log('2. Install browsers: npx playwright install chromium');
    console.log('3. Check logs: /root/openclaw-startup.log');
    console.log('4. Verify system dependencies are installed');
    console.log('');
    process.exit(1);
  }
}

main();
