// commands/interaction.js — click, fill, select, hover, press
import { getLocator } from '../ref-system.js';

export async function click(page, args, ctx) {
  const ref = args[0];
  if (!ref) throw new Error('Ref required. Usage: click @e1');
  const locator = await getLocator(page, ref, ctx.sessionDir);
  await locator.click({ timeout: 5000 });
  return { clicked: ref, url: page.url() };
}

export async function fill(page, args, ctx) {
  const ref = args[0];
  const value = args.slice(1).join(' ');
  if (!ref || !value) throw new Error('Ref and value required. Usage: fill @e1 "text"');
  const locator = await getLocator(page, ref, ctx.sessionDir);
  await locator.fill(value, { timeout: 5000 });
  return { filled: ref, value };
}

export async function select(page, args, ctx) {
  const ref = args[0];
  const value = args[1];
  if (!ref || !value) throw new Error('Ref and value required. Usage: select @e1 "option"');
  const locator = await getLocator(page, ref, ctx.sessionDir);
  await locator.selectOption(value, { timeout: 5000 });
  return { selected: ref, value };
}

export async function hover(page, args, ctx) {
  const ref = args[0];
  if (!ref) throw new Error('Ref required. Usage: hover @e1');
  const locator = await getLocator(page, ref, ctx.sessionDir);
  await locator.hover({ timeout: 5000 });
  return { hovered: ref };
}

export async function press(page, args) {
  const key = args[0];
  if (!key) throw new Error('Key required. Usage: press Enter');
  await page.keyboard.press(key);
  return { pressed: key };
}

export const interaction = { click, fill, select, hover, press };
