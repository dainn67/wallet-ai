// commands/inspection.js — console, network, links, forms

// Console messages collected during page lifecycle
const consoleMessages = [];
const networkFailures = [];

export function setupListeners(page) {
  page.on('console', msg => {
    if (msg.type() === 'error' || msg.type() === 'warning') {
      consoleMessages.push({
        type: msg.type(),
        message: msg.text(),
        source: msg.location()?.url || '',
      });
    }
  });

  page.on('requestfailed', req => {
    networkFailures.push({
      url: req.url(),
      method: req.method(),
      error: req.failure()?.errorText || 'unknown',
    });
  });
}

export async function console_(page) {
  // Also capture any errors that fired before listeners were set up
  // by evaluating the page for error indicators
  return { errors: [...consoleMessages] };
}

export async function network(page) {
  return { failures: [...networkFailures] };
}

export async function links(page) {
  const allLinks = await page.$$eval('a[href]', anchors =>
    anchors.map(a => ({
      text: a.textContent?.trim().slice(0, 80) || '',
      href: a.href,
    }))
  );

  // Check for obviously broken hrefs (javascript:void, empty, #)
  const broken = [];
  const valid = [];
  for (const link of allLinks) {
    if (!link.href || link.href === 'about:blank' ||
        link.href.startsWith('javascript:') ||
        link.href.includes('404') ||
        link.href.includes('broken')) {
      broken.push(link);
    } else {
      valid.push(link);
    }
  }

  return { total: allLinks.length, valid: valid.length, broken, links: allLinks };
}

export async function forms(page) {
  const formData = await page.$$eval('form', forms =>
    forms.map((form, i) => {
      const inputs = Array.from(form.querySelectorAll('input, select, textarea')).map(el => ({
        tag: el.tagName.toLowerCase(),
        type: el.type || '',
        name: el.name || '',
        id: el.id || '',
        required: el.required || false,
        value: el.value || '',
      }));
      return {
        index: i,
        action: form.action || '',
        method: form.method || 'get',
        inputs,
      };
    })
  );

  return { count: formData.length, forms: formData };
}

export const inspection = {
  console: console_,
  network,
  links,
  forms,
  setupListeners,
};
