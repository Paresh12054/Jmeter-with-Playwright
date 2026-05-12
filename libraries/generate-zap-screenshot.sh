#!/bin/bash

node <<'EOF'
const { chromium } = require('playwright');
const path = require('path');

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

  const htmlPath = 'file://' + path.resolve('zap-report.html');

  await page.goto(htmlPath, {
    waitUntil: 'networkidle'
  });

  await page.screenshot({
    path: 'zap-report.png',
    fullPage: true
  });

  await browser.close();

  console.log('ZAP screenshot created');

})();
EOF
