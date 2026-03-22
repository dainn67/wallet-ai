// commands/capture.js — snapshot, screenshot, text
import { assignRefs } from '../ref-system.js';
import { formatSnapshot, truncateText } from '../output.js';

export async function snapshot(page, args, ctx) {
  const data = await assignRefs(page, ctx.sessionDir);
  return formatSnapshot(data);
}

export async function screenshot(page, args) {
  const path = args[0] || `/tmp/ccpm-screenshot-${Date.now()}.png`;
  await page.screenshot({ path, fullPage: true });
  return { path };
}

export async function text(page, args) {
  let content;
  if (args[0]) {
    const el = page.locator(args[0]);
    content = await el.textContent();
  } else {
    content = await page.innerText('body');
  }
  return { text: truncateText(content) };
}

export const capture = { snapshot, screenshot, text };
