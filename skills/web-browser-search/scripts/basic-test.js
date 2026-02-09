#!/usr/bin/env node
/**
 * Basic Playwright Test - No Network Required
 * 
 * Tests that Playwright can launch and work with local HTML content.
 * This test doesn't require network access.
 */

import { chromium } from 'playwright';

console.log('='.repeat(60));
console.log('Playwright Basic Test (No Network)');
console.log('='.repeat(60));
console.log('');

async function testPlaywright() {
  let browser = null;
  const startTime = Date.now();
  
  try {
    console.log('✓ Starting test...');
    console.log('✓ Launching Chromium (headless)...');
    
    browser = await chromium.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
      ],
    });
    
    console.log('✓ Browser launched successfully');

    const context = await browser.newContext({
      viewport: { width: 1280, height: 720 },
    });

    const page = await context.newPage();
    
    // Test with local HTML content (no network required)
    console.log('✓ Creating test page with local HTML...');
    await page.setContent(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Test Page for JASPER</title>
        </head>
        <body>
          <h1>Playwright Integration Test</h1>
          <p>This is a test page to verify browser automation works.</p>
          <div id="test-content">Content extracted successfully!</div>
        </body>
      </html>
    `);

    const title = await page.title();
    console.log(`✓ Page title: "${title}"`);

    // Extract content
    const content = await page.evaluate(() => {
      return document.querySelector('#test-content')?.textContent || '';
    });
    console.log(`✓ Content extracted: "${content}"`);

    // Take a screenshot
    const screenshotPath = '/tmp/playwright-basic-test.png';
    await page.screenshot({ path: screenshotPath });
    console.log(`✓ Screenshot saved: ${screenshotPath}`);

    const loadTime = Date.now() - startTime;
    console.log(`✓ Test completed in ${loadTime}ms`);

    console.log('');
    console.log('='.repeat(60));
    console.log('✅ SUCCESS: Playwright is working correctly!');
    console.log('='.repeat(60));
    console.log('');
    console.log('Browser automation capabilities verified:');
    console.log('  ✓ Browser launch');
    console.log('  ✓ Page creation');
    console.log('  ✓ Content rendering');
    console.log('  ✓ JavaScript evaluation');
    console.log('  ✓ Screenshot capture');
    console.log('');
    console.log('The browser is ready for use in OpenClaw/JASPER!');
    console.log('');
    
    return true;
    
  } catch (error) {
    console.log('');
    console.log('='.repeat(60));
    console.log(`❌ FAILED: ${error.message}`);
    console.log('='.repeat(60));
    console.error(error.stack);
    return false;
    
  } finally {
    if (browser) {
      await browser.close();
      console.log('✓ Browser closed cleanly');
    }
  }
}

testPlaywright().then((success) => {
  process.exit(success ? 0 : 1);
});
