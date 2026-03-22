// session.js — Persistent browser context via Playwright storage state
// AD-3: Per-command sessions stored at .claude/qa/sessions/{name}/
import { chromium } from '@playwright/test';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));

function findProjectRoot() {
  let dir = __dirname;
  while (dir !== '/' && !existsSync(resolve(dir, '.claude'))) {
    dir = dirname(dir);
  }
  return dir === '/' ? __dirname : dir;
}

const PROJECT_ROOT = findProjectRoot();

export function sessionDir(name) {
  const dir = resolve(PROJECT_ROOT, '.claude/qa/sessions', name);
  mkdirSync(dir, { recursive: true });
  return dir;
}

export async function getContext(sessionName) {
  const userDataDir = sessionDir(sessionName);
  const ctx = await chromium.launchPersistentContext(userDataDir, {
    headless: true,
    args: ['--no-sandbox', '--disable-gpu'],
    viewport: { width: 1280, height: 720 },
  });
  return ctx;
}

// Save current URL so next invocation can restore page state
export function savePageState(sessionName, url) {
  const dir = sessionDir(sessionName);
  const stateFile = resolve(dir, 'page-state.json');
  writeFileSync(stateFile, JSON.stringify({ url, savedAt: new Date().toISOString() }));
}

export function loadPageState(sessionName) {
  const dir = sessionDir(sessionName);
  const stateFile = resolve(dir, 'page-state.json');
  try {
    return JSON.parse(readFileSync(stateFile, 'utf-8'));
  } catch {
    return null;
  }
}

export async function cleanSession(name) {
  const { rmSync } = await import('fs');
  const dir = sessionDir(name);
  rmSync(dir, { recursive: true, force: true });
}
