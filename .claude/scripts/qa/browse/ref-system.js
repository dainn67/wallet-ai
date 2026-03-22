// ref-system.js — Parse accessibility tree, assign @e1..@eN refs to interactive elements
// AD-2: Ref system via ariaSnapshot (Playwright 1.58+)
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { resolve } from 'path';

const INTERACTIVE_ROLES = new Set([
  'button', 'link', 'textbox', 'checkbox', 'combobox',
  'menuitem', 'tab', 'radio', 'switch', 'slider',
  'searchbox', 'spinbutton', 'option', 'menuitemcheckbox',
  'menuitemradio',
]);

// In-memory ref map for current process
let refMap = new Map();

export function getRefMap() {
  return refMap;
}

function parseAriaLine(line) {
  // Parse lines like: - button "Submit"
  //                    - textbox "Username":
  //                    - link "Home":
  //                    - checkbox "I agree to the terms"
  //                    - combobox "Role":
  //                    - option "Admin" [selected]
  const match = line.match(/^(\s*)-\s+(\w+)(?:\s+"([^"]*)")?/);
  if (!match) return null;
  const indent = match[1].length;
  const role = match[2];
  const name = match[3] || '';
  return { indent, role, name };
}

export async function assignRefs(page, sessionDir) {
  refMap = new Map();
  const snap = await page.locator(':root').ariaSnapshot();

  const refs = [];
  let counter = 0;
  const lines = snap.split('\n');

  for (const line of lines) {
    const parsed = parseAriaLine(line);
    if (!parsed) continue;
    if (!INTERACTIVE_ROLES.has(parsed.role)) continue;

    counter++;
    const refId = `@e${counter}`;
    const ref = {
      id: refId,
      role: parsed.role,
      name: parsed.name,
    };
    refs.push(ref);
    refMap.set(refId, ref);
  }

  // Persist refs to session dir for cross-invocation use
  if (sessionDir) {
    const refFile = resolve(sessionDir, 'refs.json');
    writeFileSync(refFile, JSON.stringify(refs, null, 2));
  }

  // Build annotated tree (compact)
  const annotated = buildAnnotatedTree(snap, refs);

  return { refs, tree: annotated };
}

function buildAnnotatedTree(snap, refs) {
  let refIdx = 0;
  const lines = snap.split('\n');
  const result = [];

  for (const line of lines) {
    const parsed = parseAriaLine(line);
    if (parsed && INTERACTIVE_ROLES.has(parsed.role) && refIdx < refs.length) {
      // Insert ref annotation
      const ref = refs[refIdx];
      const annotated = line.replace(
        /^(\s*-\s+\w+)/,
        `$1 ${ref.id}`
      );
      result.push(annotated);
      refIdx++;
    } else {
      // Skip non-interactive static content for brevity
      // But keep structural elements (headings, navigation, document)
      if (parsed && ['document', 'heading', 'navigation', 'contentinfo', 'main', 'banner', 'complementary', 'form', 'region'].includes(parsed.role)) {
        result.push(line);
      } else if (!parsed && line.trim().startsWith('- /')) {
        // Skip property lines like /url:, /placeholder:
        continue;
      } else if (!parsed && line.trim().startsWith('- text:')) {
        // Skip static text nodes
        continue;
      } else if (parsed && INTERACTIVE_ROLES.has(parsed.role)) {
        result.push(line);
      }
    }
  }

  return result.join('\n');
}

export function loadRefs(sessionDir) {
  refMap = new Map();
  try {
    const refFile = resolve(sessionDir, 'refs.json');
    const refs = JSON.parse(readFileSync(refFile, 'utf-8'));
    for (const ref of refs) {
      refMap.set(ref.id, ref);
    }
    return refs;
  } catch {
    return [];
  }
}

export function resolveRef(refId, sessionDir) {
  // Try in-memory first, then load from file
  if (refMap.size === 0 && sessionDir) {
    loadRefs(sessionDir);
  }
  const ref = refMap.get(refId);
  if (!ref) {
    throw new Error(`Ref ${refId} not found. Run snapshot first to get current refs.`);
  }
  return ref;
}

export async function getLocator(page, refId, sessionDir) {
  const ref = resolveRef(refId, sessionDir);
  const name = ref.name || undefined;
  return page.getByRole(ref.role, name ? { name, exact: false } : {});
}
