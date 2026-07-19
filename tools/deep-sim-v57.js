const fs = require('fs');
const path = require('path');
const vm = require('vm');
const crypto = require('crypto');

const root = path.resolve(__dirname, '..');
const htmlPath = path.join(root, 'www', 'index.html');
const html = fs.readFileSync(htmlPath, 'utf8');
const detectedVersion = (html.match(/>v(\d+\.\d+(?:\.\d+)?)<\/b>/) || [])[1] || 'unknown';
const strategyMode = process.argv.includes('--strategy');
const decisionMode = process.argv.includes('--decision-lab');
if (strategyMode && decisionMode) throw new Error('Choose either --strategy or --decision-lab');
const runsArg = process.argv.find(arg => /^--runs=\d+$/.test(arg));
const strategyRuns = runsArg ? Number(runsArg.split('=')[1]) : 400;
const starterRunsArg = process.argv.find(arg => /^--starter-runs=\d+$/.test(arg));
const starterRuns = starterRunsArg ? Number(starterRunsArg.split('=')[1]) : 500;
const openingDealsArg = process.argv.find(arg => /^--opening-deals=\d+$/.test(arg));
const openingDeals = openingDealsArg ? Number(openingDealsArg.split('=')[1]) : 20000;
const fixedStarterArg = process.argv.find(arg => /^--fixed-starter=[a-z0-9_-]+$/.test(arg));
const fixedStarter = fixedStarterArg ? fixedStarterArg.split('=')[1] : 'auto';
if (strategyMode && (!Number.isInteger(strategyRuns) || strategyRuns < 50 || strategyRuns > 5000)) {
  throw new Error('Strategy runs must be an integer from 50 to 5000');
}
if (decisionMode && (!Number.isInteger(starterRuns) || starterRuns < 100 || starterRuns > 5000)) {
  throw new Error('Starter runs must be an integer from 100 to 5000');
}
if (decisionMode && (!Number.isInteger(openingDeals) || openingDeals < 1000 || openingDeals > 100000)) {
  throw new Error('Opening deals must be an integer from 1000 to 100000');
}
const sourceSha256 = crypto.createHash('sha256').update(Buffer.from(html)).digest('hex');
const scriptSha256 = crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex');
const scripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)];
if (!scripts.length) throw new Error('No inline game script found');

let live = scripts[scripts.length - 1][1];
const cutoff = live.indexOf('// ---- Global daily leaderboard');
if (cutoff < 0) throw new Error('Could not locate simulation cutoff');
live = live.slice(0, cutoff);

function makeElement() {
  const classes = new Set();
  const el = {
    children: [], style: {}, dataset: {}, textContent: '', innerHTML: '', value: '', disabled: false,
    classList: {
      add: (...xs) => xs.forEach(x => classes.add(x)),
      remove: (...xs) => xs.forEach(x => classes.delete(x)),
      contains: x => classes.has(x),
      toggle: (x, force) => {
        const on = force === undefined ? !classes.has(x) : !!force;
        if (on) classes.add(x); else classes.delete(x);
        return on;
      }
    },
    appendChild(child) { this.children.push(child); return child; },
    remove() {}, focus() {}, setAttribute() {}, removeAttribute() {}, addEventListener() {},
    querySelector() { return makeElement(); }, querySelectorAll() { return []; },
    getBoundingClientRect() { return { x: 0, y: 0, width: 320, height: 480, bottom: 480 }; }
  };
  return el;
}

const elements = new Map();
const body = makeElement();
const documentStub = {
  body, hidden: false,
  getElementById(id) { if (!elements.has(id)) elements.set(id, makeElement()); return elements.get(id); },
  createElement() { return makeElement(); },
  querySelector() { return makeElement(); }, querySelectorAll() { return []; },
  addEventListener() {}
};

const storageMap = new Map();
const localStorageStub = {
  getItem: key => storageMap.has(key) ? storageMap.get(key) : null,
  setItem: (key, value) => storageMap.set(key, String(value)),
  removeItem: key => storageMap.delete(key)
};

function mulberry(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

let hostRandom = mulberry(0x57C0FFEE);
const mathStub = Object.create(Math);
mathStub.random = () => hostRandom();
const resetSimRandom = seed => { hostRandom = mulberry(seed >>> 0); };
const context = {
  console, Math: mathStub, JSON, Date, Set, Map, WeakMap, Promise, Object, Array, Number, String,
  Boolean, RegExp, Error, TypeError, parseInt, parseFloat, isNaN, Infinity, NaN,
  document: documentStub, localStorage: localStorageStub,
  navigator: {}, location: { hostname: 'localhost' }, history: { replaceState() {}, pushState() {} },
  screen: { width: 390, height: 844 }, matchMedia: () => ({ matches: true }),
  getComputedStyle: () => ({}), confirm: () => true, alert() {}, fetch: async () => ({ ok: false, json: async () => ({}) }),
  setTimeout: () => 0, clearTimeout() {}, setInterval: () => 0, clearInterval() {},
  requestAnimationFrame: fn => { fn(0); return 0; }, cancelAnimationFrame() {},
  addEventListener() {}, removeEventListener() {}, dispatchEvent() { return true; },
  performance: { now: () => Date.now() }, structuredClone: global.structuredClone,
  SIM_QUICK: process.env.SIM_QUICK === '1', SIM_VERSION: detectedVersion,
  SIM_MODE: decisionMode ? 'decision' : (strategyMode ? 'strategy' : 'stress'),
  SIM_STRATEGY_RUNS: strategyRuns, SIM_STARTER_RUNS: starterRuns, SIM_OPENING_DEALS: openingDeals,
  SIM_FIXED_STARTER: fixedStarter,
  SIM_SOURCE_SHA256: sourceSha256, SIM_SCRIPT_SHA256: scriptSha256,
  SIM_RESET_RANDOM: resetSimRandom,
  btoa: value => Buffer.from(value, 'binary').toString('base64'),
  atob: value => Buffer.from(value, 'base64').toString('binary')
};
context.window = context;
context.globalThis = context;
context.scrollTo = () => {};
vm.createContext(context);

const simulator = String.raw`
;globalThis.__SIM_RESULT__ = (function () {
  const startedAt = Date.now();
  const quick = !!globalThis.SIM_QUICK;
  const strategyMode = globalThis.SIM_MODE === 'strategy';
  const decisionMode = globalThis.SIM_MODE === 'decision';
  const strategyRuns = Number(globalThis.SIM_STRATEGY_RUNS) || 400;
  const decisionStarterRuns = Number(globalThis.SIM_STARTER_RUNS) || 500;
  const openingDeals = Number(globalThis.SIM_OPENING_DEALS) || 20000;
  const fixedStarter = String(globalThis.SIM_FIXED_STARTER || 'auto');
  const failures = [];
  const hookErrors = [];
  const invariantFailures = [];
  const handTypes = Object.keys(HAND_BASE);
  const utilityIds = new Set(['royalscam','lucky7','shortcut','pocketflush','cheat']);
  const raritySet = new Set(['common','uncommon','rare','wild']);
  const strategySeedBase = 0x69100000;
  const STRATEGIES = [
    {id:'adaptive_greedy',name:'Adaptive greedy',description:'Ranks every offer by broad immediate and scaling value without forcing an archetype.'},
    {id:'cheat_synergy',name:'Cheat + hand synergy',description:'Prioritises The Cheat, hand-specific multipliers, hand Boost scaling and flexible hand enablers.',prefer:['cheat','polish','flushfund','wire','boostfiend','master_class','shortcut','pocketflush','practice_mode']},
    {id:'pair_rank',name:'Pair and rank boosting',description:'Prioritises rank modifiers and Pair-or-better support.',prefer:['polish','trainer','copper','presser','retainer','even','acemag','lowball','inktrade','triple3','number_station','frequency_meter']},
    {id:'utility_niche',name:'Utility and niche',description:'Prioritises unusual deck, hand-size and conditional utility effects.',prefer:['royalscam','lucky7','sniper','shortcut','pocketflush','cheat','tailor','collector','printer','cleaner','guillotine']},
    {id:'flush_engine',name:'Flush engine',description:'Prioritises suit, colour and Flush enablers and payoffs.',prefer:['flushfund','uniform','pocketflush','color_wash','prism_lens','presser','inktrade','tailor']},
    {id:'economy_hoarding',name:'Economy hoarding',description:'Prioritises coin engines and keeps a 25-coin reserve instead of spending for tempo.',prefer:['dividend','piggy','miser','dumpster'],reserve:25},
    {id:'xmult_stacking',name:'xMult stacking',description:'Prioritises Jokers with multiplicative scoring hooks, even when the flat base is weak.',prefer:['roller','lastcall','couple','sniper','boostfiend','modded','survivor','doubledown','allin','frequency_meter','panic_button','storm_harness','guillotine','redline','master_class','danger_music','rehearsal_tape','prism_lens','glass_joystick'],preferXMult:true}
  ];

  function mixSeed(seed, stage, stream) {
    let x=(seed ^ Math.imul((stage+1)>>>0,0x9E3779B1) ^ Math.imul((stream+1)>>>0,0x85EBCA77))>>>0;
    x=Math.imul(x^(x>>>16),0x7FEB352D)>>>0;
    x=Math.imul(x^(x>>>15),0x846CA68B)>>>0;
    return (x^(x>>>16))>>>0;
  }
  function resetPhase(seed, stage, stream) { globalThis.SIM_RESET_RANDOM(mixSeed(seed,stage,stream)); }

  function record(list, item, cap) { if (list.length < (cap || 100)) list.push(item); }
  function sample(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
  function shuffled(arr) {
    const out = arr.slice();
    for (let i = out.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [out[i], out[j]] = [out[j], out[i]]; }
    return out;
  }
  function combos(arr, size) {
    const out = [], pick = [];
    function walk(start) {
      if (pick.length === size) { out.push(pick.slice()); return; }
      for (let i = start; i <= arr.length - (size - pick.length); i++) { pick.push(arr[i]); walk(i + 1); pick.pop(); }
    }
    walk(0); return out;
  }
  function bestChoice(captureByType) {
    let best = null;
    const byType = captureByType ? {} : null;
    const max = Math.min(effMaxSelect(), run.hand.length);
    for (let n = 1; n <= max; n++) {
      for (const cards of combos(run.hand, n)) {
        if (n > 1 && n < 5) {
          const type = evaluateHand(cards);
          const useful = type !== 'High Card' || allSameColor(cards) || (n === 3 && hasJoker('shortcut')) || (n === 4 && (hasJoker('pocketflush') || mod('ceiling')));
          if (!useful) continue;
        }
        const res = scoreHand(cards, false);
        if (byType) {
          const current = byType[res.handType];
          if (!current || res.total > current.res.total || (res.total === current.res.total && res.scoringCount > current.res.scoringCount)) {
            byType[res.handType] = { cards, res };
          }
        }
        if (!best || res.total > best.res.total || (res.total === best.res.total && res.scoringCount > best.res.scoringCount)) best = { cards, res };
      }
    }
    if (best && byType) best.byType = byType;
    return best;
  }
  function dominantSuit(cards) {
    const counts = {}; for (const c of cards) counts[c.suit] = (counts[c.suit] || 0) + 1;
    return Object.keys(counts).sort((a,b) => counts[b] - counts[a])[0];
  }
  function discardForDraw(strategy) {
    const ranks = {}, suit = dominantSuit(run.hand);
    for (const c of run.hand) ranks[c.rank] = (ranks[c.rank] || 0) + 1;
    const pairPlan=strategy&&strategy.id==='pair_rank';
    const flushPlan=strategy&&strategy.id==='flush_engine';
    const duplicateWeight=pairPlan?30:(flushPlan?7:18);
    const suitWeight=flushPlan?25:(pairPlan?2:7);
    const sequenceWeight=(pairPlan||flushPlan)?1.5:3;
    const valued = run.hand.map(c => {
      let near = 0; for (const o of run.hand) if (o !== c && Math.abs(o.value - c.value) <= 2) near++;
      return { c, v: (ranks[c.rank] - 1) * duplicateWeight + (c.suit === suit ? suitWeight : 0) + near * sequenceWeight + c.value * 0.35 + (c.enh ? 8 : 0) };
    }).sort((a,b) => b.v - a.v);
    const keepN = Math.min(4, Math.max(2, run.hand.length - 5));
    const keep = new Set(valued.slice(0, keepN).map(x => x.c));
    const toss = run.hand.filter(c => !keep.has(c)).slice(0, 5);
    if (!toss.length) return false;
    const tossed = new Set(toss);
    run.hand = run.hand.filter(c => !tossed.has(c));
    run.discardsLeft--;
    refillHand();
    return true;
  }
  function assertRun(where) {
    const ids = run.jokers.map(j => j.id);
    const expectedDeck = 52 - run.destroyedCount + run.copiedCount - (run.shatteredCount || 0);
    const checks = [
      [Number.isFinite(run.runCoins) && run.runCoins >= 0, 'negative/nonfinite run coins'],
      [run.jokers.length <= MAX_JOKERS, 'too many jokers'],
      [new Set(ids).size === ids.length, 'duplicate equipped joker'],
      [run.cards.length >= HAND_SIZE, 'deck below hand size'],
      [run.cards.length === expectedDeck, 'sculpted deck accounting mismatch'],
      [run.hand.every(Boolean) && run.deck.every(Boolean), 'undefined card'],
      [run.stageScore >= 0 && Number.isFinite(run.stageScore), 'invalid stage score']
    ];
    for (const [ok, message] of checks) if (!ok) record(invariantFailures, { where, message, stage: run.stage, ids, cards: run.cards.length, expectedDeck, coins: run.runCoins }, 100);
  }
  function baseContext(cards, handType) {
    return {
      handType: handType || 'Pair', cards: cards || run.hand.slice(0,5), handsPlayedThisStage: run.handsPlayedThisStage,
      handsLeft: run.handsLeft, discardsUsed: effDiscards() - run.discardsLeft, deckLeft: run.deck.length,
      heat: run.stage, state: run.jokerState, destroyed: run.destroyedCount, copied: run.copiedCount,
      handLevels: run.handLevels, runCoins: run.runCoins, hasModifier: !!run.modifier, deckSize: run.cards.length,
      heatsCleared: run.stagesCleared, deckRankMax: getMaxRankCount(run.cards), prevHandType: run.prevHandType || null
    };
  }
  function jokerValue(j) {
    let value = 0;
    if (j.rankMod) {
      let sum = 0; for (const c of run.cards) sum += Math.max(0, Number(j.rankMod(c)) || 0);
      value += (sum / Math.max(1, run.cards.length)) * 7;
    }
    const saved = { stage:run.stage, handsLeft:run.handsLeft, handsPlayed:run.handsPlayedThisStage, discards:run.discardsLeft, score:run.stageScore, mod:run.modifier };
    const scenarios = [
      ['Pair',4,0,5,0,null], ['Two Pair',3,1,3,.25,null], ['Flush',2,2,1,.5,MODIFIERS[0]],
      ['Straight',1,3,0,.6,MODIFIERS[2]], ['Full House',1,3,0,.8,MODIFIERS[6]], ['High Card',4,0,4,0,null]
    ];
    let add = 0, x = 0;
    for (const s of scenarios) {
      run.handsLeft=s[1]; run.handsPlayedThisStage=s[2]; run.discardsLeft=s[3]; run.stageScore=Math.round(stageTarget()*s[4]); run.modifier=s[5];
      const ctx = baseContext(run.hand.slice(0,5), s[0]);
      try { if (j.addMult) add += Number(j.addMult(ctx)) || 0; } catch (e) {}
      try { if (j.xMult) x += Math.max(0, (Number(j.xMult(ctx)) || 1) - 1); } catch (e) {}
    }
    Object.assign(run, { stage:saved.stage, handsLeft:saved.handsLeft, handsPlayedThisStage:saved.handsPlayed, discardsLeft:saved.discards, stageScore:saved.score, modifier:saved.mod });
    value += add / scenarios.length * 110 + x / scenarios.length * 190;
    if (j.onScored) value += 38;
    if (j.onHeatClear) value += 28;
    if (utilityIds.has(j.id)) value += 58;
    if (j.rarity === 'wild') value += 12;
    return value;
  }
  function strategyValue(j, strategy) {
    const base=jokerValue(j);
    if(!strategy||strategy.id==='adaptive_greedy') return base;
    let bonus=0;
    if(strategy.prefer&&strategy.prefer.includes(j.id)) bonus+=240;
    if(strategy.id==='cheat_synergy'){
      if(j.id==='cheat') bonus+=180;
      if(j.onScored) bonus+=24;
    } else if(strategy.id==='pair_rank'){
      if(j.rankMod) bonus+=110;
      if(['trainer','polish','fulltable'].includes(j.id)) bonus+=80;
    } else if(strategy.id==='utility_niche'){
      if(utilityIds.has(j.id)) bonus+=100;
      if(j.onHeatClear) bonus+=35;
    } else if(strategy.id==='flush_engine'){
      if(['flushfund','pocketflush','prism_lens'].includes(j.id)) bonus+=130;
    } else if(strategy.id==='economy_hoarding'){
      if(j.onHeatClear) bonus+=45;
    } else if(strategy.id==='xmult_stacking'&&j.xMult){
      bonus+=175;
    }
    return base+bonus;
  }
  function buyAtShop(metrics, strategy) {
    run.boughtThisShop=false; run.shopBuysUsed=0; run.suppliesBoughtThisShop=[]; run.pendingShopJoker=null;
    if(!run.supplyPurchaseCounts||typeof run.supplyPurchaseCounts!=='object') run.supplyPurchaseCounts={};
    if(run.__simSeed!==undefined) resetPhase(run.__simSeed,run.stage,20);
    rollJokerOffers(true); rollSupplyOffers();
    if(run.__simStats){
      const maxRefund=run.jokers.length>=MAX_JOKERS && run.jokers.length
        ? Math.max(...run.jokers.map(j=>Math.max(1,Math.floor(j.price/2))))
        : 0;
      const available=shopOffers.filter(j=>!run.jokers.some(x=>x.id===j.id));
      const affordable=available.filter(j=>shopPrice(j.price)<=run.runCoins+maxRefund);
      run.__simStats.shopVisits++;
      run.__simStats.shopOffers+=available.length;
      run.__simStats.affordableShopOffers+=affordable.length;
      if(affordable.length>=2) run.__simStats.choiceShops++;
      if(affordable.length===0) run.__simStats.deadShops++;
    }
    let limit = shopBuyLimit();
    for (let purchase = 0; purchase < limit; purchase++) {
      const ranked = shopOffers.filter(j => !run.jokers.some(x => x.id === j.id)).map(j => ({j, value:strategyValue(j,strategy)})).sort((a,b) => b.value - a.value);
      if (!ranked.length) break;
      const cand = ranked[0], price = shopPrice(cand.j.price);
      let replace = -1, refund = 0;
      if (run.jokers.length >= MAX_JOKERS) {
        const current = run.jokers.map((j,i) => ({i,j,value:strategyValue(j,strategy)})).sort((a,b) => a.value - b.value)[0];
        refund = Math.max(1, Math.floor(current.j.price/2));
        if (cand.value <= current.value * 1.08) break;
        replace = current.i;
      }
      const reserve=strategy&&strategy.reserve?strategy.reserve:0;
      if (run.runCoins + refund - price < reserve) {
        if (!reserve && purchase === 0 && run.runCoins >= REROLL_COST) {
          run.runCoins -= REROLL_COST; metrics.rerolls++; rollJokerOffers(false); purchase--; continue;
        }
        break;
      }
      run.runCoins -= price;
      if (replace >= 0) { run.runCoins += refund; const old=run.jokers[replace]; if(old.stateKey) delete run.jokerState[old.stateKey]; run.jokers[replace]=cand.j; }
      else run.jokers.push(cand.j);
      shopOffers = shopOffers.filter(j => j.id !== cand.j.id);
      metrics.jokerBuys[cand.j.id] = (metrics.jokerBuys[cand.j.id] || 0) + 1;
    }
    buySupplies(metrics,strategy);
  }
  function buySupplies(metrics,strategy) {
    if(strategy&&strategy.reserve&&run.runCoins<=strategy.reserve+8) return;
    let bought = 0;
    for (const s of supplyOffers) {
      if (bought >= 2) break;
      const price = supplyPrice(s); if (run.runCoins < price) continue;
      let used = false;
      if (s.id === 'boost') {
        const preferred = Object.keys(run.handTypeCounts).sort((a,b) => (run.handTypeCounts[b]||0)-(run.handTypeCounts[a]||0))[0] || 'Pair';
        if ((run.handLevels[preferred]||0) < MAX_HAND_LEVEL) { run.handLevels[preferred]=(run.handLevels[preferred]||0)+1; run.boostsBought++; used=true; }
      } else if (s.id === 'scalpel' && run.cards.length > 42) {
        let idx=0; for(let i=1;i<run.cards.length;i++) if(run.cards[i].value<run.cards[idx].value) idx=i;
        run.cards.splice(idx,1); run.destroyedCount++; used=true;
      } else if (s.id === 'copier' && (hasJoker('printer')||hasJoker('collector')||hasJoker('tailor')||Math.random()<.24)) {
        const counts={}; for(const c of run.cards) counts[c.rank]=(counts[c.rank]||0)+1;
        const target=run.cards.slice().sort((a,b)=>(counts[b.rank]-counts[a.rank])||b.value-a.value)[0];
        run.cards.push(Object.assign({},target)); run.copiedCount++; used=true;
      } else if (s.id === 'dye' && (hasJoker('flushfund')||hasJoker('pocketflush')||hasJoker('uniform')||hasJoker('color_wash'))) {
        const suit=dominantSuit(run.cards), idx=run.cards.findIndex(c=>c.suit!==suit);
        if(idx>=0){ const su=SUITS.find(x=>x.s===suit); run.cards[idx].suit=suit; run.cards[idx].red=su.red; used=true; }
      } else if (s.id === 'enhance' && Math.random()<.42) {
        const candidates=run.cards.filter(c=>!c.enh); if(candidates.length){ sample(candidates).enh=sample(['gild','neon','glass','wildsuit']); run.enhancedCount++; used=true; }
      }
      if (used) {
        run.runCoins -= price;
        run.supplyPurchaseCounts[s.id]=supplyPurchaseCount(s)+1;
        run.suppliesBoughtThisShop.push(s.id);
        bought++;
        metrics.supplies[s.id]=(metrics.supplies[s.id]||0)+1;
      }
    }
  }
  function playChoice(choice, metrics) {
    const scoreBefore=run.stageScore, handsBefore=run.handsLeft, targetBefore=stageTarget();
    const cards=choice.cards, res=scoreHand(cards,true);
    if (!Number.isFinite(res.total) || !Number.isFinite(res.mult) || res.total < 0 || res.mult < 0) record(failures,{kind:'invalid-score',res,jokers:run.jokers.map(j=>j.id)},100);
    run.stageScore += res.total; run.totalScore += res.total;
    run.bestPlay=Math.max(run.bestPlay,res.total); if(run.bestPlay===res.total) run.bestPlayType=res.handType;
    run.handTypeCounts[res.handType]=(run.handTypeCounts[res.handType]||0)+1;
    metrics.handTypes[res.handType]=(metrics.handTypes[res.handType]||0)+1;
    if(run.__simStats){
      const activeJokers=new Set(res.events.filter(e=>Number.isInteger(e.jokerIdx)&&e.jokerIdx>=0).map(e=>e.jokerIdx));
      run.__simStats.plays++;
      run.__simStats.playedCards+=cards.length;
      run.__simStats.jokerTriggerEvents+=res.events.filter(e=>Number.isInteger(e.jokerIdx)&&e.jokerIdx>=0).length;
      run.__simStats.activeJokerSlots+=activeJokers.size;
      run.__simStats.equippedJokerSlots+=run.jokers.length;
      if(activeJokers.size>0) run.__simStats.activeJokerPlays++;
      if(res.total>=targetBefore) run.__simStats.wildMoments++;
      else if(res.total>=targetBefore*.6) run.__simStats.megaMoments++;
      else if(res.total>=targetBefore*.35) run.__simStats.greatMoments++;
      else if(res.total>=targetBefore*.2) run.__simStats.niceMoments++;
      if(scoreBefore<targetBefore && run.stageScore>=targetBefore){
        if(handsBefore===1) run.__simStats.finalPlayClears++;
        if(handsBefore===1 && scoreBefore<targetBefore*.75) run.__simStats.comebackClears++;
      }
      run.__simStats.playScores.push(res.total);
    }
    run.handsLeft--; run.handsPlayedThisStage++;
    run.prevHandType=res.handType;
    for(const j of run.jokers) if(j.onScored) j.onScored(res.ctx);
    let shattered=0;
    cards.forEach((c,i)=>{ if(c.enh==='glass'&&res.flags[i]&&run.cards.length-shattered>HAND_SIZE&&Math.random()<.2){ const k=run.cards.findIndex(x=>x.rank===c.rank&&x.suit===c.suit&&x.enh==='glass'); if(k>=0){run.cards.splice(k,1);shattered++;} } });
    run.shatteredCount=(run.shatteredCount||0)+shattered;
    const used=new Set(cards); run.hand=run.hand.filter(c=>!used.has(c)); refillHand();
    return res;
  }
  function clearHeat(metrics) {
    run.stagesCleared++;
    if(run.__simStats){
      const target=stageTarget();
      run.__simStats.clearMargins.push((run.stageScore-target)/Math.max(1,target));
      run.__simStats.clearPlays.push(run.handsPlayedThisStage);
    }
    const grade=GRADES[Math.min(4,Math.max(1,run.handsPlayedThisStage))];
    const interest=Math.min(INTEREST_CAP,Math.floor(run.runCoins/INTEREST_PER));
    run.runCoins += runReward(run.stage)+interest+grade.bonus;
    for(const j of run.jokers.slice()) if(j.onHeatClear) j.onHeatClear();
    if(run.modifier) run.modifiersSurvived.push(run.modifier.name);
    run.inflation=mod('inflation');
    assertRun('clear heat '+run.stage);
  }
  function setupHeat(stage) {
    run.stage=stage; run.stageScore=0; run.handsLeft=HANDS_PER_STAGE; run.handsPlayedThisStage=0; run.prevHandType=null;
    if(run.__simSeed!==undefined) resetPhase(run.__simSeed,stage,1);
    assignModifier(); run.discardsLeft=effDiscards();
    if(run.__simSeed!==undefined) resetPhase(run.__simSeed,stage,2);
    run.deck=buildDeck(); run.heatDeck=run.deck.slice(); dealFreshHand();
  }
  function simulateOne(config, metrics) {
    pendingGauntlet=!!config.gauntlet;
    run=newRunState(); pendingGauntlet=false;
    run.gauntlet=!!config.gauntlet; run.cards=baseCardSet(); run.jokers=[]; run.jokerState={};
    run.__simSeed=config.seed;
    run.__simStats={
      plays:0,playedCards:0,jokerTriggerEvents:0,activeJokerSlots:0,equippedJokerSlots:0,activeJokerPlays:0,
      wildMoments:0,megaMoments:0,greatMoments:0,niceMoments:0,finalPlayClears:0,comebackClears:0,
      shopVisits:0,shopOffers:0,affordableShopOffers:0,choiceShops:0,deadShops:0,
      playScores:[],clearMargins:[],clearPlays:[]
    };
    account.unlocked=new Set(config.unlocked);
    const forcedStarterIds=Array.isArray(config.starterIds)
      ? config.starterIds
      : (config.starterId ? [config.starterId] : []);
    for(const id of forcedStarterIds){
      const starter=JOKERS.find(j=>j.id===id);
      if(starter && !run.jokers.some(j=>j.id===id)) run.jokers.push(starter);
    }
    setupHeat(1);
    if(config.starter && !forcedStarterIds.length){
      const candidates=JOKERS.filter(j=>account.unlocked.has(j.id));
      if(candidates.length) run.jokers.push(candidates.map(j=>({j,v:strategyValue(j,config.strategy)})).sort((a,b)=>b.v-a.v)[0].j);
    }
    const finalHeat=config.gauntlet?GAUNTLET_HEATS:12;
    let won=false, failAt=0;
    for(let stage=1;stage<=finalHeat;stage++){
      if(stage>1) setupHeat(stage);
      let guard=0;
      while(run.stageScore<stageTarget() && run.handsLeft>0 && run.hand.length && guard++<30){
        const best=bestChoice(); if(!best) break;
        const need=(stageTarget()-run.stageScore)/Math.max(1,run.handsLeft);
        const weak=(best.res.handType==='High Card'||best.res.handType==='Pair') && best.res.total<need;
        if(run.discardsLeft>0 && run.deck.length>0 && (best.res.total<need*.78 || weak)) { if(discardForDraw(config.strategy)){ assertRun('discard heat '+stage); continue; } }
        playChoice(best,metrics); assertRun('play heat '+stage);
      }
      if(run.stageScore<stageTarget()){ failAt=stage; break; }
      clearHeat(metrics);
      if(stage===finalHeat){won=true;break;}
      buyAtShop(metrics,config.strategy); assertRun('shop heat '+stage);
      run.inflation=false;
    }
    metrics.runs++; if(won) metrics.wins++; else metrics.failAt[failAt]=(metrics.failAt[failAt]||0)+1;
    metrics.cleared.push(run.stagesCleared); metrics.scores.push(run.totalScore); metrics.bestPlays.push(run.bestPlay);
    for(const j of run.jokers) metrics.finalJokers[j.id]=(metrics.finalJokers[j.id]||0)+1;
    const outcome={
      seed:config.seed,won,failAt,cleared:run.stagesCleared,totalScore:run.totalScore,bestPlay:run.bestPlay,
      starterIds:forcedStarterIds.slice(),finalJokers:run.jokers.map(j=>j.id),
      handTypeCounts:Object.assign({},run.handTypeCounts),simStats:{
        plays:run.__simStats.plays,playedCards:run.__simStats.playedCards,
        jokerTriggerEvents:run.__simStats.jokerTriggerEvents,activeJokerSlots:run.__simStats.activeJokerSlots,
        equippedJokerSlots:run.__simStats.equippedJokerSlots,activeJokerPlays:run.__simStats.activeJokerPlays,
        wildMoments:run.__simStats.wildMoments,megaMoments:run.__simStats.megaMoments,
        greatMoments:run.__simStats.greatMoments,niceMoments:run.__simStats.niceMoments,
        finalPlayClears:run.__simStats.finalPlayClears,comebackClears:run.__simStats.comebackClears,
        shopVisits:run.__simStats.shopVisits,shopOffers:run.__simStats.shopOffers,
        affordableShopOffers:run.__simStats.affordableShopOffers,choiceShops:run.__simStats.choiceShops,
        deadShops:run.__simStats.deadShops,playScores:run.__simStats.playScores.slice(),
        clearMargins:run.__simStats.clearMargins.slice(),clearPlays:run.__simStats.clearPlays.slice()
      }
    };
    if(metrics.outcomes) metrics.outcomes.push(outcome);
    return outcome;
  }
  function blankMetrics(name){ return {name,runs:0,wins:0,cleared:[],scores:[],bestPlays:[],failAt:{},handTypes:{},jokerBuys:{},finalJokers:{},supplies:{},rerolls:0}; }
  function summarize(m){
    const avg=a=>a.reduce((s,x)=>s+x,0)/Math.max(1,a.length), sorted=m.cleared.slice().sort((a,b)=>a-b);
    const pct=p=>sorted[Math.min(sorted.length-1,Math.floor(sorted.length*p))]||0;
    const top=o=>Object.entries(o).sort((a,b)=>b[1]-a[1]).slice(0,15).map(([id,n])=>({id,n}));
    return {name:m.name,runs:m.runs,wins:m.wins,winRate:+(100*m.wins/Math.max(1,m.runs)).toFixed(2),avgCleared:+avg(m.cleared).toFixed(2),median:pct(.5),p90:pct(.9),avgScore:+avg(m.scores).toFixed(1),avgBestPlay:+avg(m.bestPlays).toFixed(1),failAt:m.failAt,handTypes:m.handTypes,topBuys:top(m.jokerBuys),topFinal:top(m.finalJokers),supplies:m.supplies,rerolls:m.rerolls};
  }
  function average(values){ return values.reduce((sum,value)=>sum+value,0)/Math.max(1,values.length); }
  function normalizedEntropy(counts){
    const values=Object.values(counts||{}).filter(value=>value>0), total=values.reduce((sum,value)=>sum+value,0);
    if(!total||values.length<2) return 0;
    const entropy=-values.reduce((sum,value)=>{const p=value/total;return sum+p*Math.log(p);},0);
    return entropy/Math.log(handTypes.length);
  }
  function percentile(values,p){
    if(!values.length) return 0;
    const sorted=values.slice().sort((a,b)=>a-b);
    return sorted[Math.min(sorted.length-1,Math.max(0,Math.floor((sorted.length-1)*p)))];
  }
  function funSummary(outcomes){
    const aggregateHands={}, totals={
      plays:0,playedCards:0,jokerTriggerEvents:0,activeJokerSlots:0,equippedJokerSlots:0,activeJokerPlays:0,
      wildMoments:0,megaMoments:0,greatMoments:0,niceMoments:0,finalPlayClears:0,comebackClears:0,
      shopVisits:0,shopOffers:0,affordableShopOffers:0,choiceShops:0,deadShops:0,clears:0
    };
    const clearMargins=[], clearPlays=[], playScores=[], runEntropies=[], builds=new Set();
    for(const outcome of outcomes){
      for(const [type,count] of Object.entries(outcome.handTypeCounts||{})) aggregateHands[type]=(aggregateHands[type]||0)+count;
      runEntropies.push(normalizedEntropy(outcome.handTypeCounts||{}));
      const stats=outcome.simStats||{};
      for(const key of Object.keys(totals)) if(key!=='clears') totals[key]+=Number(stats[key]||0);
      totals.clears+=outcome.cleared||0;
      clearMargins.push(...(stats.clearMargins||[])); clearPlays.push(...(stats.clearPlays||[])); playScores.push(...(stats.playScores||[]));
      builds.add((outcome.finalJokers||[]).slice().sort().join('|'));
    }
    const handEntries=Object.entries(aggregateHands).sort((a,b)=>b[1]-a[1]);
    const totalHandPlays=handEntries.reduce((sum,row)=>sum+row[1],0);
    let jaccardTotal=0,jaccardPairs=0;
    const pairLimit=Math.min(1000,Math.max(0,outcomes.length-1));
    for(let i=0;i<pairLimit;i++){
      const a=new Set(outcomes[i].finalJokers||[]);
      const b=new Set(outcomes[(i*37+17)%outcomes.length].finalJokers||[]);
      const union=new Set([...a,...b]), intersection=[...a].filter(id=>b.has(id)).length;
      if(union.size){ jaccardTotal+=1-intersection/union.size; jaccardPairs++; }
    }
    const meanScore=average(outcomes.map(o=>o.totalScore));
    const variance=average(outcomes.map(o=>Math.pow(o.totalScore-meanScore,2)));
    const gradeCounts={S:0,A:0,B:0,C:0};
    for(const plays of clearPlays) gradeCounts[plays<=1?'S':plays===2?'A':plays===3?'B':'C']++;
    const reachedBoss=outcomes.filter(o=>o.cleared>=11).length;
    const bossFails=outcomes.filter(o=>o.failAt===12).length;
    return {
      handEntropy:+normalizedEntropy(aggregateHands).toFixed(3),
      meanRunHandEntropy:+average(runEntropies).toFixed(3),
      dominantHand:handEntries.length?handEntries[0][0]:null,
      dominantHandShare:+(100*(handEntries.length?handEntries[0][1]:0)/Math.max(1,totalHandPlays)).toFixed(2),
      handShares:Object.fromEntries(handEntries.map(([type,count])=>[type,+(100*count/Math.max(1,totalHandPlays)).toFixed(2)])),
      avgPlaysPerRun:+(totals.plays/Math.max(1,outcomes.length)).toFixed(2),
      avgPlaysPerClear:+(totals.plays/Math.max(1,totals.clears)).toFixed(2),
      avgCardsPerPlay:+(totals.playedCards/Math.max(1,totals.plays)).toFixed(2),
      jokerTriggerEventsPerPlay:+(totals.jokerTriggerEvents/Math.max(1,totals.plays)).toFixed(2),
      jokerActivePlayRate:+(100*totals.activeJokerPlays/Math.max(1,totals.plays)).toFixed(2),
      activeEquippedSlotRate:+(100*totals.activeJokerSlots/Math.max(1,totals.equippedJokerSlots)).toFixed(2),
      notablePlayRate:+(100*(totals.wildMoments+totals.megaMoments+totals.greatMoments)/Math.max(1,totals.plays)).toFixed(2),
      anyCalloutPlayRate:+(100*(totals.wildMoments+totals.megaMoments+totals.greatMoments+totals.niceMoments)/Math.max(1,totals.plays)).toFixed(2),
      finalPlayClearRate:+(100*totals.finalPlayClears/Math.max(1,totals.clears)).toFixed(2),
      comebackClearRate:+(100*totals.comebackClears/Math.max(1,totals.clears)).toFixed(2),
      closeClearRate:+(100*clearMargins.filter(value=>value<=.10).length/Math.max(1,clearMargins.length)).toFixed(2),
      avgClearMarginPct:+(100*average(clearMargins)).toFixed(2),
      p90ClearMarginPct:+(100*percentile(clearMargins,.9)).toFixed(2),
      meaningfulShopRate:+(100*totals.choiceShops/Math.max(1,totals.shopVisits)).toFixed(2),
      deadShopRate:+(100*totals.deadShops/Math.max(1,totals.shopVisits)).toFixed(2),
      avgAffordableOffersPerShop:+(totals.affordableShopOffers/Math.max(1,totals.shopVisits)).toFixed(2),
      uniqueFinalBuilds:builds.size,
      uniqueFinalBuildRate:+(100*builds.size/Math.max(1,outcomes.length)).toFixed(2),
      meanBuildJaccardDistance:+(jaccardTotal/Math.max(1,jaccardPairs)).toFixed(3),
      scoreCoefficientOfVariation:+(Math.sqrt(variance)/Math.max(1,meanScore)).toFixed(3),
      earlyLossRate:+(100*outcomes.filter(o=>!o.won&&o.failAt>0&&o.failAt<=6).length/Math.max(1,outcomes.length)).toFixed(2),
      bossHazard:+(100*bossFails/Math.max(1,reachedBoss)).toFixed(2),
      gradeShares:Object.fromEntries(Object.entries(gradeCounts).map(([grade,count])=>[grade,+(100*count/Math.max(1,clearPlays.length)).toFixed(2)])),
      playScoreMedian:+percentile(playScores,.5).toFixed(1),playScoreP90:+percentile(playScores,.9).toFixed(1)
    };
  }

  function wilson(successes,total){
    if(!total) return {low:0,high:0};
    const z=1.959963984540054,p=successes/total,z2=z*z,den=1+z2/total;
    const center=(p+z2/(2*total))/den;
    const margin=z*Math.sqrt((p*(1-p)+z2/(4*total))/total)/den;
    return {low:+(100*Math.max(0,center-margin)).toFixed(2),high:+(100*Math.min(1,center+margin)).toFixed(2)};
  }

  if(decisionMode){
    const allIds=JOKERS.map(j=>j.id), starterPool=STARTER_JOKER_IDS.slice();
    const adaptive=STRATEGIES.find(strategy=>strategy.id==='adaptive_greedy');
    const starterArms=[
      {id:'none',name:'No start boost',ids:[],cost:0},
      ...starterPool.map(id=>{const joker=JOKERS.find(j=>j.id===id);return {id,name:joker.name,ids:[id],cost:starterJokerPrice(joker)};}),
      {id:'guided_copper_polish',name:'Guided first run: Copper Chip + Pair Polisher',ids:['copper','polish'],cost:0,tutorialOnly:true}
    ];
    const openingSeedBase=0x69131000, starterSeedBase=0x69132000;
    const openingMetrics=Object.fromEntries(starterArms.map(arm=>[arm.id,{
      id:arm.id,name:arm.name,ids:arm.ids.slice(),cost:arm.cost,tutorialOnly:!!arm.tutorialOnly,
      scores:[],handTypes:{},cardCounts:{},onePlayClears:0
    }]));
    const guidedFrontier=Object.fromEntries(handTypes.map(type=>[type,{available:0,scores:[]}]));

    function openingCandidateScore(candidate,jokers){
      const ctx=baseContext(candidate.cards,candidate.handType);
      let rankSum=0;
      for(const card of candidate.cards){
        if(!candidate.scoring.has(card)) continue;
        let value=card.value;
        for(const joker of jokers) if(joker.rankMod) value+=Number(joker.rankMod(card))||0;
        rankSum+=value;
      }
      const rankScore=Math.round(rankSum*RANK_SCALE);
      const valuePoints=HAND_BASE[candidate.handType]+rankScore;
      let mult=BASE_MULT;
      for(const joker of jokers) if(joker.addMult) mult+=Number(joker.addMult(ctx))||0;
      for(const joker of jokers) if(joker.xMult) mult*=Number(joker.xMult(ctx))||1;
      return Math.round(valuePoints*mult);
    }
    function openingCandidates(){
      const out=[], max=Math.min(effMaxSelect(),run.hand.length);
      for(let size=1;size<=max;size++){
        for(const cards of combos(run.hand,size)){
          const handType=evaluateHand(cards);
          if(size>1&&size<5){
            const useful=handType!=='High Card'||allSameColor(cards);
            if(!useful) continue;
          }
          out.push({cards,handType,scoring:scoringCards(cards,handType)});
        }
      }
      return out;
    }
    for(let index=0;index<openingDeals;index++){
      const seed=(openingSeedBase+index)>>>0;
      globalThis.SIM_RESET_RANDOM(seed);
      pendingGauntlet=false; run=newRunState(); run.cards=baseCardSet(); run.jokers=[]; run.jokerState={}; run.__simSeed=seed;
      account.unlocked=new Set(allIds);
      setupHeat(1);
      const candidates=openingCandidates();
      for(const arm of starterArms){
        const jokers=arm.ids.map(id=>JOKERS.find(j=>j.id===id)).filter(Boolean);
        run.jokers=jokers;
        let best=null;
        const bestByType=arm.id==='guided_copper_polish'?{}:null;
        for(const candidate of candidates){
          const score=openingCandidateScore(candidate,jokers);
          const option={candidate,score};
          if(!best||score>best.score||(score===best.score&&candidate.scoring.size>best.candidate.scoring.size)) best=option;
          if(bestByType){
            const current=bestByType[candidate.handType];
            if(!current||score>current.score||(score===current.score&&candidate.scoring.size>current.candidate.scoring.size)) bestByType[candidate.handType]=option;
          }
        }
        const metrics=openingMetrics[arm.id];
        metrics.scores.push(best.score);
        metrics.handTypes[best.candidate.handType]=(metrics.handTypes[best.candidate.handType]||0)+1;
        metrics.cardCounts[best.candidate.cards.length]=(metrics.cardCounts[best.candidate.cards.length]||0)+1;
        if(best.score>=HEAT_TARGETS[0]) metrics.onePlayClears++;
        if(bestByType){
          for(const [type,option] of Object.entries(bestByType)){
            guidedFrontier[type].available++;
            guidedFrontier[type].scores.push(option.score);
          }
        }
      }
      if((index+1)%5000===0) console.log('Opening deals complete:',index+1+'/'+openingDeals);
    }
    const openingSummaries=starterArms.map(arm=>{
      const metrics=openingMetrics[arm.id], total=metrics.scores.length;
      const typeEntries=Object.entries(metrics.handTypes).sort((a,b)=>b[1]-a[1]);
      return {
        id:arm.id,name:arm.name,starterIds:arm.ids.slice(),cost:arm.cost,tutorialOnly:!!arm.tutorialOnly,deals:total,
        avgBestScore:+average(metrics.scores).toFixed(2),medianBestScore:+percentile(metrics.scores,.5).toFixed(1),
        p10BestScore:+percentile(metrics.scores,.1).toFixed(1),p90BestScore:+percentile(metrics.scores,.9).toFixed(1),
        onePlayClearRate:+(100*metrics.onePlayClears/Math.max(1,total)).toFixed(2),
        dominantBestHand:typeEntries.length?typeEntries[0][0]:null,
        dominantBestHandShare:+(100*(typeEntries.length?typeEntries[0][1]:0)/Math.max(1,total)).toFixed(2),
        bestHandTypeShares:Object.fromEntries(typeEntries.map(([type,count])=>[type,+(100*count/Math.max(1,total)).toFixed(2)])),
        selectedCardCountShares:Object.fromEntries(Object.entries(metrics.cardCounts).map(([count,n])=>[count,+(100*n/Math.max(1,total)).toFixed(2)]))
      };
    });
    const guidedHandFrontier=Object.fromEntries(Object.entries(guidedFrontier).map(([type,metrics])=>[type,{
      availabilityRate:+(100*metrics.available/openingDeals).toFixed(2),
      conditionalAvgBestScore:+average(metrics.scores).toFixed(2),
      conditionalMedianBestScore:+percentile(metrics.scores,.5).toFixed(1),
      conditionalP90BestScore:+percentile(metrics.scores,.9).toFixed(1)
    }]));

    const starterSummaries=[];
    for(const arm of starterArms){
      const metrics=blankMetrics(arm.id); metrics.outcomes=[];
      for(let index=0;index<decisionStarterRuns;index++){
        const seed=(starterSeedBase+index)>>>0;
        globalThis.SIM_RESET_RANDOM(seed);
        simulateOne({unlocked:starterPool,starterIds:arm.ids,gauntlet:false,strategy:adaptive,seed},metrics);
      }
      const base=summarize(metrics), reachByHeat={};
      for(let heat=1;heat<=12;heat++) reachByHeat[heat]=+(100*metrics.outcomes.filter(outcome=>outcome.cleared>=heat-1).length/decisionStarterRuns).toFixed(2);
      starterSummaries.push({
        id:arm.id,name:arm.name,starterIds:arm.ids.slice(),cost:arm.cost,tutorialOnly:!!arm.tutorialOnly,
        runs:decisionStarterRuns,wins:metrics.wins,winRate:base.winRate,winRate95:wilson(metrics.wins,decisionStarterRuns),
        avgCleared:base.avgCleared,median:base.median,p90:base.p90,avgScore:base.avgScore,avgBestPlay:base.avgBestPlay,
        reachByHeat,failAt:base.failAt,handTypes:base.handTypes,topBuys:base.topBuys,topFinal:base.topFinal,
        fun:funSummary(metrics.outcomes),outcomes:metrics.outcomes
      });
      console.log('Starter arm complete:',arm.id,metrics.wins+'/'+decisionStarterRuns,'wins');
    }
    const bestStarter=starterSummaries.slice().sort((a,b)=>b.winRate-a.winRate||b.avgCleared-a.avgCleared)[0];
    const pairedAgainstBest=starterSummaries.map(arm=>{
      let bestOnly=0,armOnly=0,bothWin=0,bothLose=0;
      for(let index=0;index<decisionStarterRuns;index++){
        const bestWon=!!bestStarter.outcomes[index].won,armWon=!!arm.outcomes[index].won;
        if(bestWon&&armWon) bothWin++; else if(bestWon) bestOnly++; else if(armWon) armOnly++; else bothLose++;
      }
      return {id:arm.id,bestId:bestStarter.id,deltaWinRatePp:+(arm.winRate-bestStarter.winRate).toFixed(2),bestOnly,armOnly,bothWin,bothLose};
    });
    return {
      mode:'decision',source:'www/index.html',version:globalThis.SIM_VERSION,
      sourceSha256:globalThis.SIM_SOURCE_SHA256,script:'tools/deep-sim-v57.js',scriptSha256:globalThis.SIM_SCRIPT_SHA256,
      generatedAt:new Date().toISOString(),durationMs:Date.now()-startedAt,
      methodology:{
        opening:'Paired initial nine-card deals. Every legal useful one-to-five-card play is enumerated. The displayed best score is immediate score, not a claim that immediate greed maximises the full run.',
        starters:'Paired complete 12-Heat runs with the same adaptive shop policy and the real ten-Joker starter shop pool. Start-boost account coin costs are reported but not deducted from run coins.',
        fun:'Descriptive simulation proxies only: choice variety, build diversity, Joker activity, dramatic clears, shop agency and failure walls. Human enjoyment requires closed-test ratings.'
      },
      seedSpec:{openingBase:'0x69131000',starterBase:'0x69132000',paired:true,phaseStreams:['modifier','deck-and-draw','shop']},
      counts:{jokers:JOKERS.length,openingDeals,openingArms:starterArms.length,starterRunsPerArm:decisionStarterRuns,starterArms:starterArms.length,fullRuns:decisionStarterRuns*starterArms.length},
      opening:{summaries:openingSummaries,guidedHandFrontier},
      starters:{shopPool:'starter_collection',policy:adaptive.id,bestId:bestStarter.id,summaries:starterSummaries,pairedAgainstBest},
      dataFailures:failures,hookErrors,invariantFailures
    };
  }

  if(strategyMode){
    const allIds=JOKERS.map(j=>j.id), summaries=[];
    const forcedStarterIds=fixedStarter==='guided' ? ['copper','polish']
      : (fixedStarter==='none'||fixedStarter==='auto' ? [] : [fixedStarter]);
    if(forcedStarterIds.some(id=>!allIds.includes(id))) throw new Error('Unknown fixed starter: '+fixedStarter);
    for(const strategy of STRATEGIES){
      const metrics=blankMetrics(strategy.id); metrics.outcomes=[];
      for(let i=0;i<strategyRuns;i++){
        const seed=(strategySeedBase+i)>>>0;
        globalThis.SIM_RESET_RANDOM(seed);
        simulateOne({
          unlocked:allIds,starter:fixedStarter==='auto',starterIds:forcedStarterIds,
          gauntlet:false,strategy,seed
        },metrics);
      }
      const base=summarize(metrics);
      const reached9=metrics.outcomes.filter(x=>x.cleared>=8).length;
      const reached11=metrics.outcomes.filter(x=>x.cleared>=10).length;
      const cleared12=metrics.outcomes.filter(x=>x.won).length;
      const reachByHeat={};
      for(let heat=1;heat<=12;heat++) reachByHeat[heat]=+(100*metrics.outcomes.filter(x=>x.cleared>=heat-1).length/strategyRuns).toFixed(2);
      summaries.push({
        id:strategy.id,name:strategy.name,description:strategy.description,
        preferenceIds:(strategy.prefer||[]).slice(),reserve:strategy.reserve||0,
        runs:strategyRuns,wins:cleared12,winRate:+(100*cleared12/strategyRuns).toFixed(2),
        winRate95:wilson(cleared12,strategyRuns),
        reachH9:+(100*reached9/strategyRuns).toFixed(2),reachH9_95:wilson(reached9,strategyRuns),
        reachH11:+(100*reached11/strategyRuns).toFixed(2),reachH11_95:wilson(reached11,strategyRuns),
        avgCleared:base.avgCleared,median:base.median,p90:base.p90,avgScore:base.avgScore,avgBestPlay:base.avgBestPlay,
        failAt:base.failAt,handTypes:base.handTypes,topBuys:base.topBuys,topFinal:base.topFinal,
        fun:funSummary(metrics.outcomes),
        outcomes:metrics.outcomes
      });
      console.log('Strategy complete:',strategy.id,cleared12+'/'+strategyRuns,'wins');
    }
    const best=summaries.slice().sort((a,b)=>b.winRate-a.winRate)[0];
    const pairedAgainstBest=summaries.map(strategy=>{
      let bestOnly=0,strategyOnly=0,bothWin=0,bothLose=0;
      for(let i=0;i<strategyRuns;i++){
        const bw=!!best.outcomes[i].won,sw=!!strategy.outcomes[i].won;
        if(bw&&sw) bothWin++; else if(bw) bestOnly++; else if(sw) strategyOnly++; else bothLose++;
      }
      return {id:strategy.id,bestId:best.id,deltaWinRatePp:+(strategy.winRate-best.winRate).toFixed(2),bestOnly,strategyOnly,bothWin,bothLose};
    });
    let mixedOutcomeSeeds=0,universalWinSeeds=0,universalLossSeeds=0;
    for(let i=0;i<strategyRuns;i++){
      const wins=summaries.map(strategy=>!!strategy.outcomes[i].won);
      const count=wins.filter(Boolean).length;
      if(count===0) universalLossSeeds++;
      else if(count===wins.length) universalWinSeeds++;
      else mixedOutcomeSeeds++;
    }
    return {
      mode:'strategy',source:'www/index.html',version:globalThis.SIM_VERSION,
      sourceSha256:globalThis.SIM_SOURCE_SHA256,script:'tools/deep-sim-v57.js',scriptSha256:globalThis.SIM_SCRIPT_SHA256,
      generatedAt:new Date().toISOString(),durationMs:Date.now()-startedAt,
      starterMode:fixedStarter,
      seedSpec:{base:'0x69100000',runsPerStrategy:strategyRuns,pairedRunSeeds:true,phaseStreams:['modifier','deck-and-draw','shop'],note:'Each strategy reuses the same per-run seed. Heat setup and shop phases reset deterministic substreams; paths can still diverge after different decisions.'},
      counts:{jokers:JOKERS.length,strategies:STRATEGIES.length,runsPerStrategy:strategyRuns,fullRuns:STRATEGIES.length*strategyRuns},
      agency:{mixedOutcomeSeeds,universalWinSeeds,universalLossSeeds,mixedOutcomeRate:+(100*mixedOutcomeSeeds/strategyRuns).toFixed(2),universalLossRate:+(100*universalLossSeeds/strategyRuns).toFixed(2)},
      dataFailures:failures,hookErrors,invariantFailures,strategies:summaries,pairedAgainstBest
    };
  }

  // Static data and hook validation.
  const ids=new Set(), names=new Set();
  for(const j of JOKERS){
    if(ids.has(j.id)) record(failures,{kind:'duplicate-joker-id',id:j.id}); ids.add(j.id);
    if(names.has(j.name)) record(failures,{kind:'duplicate-joker-name',name:j.name}); names.add(j.name);
    if(!raritySet.has(j.rarity)||!Number.isFinite(j.price)||j.price<0||typeof j.desc!=='string') record(failures,{kind:'bad-joker-data',id:j.id});
  }
  pendingGauntlet=false; run=newRunState(); run.cards=baseCardSet(); run.deck=buildDeck(); dealFreshHand(); account.unlocked=new Set(JOKERS.map(j=>j.id));
  const hookStats=[];
  for(const j of JOKERS){
    let tested=0, active=0;
    try{ if(j.rankMod){ for(const c of run.cards){tested++; if((j.rankMod(c)||0)!==0)active++;} } }catch(e){hookErrors.push({id:j.id,hook:'rankMod',error:String(e)});}
    const savedJokers=run.jokers.slice(); run.jokers=[j];
    for(let i=0;i<12;i++){
      run.stage=1+i; run.handsLeft=1+(i%4); run.handsPlayedThisStage=i%4; run.discardsLeft=i%6; run.destroyedCount=i%8; run.copiedCount=i%5;
      run.runCoins=i*4; run.stagesCleared=i; run.stageScore=0; run.handLevels={Pair:i%3,Flush:(i+1)%3};
      run.modifier=i%4===0?MODIFIERS[i%MODIFIERS.length]:null;
      if(i%3===0) run.cards=baseCardSet().slice(0,40); else run.cards=baseCardSet();
      const cards=shuffled(run.cards).slice(0,5), ctx=baseContext(cards,handTypes[i%handTypes.length]);
      try{ if(j.addMult){tested++;if(Math.abs(Number(j.addMult(ctx))||0)>.0001)active++;} }catch(e){hookErrors.push({id:j.id,hook:'addMult',error:String(e)});}
      try{ if(j.xMult){tested++;if(Math.abs((Number(j.xMult(ctx))||1)-1)>.0001)active++;} }catch(e){hookErrors.push({id:j.id,hook:'xMult',error:String(e)});}
    }
    run.cards=baseCardSet(); run.jokers=savedJokers;
    if(j.onScored||j.onHeatClear||utilityIds.has(j.id)) active++;
    hookStats.push({id:j.id,tested,active,activationRate:tested?+(100*active/tested).toFixed(1):100});
  }

  // Random scoring stress and all-Joker interaction coverage.
  let scoringCases=0;
  const scoringTarget=quick?10000:50000;
  for(let i=0;i<scoringTarget;i++){
    run=newRunState(); run.cards=baseCardSet(); run.deck=buildDeck(); run.handLevels={};
    const count=Math.floor(Math.random()*6); run.jokers=shuffled(JOKERS).slice(0,count); run.stage=1+Math.floor(Math.random()*15);
    run.stagesCleared=Math.max(0,run.stage-1); run.handsLeft=1+Math.floor(Math.random()*4); run.handsPlayedThisStage=4-run.handsLeft;
    run.discardsLeft=Math.floor(Math.random()*6); run.modifier=Math.random()<.35?sample(MODIFIERS):null;
    if(Math.random()<.25) run.handLevels[sample(handTypes)]=1+Math.floor(Math.random()*5);
    const n=1+Math.floor(Math.random()*Math.min(6,effMaxSelect())); const cards=shuffled(run.cards).slice(0,n);
    for(const c of cards) if(Math.random()<.04)c.enh=sample(Object.keys(ENHANCEMENTS));
    try{ const res=scoreHand(cards,false); scoringCases++; if(!Number.isFinite(res.total)||!Number.isFinite(res.mult)||res.total<0||res.scoringCount<1||res.scoringCount>cards.length) record(failures,{kind:'scoring-invariant',i,total:res.total,mult:res.mult,type:res.handType,count:cards.length,jokers:run.jokers.map(j=>j.id)},100); }
    catch(e){ record(failures,{kind:'scoring-throw',i,error:String(e),jokers:run.jokers.map(j=>j.id)},100); }
  }
  console.log('Scoring sweep complete:', scoringCases);

  // Deterministic Frostbite high-card check.
  run=newRunState(); run.cards=baseCardSet(); run.jokers=[]; run.modifier=MODIFIERS.find(m=>m.id==='frostbite');
  const aceSpade=run.cards.find(c=>c.rank==='A'&&c.suit==='\u2660'), kingHeart=run.cards.find(c=>c.rank==='K'&&c.suit==='\u2665');
  const frostbiteResult=scoreHand([aceSpade,kingHeart],false);

  // The Cheat must choose the highest final-scoring 5-card subset, including hand-specific Jokers and boosts.
  let cheatCases=0, cheatMismatches=0; const cheatExamples=[];
  const cheat=JOKERS.find(j=>j.id==='cheat'), typeJokers=JOKERS.filter(j=>['polish','flushfund','wire','boostfiend','doubledown','master_class'].includes(j.id));
  const cheatTarget=quick?5000:15000;
  for(let i=0;i<cheatTarget;i++){
    run=newRunState(); run.cards=baseCardSet(); run.jokers=[cheat,...shuffled(typeJokers).slice(0,2)]; run.stage=6; run.handsLeft=2; run.handsPlayedThisStage=2;
    run.handLevels={}; if(Math.random()<.7)run.handLevels[sample(handTypes)]=1+Math.floor(Math.random()*5);
    run.prevHandType=Math.random()<.5?sample(handTypes):null;
    const six=shuffled(run.cards).slice(0,6), actual=scoreHand(six,false);
    let best=-Infinity,bestType='';
    for(let skip=0;skip<6;skip++){const r=scoreHand(six.filter((_,k)=>k!==skip),false);if(r.total>best){best=r.total;bestType=r.handType;}}
    cheatCases++; if(actual.total<best){cheatMismatches++; if(cheatExamples.length<8)cheatExamples.push({cards:six.map(c=>c.rank+c.suit),jokers:run.jokers.map(j=>j.id),levels:run.handLevels,actual:actual.total,actualType:actual.handType,best,bestType});}
  }
  console.log('Cheat subset sweep complete:', cheatCases, 'mismatches:', cheatMismatches);

  const allIds=JOKERS.map(j=>j.id), freeIds=JOKERS.filter(j=>j.unlock===0).map(j=>j.id);
  const cohorts=[];
  const standardRuns=quick?300:1500, starterRuns=quick?150:700, gauntletRuns=quick?100:400;
  const standard=blankMetrics('standard_all_unlocked'); for(let i=0;i<standardRuns;i++)simulateOne({unlocked:allIds,starter:true,gauntlet:false},standard); cohorts.push(summarize(standard));
  console.log('Standard cohort complete:', standard.runs);
  const starter=blankMetrics('standard_free_pool'); for(let i=0;i<starterRuns;i++)simulateOne({unlocked:freeIds,starter:true,gauntlet:false},starter); cohorts.push(summarize(starter));
  console.log('Free-pool cohort complete:', starter.runs);
  const gauntlet=blankMetrics('gauntlet_all_unlocked'); for(let i=0;i<gauntletRuns;i++)simulateOne({unlocked:allIds,starter:true,gauntlet:true},gauntlet); cohorts.push(summarize(gauntlet));
  console.log('Gauntlet cohort complete:', gauntlet.runs);

  return {
    mode:'stress',source:'www/index.html',version:globalThis.SIM_VERSION,
    sourceSha256:globalThis.SIM_SOURCE_SHA256,script:'tools/deep-sim-v57.js',scriptSha256:globalThis.SIM_SCRIPT_SHA256,
    seedSpec:{base:'0x57C0FFEE',generator:'mulberry32',deterministic:true},
    generatedAt:new Date().toISOString(),durationMs:Date.now()-startedAt,
    counts:{jokers:JOKERS.length,freeJokers:freeIds.length,scoringCases,cheatCases,fullRuns:standardRuns+starterRuns+gauntletRuns},
    dataFailures:failures,hookErrors,invariantFailures,
    jokerHooks:hookStats,
    frostbiteCheck:{cards:['A\u2660','K\u2665'],actualTotal:frostbiteResult.total,scoringFlags:frostbiteResult.flags,actualType:frostbiteResult.handType,expectedScoringCard:'K\u2665'},
    cheatAudit:{cases:cheatCases,mismatches:cheatMismatches,mismatchRate:+(100*cheatMismatches/cheatCases).toFixed(2),examples:cheatExamples},
    cohorts
  };
})();
`;

// Deep paired decision/strategy runs can take well over the original stress
// suite's 30-minute ceiling on Windows laptops. Keep a finite guard while
// allowing an explicitly requested long simulation to finish.
vm.runInContext(live + simulator, context, { filename: 'wildcard-v5.7-live-sim.js', timeout: 7200000 });
const result = context.__SIM_RESULT__;
if (!result) throw new Error('Simulator returned no result');

const downloads = process.env.SIM_OUTPUT_DIR
  ? path.resolve(process.env.SIM_OUTPUT_DIR)
  : path.join(process.env.USERPROFILE || path.dirname(root), 'Downloads');
if (result.mode === 'decision') {
  const jsonName=`wildcard-v${detectedVersion}-decision-lab-results.json`;
  const reportName=`wildcard-v${detectedVersion}-decision-lab-report.md`;
  const jsonPath=path.join(downloads,jsonName), reportPath=path.join(downloads,reportName);
  const openingRows=result.opening.summaries.map(row=>`| ${row.name} | ${row.deals.toLocaleString()} | ${row.avgBestScore} | ${row.medianBestScore} | ${row.p90BestScore} | ${row.onePlayClearRate}% | ${row.dominantBestHand} (${row.dominantBestHandShare}%) |`).join('\n');
  const starterRows=result.starters.summaries.map(row=>`| ${row.name} | ${row.runs.toLocaleString()} | ${row.winRate}% | ${row.winRate95.low}%–${row.winRate95.high}% | ${row.avgCleared} | ${row.reachByHeat[9]}% | ${row.reachByHeat[12]}% | ${row.fun.bossHazard}% |`).join('\n');
  const frontierRows=Object.entries(result.opening.guidedHandFrontier)
    .sort((a,b)=>b[1].conditionalAvgBestScore-a[1].conditionalAvgBestScore)
    .map(([type,row])=>`| ${type} | ${row.availabilityRate}% | ${row.conditionalAvgBestScore} | ${row.conditionalMedianBestScore} | ${row.conditionalP90BestScore} |`).join('\n');
  const best=result.starters.summaries.find(row=>row.id===result.starters.bestId);
  const report=`# WILDCARD v${detectedVersion} Opening and Starter Decision Lab

Generated from the canonical game source with paired deterministic seeds.

## Provenance

- Source: \`www/index.html\`
- Source SHA-256: \`${result.sourceSha256}\`
- Simulator: \`${result.script}\`
- Simulator SHA-256: \`${result.scriptSha256}\`
- Opening deals: ${result.counts.openingDeals.toLocaleString()} paired deals across ${result.counts.openingArms} configurations
- Full runs: ${result.counts.starterArms} starter configurations × ${result.counts.starterRunsPerArm.toLocaleString()} paired seeds = ${result.counts.fullRuns.toLocaleString()}

## Best Immediate Opening Play

| Start configuration | Deals | Mean best score | Median | P90 | Clears Heat 1 in one play | Most common best hand |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
${openingRows}

Immediate score is not the same as full-run value. These results enumerate the best legal useful play on the initial nine-card deal and do not assume a player should always play instead of discarding.

## Guided First-Run Hand Frontier

| Hand type | Available in initial deal | Mean best score when available | Median | P90 |
| --- | ---: | ---: | ---: | ---: |
${frontierRows}

## Starter Joker Full Runs

Every arm uses the same adaptive shop policy, the same paired run seeds and the real ten-Joker starter shop pool.

| Starter | Runs | Clear Heat 12 | Wilson 95% CI | Avg Heats cleared | Reach Heat 9 | Reach Heat 12 | Heat 12 hazard |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
${starterRows}

Observed leader: **${best.name}** at **${best.winRate}%**. Confidence intervals and paired outcomes must be considered before treating small gaps as real.

## Fun-Proxy Readout for the Observed Leader

- Hand diversity entropy: ${best.fun.handEntropy}
- Dominant hand: ${best.fun.dominantHand} (${best.fun.dominantHandShare}% of plays)
- Joker-active plays: ${best.fun.jokerActivePlayRate}%; trigger events per play: ${best.fun.jokerTriggerEventsPerPlay}
- Final-play clears: ${best.fun.finalPlayClearRate}%; close clears: ${best.fun.closeClearRate}%; comeback clears: ${best.fun.comebackClearRate}%
- Meaningful shops: ${best.fun.meaningfulShopRate}%; dead shops: ${best.fun.deadShopRate}%
- Mean final-build Jaccard distance: ${best.fun.meanBuildJaccardDistance}

## Validation and Limits

- Data/scoring failures: ${result.dataFailures.length}
- Hook errors: ${result.hookErrors.length}
- Run invariant failures: ${result.invariantFailures.length}
- Starter account-coin costs are reported but not deducted from run coins.
- Simulation proxies cannot prove enjoyment. Closed testing still needs player pace, fairness and Joker-recall questions.
`;
  fs.writeFileSync(jsonPath,JSON.stringify(result,null,2));
  fs.writeFileSync(reportPath,report);
  const releaseDir=path.join(root,'docs','release');
  fs.writeFileSync(path.join(releaseDir,jsonName),JSON.stringify(result,null,2));
  fs.writeFileSync(path.join(releaseDir,reportName),report);
  console.log(JSON.stringify({
    jsonPath,reportPath,durationMs:result.durationMs,counts:result.counts,
    bestStarter:{id:best.id,winRate:best.winRate,ci:best.winRate95,avgCleared:best.avgCleared},
    failures:{data:result.dataFailures.length,hooks:result.hookErrors.length,invariants:result.invariantFailures.length}
  },null,2));
  process.exit(0);
}
if (result.mode === 'strategy') {
  const jsonName=`wildcard-v${detectedVersion}-strategy-results.json`;
  const reportName=`wildcard-v${detectedVersion}-strategy-report.md`;
  const jsonPath=path.join(downloads,jsonName), reportPath=path.join(downloads,reportName);
  const rows=result.strategies.map(s=>`| ${s.name} | ${s.runs} | ${s.winRate}% | ${s.winRate95.low}%–${s.winRate95.high}% | ${s.reachH9}% | ${s.reachH11}% | ${s.avgCleared} |`).join('\n');
  const funRows=result.strategies.map(s=>`| ${s.name} | ${s.fun.handEntropy} | ${s.fun.dominantHand} (${s.fun.dominantHandShare}%) | ${s.fun.jokerActivePlayRate}% | ${s.fun.jokerTriggerEventsPerPlay} | ${s.fun.finalPlayClearRate}% | ${s.fun.meaningfulShopRate}% | ${s.fun.deadShopRate}% | ${s.fun.meanBuildJaccardDistance} |`).join('\n');
  const best=result.strategies.slice().sort((a,b)=>b.winRate-a.winRate)[0];
  const report=`# WILDCARD v${detectedVersion} Strategy Lab

Generated from the canonical game source with paired deterministic run seeds.

## Provenance

- Source: \`www/index.html\`
- Source SHA-256: \`${result.sourceSha256}\`
- Simulator: \`${result.script}\`
- Simulator SHA-256: \`${result.scriptSha256}\`
- Runs: ${result.counts.strategies} strategies × ${result.counts.runsPerStrategy} paired seeds = ${result.counts.fullRuns.toLocaleString()} complete runs
- Seed base: ${result.seedSpec.base}; phase streams: ${result.seedSpec.phaseStreams.join(', ')}
- Fixed start mode: ${result.starterMode}

## Results

| Strategy | Runs | Clear Heat 12 | Wilson 95% CI | Reach Heat 9 | Reach Heat 11 | Avg Heats Cleared |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
${rows}

The observed leader is **${best.name}** at **${best.winRate}%**, but rankings should not be treated as conclusive when confidence intervals overlap. These are deterministic bot policies, not player telemetry.

## Fun Proxies

| Strategy | Hand entropy | Dominant hand | Joker-active plays | Trigger events/play | Final-play clears | Meaningful shops | Dead shops | Build Jaccard distance |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
${funRows}

Across paired seeds, ${result.agency.mixedOutcomeRate}% produced different win/loss outcomes across strategies; ${result.agency.universalLossRate}% were lost by every tested strategy.

## Strategy Definitions

${result.strategies.map(s=>`- **${s.name}:** ${s.description}${s.reserve?` It keeps a ${s.reserve}-coin reserve.`:''}`).join('\n')}

## Validation

- Data/scoring failures: ${result.dataFailures.length}
- Hook errors: ${result.hookErrors.length}
- Run invariant failures: ${result.invariantFailures.length}
- Raw seed-level outcomes are retained in the JSON for paired comparisons and independent review.

## Method Caveat

Each strategy receives the same run seed, with deterministic substreams reset for modifier, deck/draw and shop phases. Different decisions can still consume different amounts of randomness after a phase begins, so this is a paired, reproducible comparison rather than a claim that every downstream draw is identical.
The card-play selector still maximises immediate score for every strategy. Strategy differences primarily measure shop/build preferences and Pair/Flush discard priorities, not fully independent human play styles.
`;
  fs.writeFileSync(jsonPath,JSON.stringify(result,null,2));
  fs.writeFileSync(reportPath,report);
  const releaseDir=path.join(root,'docs','release');
  fs.writeFileSync(path.join(releaseDir,jsonName),JSON.stringify(result,null,2));
  fs.writeFileSync(path.join(releaseDir,reportName),report);
  console.log(JSON.stringify({jsonPath,reportPath,durationMs:result.durationMs,counts:result.counts,best:{id:best.id,winRate:best.winRate,ci:best.winRate95},failures:{data:result.dataFailures.length,hooks:result.hookErrors.length,invariants:result.invariantFailures.length}},null,2));
  process.exit(0);
}
const jsonPath = path.join(downloads, `wildcard-v${detectedVersion}-sim-results.json`);
const reportPath = path.join(downloads, `wildcard-v${detectedVersion}-sim-report.md`);
fs.writeFileSync(jsonPath, JSON.stringify(result, null, 2));

const top = items => items.map(x => `${x.id} (${x.n})`).join(', ') || 'none';
const tableRows = result.cohorts.map(c => `| ${c.name} | ${c.runs} | ${c.winRate}% | ${c.avgCleared} | ${c.median} | ${c.p90} | ${c.avgScore} | ${c.avgBestPlay} |`).join('\n');
const zeroHooks = result.jokerHooks.filter(x => x.active === 0).map(x => x.id);
const alwaysHooks = result.jokerHooks.filter(x => x.tested >= 10 && x.activationRate >= 99).map(x => x.id);
const report = `# WILDCARD v${detectedVersion} Simulation Audit

Generated from the live \`www/index.html\` game script.

- Source SHA-256: \`${result.sourceSha256}\`
- Simulator SHA-256: \`${result.scriptSha256}\`
- Deterministic seed: \`${result.seedSpec.base}\` (${result.seedSpec.generator})

## Scope

- ${result.counts.scoringCases.toLocaleString()} randomized scoring and Joker-combination cases.
- ${result.counts.cheatCases.toLocaleString()} six-card "The Cheat" subset comparisons.
- ${result.counts.fullRuns.toLocaleString()} complete bot runs across standard, new-player, and Gauntlet cohorts.
- ${result.counts.jokers} Jokers checked for data validity, hook exceptions, unreachable effects, and interaction failures.
- Invariants checked after every discard, play, clear, and shop.

## Cohorts

| Cohort | Runs | Win rate | Avg cleared | Median | P90 | Avg score | Avg best play |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
${tableRows}

## Confirmed Mechanics Findings

- Frostbite high-card selection: played A♠ + K♥, scoring flags were ${JSON.stringify(result.frostbiteCheck.scoringFlags)}. The non-frozen K♥ should score. This is ${result.frostbiteCheck.scoringFlags[1] ? 'working' : 'broken'}.
- The Cheat chose a lower-scoring five-card subset in ${result.cheatAudit.mismatches.toLocaleString()} / ${result.cheatAudit.cases.toLocaleString()} cases (${result.cheatAudit.mismatchRate}%).
- Hook exceptions: ${result.hookErrors.length}.
- Scoring/data failures: ${result.dataFailures.length}.
- Run invariant failures: ${result.invariantFailures.length}.
- Never-activated Joker hooks in the coverage matrix: ${zeroHooks.join(', ') || 'none'}.
- Effectively always-active hooks in the coverage matrix: ${alwaysHooks.join(', ') || 'none'}.

## Failure Walls

${result.cohorts.map(c => `- **${c.name}:** ${Object.entries(c.failAt).map(([h,n])=>`Heat ${h}: ${n}`).join(', ') || 'no failures'}`).join('\n')}

## Most Selected Jokers

${result.cohorts.map(c => `- **${c.name}:** buys ${top(c.topBuys)}; final builds ${top(c.topFinal)}`).join('\n')}

## First Cheat Mismatches

\`\`\`json
${JSON.stringify(result.cheatAudit.examples, null, 2)}
\`\`\`
`;
fs.writeFileSync(reportPath, report);
const releaseDir = path.join(root, 'docs', 'release');
fs.writeFileSync(path.join(releaseDir, `wildcard-v${detectedVersion}-sim-results.json`), JSON.stringify(result, null, 2));
fs.writeFileSync(path.join(releaseDir, `wildcard-v${detectedVersion}-sim-report.md`), report);

console.log(JSON.stringify({
  jsonPath, reportPath, durationMs: result.durationMs, counts: result.counts,
  cohorts: result.cohorts.map(c => ({name:c.name,winRate:c.winRate,avgCleared:c.avgCleared,failAt:c.failAt})),
  dataFailures: result.dataFailures.length, hookErrors: result.hookErrors.length,
  invariantFailures: result.invariantFailures.length, frostbite: result.frostbiteCheck,
  cheat: {mismatches:result.cheatAudit.mismatches,rate:result.cheatAudit.mismatchRate}
}, null, 2));
