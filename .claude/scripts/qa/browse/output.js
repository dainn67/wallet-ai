// output.js — Token-optimized output formatter
// NFR-2: Snapshot output must be <500 tokens for typical page

const DEFAULT_MAX_TOKENS = 500;
const CHARS_PER_TOKEN = 4; // conservative estimate

export function estimateTokens(text) {
  if (!text) return 0;
  const words = text.split(/\s+/).filter(Boolean).length;
  return Math.ceil(words * 1.3);
}

export function truncateText(text, maxChars = 2000) {
  if (!text || text.length <= maxChars) return text;
  return text.slice(0, maxChars) + '... (truncated)';
}

export function formatSnapshot(snapshotData, maxTokens = DEFAULT_MAX_TOKENS) {
  // Only include interactive elements with refs (token-efficient)
  const { refs, tree } = snapshotData;
  const refSummary = refs.map(r => {
    let line = `${r.id} ${r.role}`;
    if (r.name) line += ` "${r.name}"`;
    if (r.value !== undefined) line += ` val="${r.value}"`;
    if (r.checked !== undefined) line += ` checked=${r.checked}`;
    return line;
  }).join('\n');

  const tokens = estimateTokens(refSummary);
  if (tokens <= maxTokens) {
    return { refs, tree: refSummary, tokenEstimate: tokens };
  }

  // Truncate if over budget — keep as many refs as fit
  const lines = refSummary.split('\n');
  let result = '';
  for (const line of lines) {
    const candidate = result ? result + '\n' + line : line;
    if (estimateTokens(candidate) > maxTokens) break;
    result = candidate;
  }
  const finalTokens = estimateTokens(result);
  return {
    refs: refs.slice(0, result.split('\n').length),
    tree: result + `\n... (${refs.length - result.split('\n').length} more refs truncated)`,
    tokenEstimate: finalTokens,
  };
}

export function formatOutput(data) {
  return data;
}
