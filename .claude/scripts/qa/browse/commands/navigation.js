// commands/navigation.js — goto, back, reload

export async function goto(page, args) {
  const url = args[0];
  if (!url) throw new Error('URL required. Usage: goto URL');
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  return { url: page.url(), title: await page.title() };
}

export async function back(page) {
  await page.goBack({ waitUntil: 'domcontentloaded' });
  return { url: page.url(), title: await page.title() };
}

export async function reload(page) {
  await page.reload({ waitUntil: 'domcontentloaded' });
  return { url: page.url(), title: await page.title() };
}

export const navigation = { goto, back, reload };
