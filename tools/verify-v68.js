const fs = require('fs');
const crypto = require('crypto');
const vm = require('vm');

const html = fs.readFileSync('www/index.html', 'utf8');
const rules = fs.readFileSync('firestore.rules', 'utf8');
const cloudPlugin = fs.readFileSync('android/app/src/main/java/com/nisarg/wildcard/WildcardCloudPlugin.java', 'utf8');
const mainActivity = fs.readFileSync('android/app/src/main/java/com/nisarg/wildcard/MainActivity.java', 'utf8');
const serviceWorker = fs.readFileSync('www/sw.js', 'utf8');
const standalonePath = 'playtest/WILDCARD-work-laptop-standalone.html';
const standalone = fs.readFileSync(standalonePath, 'utf8');
const backgroundDir = 'www/assets/art/backgrounds';
const backgrounds = [
  'wildcard-main-menu-palace.webp',
  'wildcard-the-house-boss-room.webp',
  'wildcard-sly-shop-backroom.webp',
  'wildcard-royal-vault-chest-room.webp',
  'wildcard-endless-victory-cosmos.webp'
];

function assert(ok, message) { if (!ok) throw new Error(message); }
function block(start, end) {
  const a=html.indexOf(start), b=html.indexOf(end,a+start.length);
  assert(a>=0&&b>a, `Missing block: ${start}`);
  return html.slice(a,b);
}

const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)];
scripts.forEach(m=>{ if(m[1].trim()) new Function(m[1]); });
const ids=[...html.matchAll(/\sid="([^"]+)"/g)].map(m=>m[1]);
assert(new Set(ids).size===ids.length,'Duplicate HTML ids');
assert(!/<script[^>]+src=/i.test(html),'External script dependency remains');
assert(html.includes('>v6.9.1</b>'),'Public version label is not v6.9.1');

// Artwork remains small in the APK, while the optional desktop playtest embeds
// it into one portable file generated from this exact canonical HTML.
for (const filename of backgrounds) {
  const path=`${backgroundDir}/${filename}`;
  assert(fs.existsSync(path),`Missing runtime artwork: ${filename}`);
  assert(fs.statSync(path).size<300_000,`Runtime artwork is too large: ${filename}`);
  assert(html.includes(`assets/art/backgrounds/${filename}`),`Runtime artwork is not wired into HTML: ${filename}`);
  assert(serviceWorker.includes(`/assets/art/backgrounds/${filename}`),`Runtime artwork is not available to the offline PWA: ${filename}`);
  assert(!standalone.includes(`assets/art/backgrounds/${filename}`),`Standalone still has an external artwork path: ${filename}`);
}
const htmlSha256=crypto.createHash('sha256').update(Buffer.from(html)).digest('hex');
assert(standalone.includes(`Canonical source: www/index.html - SHA-256 ${htmlSha256}`),'Standalone provenance does not match current HTML');
assert((standalone.match(/data:image\/webp;base64,/g)||[]).length>=backgrounds.length,'Standalone artwork is not embedded');
assert(Buffer.byteLength(standalone)<7_000_000,'Standalone playtest exceeds 7 MB');
assert(standalone.includes('>v6.9.1</b>'),'Standalone public version is not v6.9.1');

// Optional account/cloud save and official Play Games integration.
assert(html.includes('function cloudSignIn()'),'Google sign-in control missing');
assert(html.includes('function reconcileCloudAccount(user,announce)'),'No-reset cloud reconciliation missing');
assert(html.includes('function scheduleCloudSave()'),'Cloud checkpoint scheduling missing');
assert(html.includes('function openOfficialLeaderboard()'),'Official leaderboard control missing');
assert(html.includes('WN.loadPlayGamesLeaderboard(span)'),'In-game Play Games leaderboard fallback missing');
assert(html.includes('function capturePlayGamesCode'),'Safe Play Games diagnostic capture missing');
assert(html.includes('function playGamesUserMessage'),'Actionable Play Games diagnostic messages missing');
assert(html.includes('Optional Google account & cloud backup'),'Cloud privacy disclosure missing');
assert(cloudPlugin.includes('GoogleAuthProvider.getCredential'),'Firebase Google credential exchange missing');
assert(cloudPlugin.includes('GetSignInWithGoogleOption'),'Explicit Google sign-in button flow missing');
assert(cloudPlugin.includes('postDelayed(timeout, 15_000L)'),'Google sign-in anti-freeze timeout missing');
assert(cloudPlugin.includes('submitScoreImmediate'),'Play Games score submission missing');
assert(cloudPlugin.includes('loadTopScores'),'In-game official leaderboard data load missing');
assert(cloudPlugin.includes('rejectPlayGames'),'Native Play Games diagnostic bridge missing');
assert(cloudPlugin.includes('GamesClientStatusCodes.getStatusCodeString'),'Documented Play Games status mapping missing');
assert(mainActivity.includes('WindowInsetsCompat.Type.systemBars()'),'Immersive Android system-bar hiding missing');
assert(mainActivity.includes('BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE'),'Transient system-bar gesture behavior missing');
assert(rules.includes("request.auth.uid == uid"),'Firestore owner check missing');
assert(rules.includes("allow delete: if false"),'Firestore cloud-save deletion is not denied');
assert(rules.includes("hasOnlyAllowedFields"),'Firestore field allowlist missing');

const cloudCode=block('/* ===================== v6.9.1 optional Google cloud save ===================== */','const account = {');
const cloudCtx={
  console, Date, Set, JSON, Number, String, Object, Array, Math, Promise,
  savedStamp(raw){try{return Number(JSON.parse(raw||'')._savedAt)||0;}catch(e){return 0;}},
  setTimeout(){return 0;},clearTimeout(){},window:{},document:{getElementById(){return null;}},localStorage:{getItem(){return null;},setItem(){},removeItem(){}}
};
vm.createContext(cloudCtx);
vm.runInContext(cloudCode+';globalThis.__merge=mergeAccountSaves;',cloudCtx);
const merged=JSON.parse(cloudCtx.__merge(
  JSON.stringify({_savedAt:20,coins:40,bestScore:100,unlocked:['phone'],cosmeticsOwned:['felt_neon'],noAds:false,playerName:'PHONE'}),
  JSON.stringify({_savedAt:10,coins:25,bestScore:500,unlocked:['cloud'],cosmeticsOwned:['felt_royal'],noAds:true,playerName:'CLOUD'})
));
assert(merged.coins===40&&merged.bestScore===500,'First-link merge lost numeric progress');
assert(merged.unlocked.includes('phone')&&merged.unlocked.includes('cloud'),'First-link merge lost unlocks');
assert(merged.cosmeticsOwned.includes('felt_neon')&&merged.cosmeticsOwned.includes('felt_royal'),'First-link merge lost cosmetics');
assert(merged.noAds===true&&merged.playerName==='PHONE','First-link merge lost purchase or phone preference');

// Mission refresh and persistence.
assert(html.includes('id="mission-refresh-ad"'),'Mission refresh button missing');
assert(html.includes('Watch ≈30s Ad & Refresh'),'30-second rewarded-ad label missing');
assert(html.includes("WN.showRewardedAd(ok=>"),'Native rewarded-ad bridge not used');
assert(html.includes('missionRefreshDate'),'Daily refresh limit is not persisted');
assert(html.includes('missionSet:account.missionSet'),'Mission selection is not persisted');
assert(html.includes('if(visibleMissionRewardReady())'),'Ready rewards can be hidden by refresh');
assert(html.includes('if(adViewsLeftToday()<=0)'),'Rewarded-ad cap is not enforced');
assert(html.includes("account.missionRefreshDate=todayStr()"),'Refresh day is not recorded');

// Execute the deterministic selector in isolation and prove a refresh changes all
// three slots without mutating progress or claimed-reward state.
const missionCode=block('const MISSION_POOL=[','/* ---- Cabinet: badges + titles ---- */');
const ctx={
  account:{missionClaimed:{},missionStats:{hands:27},missionWeek:'2026-W29',missionSet:[],missionRotation:0,missionRefreshDate:''},
  mulberry32:a=>function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;},
  saveAccount(){}, todayStr(){return '2026-07-13';}, isoWeekKey(){return '2026-W29';},
  adViewsLeftToday(){return 5;}, toast(){}, nativeHaptic(){}, chord(){}, renderMissions(){}, grantCoins(){},
  window:{}, console
};
vm.createContext(ctx);
vm.runInContext(missionCode+`;globalThis.__missionTest={
  first:chooseMissionSet('2026-W29',0,[]),
  second:null,
  setSecond(){this.second=chooseMissionSet('2026-W29',1,this.first)},
  poolSize:MISSION_POOL.length
};globalThis.__missionTest.setSecond();`,ctx);
const mt=ctx.__missionTest;
assert(mt.poolSize===6,'Unexpected mission pool size');
assert(mt.first.length===3&&new Set(mt.first).size===3,'Initial mission set invalid');
assert(mt.second.length===3&&new Set(mt.second).size===3,'Refreshed mission set invalid');
assert(mt.second.every(id=>!mt.first.includes(id)),'Refresh did not replace all three missions');
assert(ctx.account.missionStats.hands===27,'Mission progress was reset by selection');

// Chest presentation, safety and Android-friendly animation.
assert(html.includes('function premiumChestHtml'),'Premium chest model missing');
assert(html.includes('class="vault-lid"'),'Animated chest lid missing');
assert(html.includes('class="vault-lock"'),'Chest lock missing');
assert(html.includes('class="vault-beam"'),'Chest opening beam missing');
assert(html.includes('class="vault-particles"'),'Chest particles missing');
assert(html.includes('NEW JOKER UNLOCKED'),'Final unlock card missing');
assert(html.includes('NEW COSMETIC UNLOCKED'),'Cosmetic Vault still uses the old reveal');
assert(html.includes("premiumChestHtml('cosmetic','full')"),'Cosmetic Vault chest model missing');
assert(html.includes('if(chestOpening) return;'),'Chest double-tap guard missing');
const spin=block('function spinChest(tier){','/* removed dead duplicate revealJoker');
assert(spin.indexOf('account.unlocked.add(win.id)')<spin.indexOf('revealJoker(win'),'Unlock is not saved before reveal');
assert(html.includes("body.perf-lite .vault-stage"),'Android performance rule missing');
assert(html.includes('@media(prefers-reduced-motion:reduce){.vault-stage *'),'Reduced-motion support missing');

const sim=JSON.parse(fs.readFileSync('docs/release/wildcard-v6.9.1-sim-results.json','utf8'));
assert(sim.version==='6.9.1','Simulation report is not v6.9.1');
assert(sim.dataFailures.length===0&&sim.hookErrors.length===0&&sim.invariantFailures.length===0,'Simulation failures detected');
assert(sim.cheatAudit.mismatches===0,'The Cheat regression detected');
assert(sim.frostbiteCheck.scoringFlags[1]===true,'Frostbite regression detected');

console.log(JSON.stringify({
  version:'6.9.1',scriptsCompiled:scripts.length,htmlIds:ids.length,
  cloud:{googleSignIn:true,noResetMerge:true,offlinePhoneSave:true,ownerOnlyRules:true,playGamesDiagnostics:true},
  artwork:{runtimeWebp:backgrounds.length,pwaOffline:true,standaloneEmbedded:true,standaloneBytes:Buffer.byteLength(standalone),sourceSha256:htmlSha256},
  missionRefresh:{nativeRewarded:true,onePerDay:true,progressPreserved:true,allThreeChanged:true},
  royalVault:{layeredChest:true,doubleTapGuard:true,unlockSavedBeforeAnimation:true,reducedMotion:true},
  simulation:sim.counts,failures:0
},null,2));
