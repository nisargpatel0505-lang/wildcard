const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const crypto = require('crypto');

const root = path.resolve(__dirname, '..');
const androidDir = path.join(root, 'android');
const assetPath = path.join(androidDir, 'app', 'src', 'main', 'assets', 'public', 'index.html');
const developerRoot = path.join(androidDir, 'app', 'src', 'developer');
const developerAssetPath = path.join(developerRoot, 'assets', 'public', 'index.html');
const builtApk = path.join(androidDir, 'app', 'build', 'outputs', 'apk', 'developer', 'app-developer.apk');
const releaseApk = path.join(root, 'releases', 'WILDCARD-v6.9.11-developer.apk');

function runWindows(command, cwd) {
  const shell = process.env.ComSpec || 'cmd.exe';
  const result = spawnSync(shell, ['/d', '/s', '/c', command], { cwd, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed with exit code ${result.status}`);
}

function insertBefore(html, anchor, addition, label) {
  const at = html.indexOf(anchor);
  if (at < 0) throw new Error(`Developer build anchor missing: ${label}`);
  return html.slice(0, at) + addition + html.slice(at);
}

function makeDeveloperHtml(production) {
  if (production.includes('WILDCARD_DEV_BUILD')) throw new Error('Android asset is already developer-patched');
  if (production.includes('function applyDevCode()')) throw new Error('Production HTML unexpectedly contains developer controls');

  const developerScreen = String.raw`<!-- WILDCARD_DEV_BUILD: this screen exists only in the locally built developer APK. -->
<section class="screen" id="developer">
  <div class="panel" style="max-width:620px">
    <button class="top-back" aria-label="Back" onclick="openSettings()">←</button>
    <h2>Developer Code</h2>
    <p class="sub">Local testing controls. Changes save on this device.</p>
    <div class="dev-balance">Coins: <b id="dev-balance" style="color:var(--gold)">0</b> · Jokers: <b id="dev-jokers" style="color:var(--mint)">0/57</b> · Gauntlet: <b id="dev-gauntlet" style="color:var(--rare)">Locked</b></div>
    <div class="dev-console">
      <input id="dev-code" type="password" placeholder="Enter developer code" autocomplete="off" autocapitalize="none" spellcheck="false">
      <button class="btn alt" onclick="applyDevCode()">Unlock Tools</button>
    </div>
    <div class="dev-status" id="dev-msg">Enter the developer code to continue.</div>
    <div class="dev-tools" id="dev-tools">
      <button class="btn" onclick="devGrantCoins()">+5,000 Coins</button>
      <button class="btn alt" onclick="devUnlockGauntlet()">Unlock Gauntlet</button>
      <button class="btn alt" onclick="devUnlockJokers()">Unlock All Jokers</button>
      <button class="btn ghost" onclick="devResetChestPool()">Reset Joker Chests</button>
      <button class="btn ghost" onclick="devUnlockCosmetics()">Unlock Cosmetics</button>
      <button class="btn ghost" onclick="devResetDaily()">Reset Daily Attempt</button>
      <button class="btn ghost" onclick="devReplayTutorial()">Replay Sly Tutorial</button>
    </div>
    <button class="btn ghost" onclick="openSettings()">Back to Settings</button>
  </div>
</section>

`;

  const developerFunctions = String.raw`// WILDCARD_DEV_BUILD: stripped from production HTML/AAB.
let devAccess=false;
const releaseGauntletUnlocked=gauntletUnlocked;
gauntletUnlocked=function(){ return devAccess||releaseGauntletUnlocked(); };
async function developerCodeValid(code){
  try{
    const bytes=new TextEncoder().encode(String(code||'').trim().toLowerCase());
    const digest=await crypto.subtle.digest('SHA-256',bytes);
    const hex=Array.from(new Uint8Array(digest)).map(v=>v.toString(16).padStart(2,'0')).join('');
    return hex==='7df11fa33b21c72c35d01b5b5606b28c4ec7028a29b2f5c3aa0796e17f744108';
  }catch(e){ return false; }
}
function openDeveloper(){ renderDeveloper(); showScreen('developer'); }
function renderDeveloper(){
  const bal=document.getElementById('dev-balance');
  const jokers=document.getElementById('dev-jokers');
  const gauntlet=document.getElementById('dev-gauntlet');
  const tools=document.getElementById('dev-tools');
  if(bal) bal.textContent=account.coins.toLocaleString();
  if(jokers) jokers.textContent=account.unlocked.size+'/'+JOKERS.length;
  if(gauntlet){ gauntlet.textContent=gauntletUnlocked()?'Open':'Locked'; gauntlet.style.color=gauntletUnlocked()?'var(--mint)':'var(--rare)'; }
  if(tools) tools.style.display=devAccess?'grid':'none';
}
async function applyDevCode(){
  const input=document.getElementById('dev-code');
  const msg=document.getElementById('dev-msg');
  if(await developerCodeValid(input&&input.value)){
    devAccess=true;
    account.coins=Math.max(account.coins,5000);
    account.tutorialDone=true;
    JOKERS.forEach(j=>account.unlocked.add(j.id));
    saveAccount(); updateMenuAccount(); renderDeveloper();
    msg.textContent='Developer access active · 5,000+ coins · Gauntlet and all Jokers unlocked. Best Heat is unchanged.';
    msg.style.color='var(--mint)';
    chord([659,784,988,1319]);
  }else{
    msg.textContent='Invalid code.';
    msg.style.color='var(--coral)';
    tone(160,0.15,'sawtooth',0.04);
  }
  if(input) input.value='';
}
function devGrantCoins(){
  account.coins+=5000; saveAccount(); refreshCoinReadouts(); renderDeveloper();
  toast('+5,000 testing coins','var(--gold)');
}
function devUnlockGauntlet(){
  devAccess=true; renderDeveloper();
  toast('Gauntlet access enabled; Best Heat unchanged','var(--rare)');
}
function devUnlockJokers(){
  JOKERS.forEach(j=>account.unlocked.add(j.id)); account.tutorialDone=true; saveAccount(); renderDeveloper();
  toast('All '+JOKERS.length+' Jokers unlocked','var(--mint)');
}
function devResetChestPool(){
  if(!confirm('Reset paid Joker unlocks on this device so chests can be tested again?')) return;
  account.unlocked=new Set(JOKERS.filter(j=>j.unlock===0).map(j=>j.id)); account.tutorialDone=true;
  saveAccount(); renderDeveloper(); toast('Joker chest pool restored','var(--rare)');
}
function devUnlockCosmetics(){
  COSMETICS.forEach(c=>account.cosmeticsOwned.add(c.id)); saveAccount(); applyCosmetics(); renderDeveloper();
  toast('All cosmetics unlocked','var(--mint)');
}
function devResetDaily(){
  account.dailyRunDate=''; account.dailyBest={date:'',score:0}; saveAccount(); updateMenuAccount(); renderDeveloper();
  toast('Daily attempt reset','var(--mint)');
}
function devReplayTutorial(){ replayTutorial(); }

`;

  const developerSetting = `    +'<div class="set-row"><span class="set-copy"><b>Developer tools</b><small>Local developer APK · code protected</small></span><button class="btn ghost" onclick="openDeveloper()">Open</button></div>'\n`;
  const settingsAnchor = `    +'<div class="set-row"><span class="set-copy"><b>Replay tutorial</b>`;
  const backAnchor = `  if(active.id==='chest'){ showScreen('unlocks'); renderUnlocks(); return true; }`;

  let html = insertBefore(production, '<!-- ============ GAME ============ -->', developerScreen, 'game screen');
  html = insertBefore(html, 'function replayTutorial(){', developerFunctions, 'tutorial replay');
  html = insertBefore(html, settingsAnchor, developerSetting, 'settings row');
  html = insertBefore(html, backAnchor, `  if(active.id==='developer'){ openSettings(); return true; }\n`, 'Android back route');
  return html;
}

runWindows('npm run sync:android', root);
const productionAsset = fs.readFileSync(assetPath, 'utf8');
const developerAsset = makeDeveloperHtml(productionAsset);

if (fs.existsSync(developerRoot)) {
  throw new Error(`Refusing to overwrite existing developer source set: ${developerRoot}`);
}

try {
  fs.mkdirSync(path.dirname(developerAssetPath), { recursive: true });
  fs.writeFileSync(developerAssetPath, developerAsset, 'utf8');
  runWindows('gradlew.bat :app:clean :app:assembleDeveloper --no-daemon', androidDir);
  fs.mkdirSync(path.dirname(releaseApk), { recursive: true });
  fs.copyFileSync(builtApk, releaseApk);
} finally {
  fs.rmSync(developerRoot, { recursive: true, force: true });
}

const apkBytes = fs.readFileSync(releaseApk);
console.log(JSON.stringify({
  output: path.relative(root, releaseApk),
  bytes: apkBytes.length,
  sha256: crypto.createHash('sha256').update(apkBytes).digest('hex'),
  productionAssetUnchanged: fs.readFileSync(assetPath, 'utf8') === productionAsset,
  developerOverlayRemoved: !fs.existsSync(developerRoot)
}, null, 2));
