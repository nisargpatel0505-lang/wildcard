const fs = require('fs');
const path = require('path');
const vm = require('vm');
const crypto = require('crypto');

const root = path.resolve(__dirname, '..');
const htmlPath = path.join(root, 'www', 'index.html');
const html = fs.readFileSync(htmlPath, 'utf8');
const detectedVersion = (html.match(/>v(\d+\.\d+(?:\.\d+)?)<\/b>/) || [])[1] || 'unknown';
const strategyMode = process.argv.includes('--strategy');
const runsArg = process.argv.find(arg => /^--runs=\d+$/.test(arg));
const strategyRuns = runsArg ? Number(runsArg.split('=')[1]) : 400;
if (strategyMode && (!Number.isInteger(strategyRuns) || strategyRuns < 50 || strategyRuns > 5000)) {
  throw new Error('Strategy runs must be an integer from 50 to 5000');
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
  performance: { now: () => Date.now() }, structuredClone: global.structuredClone,
  SIM_QUICK: process.env.SIM_QUICK === '1', SIM_VERSION: detectedVersion,
  SIM_MODE: strategyMode ? 'strategy' : 'stress', SIM_STRATEGY_RUNS: strategyRuns,
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
  const strategyRuns = Number(globalThis.SIM_STRATEGY_RUNS) || 400;
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
  function bestChoice() {
    let best = null;
    const max = Math.min(effMaxSelect(), run.hand.length);
    for (let n = 1; n <= max; n++) {
      for (const cards of combos(run.hand, n)) {
        if (n > 1 && n < 5) {
          const type = evaluateHand(cards);
          const useful = type !== 'High Card' || allSameColor(cards) || (n === 3 && hasJoker('shortcut')) || (n === 4 && (hasJoker('pocketflush') || mod('ceiling')));
          if (!useful) continue;
        }
        const res = scoreHand(cards, false);
        if (!best || res.total > best.res.total || (res.total === best.res.total && res.scoringCount > best.res.scoringCount)) best = { cards, res };
      }
    }
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
    run.boughtThisShop=false; run.shopBuysUsed=0; run.suppliesBought=0; run.pendingShopJoker=null;
    if(run.__simSeed!==undefined) resetPhase(run.__simSeed,run.stage,20);
    rollJokerOffers(true); rollSupplyOffers();
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
      if (used) { run.runCoins -= price; run.suppliesBought++; bought++; metrics.supplies[s.id]=(metrics.supplies[s.id]||0)+1; }
    }
  }
  function playChoice(choice, metrics) {
    const cards=choice.cards, res=scoreHand(cards,true);
    if (!Number.isFinite(res.total) || !Number.isFinite(res.mult) || res.total < 0 || res.mult < 0) record(failures,{kind:'invalid-score',res,jokers:run.jokers.map(j=>j.id)},100);
    run.stageScore += res.total; run.totalScore += res.total;
    run.bestPlay=Math.max(run.bestPlay,res.total); if(run.bestPlay===res.total) run.bestPlayType=res.handType;
    run.handTypeCounts[res.handType]=(run.handTypeCounts[res.handType]||0)+1;
    metrics.handTypes[res.handType]=(metrics.handTypes[res.handType]||0)+1;
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
    account.unlocked=new Set(config.unlocked);
    setupHeat(1);
    if(config.starter){
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
    const outcome={seed:config.seed,won,failAt,cleared:run.stagesCleared,totalScore:run.totalScore,bestPlay:run.bestPlay,finalJokers:run.jokers.map(j=>j.id)};
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

  function wilson(successes,total){
    if(!total) return {low:0,high:0};
    const z=1.959963984540054,p=successes/total,z2=z*z,den=1+z2/total;
    const center=(p+z2/(2*total))/den;
    const margin=z*Math.sqrt((p*(1-p)+z2/(4*total))/total)/den;
    return {low:+(100*Math.max(0,center-margin)).toFixed(2),high:+(100*Math.min(1,center+margin)).toFixed(2)};
  }

  if(strategyMode){
    const allIds=JOKERS.map(j=>j.id), summaries=[];
    for(const strategy of STRATEGIES){
      const metrics=blankMetrics(strategy.id); metrics.outcomes=[];
      for(let i=0;i<strategyRuns;i++){
        const seed=(strategySeedBase+i)>>>0;
        globalThis.SIM_RESET_RANDOM(seed);
        simulateOne({unlocked:allIds,starter:true,gauntlet:false,strategy,seed},metrics);
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
    return {
      mode:'strategy',source:'www/index.html',version:globalThis.SIM_VERSION,
      sourceSha256:globalThis.SIM_SOURCE_SHA256,script:'tools/deep-sim-v57.js',scriptSha256:globalThis.SIM_SCRIPT_SHA256,
      generatedAt:new Date().toISOString(),durationMs:Date.now()-startedAt,
      seedSpec:{base:'0x69100000',runsPerStrategy:strategyRuns,pairedRunSeeds:true,phaseStreams:['modifier','deck-and-draw','shop'],note:'Each strategy reuses the same per-run seed. Heat setup and shop phases reset deterministic substreams; paths can still diverge after different decisions.'},
      counts:{jokers:JOKERS.length,strategies:STRATEGIES.length,runsPerStrategy:strategyRuns,fullRuns:STRATEGIES.length*strategyRuns},
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

// The expanded v6.9.1 suite runs 50k scoring cases, 15k Cheat checks and
// 2,600 complete runs. Slower Windows laptops can legitimately need more than
// the old 15-minute ceiling, so keep the guard while allowing the full audit.
vm.runInContext(live + simulator, context, { filename: 'wildcard-v5.7-live-sim.js', timeout: 1800000 });
const result = context.__SIM_RESULT__;
if (!result) throw new Error('Simulator returned no result');

const downloads = path.join(process.env.USERPROFILE || path.dirname(root), 'Downloads');
if (result.mode === 'strategy') {
  const jsonName=`wildcard-v${detectedVersion}-strategy-results.json`;
  const reportName=`wildcard-v${detectedVersion}-strategy-report.md`;
  const jsonPath=path.join(downloads,jsonName), reportPath=path.join(downloads,reportName);
  const rows=result.strategies.map(s=>`| ${s.name} | ${s.runs} | ${s.winRate}% | ${s.winRate95.low}%–${s.winRate95.high}% | ${s.reachH9}% | ${s.reachH11}% | ${s.avgCleared} |`).join('\n');
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

## Results

| Strategy | Runs | Clear Heat 12 | Wilson 95% CI | Reach Heat 9 | Reach Heat 11 | Avg Heats Cleared |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
${rows}

The observed leader is **${best.name}** at **${best.winRate}%**, but rankings should not be treated as conclusive when confidence intervals overlap. These are deterministic bot policies, not player telemetry.

## Strategy Definitions

${result.strategies.map(s=>`- **${s.name}:** ${s.description}${s.reserve?` It keeps a ${s.reserve}-coin reserve.`:''}`).join('\n')}

## Validation

- Data/scoring failures: ${result.dataFailures.length}
- Hook errors: ${result.hookErrors.length}
- Run invariant failures: ${result.invariantFailures.length}
- Raw seed-level outcomes are retained in the JSON for paired comparisons and independent review.

## Method Caveat

Each strategy receives the same run seed, with deterministic substreams reset for modifier, deck/draw and shop phases. Different decisions can still consume different amounts of randomness after a phase begins, so this is a paired, reproducible comparison rather than a claim that every downstream draw is identical.
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
