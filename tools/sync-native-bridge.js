'use strict';

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const indexPath = path.join(root, 'www', 'index.html');
const bridgePath = path.join(root, 'www', 'native-bridge.js');
const startMarker = '/* WILDCARD native bridge for the Capacitor Android shell.';
const endMarker = '\n})();';

function bridgeRange(html) {
  const start = html.indexOf(startMarker);
  if (start < 0) throw new Error('Native bridge start marker is missing from www/index.html');
  const endStart = html.indexOf(endMarker, start);
  if (endStart < 0) throw new Error('Native bridge end marker is missing from www/index.html');
  return { start, end: endStart + endMarker.length };
}

function bridgeFromIndex(html) {
  const range = bridgeRange(html);
  return html.slice(range.start, range.end) + '\n';
}

const mode = process.argv[2] || '--check';
const html = fs.readFileSync(indexPath, 'utf8');

if (mode === '--from-index') {
  fs.writeFileSync(bridgePath, bridgeFromIndex(html));
  console.log('Copied inline native bridge to www/native-bridge.js.');
} else if (mode === '--to-index') {
  const bridge = fs.readFileSync(bridgePath, 'utf8').trimEnd();
  if (!bridge.startsWith(startMarker) || !bridge.endsWith('})();')) {
    throw new Error('www/native-bridge.js does not contain the expected complete bridge');
  }
  const range = bridgeRange(html);
  const next = html.slice(0, range.start) + bridge + html.slice(range.end);
  fs.writeFileSync(indexPath, next);
  console.log('Copied www/native-bridge.js into the canonical inline bridge.');
} else if (mode === '--check') {
  const actual = fs.readFileSync(bridgePath, 'utf8').trim();
  const expected = bridgeFromIndex(html).trim();
  if (actual !== expected) throw new Error('Inline bridge and www/native-bridge.js have drifted');
  console.log('Native bridge copies are byte-identical.');
} else {
  throw new Error('Use --check, --from-index or --to-index');
}
