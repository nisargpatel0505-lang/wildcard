const fs = require('fs');
const crypto = require('crypto');
const vm = require('vm');

const html = fs.readFileSync('www/index.html', 'utf8');
const rules = fs.readFileSync('firestore.rules', 'utf8');
const cloudPlugin = fs.readFileSync('android/app/src/main/java/com/nisarg/wildcard/WildcardCloudPlugin.java', 'utf8');
const mainActivity = fs.readFileSync('android/app/src/main/java/com/nisarg/wildcard/MainActivity.java', 'utf8');
const serviceWorker = fs.readFileSync('www/sw.js', 'utf8');
const privacyPolicy = fs.readFileSync('www/privacy.html', 'utf8');
const piApi = fs.readFileSync('deploy/wildcard-api.py', 'utf8');
const piDeploy = fs.readFileSync('deploy/update-pi.sh', 'utf8');
const androidPublic = fs.readFileSync('android/app/src/main/assets/public/index.html', 'utf8');
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
const externalizedAssets = [
  'assets/art/backgrounds/wildcard-cosmic-base.webp',
  'assets/art/backgrounds/wildcard-cosmic-wilds.webp',
  'assets/art/backgrounds/wildcard-menu-keyart.png',
  'assets/art/sly/sly-expression-grid.webp',
  'assets/art/sly/sly-skins-grid.webp',
  'assets/art/sly/sly-stage-actions-grid.webp',
  'assets/art/wildcard-logo-boot.webp',
  'fonts/bungee-regular.ttf',
  'fonts/space-grotesk-400.ttf',
  'fonts/space-grotesk-500.ttf',
  'fonts/space-grotesk-700.ttf'
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
assert(html.includes('>v6.9.11</b>'),'Public version label is not v6.9.11');
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
assert(crypto.createHash('sha256').update(Buffer.from(androidPublic)).digest('hex')===htmlSha256,'Android bundled HTML is stale relative to canonical source');
assert(standalone.includes(`Canonical source: www/index.html - SHA-256 ${htmlSha256}`),'Standalone provenance does not match current HTML');
assert((standalone.match(/data:image\/webp;base64,/g)||[]).length>=backgrounds.length,'Standalone artwork is not embedded');
assert(Buffer.byteLength(standalone)<16_000_000,'Standalone playtest exceeds 16 MB');
assert(standalone.includes('>v6.9.11</b>'),'Standalone public version is not v6.9.11');
assert(!html.includes(';base64,'),'Canonical HTML still contains Base64 binary assets');
assert(Buffer.byteLength(html)<600_000,'Canonical HTML was not reduced below 600 KB');
for (const asset of externalizedAssets) {
  const path=`www/${asset}`;
  assert(fs.existsSync(path),`Missing externalized runtime asset: ${asset}`);
  assert(html.includes(asset),`Canonical HTML does not reference externalized asset: ${asset}`);
  assert(serviceWorker.includes('/'+asset),`Externalized asset is missing from the offline shell: ${asset}`);
  assert(!standalone.includes(asset),`Standalone still depends on externalized asset: ${asset}`);
}
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
assert(!html.includes('function triggerWinFX(')&&!html.includes('function previewWinFX('),'Win FX runtime or preview code remains');
assert(!html.includes("kind:'win'")&&!html.includes('Win effects')&&!html.includes('win-fx-pulse'),'Win FX remains in the catalogue or UI');
assert(!playHandCode.includes('sparks('),'Gameplay scoring still creates particle FX');
assert(!playHandCode.includes('offsetWidth'),'Gameplay scoring still forces synchronous layout');
assert(html.includes('const SCORE_PACE={normal:1.85,fast:1.04}'),'Readable Normal/Fast scoring pace is missing');
assert(html.includes('reducedMotion?Math.min(paced,160)'),'Reduced-motion scoring still waits through the full paced timeline');
assert(!html.includes("document.addEventListener('pointerdown', ()=>{ if(run && run.animating) ffwd=true;"),'Hidden tap-to-fast-forward scoring path remains');
assert(playHandCode.includes("await beat(account.speed==='fast'?260:360)"),'Readable Joker trigger hold is missing');
const apiResolverMatch=html.match(/function resolveDailyApiBase\(hostname,nativeShell\)\{[\s\S]*?\n\}/);
assert(apiResolverMatch,'Daily Board resolver is missing');
const apiCtx={}; vm.createContext(apiCtx);
vm.runInContext("const DAILY_API_ORIGIN='https://raspberrypi.tail20f574.ts.net';"+apiResolverMatch[0]+';globalThis.resolve=resolveDailyApiBase;',apiCtx);
const liveBoard='https://raspberrypi.tail20f574.ts.net';
assert(apiCtx.resolve('localhost',true)===liveBoard,'Android localhost does not resolve to the live Daily Board');
assert(apiCtx.resolve('localhost',false)===''&&apiCtx.resolve('',false)==='','Local browser/file previews must remain relative');
assert(apiCtx.resolve('raspberrypi.tail20f574.ts.net',false)==='','Pi-hosted game must use its same-origin Daily Board');
assert(apiCtx.resolve('example.com',false)===liveBoard,'External web hosts do not resolve to the live Daily Board');
assert(html.includes("retry.textContent='Post my '+completedScore.toLocaleString()+' score'"),'Completed Daily scores cannot be retried from the board');
assert(html.includes('fetchDailyBoard(todayStr())'),'Daily Board GET can disagree with the local challenge date around midnight');
assert(html.includes('if(run) run.dailyDate=today')&&html.includes('date=(run&&run.dailyDate)||dailyChallengeDate'),'Daily run date is not fixed from launch through settlement');
assert(html.includes("Board: '+boardDate")&&html.includes('date:boardDate'),'Daily score submission can drift to a different date');
assert(piApi.includes('"6.9.10", "6.9.11"'),'Pi analytics does not accept the v6.9.11 client');

// Privacy-minimised Pi analytics: bounded memory only, background/idle transport,
// and an aggregate-only backend with no public read route.
const telemetryCode=block('// ---- Anonymous aggregate analytics','async function fetchDailyRequest');
assert(telemetryCode.includes("new Set(['app_open','run_start','run_end'])"),'Analytics event allowlist changed');
assert(telemetryCode.includes('requestIdleCallback')&&telemetryCode.includes('keepalive:true'),'Analytics is not scheduled through idle/background transport');
assert(telemetryCode.includes('keepalive:true')&&telemetryCode.includes("credentials:'omit'")&&telemetryCode.includes("referrerPolicy:'no-referrer'"),'Analytics fallback request is not privacy/performance constrained');
assert(!telemetryCode.includes('await ')&&!telemetryCode.includes('localStorage'),'Analytics can block or persist on the device');
const telemetryCtx={
  DAILY_API_NATIVE:true,location:{hostname:'localhost'},API_BASE:liveBoard,window:{},
  navigator:{},Blob:class Blob{},Set,JSON,Math,Number,
  requestIdleCallback(){return 1;},setTimeout(){return 1;},fetch(){return Promise.resolve({});},run:null
};
vm.createContext(telemetryCtx);
vm.runInContext(telemetryCode+`;globalThis.__t={queue:queueTelemetry,items:telemetryQueue,band:telemetryHeatBand};`,telemetryCtx);
telemetryCtx.__t.queue('app_open');
telemetryCtx.__t.queue('run_start',{m:'normal'});
telemetryCtx.__t.queue('run_end',{m:'daily',o:'lost',h:telemetryCtx.__t.band(6)});
telemetryCtx.__t.queue('score',{score:999});
const telemetryPayload=JSON.stringify(telemetryCtx.__t.items);
assert(telemetryCtx.__t.items.length===3&&telemetryPayload.includes('"h":"4-6"'),'Analytics payload builder or Heat bucketing failed');
for(const forbidden of ['uid','email','playerName','score','coins','cards','jokers','device','session','userAgent']){
  assert(!telemetryPayload.toLowerCase().includes(forbidden.toLowerCase()),'Analytics payload contains forbidden field: '+forbidden);
}
const localTelemetryCtx={
  DAILY_API_NATIVE:false,location:{hostname:'localhost'},API_BASE:'',window:{},navigator:{},
  Blob:class Blob{},Set,JSON,Math,Number,requestIdleCallback(){},setTimeout(){},fetch(){},run:null
};
vm.createContext(localTelemetryCtx);
vm.runInContext(telemetryCode+`;queueTelemetry('app_open');globalThis.__count=telemetryQueue.length;`,localTelemetryCtx);
assert(localTelemetryCtx.__count===0,'Downloaded/local playtest unexpectedly sends analytics');
assert(html.includes("queueTelemetry('run_start'")&&html.includes("queueTelemetry('run_end'"),'Run lifecycle analytics hooks are incomplete');
assert(html.includes('queueRunEndTelemetry(run,false,true)')&&html.includes('activeRun._telemetryEnded=true')&&html.includes('flushTelemetry(true)'),'Deduplicated Gauntlet win or background flush analytics hook is missing');
assert(html.includes("const RUN_FIELDS=['runId','telemetryMode'")&&html.includes('function queueReplacedRunTelemetry()'),'Saved/replaced run analytics mode is not preserved');
assert(html.includes("const completed=saved.phase==='wincomplete'")&&html.includes("queueRunEndTelemetry(active,saved.telemetryMode==='daily',completed)"),'Replacing a banked Heat-12 run is misreported as terminated');
assert(html.includes("if(!dailyMode) saveRunState('wincomplete')"),'Daily win state can resume without its seeded Daily context');
assert(html.includes('<h3>Anonymous aggregate analytics</h3>')&&privacyPolicy.includes('<h2>Anonymous aggregate analytics</h2>'),'Analytics privacy disclosures are missing');
assert(privacyPolicy.includes('Last updated: 17 July 2026'),'Hosted privacy policy date was not updated');
assert(piApi.includes('ANALYTICS_KEEP_DAYS = 90')&&piApi.includes('MAX_ANALYTICS_REQUESTS_PER_MINUTE = 60')&&piApi.includes('MAX_ANALYTICS_EVENTS_PER_DAY = 20_000'),'Pi analytics retention/rate guard is missing');
assert(piApi.includes('Analytics deliberately has no public read endpoint'),'Pi analytics accidentally gained a public read surface');
assert(piDeploy.includes('privacy.html')&&piDeploy.includes('deploy/wildcard-api.py')&&piDeploy.includes('$HOME/deploy-game.sh'),'Pi deploy no longer preserves privacy/API/GoatCounter-aware deployment');
assert(piDeploy.includes('python3 -c')&&piDeploy.includes('before-$stamp')&&piDeploy.includes('wait_for_api')&&piDeploy.includes('New WILDCARD API failed validation'),'Pi API deploy lacks syntax validation, backup, process-identity health check or rollback');
assert(piDeploy.includes('exec "$repo_dir/deploy/update-pi.sh" --after-pull')&&piDeploy.includes('verify_package_source'),'Pi deploy can self-update mid-execution or publish stale Android assets');
assert(html.includes('aria-label="Sly’s Stake Contract locked">🔒 Locked</div>'),'Locked Stake Contract leaks details');
assert(html.includes('position:fixed;top:calc(7px + var(--sat));left:calc(7px + var(--sal))'),'Mobile Back button is not pinned to the top-left safe area');
assert(html.includes('await beat(240);\n\n  const co = calloutFor'),'Optimized score-settle beat changed');
const floatAt=playHandCode.indexOf("floatScore('+'+res.total)");
const revealBeatAt=playHandCode.indexOf('await beat(300);',floatAt);
assert(floatAt>=0&&revealBeatAt>floatAt,'Score reveal beat changed');
assert(html.includes('await beat(220);'),'Played-card exit beat changed');
assert(playHandCode.includes('lockScoringControls();')&&!playHandCode.slice(0,playHandCode.indexOf('try {')).includes('renderGame(false)'),'Scoring tap still triggers a full render');
assert(!html.includes('function tickNumber('),'Animated Heat score counter remains');
assert(playHandCode.includes("bumpMission('hands',1,false)")&&html.includes('function bumpMission(stat,n,persist=true)'),'Mission writes are not batched');
assert(playHandCode.includes('await sleep(600);')&&playHandCode.includes('await sleep(400);'),'Terminal waits are still pace-scaled');
assert(html.includes("body.perf-lite .bgfx .blob")&&html.includes('display:none!important'),'Mobile background blur layers remain active');
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
assert(html.includes('function jokerAvailableForRun(joker)')&&html.includes('dailyMode||account.unlocked.has(joker.id)'),'Daily shop does not use the full shared Joker catalogue');
assert(html.includes('Daily shops may offer Jokers you have not permanently unlocked'),'Daily full-catalogue rule is not explained');
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
assert(cosmeticVaultBlock.includes("UI Theme 0.8% · Table/Sly 99.2%"),'Cosmetic Vault kind gate is ambiguous');
assert(html.includes("Guaranteed new cosmetic · duplicate-free · '+pool.length+' locked"),'Cosmetic Vault shelf still shows overlapping probability series');
assert(!cosmetics.some(c=>c.kind==='win'),'Retired Win FX cosmetics remain in the live catalogue');

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
const billingCode=block('/* ============================ BILLING ============================ */',"document.addEventListener('deviceready', initBilling, false);");
assert(billingCode.includes('receipt.collection')&&billingCode.includes('receipt.sourceReceipt && receipt.sourceReceipt.transactions'),'Billing bridge does not understand v13 VerifiedReceipt');
const verifiedBillingCode=billingCode.slice(billingCode.indexOf('.verified(function (receipt)'),billingCode.indexOf('store.initialize'));
assert(verifiedBillingCode.indexOf('settlePurchase(productId, true)')<verifiedBillingCode.indexOf('finishDeliveredReceipt(receipt)'),'Billing receipt is finished before durable app delivery');
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
assert(html.includes('id="ward-ad-btn"')&&html.includes('id="chest-ad-btn"'),'Rewarded +25 shortcut is missing from Wardrobe or Vault');
assert(html.includes("updateRewardAdButton('ward-ad-btn')")&&html.includes("updateRewardAdButton('chest-ad-btn')"),'Context rewarded buttons do not refresh their daily state');
assert(html.includes('function refreshMenuNotices()')&&html.includes("setMenuNotice('btn-missions'"),'Weekly/Achievement notification badges are not wired');
assert(html.includes("white-space:pre-line!important")&&html.includes("Claim +'+a.reward+' in Achievements"),'Achievement toast is not phone-contained');
assert(html.includes('function ensureDelegatedHandSelection(handEl)')&&html.includes('el.offsetLeft+el.offsetWidth/2'),'Adjacent-card hit testing is not based on stable card centres');
assert(html.includes('grid-template-columns:repeat(6,minmax(0,1fr))')&&html.includes('#joker-row .joker:nth-child(5){grid-column:4/span 2}'),'Five-Joker 3+2 phone grid is missing');
assert(html.includes("role=\"status\" aria-live=\"polite\"")&&html.includes("chip.textContent='TRIGGER · '+label"),'Joker trigger feedback is not explicit or accessible');
assert(html.includes("background-attachment:scroll,scroll,scroll!important")&&html.includes("data-screen='cabinet'"),'Still premium secondary-screen wallpaper is missing');
/* v6.9.11 replaced the provisional active-prize assertion below with an
   explicit, non-active reward plan until authenticated settlement exists.
assert(html.includes('const DAILY_BOARD_PRIZES={1:300,2:200,3:200}')&&html.includes('#1 +300 · #2–3 +200'),'Daily Board prize policy is not displayed');

*/
assert(!html.includes('const DAILY_BOARD_PRIZES=')&&html.includes('Planned rewards (not active yet): #1 300'),'Daily Board rewards are not clearly marked as a future secure plan');
assert(html.includes("if(chestOpening){ toast('Vault opening in progress"),'Android/browser Back can escape a live vault reveal');

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
assert(html.includes('class="vault-actions"')&&html.includes("stage.querySelector('.vault-actions').appendChild(claim)"),'Vault Claim action is still outside the illuminated frame');
assert(!block('function revealJoker(win, done','// ---------- Daily streak reward').includes("+ '<div class=\"vault-reward-effect\"><b>'+win.name"),'Joker reveal still repeats its name and effect');
assert(html.includes("Survives its first Heat, then has a 25% chance")&&html.includes("const key='glass_joystick_armed'"),'Glass Joystick protection/25% rule is missing');
assert(html.includes("body.perf-lite .vault-stage"),'Android performance rule missing');
assert(html.includes('@media(prefers-reduced-motion:reduce){.vault-stage *'),'Reduced-motion support missing');

const sim=JSON.parse(fs.readFileSync('docs/release/wildcard-v6.9.11-sim-results.json','utf8'));
assert(sim.version==='6.9.11','Focused simulation report is not v6.9.11');
assert(sim.mode==='stress','Release simulation is not a full stress result');
assert(sim.counts.scoringCases===10000&&sim.counts.cheatCases===5000&&sim.counts.fullRuns===550,'Focused v6.9.11 regression counts are incomplete');
assert(sim.sourceSha256===htmlSha256,'Release simulation was not generated from the current canonical HTML');
const simScript=fs.readFileSync('tools/deep-sim-v57.js');
const simScriptSha256=crypto.createHash('sha256').update(simScript).digest('hex');
assert(sim.script==='tools/deep-sim-v57.js'&&sim.scriptSha256===simScriptSha256,'Release simulation harness provenance is stale');
assert(sim.seedSpec&&sim.seedSpec.base==='0x57C0FFEE'&&sim.seedSpec.deterministic===true,'Release simulation seed provenance is missing');
assert(sim.dataFailures.length===0&&sim.hookErrors.length===0&&sim.invariantFailures.length===0,'Simulation failures detected');
assert(sim.cheatAudit.mismatches===0,'The Cheat regression detected');
assert(sim.frostbiteCheck.scoringFlags[1]===true,'Frostbite regression detected');

const strategy=JSON.parse(fs.readFileSync('docs/release/wildcard-v6.9.10-strategy-results.json','utf8'));
assert(strategy.version==='6.9.10'&&strategy.mode==='strategy','Strategy comparison is not a v6.9.10 strategy result');
assert(strategy.counts.strategies===7&&strategy.counts.runsPerStrategy===400&&strategy.counts.fullRuns===2800,'Strategy comparison is incomplete');
assert(strategy.script==='tools/deep-sim-v57.js'&&strategy.scriptSha256===simScriptSha256,'Strategy comparison harness provenance is stale');
assert(strategy.seedSpec&&strategy.seedSpec.base==='0x69100000'&&strategy.seedSpec.pairedRunSeeds===true,'Strategy comparison seed provenance is missing');
assert(Array.isArray(strategy.strategies)&&strategy.strategies.length===7,'Strategy comparison does not contain seven strategies');
assert(strategy.strategies.every(s=>s.runs===400&&Array.isArray(s.outcomes)&&s.outcomes.length===400),'Strategy comparison raw outcomes are incomplete');
assert(strategy.dataFailures.length===0&&strategy.hookErrors.length===0&&strategy.invariantFailures.length===0,'Strategy comparison failures detected');

const economy=JSON.parse(fs.readFileSync('docs/release/wildcard-v6.9.10-economy-results.json','utf8'));
const economyScript=fs.readFileSync('tools/economy-sim-v69.js');
const economyScriptSha256=crypto.createHash('sha256').update(economyScript).digest('hex');
const stressResultSha256=crypto.createHash('sha256').update(fs.readFileSync('docs/release/wildcard-v6.9.10-sim-results.json')).digest('hex');
assert(economy.reportVersion==='6.9.10'&&economy.passed===true,'Economy model is not a passing v6.9.10 result');
assert(economy.script&&economy.script.file==='tools/economy-sim-v69.js'&&economy.script.sha256===economyScriptSha256,'Economy model script provenance is stale');
assert(economy.gameplayInput&&economy.gameplayInput.file==='docs/release/wildcard-v6.9.10-sim-results.json'&&economy.gameplayInput.sha256===stressResultSha256,'Economy model gameplay-input provenance is stale');
assert(economy.gates.every(g=>g.pass),'Economy model contains a failed release gate');

console.log(JSON.stringify({
  version:'6.9.11',scriptsCompiled:scripts.length,htmlIds:ids.length,
  cloud:{googleSignIn:true,noResetMerge:true,offlinePhoneSave:true,ownerOnlyRules:true,playGamesDiagnostics:true},
  artwork:{runtimeWebp:backgrounds.length,pwaOffline:true,standaloneEmbedded:true,standaloneBytes:Buffer.byteLength(standalone),sourceSha256:htmlSha256},
  missionRefresh:{nativeRewarded:true,onePerDay:true,progressPreserved:true,allThreeChanged:true},
  royalVault:{layeredChest:true,doubleTapGuard:true,unlockSavedBeforeAnimation:true,reducedMotion:true},
  simulation:sim.counts,strategyComparison:strategy.counts,economy:{gates:economy.gates.length,modelHash:economy.modelHash},failures:0
},null,2));
