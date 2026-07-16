const fs = require('fs');
const vm = require('vm');

const html = fs.readFileSync('www/index.html', 'utf8');
function assert(ok, message) { if (!ok) throw new Error(message); }
function block(start, end) {
  const a = html.indexOf(start), b = html.indexOf(end, a + start.length);
  assert(a >= 0 && b > a, `Missing block: ${start}`);
  return html.slice(a, b);
}

// Evaluate the live catalogue and pricing functions, rather than copying their
// values into this test. That makes the test fail if runtime and model drift.
const economyCode = block('const ECONOMY = Object.freeze({', 'const INTEREST_PER');
const jokerCode = block('const JOKERS = [', 'function hasJoker');
const priceCode = block('function jokerUnlockCost(j){', 'function jokerTags');
const dailyCode = block('function dailyReward(streak){', 'function claimDaily');
const chestCode = block('const CHESTS={', 'const RARITY_LABEL');
const ctx = { Object, Math };
vm.createContext(ctx);
vm.runInContext(`${economyCode};${jokerCode};${priceCode};${dailyCode};${chestCode};globalThis.__x={ECONOMY,JOKERS,jokerUnlockCost,dailyReward,CHESTS};`, ctx);
const { ECONOMY, JOKERS, jokerUnlockCost, dailyReward, CHESTS } = ctx.__x;
const free = JOKERS.filter(j => jokerUnlockCost(j) === 0);
const paid = JOKERS.filter(j => jokerUnlockCost(j) > 0);
const directTotal = paid.reduce((n, j) => n + jokerUnlockCost(j), 0);
assert(free.length === 10, `Expected 10 free Jokers, got ${free.length}`);
assert(paid.length === 47, `Expected 47 paid Jokers, got ${paid.length}`);
assert(directTotal === 10875, `Paid Joker sink drifted: ${directTotal}`);
assert(jokerUnlockCost(JOKERS.find(j => j.id === 'trainer')) === 190, 'Tutorial Rare price drifted');
assert(CHESTS.wood.price === 100 && CHESTS.gold.price === 300, 'Joker Vault prices drifted');
assert(ECONOMY.rewardedCoin.amount === 25 && ECONOMY.rewardedCoin.dailyCap === 5, 'Coin-ad reward drifted');

const sumDays = n => Array.from({ length:n }, (_, i) => dailyReward(i + 1)).reduce((a, b) => a + b, 0);
assert(dailyReward(1) === 30 && dailyReward(7) === 138 && dailyReward(10) === 192 && dailyReward(200) === 192, 'Daily curve values drifted');
assert(sumDays(7) === 588 && sumDays(30) === 4950 && sumDays(180) === 33750, 'Daily curve totals drifted');

// A full stale cloud ledger must not displace a reward just paid on this
// phone when the bounded claim history is reconciled.
const mergeCode = block('function parseJsonObject(raw){', 'function installCloudReconciledSave(');
const mergeCtx = {
  Date:{ now:()=>123456 },
  validRewardClaims:ids=>[...new Set((Array.isArray(ids)?ids:[]).filter(id=>typeof id==='string'&&id.length<=96))].slice(-256),
  savedStamp:raw=>{ try{return Number(JSON.parse(raw)._savedAt)||0;}catch(e){return 0;} }
};
vm.createContext(mergeCtx);
vm.runInContext(`${mergeCode};globalThis.__merge={mergeAccountSaves};`, mergeCtx);
const staleClaims=Array.from({length:256},(_,i)=>`cloud:${i}`);
const merged=JSON.parse(mergeCtx.__merge.mergeAccountSaves(
  JSON.stringify({_savedAt:20,coins:10,rewardClaims:['run-live:double']}),
  JSON.stringify({_savedAt:10,coins:9,rewardClaims:staleClaims})
));
assert(merged.rewardClaims.length===256 && merged.rewardClaims.includes('run-live:double'), 'Cloud reconciliation evicted the newest local reward claim');

// Account reward claims are the atomic, bounded idempotency ledger used by
// Heat rewards and run-end doubles.
const claimCode = block('function hasRewardClaim(id){', '// ---------- Rewarded ad');
const claimCtx = {
  account:{ coins:10, rewardClaims:[] },
  clampInt:(v,min=0,max=9999999)=>Math.max(min,Math.min(max,Math.floor(Number(v)||0))),
  validRewardClaims:ids=>[...new Set(ids)].slice(-256),
  saveAccount(){ this.saves=(this.saves||0)+1; }, refreshCoinReadouts(){}, toast(){}, chord(){}, checkAchievements(){},
  run:{ runId:'run-test', accountEarned:0, accountRewardIds:[] }
};
vm.createContext(claimCtx);
vm.runInContext(`${claimCode};globalThis.__claim={grantCoinsOnce,creditRunAccountOnce,hasRewardClaim};`, claimCtx);
assert(claimCtx.__claim.grantCoinsOnce('run-test:double', 25, '', false) === true, 'First reward claim was rejected');
assert(claimCtx.account.coins === 35, 'First reward claim paid the wrong amount');
assert(claimCtx.__claim.grantCoinsOnce('run-test:double', 25, '', false) === false, 'Duplicate reward claim was accepted');
assert(claimCtx.account.coins === 35, 'Duplicate reward claim paid twice');
claimCtx.__claim.creditRunAccountOnce('heat:1', 2);
claimCtx.__claim.creditRunAccountOnce('heat:1', 2);
assert(claimCtx.account.coins === 37 && claimCtx.run.accountEarned === 2, 'Heat reward idempotency failed');

// Terminal-state behavior: only a natural out-of-plays loss receives the offer,
// and the resumable revive checkpoint is written before the prompt opens.
const reviveCore = block('function canOfferRunRevive(reason){', 'function openRunReviveOffer(){');
function reviveHarness(overrides={}) {
  const state = {
    run:{ abandoned:false, reviveUsed:false, terminalPending:false, handsLeft:0, hand:[{}], animating:true, failureReason:'', ...overrides },
    dailyMode:false, checkpoints:[], opened:0, ended:0, renderGame(){}
  };
  state.saveRunState=phase=>state.checkpoints.push(phase);
  state.openRunReviveOffer=()=>{ state.opened++; };
  state.gameOver=()=>{ state.ended++; };
  vm.createContext(state);
  vm.runInContext(`${reviveCore};globalThis.__rev={canOfferRunRevive,requestFailedHeat,declineRunRevive};`, state);
  return state;
}
let rev = reviveHarness();
rev.__rev.requestFailedHeat('plays');
assert(rev.run.terminalPending && rev.checkpoints.join(',') === 'revive' && rev.opened === 1 && rev.ended === 0, 'Natural failure did not enter resumable revive phase');
rev.__rev.declineRunRevive();
assert(!rev.run.terminalPending && rev.ended === 1, 'Declining revive did not finalize exactly once');
rev = reviveHarness({ hand:[] }); rev.__rev.requestFailedHeat('cards');
assert(rev.ended === 1 && rev.opened === 0, 'Card exhaustion incorrectly offered a revive');
rev = reviveHarness(); rev.dailyMode = true; rev.__rev.requestFailedHeat('plays');
assert(rev.ended === 1 && rev.opened === 0, 'Daily Challenge incorrectly offered a revive');

const reviveUi = block('function openRunReviveOffer(){', '// arcade "game over" jingle');
const usedAt = reviveUi.indexOf('run.reviveUsed=true');
const savedAt = reviveUi.indexOf("saveRunState('game')", usedAt);
const renderedAt = reviveUi.indexOf('renderGame(true)', savedAt);
assert(usedAt >= 0 && savedAt > usedAt && renderedAt > savedAt, 'Revive is not persisted before controls re-enable');
assert(reviveUi.includes('run.handsLeft=1') && reviveUi.includes('run.leaderboardEligible=false'), 'Revive grant or leaderboard protection is missing');

const doubleCode = block('function doubleCoinsClaimId(){', 'function gameOver(won){');
assert(doubleCode.includes('grantCoinsOnce(id,base'), 'Run double does not use the idempotency ledger');
assert(doubleCode.includes('run.abandoned') && doubleCode.includes('run.doubleBaseCoins'), 'Run double eligibility/snapshot is missing');
assert(doubleCode.includes('clearRunState()'), 'Run double callback can resurrect a completed run');
const rewardedCode = block('function showRewardedPlacement(', 'function rewardedAd(');
assert(!rewardedCode.includes('setInterval') && !rewardedCode.includes('Reward in '), 'Rewarded preview still uses a coercive timer');
assert(rewardedCode.includes("btn.textContent='Simulate completed reward'"), 'Explicit browser reward simulation is missing');
const saveCode = block('function currentRunPhase(){', 'function clearRunState(){');
assert(saveCode.includes("active&&active.id==='gameover' ? 'gameover'") && saveCode.includes("['game','shop','revive','wincomplete'].includes(phase)"), 'Completed or inactive screens can checkpoint a run as resumable');

console.log(JSON.stringify({
  jokers:{ free:free.length, paid:paid.length, directTotal },
  daily:{ day1:dailyReward(1), day7:dailyReward(7), cap:dailyReward(200), total180:sumDays(180) },
  vaults:{ wood:CHESTS.wood.price, gold:CHESTS.gold.price },
  rewards:{ idempotent:true, reviveCheckpoint:true, doubleOnce:true, noCountdown:true }
}, null, 2));
