const fs = require('fs');
const vm = require('vm');

const html = fs.readFileSync('www/index.html', 'utf8');

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

const sim=JSON.parse(fs.readFileSync('docs/release/wildcard-v6.8-sim-results.json','utf8'));
assert(sim.version==='6.8','Simulation report is not v6.8');
assert(sim.dataFailures.length===0&&sim.hookErrors.length===0&&sim.invariantFailures.length===0,'Simulation failures detected');
assert(sim.cheatAudit.mismatches===0,'The Cheat regression detected');
assert(sim.frostbiteCheck.scoringFlags[1]===true,'Frostbite regression detected');

console.log(JSON.stringify({
  version:'6.8',scriptsCompiled:scripts.length,htmlIds:ids.length,
  missionRefresh:{nativeRewarded:true,onePerDay:true,progressPreserved:true,allThreeChanged:true},
  royalVault:{layeredChest:true,doubleTapGuard:true,unlockSavedBeforeAnimation:true,reducedMotion:true},
  simulation:sim.counts,failures:0
},null,2));
