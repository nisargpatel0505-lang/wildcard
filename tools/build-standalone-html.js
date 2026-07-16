const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const sourcePath = path.join(root, 'www', 'index.html');
const outputPath = path.join(root, 'playtest', 'WILDCARD-work-laptop-standalone.html');
const artDir = path.join(root, 'www', 'assets', 'art', 'backgrounds');
const backgrounds = [
  'wildcard-main-menu-palace.webp',
  'wildcard-the-house-boss-room.webp',
  'wildcard-sly-shop-backroom.webp',
  'wildcard-royal-vault-chest-room.webp',
  'wildcard-endless-victory-cosmos.webp',
  'wildcard-theme-neon-heist.webp',
  'wildcard-theme-moonlit-masquerade.webp',
  'wildcard-theme-ember-casino.webp',
  'wildcard-theme-emerald-throne.webp',
  'wildcard-theme-haunted-carnival.webp',
  'wildcard-theme-clockwork-royale.webp'
];
const runtimeAssets = [
  { relative: 'assets/art/wildcard-logo-v692.webp', path: path.join(root, 'www', 'assets', 'art', 'wildcard-logo-v692.webp'), mime: 'image/webp' },
  { relative: 'assets/art/wildcard-logo-boot.webp', path: path.join(root, 'www', 'assets', 'art', 'wildcard-logo-boot.webp'), mime: 'image/webp' },
  { relative: 'assets/art/backgrounds/wildcard-cosmic-base.webp', path: path.join(root, 'www', 'assets', 'art', 'backgrounds', 'wildcard-cosmic-base.webp'), mime: 'image/webp' },
  { relative: 'assets/art/backgrounds/wildcard-cosmic-wilds.webp', path: path.join(root, 'www', 'assets', 'art', 'backgrounds', 'wildcard-cosmic-wilds.webp'), mime: 'image/webp' },
  { relative: 'assets/art/backgrounds/wildcard-menu-keyart.png', path: path.join(root, 'www', 'assets', 'art', 'backgrounds', 'wildcard-menu-keyart.png'), mime: 'image/png' },
  { relative: 'assets/art/sly/sly-expression-grid.webp', path: path.join(root, 'www', 'assets', 'art', 'sly', 'sly-expression-grid.webp'), mime: 'image/webp' },
  { relative: 'assets/art/sly/sly-skins-grid.webp', path: path.join(root, 'www', 'assets', 'art', 'sly', 'sly-skins-grid.webp'), mime: 'image/webp' },
  { relative: 'assets/art/sly/sly-stage-actions-grid.webp', path: path.join(root, 'www', 'assets', 'art', 'sly', 'sly-stage-actions-grid.webp'), mime: 'image/webp' },
  { relative: 'fonts/bungee-regular.ttf', path: path.join(root, 'www', 'fonts', 'bungee-regular.ttf'), mime: 'font/ttf' },
  { relative: 'fonts/space-grotesk-400.ttf', path: path.join(root, 'www', 'fonts', 'space-grotesk-400.ttf'), mime: 'font/ttf' },
  { relative: 'fonts/space-grotesk-500.ttf', path: path.join(root, 'www', 'fonts', 'space-grotesk-500.ttf'), mime: 'font/ttf' },
  { relative: 'fonts/space-grotesk-700.ttf', path: path.join(root, 'www', 'fonts', 'space-grotesk-700.ttf'), mime: 'font/ttf' },
  { relative: 'assets/audio/bit-shift-kevin-macleod-115bpm.mp3', path: path.join(root, 'www', 'assets', 'audio', 'bit-shift-kevin-macleod-115bpm.mp3'), mime: 'audio/mpeg' }
];

const source = fs.readFileSync(sourcePath);
const sourceSha256 = crypto.createHash('sha256').update(source).digest('hex');
let html = source.toString('utf8');

for (const filename of backgrounds) {
  const bytes = fs.readFileSync(path.join(artDir, filename));
  const dataUri = `data:image/webp;base64,${bytes.toString('base64')}`;
  const relative = `assets/art/backgrounds/${filename}`;
  if (!html.includes(relative)) throw new Error(`Canonical HTML does not reference ${relative}`);
  html = html.split(relative).join(dataUri);
}
for (const asset of runtimeAssets) {
  const bytes = fs.readFileSync(asset.path);
  if (!html.includes(asset.relative)) throw new Error(`Canonical HTML does not reference ${asset.relative}`);
  html = html.split(asset.relative).join(`data:${asset.mime};base64,${bytes.toString('base64')}`);
}

const icon = fs.readFileSync(path.join(root, 'www', 'icon-192.png')).toString('base64');
html = html
  .replace('<link rel="manifest" href="/manifest.json">', '')
  .replaceAll('href="/icon-192.png"', `href="data:image/png;base64,${icon}"`)
  .replace(
    '<!DOCTYPE html>',
    `<!DOCTYPE html>\n<!-- GENERATED STANDALONE PLAYTEST. Canonical source: www/index.html - SHA-256 ${sourceSha256} -->`
  );

for (const filename of backgrounds) {
  if (html.includes(`assets/art/backgrounds/${filename}`)) {
    throw new Error(`Standalone file still depends on ${filename}`);
  }
}
for (const asset of runtimeAssets) {
  if (html.includes(asset.relative)) throw new Error(`Standalone file still depends on ${asset.relative}`);
}

fs.writeFileSync(outputPath, html);
console.log(JSON.stringify({
  output: path.relative(root, outputPath),
  source: path.relative(root, sourcePath),
  sourceSha256,
  bytes: Buffer.byteLength(html),
  embeddedBackgrounds: backgrounds.length,
  embeddedIcon: true,
  embeddedRuntimeAssets: runtimeAssets.map(asset => asset.relative)
}, null, 2));
