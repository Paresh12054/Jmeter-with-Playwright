#!/bin/bash

node <<'EOF'
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

(async () => {

  const browser = await chromium.launch({
    headless: true
  });

  const page = await browser.newPage({
    viewport: {
      width: 1600,
      height: 900
    }
  });

  const reports = fs.readdirSync('.')
    .filter(f => f.startsWith('playwright-report-'))
    .sort();

  if (reports.length === 0) {
    console.error('No playwright-report-* directory found');
    process.exit(1);
  }

  const latestReport = reports[reports.length - 1];

  console.log(`Using report: ${latestReport}`);

  const htmlPath =
    'file://' + path.resolve(`${latestReport}/index.html`);

  await page.goto(htmlPath, {
    waitUntil: 'networkidle'
  });

  await page.screenshot({
    path: 'playwright-report.png',
    fullPage: true
  });

  await browser.close();

  console.log('Playwright screenshot created');

})();
EOF
