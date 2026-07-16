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
  'wildcard-endless-victory-cosmos.webp',
  'wildcard-theme-neon-heist.webp',
  'wildcard-theme-moonlit-masquerade.webp',
  'wildcard-theme-ember-casino.webp',
  'wildcard-theme-emerald-throne.webp',
  'wildcard-theme-haunted-carnival.webp',
  'wildcard-theme-clockwork-royale.webp'
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
assert(html.includes('>v6.9.8</b>'),'Public version label is not v6.9.8');
assert(html.includes('WN.loadPlayGamesLeaderboard = function (span)'),'Play Games leaderboard bridge is not wired');

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
assert(Buffer.byteLength(standalone)<16_000_000,'Standalone playtest exceeds 16 MB');
assert(standalone.includes('>v6.9.8</b>'),'Standalone public version is not v6.9.8');
for (const asset of ['assets/art/wildcard-logo-v692.webp','assets/audio/bit-shift-kevin-macleod-115bpm.mp3']) {
  assert(fs.existsSync(`www/${asset}`),`Missing runtime asset: ${asset}`);
  assert(html.includes(asset),`Runtime asset is not wired into HTML: ${asset}`);
  assert(serviceWorker.includes('/'+asset),`Runtime asset is not available to the offline PWA: ${asset}`);
  assert(!standalone.includes(asset),`Standalone still has an external asset path: ${asset}`);
}
assert(standalone.includes('data:audio/mpeg;base64,'),'Standalone music is not embedded');
assert(html.includes('function replayTutorial()'),'Safe tutorial replay is missing');
assert(html.includes("handLabel(res.handType)+' · '+res.scoringCount+' OF '+sel.length+' SCORES'"),'Compact score label is missing');
assert(!html.includes('Play scores these '+"'+selCount+'"),'Persistent play/discard hint remains');
assert(html.includes("var(--ui-art-tint),var(--theme-home-art,var(--art-menu-palace))"),'Menu artwork is not theme-aware');
assert(html.includes("playDeathScreen(run.abandoned?'terminated':'gameover',proceed)"),'Failure and termination overlays are not wired');
assert(html.includes('Names and effects stay visible'),'Joker effects are not visibly explained in the shop');
assert(html.includes("var(--art-house-room)!important"),'Sly Kingdom artwork is not wired');
const playHandCode=block('async function playHand(){','function discardSelected(){');
assert(!playHandCode.includes('triggerWinFX('),'Gameplay Win FX is still active');
assert(!playHandCode.includes('sparks('),'Gameplay scoring still creates particle FX');
assert(!playHandCode.includes('offsetWidth'),'Gameplay scoring still forces synchronous layout');
assert(!html.includes("['win','Win FX']"),'Win FX remains player-facing in the Wardrobe');
assert(html.includes("account.speed==='fast'?0.65:1.08"),'Normal scoring pace changed from the approved rhythm');
assert(html.includes('await beat(520);\n\n  const co = calloutFor'),'Final score-settle beat changed');
const floatAt=playHandCode.indexOf("floatScore('+'+res.total)");
const revealBeatAt=playHandCode.indexOf('await beat(500);',floatAt);
assert(floatAt>=0&&revealBeatAt>floatAt,'Win reveal beat changed');
assert(html.includes('await beat(340);'),'Played-card exit beat changed');
const scoreOverlayCode=block('function floatScore(text){','// ---------- SLY THE MASCOT ----------');
assert(!scoreOverlayCode.includes('offsetWidth')&&scoreOverlayCode.includes("replayUiPulse(el,'show'"),'Score overlays still force synchronous layout');

// v6.9.7+ phone UX: decluttered home, nested shop, Daily mode and production-safe Settings.
const menuBlock=block('<!-- ============ MENU ============ -->','<!-- ============ HOW TO ============ -->');
const modeBlock=block('function chooseRunMode(){','function startNormalRun(){');
const settingsBlock=block('function renderSettings(){','function openMusicCredits(){');
const startBoostBlock=block('<!-- ============ START BOOST ============ -->','<!-- ============ AD BREAK ============ -->');
assert(menuBlock.includes('onclick="openHomeShop()"')&&menuBlock.includes('onclick="openMoreMenu()"'),'Home Shop/More grouping is missing');
assert(!menuBlock.includes('onclick="startDailyRun()"'),'Daily Challenge is still a top-level menu action');
assert(!menuBlock.includes('id="dev-menu-btn"'),'Developer Code is still a top-level menu action');
assert(modeBlock.includes('id="mode-daily"')&&modeBlock.includes('account.dailyRunDate===todayStr()'),'Daily Challenge is not in the New Run picker');
assert(modeBlock.includes("dailyDone?' disabled':''")&&modeBlock.includes('available again tomorrow'),'Completed Daily is not disabled until tomorrow');
assert(modeBlock.includes('startDailyRun()'),'Daily picker action is not wired');
assert(settingsBlock.includes('onclick="replayTutorial()"'),'Tutorial replay is not available from Settings');
assert(!html.includes('Developer Code')&&!html.includes('function applyDevCode()'),'Production developer unlock path is still shipped');
assert(!startBoostBlock.includes('onclick="openSettings()"'),'Start Boost back control incorrectly opens Settings');

const dailyLaunchBlock=block('function launchDailyRun(){','function endDailyRun(){');
assert(dailyLaunchBlock.indexOf('account.dailyRunDate=today')<dailyLaunchBlock.indexOf('beginRun()'),'Daily attempt is not locked before play begins');
assert(html.includes('Seeded shop rolls draw from your unlocked collection'),'Daily shop copy still overpromises identical stock');
assert(html.includes("desc:'★ BOSS ★ The House takes a 10% bigger cut")&&!html.includes('House takes a 20% bigger cut'),'THE HOUSE copy does not match its target calculation');
const nextStageBlock=block('function nextStage(){','function continueEndless(){');
assert(nextStageBlock.includes('run.guidedFirstRun && run.guideStep===3')&&nextStageBlock.includes('run.guideStep=4'),'Final first-run coach stage remains unreachable');

const cosmeticCode=block('const COSMETICS = [','const COSMETIC_DEFAULTS');
const cosmeticCtx={}; vm.createContext(cosmeticCtx);
vm.runInContext(cosmeticCode+';globalThis.__cos=COSMETICS;',cosmeticCtx);
const cosmetics=cosmeticCtx.__cos;
const standardThemes=['theme_sunset','theme_ice','theme_neon_elite','theme_gold','theme_vapor','theme_blood','theme_cosmic'];
const slyThemes=['theme_neon_heist','theme_moonlit_mask','theme_ember','theme_emerald_throne','theme_haunted','theme_clockwork'];
assert(standardThemes.every(id=>cosmetics.find(c=>c.id===id).price===1000),'A standard UI theme is not 1,000 coins');
assert(slyThemes.every(id=>cosmetics.find(c=>c.id===id).price>=3500),'A premium Sly UI theme is not priced well above standard themes');
const cosmeticVaultBlock=block('function cosmeticVaultOddsText(pool){','function revealCosmetic(cos, done){');
assert(cosmeticVaultBlock.includes("UI Theme 0.8% · Other 99.2%"),'Cosmetic Vault does not disclose the theme gate');
assert(cosmeticVaultBlock.includes("c.kind!=='win'"),'Cosmetic Vault can still award disabled Win FX');

const introCode=block('function showRoundIntro(){','function playSlyStageFX');
assert(introCode.includes('run.modifier.name')&&introCode.includes('run.modifier.desc'),'Heat intro does not show the active modifier effect');
const reactAt=playHandCode.indexOf('slyReact(res.handType, res.total, stageTarget())');
assert(reactAt>floatAt&&reactAt<playHandCode.indexOf('if(run.stageScore >= stageTarget())'),'Sly reaction does not cover every completed hand');
assert(html.includes('.mascot[data-sly-mood="pair"]')&&html.includes('@keyframes slyMoodPulse'),'Premium Sly skins have no visible hand-reaction treatment');
const slyCode=block('const SLY = {','function sparks(').toLowerCase();
for(const phrase of ['security!','illegal.','grandma','pathetic. lol','prayed harder']) assert(!slyCode.includes(phrase),'Legacy Sly dialogue remains: '+phrase);
assert(slyCode.includes("'high card'")&&slyCode.includes("'royal flush'"),'Hand-specific Sly reactions are incomplete');

const deckCode=block('function openDeckView(){','// ---------- Win screen ----------');
assert(deckCode.includes("classList.add('deck-view-active')")&&deckCode.includes("const VALUES=[2,3,4,5,6,7,8,9,10,11,12,13,14]"),'Compact deck matrix is not wired');
assert(deckCode.includes('const liveCounts=new Map()')&&!deckCode.includes('new Set(run.deck)'),'Deck matrix live counts are not save/resume safe');
assert(html.includes('repeat(13,minmax(0,1fr))'),'Deck matrix does not fit all 13 ranks at a glance');
assert(!html.includes('.deck-row{'),'Legacy horizontally scrolling deck rows remain');
assert(html.includes("classList.remove('active','joker-inspect-active','deck-view-active')"),'Deck overlay styling leaks into later overlays');

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
  validRewardClaims(ids){return [...new Set((Array.isArray(ids)?ids:[]).filter(id=>typeof id==='string'&&id.length<=96))].slice(-256);},
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

// v6.9.8 economy and rewarded placements.
assert(html.includes('dailyLogin:Object.freeze({base:30, step:18, cap:192})'),'Rebalanced daily curve is missing');
assert(html.includes('jokerVaultPrice:Object.freeze({wood:100, gold:300})'),'Rebalanced Joker Vault prices are missing');
assert(html.includes("return Math.round((j.unlock*multiplier)/5)*5"),'Rarity-weighted Joker pricing is missing');
assert(html.includes("saveRunState('revive')")&&html.includes("run.handsLeft=1"),'Save-safe one-play revive is missing');
assert(html.includes("run.leaderboardEligible=false"),'Revived scores can still reach official rankings');
assert(html.includes("grantCoinsOnce(id,base,'run coins doubled',true)"),'Idempotent run-coin double is missing');
assert(html.includes("btn.textContent='Simulate completed reward'"),'Reward preview still depends on a countdown');
assert(html.includes('rewardClaims:account.rewardClaims'),'Reward-claim ledger is not persisted');

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

const sim=JSON.parse(fs.readFileSync('docs/release/wildcard-v6.9.8-sim-results.json','utf8'));
assert(sim.version==='6.9.8','Simulation report is not v6.9.8');
assert(sim.dataFailures.length===0&&sim.hookErrors.length===0&&sim.invariantFailures.length===0,'Simulation failures detected');
assert(sim.cheatAudit.mismatches===0,'The Cheat regression detected');
assert(sim.frostbiteCheck.scoringFlags[1]===true,'Frostbite regression detected');

console.log(JSON.stringify({
  version:'6.9.8',scriptsCompiled:scripts.length,htmlIds:ids.length,
  cloud:{googleSignIn:true,noResetMerge:true,offlinePhoneSave:true,ownerOnlyRules:true,playGamesDiagnostics:true},
  artwork:{runtimeWebp:backgrounds.length,pwaOffline:true,standaloneEmbedded:true,standaloneBytes:Buffer.byteLength(standalone),sourceSha256:htmlSha256},
  missionRefresh:{nativeRewarded:true,onePerDay:true,progressPreserved:true,allThreeChanged:true},
  royalVault:{layeredChest:true,doubleTapGuard:true,unlockSavedBeforeAnimation:true,reducedMotion:true},
  simulation:sim.counts,failures:0
},null,2));
