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
  'wildcard-endless-victory-cosmos.webp'
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

const icon = fs.readFileSync(path.join(root, 'www', 'icon-192.png')).toString('base64');
html = html
  .replace('<link rel="manifest" href="/manifest.json">', '')
  .replaceAll('href="/icon-192.png"', `href="data:image/png;base64,${icon}"`)
  .replace(
    '<!DOCTYPE html>',
    `<!DOCTYPE html>\n<!-- GENERATED STANDALONE PLAYTEST. Canonical source: www/index.html · SHA-256 ${sourceSha256} -->`
  );

for (const filename of backgrounds) {
  if (html.includes(`assets/art/backgrounds/${filename}`)) {
    throw new Error(`Standalone file still depends on ${filename}`);
  }
}

fs.writeFileSync(outputPath, html);
console.log(JSON.stringify({
  output: path.relative(root, outputPath),
  source: path.relative(root, sourcePath),
  sourceSha256,
  bytes: Buffer.byteLength(html),
  embeddedBackgrounds: backgrounds.length,
  embeddedIcon: true
}, null, 2));
