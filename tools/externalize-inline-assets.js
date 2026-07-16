const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = path.resolve(__dirname, '..');
const htmlPath = path.join(root, 'www', 'index.html');
const mappings = [
  ['font/ttf', 'fonts/bungee-regular.ttf', 110456, true],
  ['font/ttf', 'fonts/space-grotesk-400.ttf', 69360, true],
  ['font/ttf', 'fonts/space-grotesk-500.ttf', 69416, true],
  ['font/ttf', 'fonts/space-grotesk-700.ttf', 69308, true],
  ['image/webp', 'assets/art/backgrounds/wildcard-cosmic-base.webp', 32442, false],
  ['image/webp', 'assets/art/sly/sly-expression-grid.webp', 161504, false],
  ['image/webp', 'assets/art/backgrounds/wildcard-cosmic-wilds.webp', 26972, false],
  ['image/webp', 'assets/art/sly/sly-skins-grid.webp', 183772, false],
  ['image/webp', 'assets/art/sly/sly-stage-actions-grid.webp', 106298, false],
  ['image/png', 'assets/art/backgrounds/wildcard-menu-keyart.png', 2041768, false],
  ['image/webp', 'assets/art/wildcard-logo-boot.webp', 88808, false],
];

const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
let html = fs.readFileSync(htmlPath, 'utf8');
const matches = [...html.matchAll(/data:([^;,]+);base64,([A-Za-z0-9+/=]+)/g)];

if (matches.length === 0) {
  const missing = mappings.filter(([, rel]) => !fs.existsSync(path.join(root, 'www', rel)));
  if (missing.length) throw new Error(`HTML is externalized but ${missing.length} mapped assets are missing`);
  console.log(JSON.stringify({ alreadyExternalized: true, assets: mappings.length }, null, 2));
  process.exit(0);
}
if (matches.length !== mappings.length) throw new Error(`Expected ${mappings.length} Base64 assets, found ${matches.length}`);

const written = [];
matches.forEach((match, index) => {
  const [expectedMime, rel, expectedBytes, mustExist] = mappings[index];
  const mime = match[1];
  const bytes = Buffer.from(match[2], 'base64');
  if (mime !== expectedMime) throw new Error(`Asset ${index + 1}: expected ${expectedMime}, found ${mime}`);
  if (bytes.length !== expectedBytes) throw new Error(`Asset ${index + 1}: expected ${expectedBytes} bytes, found ${bytes.length}`);
  const target = path.join(root, 'www', rel);
  if (mustExist) {
    if (!fs.existsSync(target)) throw new Error(`Expected existing asset is missing: ${rel}`);
    const existing = fs.readFileSync(target);
    if (sha(existing) !== sha(bytes)) throw new Error(`Existing asset differs from inline payload: ${rel}`);
  } else {
    fs.mkdirSync(path.dirname(target), { recursive: true });
    if (fs.existsSync(target) && sha(fs.readFileSync(target)) !== sha(bytes)) throw new Error(`Refusing to overwrite different asset: ${rel}`);
    fs.writeFileSync(target, bytes);
  }
  html = html.replace(match[0], rel.replace(/\\/g, '/'));
  written.push({ path: rel, bytes: bytes.length, sha256: sha(bytes) });
});

fs.writeFileSync(htmlPath, html, 'utf8');
console.log(JSON.stringify({ htmlBytes: Buffer.byteLength(html), assets: written }, null, 2));
