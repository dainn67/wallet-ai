// index.js — Entry point for ccpm-browse Node.js module
// AD-1: Shell wrapper delegates here: node index.js SESSION COMMAND ARGS...
import { getContext, sessionDir, savePageState, loadPageState } from './session.js';
import { navigation } from './commands/navigation.js';
import { capture } from './commands/capture.js';
import { interaction } from './commands/interaction.js';
import { inspection } from './commands/inspection.js';

const [,, session, command, ...args] = process.argv;

const commands = {
  ...navigation,
  ...capture,
  ...interaction,
  console: inspection.console,
  network: inspection.network,
  links: inspection.links,
  forms: inspection.forms,
};

// Commands that navigate to a new URL (save state after)
const NAV_COMMANDS = new Set(['goto', 'back', 'reload']);
// Commands that need a page loaded first
const PAGE_COMMANDS = new Set([
  'snapshot', 'screenshot', 'text', 'click', 'fill', 'select',
  'hover', 'press', 'console', 'network', 'links', 'forms',
]);

if (!command || !commands[command]) {
  console.log(JSON.stringify({
    success: false,
    error: `Unknown command: ${command}`,
    data: null,
  }));
  process.exit(1);
}

const sessionName = session || 'default';
const sDir = sessionDir(sessionName);

let ctx;
try {
  ctx = await getContext(sessionName);
  const page = ctx.pages()[0] || await ctx.newPage();

  // Set up console/network listeners for inspection commands
  inspection.setupListeners(page);

  // Restore page state for non-goto commands
  if (PAGE_COMMANDS.has(command)) {
    const state = loadPageState(sessionName);
    if (state && state.url) {
      await page.goto(state.url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    }
  }

  // Context object passed to commands that need session state
  const cmdCtx = { sessionDir: sDir, sessionName };

  const result = await commands[command](page, args, cmdCtx);

  // Save page URL after navigation
  if (NAV_COMMANDS.has(command) || command === 'click') {
    savePageState(sessionName, page.url());
  }

  console.log(JSON.stringify({ success: true, error: null, data: result }));
  await ctx.close();
} catch (e) {
  console.log(JSON.stringify({ success: false, error: e.message, data: null }));
  if (ctx) {
    try { await ctx.close(); } catch {}
  }
  process.exit(1);
}
