import { test, expect, Page } from '@playwright/test';

test('Fill and submit Text Box form', async ({ page }: { page: Page }) => {
  // Navigate to the page
  await page.goto('https://xqa.io/practice/text-box');

  // Fill the form
  await page.locator('#userName').fill('John Doe');
  await page.locator('#userEmail').fill('john@example.com');
  await page.locator('#currentAddress').fill('123 Main Street');
  await page.locator('#permanentAddress').fill('456 Secondary Street');

  // Click submit
  await page.locator('#submit').click();

  // Assertions
  //await expect(page.locator('#name')).toContainText('John Doe');
 // await expect(page.locator('#email')).toContainText('john@example.com');
//  await expect(page.locator('#currentAddress')).toContainText('123 Main Street');
  //await expect(page.locator('#permanentAddress')).toContainText('456 Secondary Street');
});