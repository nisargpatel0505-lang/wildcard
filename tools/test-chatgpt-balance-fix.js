'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'www', 'index.html'), 'utf8');
const scripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)];
assert.ok(scripts.length, 'no inline game script');
let live = scripts[scripts.length - 1][1];
const cutoff = live.indexOf('// ---- Global daily leaderboard');
assert.ok(cutoff > 0, 'simulation cutoff missing');
live = live.slice(0, cutoff);

function makeElement(id = '') {
  const classes = new Set();
  const attributes = new Map();
  return {
    id,
    children: [], style: {}, dataset: {}, textContent: '', innerHTML: '', value: '', disabled: false,
    hidden: false, offsetParent: {}, isConnected: true,
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
    remove() {}, focus() {}, scrollIntoView() {},
    setAttribute(k, v) { attributes.set(k, String(v)); },
    getAttribute(k) { return attributes.get(k) ?? null; },
    removeAttribute(k) { attributes.delete(k); },
    addEventListener() {}, removeEventListener() {},
    querySelector() { return makeElement(); }, querySelectorAll() { return []; },
    getBoundingClientRect() { return { x: 0, y: 0, width: 320, height: 480, bottom: 480 }; }
  };
}

const elements = new Map();
const body = makeElement('body');
const documentStub = {
  body, hidden: false, activeElement: null,
  getElementById(id) { if (!elements.has(id)) elements.set(id, makeElement(id)); return elements.get(id); },
  createElement() { return makeElement(); },
  querySelector() { return makeElement('active'); }, querySelectorAll() { return []; },
  addEventListener() {}, removeEventListener() {}
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
let hostRandom = mulberry(0xC0562026);
const mathStub = Object.create(Math);
mathStub.random = () => hostRandom();
const context = {
  console, Math: mathStub, JSON, Date, Set, Map, WeakMap, Promise, Object, Array, Number, String,
  Boolean, RegExp, Error, TypeError, parseInt, parseFloat, isNaN, Infinity, NaN,
  document: documentStub, localStorage: localStorageStub,
  navigator: {}, location: { hostname: 'localhost', protocol: 'http:' }, history: { replaceState() {}, pushState() {} },
  screen: { width: 390, height: 844 }, matchMedia: () => ({ matches: true, addEventListener() {}, removeEventListener() {} }),
  getComputedStyle: () => ({}), confirm: () => true, alert() {}, fetch: async () => ({ ok: false, json: async () => ({}) }),
  setTimeout: fn => { if (typeof fn === 'function') fn(); return 1; }, clearTimeout() {}, setInterval: () => 1, clearInterval() {},
  requestAnimationFrame: fn => { if (typeof fn === 'function') fn(0); return 0; }, cancelAnimationFrame() {},
  addEventListener() {}, removeEventListener() {}, dispatchEvent() { return true; },
  performance: { now: () => Date.now() }, structuredClone: global.structuredClone,
  TextEncoder, TextDecoder,
  crypto: global.crypto,
  btoa: value => Buffer.from(value, 'binary').toString('base64'),
  atob: value => Buffer.from(value, 'base64').toString('binary')
};
context.window = context;
context.globalThis = context;
context.scrollTo = () => {};
vm.createContext(context);

const tests = String.raw`
;globalThis.__FIX_TESTS__ = (function(){
  const results=[];
  function test(name, fn){
    try{ fn(); results.push({name,pass:true}); }
    catch(error){ results.push({name,pass:false,error:String(error&&error.stack||error)}); }
  }
  function ok(value,message){ if(!value) throw new Error(message||'expected truthy'); }
  function equal(actual,expected,message){ if(actual!==expected) throw new Error((message||'values differ')+': '+actual+' !== '+expected); }
  function reset(stage=1){
    storageMap.clear();
    run=newRunState();
    run.stage=stage;
    run.cards=baseCardSet();
    run.jokers=[];
    run.jokerState={};
    run.runCoins=1000;
    run.deck=[];
    run.hand=[];
    run.modifier=null;
    normalizeSupplyState();
    return run;
  }

  test('Shortcut three-card suited sequence remains a Straight',()=>{
    reset(8);
    run.jokers=[JOKERS.find(j=>j.id==='shortcut')];
    const cards=[
      {rank:'Q',value:12,suit:'♠',red:false},
      {rank:'K',value:13,suit:'♠',red:false},
      {rank:'A',value:15,suit:'♠',red:false}
    ];
    equal(evaluateHand(cards),'Straight','three-card Shortcut exploit survived');
  });

  test('Copier blocks enhanced, copied and third exact copies',()=>{
    reset(5);
    const ace={rank:'A',value:15,suit:'♠',red:false,enh:'neon'};
    equal(canCopyCard(ace),false,'enhanced Ace was copyable');
    const plain={rank:'A',value:15,suit:'♥',red:true};
    run.cards=[plain,{...plain,copied:true}];
    equal(canCopyCard(plain),false,'third exact Ace was copyable');
    equal(canCopyCard(run.cards[1]),false,'copied card was recursively copyable');
    equal(canEnhanceCard(run.cards[1]),false,'copied card was enhanceable');
  });

  test('Scalpel floor is 24 cards',()=>{
    reset(5);
    run.cards=baseCardSet().slice(0,MIN_DECK_SIZE);
    equal(run.cards.length,24);
    ok(run.cards.length<=MIN_DECK_SIZE,'deck floor constant not active');
  });

  test('Legacy exploit decks are repaired on resume',()=>{
    reset(30);
    const q={rank:'Q',value:12,suit:'♠',red:false};
    const k={rank:'K',value:13,suit:'♠',red:false};
    const a={rank:'A',value:15,suit:'♠',red:false,enh:'neon'};
    run.cards=[{...a,copied:true,enh:'glass'},q,{...q,copied:true},{...q,copied:true},k,{...k,copied:true},a];
    run.copiedCount=4; run.enhancedCount=2; run.destroyedCount=49;
    const result=normalizeDeckIntegrity();
    equal(result.changed,true);
    equal(run.cards.length,MIN_DECK_SIZE,'repair did not restore deck floor');
    ok(exactCardCount('Q','♠')<=MAX_EXACT_CARD_COPIES,'third Queen survived repair');
    ok(run.cards.filter(c=>c.copied).every(c=>!c.enh),'copied enhancement survived repair');
  });

  test('Supply surcharge is +5 through Heat 20 and +10 afterwards',()=>{
    reset(20);
    const copier=SUPPLIES.find(s=>s.id==='copier');
    equal(supplyPrice(copier),5);
    run.supplyPurchaseLedger.push({id:'copier',stage:20,step:nextSupplyIncrease()});
    normalizeSupplyState();
    equal(supplyPrice(copier),10,'Heat 20 purchase did not add five');
    run.stage=21;
    run.supplyPurchaseLedger.push({id:'copier',stage:21,step:nextSupplyIncrease()});
    normalizeSupplyState();
    equal(supplyPrice(copier),20,'Heat 21 purchase did not add ten');
    equal(supplyPurchaseCount(copier),2);
  });

  test('Legacy counts migrate to the durable ledger and survive JSON resume',()=>{
    reset(7);
    run.supplyPurchaseLedger=[];
    run.supplyPurchaseCounts={scalpel:2};
    normalizeSupplyState();
    equal(run.supplyPurchaseLedger.length,2);
    equal(supplyPrice(SUPPLIES.find(s=>s.id==='scalpel')),13);
    const saved=JSON.parse(JSON.stringify(run));
    run=newRunState();
    Object.assign(run,saved);
    normalizeSupplyState();
    equal(run.supplyPurchaseLedger.length,2);
    equal(supplyPrice(SUPPLIES.find(s=>s.id==='scalpel')),13);
  });

  test('finishSupply persists its purchase ledger immediately',()=>{
    reset(5);
    supplyOffers=[SUPPLIES.find(s=>s.id==='copier')];
    shopOffers=[];
    const copier=supplyOffers[0];
    const before=run.runCoins;
    equal(finishSupply(copier,'test purchase',()=>{}),true);
    equal(run.runCoins,before-5);
    equal(run.supplyPurchaseLedger.length,1);
    const raw=localStorage.getItem(RUN_KEY);
    ok(raw,'purchase was not saved');
    const saved=JSON.parse(raw);
    equal(saved.supplyPurchaseLedger.length,1,'saved ledger missing purchase');
    equal(saved.supplyPurchaseLedger[0].step,5);
  });

  test('Heat 51 receives two distinct stacked modifiers with a hard counter every deal',()=>{
    reset(51);
    run.endless=true;
    for(let i=0;i<100;i++){
      assignModifier();
      const parts=modifierParts();
      const ids=parts.map(m=>m.id);
      equal(ids.length,2,'late Endless did not stack two modifiers');
      equal(new Set(ids).size,2,'duplicate modifier stack');
      ok(parts.some(m=>m.hard),'late Endless rolled two soft modifiers');
    }
  });

  test('Stacked modifiers serialize and restore',()=>{
    reset(51); run.endless=true; assignModifier();
    const ids=modifierIds();
    const restored=restoreModifier(JSON.parse(JSON.stringify(ids)));
    equal(modifierParts(restored).length,2);
    equal(modifierParts(restored).map(m=>m.id).join(','),ids.join(','));
  });

  test('Null Field removes additive, multiplicative, Neon and Glass Mult',()=>{
    reset(18);
    run.modifier=restoreModifier(['blackout']);
    run.jokers=[JOKERS.find(j=>j.id==='copper'),JOKERS.find(j=>j.xMult)];
    const card={rank:'A',value:15,suit:'♠',red:false,enh:'glass'};
    run.cards=[card]; run.hand=[card]; run.deck=[];
    const result=scoreHand([card],false);
    equal(result.mult,BASE_MULT,'Null Field leaked a multiplier source');
  });

  test('Echo Chamber halves a repeated hand type',()=>{
    reset(15);
    run.modifier=restoreModifier(['echo']);
    run.prevHandType='Pair';
    const cards=[{rank:'A',value:15,suit:'♠',red:false},{rank:'A',value:15,suit:'♥',red:true}];
    run.cards=cards; run.hand=cards; run.deck=[];
    const result=scoreHand(cards,false);
    equal(result.handType,'Pair');
    equal(result.mult,BASE_MULT*0.5);
  });

  test('Endless target accelerates beyond the old linear curve',()=>{
    reset(50); run.endless=true;
    const old50=HEAT_TARGETS[11]+ENDLESS_STEP*(50-12);
    ok(stageTarget()>old50*2.5,'Heat 50 target still effectively linear');
    reset(74); run.endless=true;
    const old74=HEAT_TARGETS[11]+ENDLESS_STEP*(74-12);
    ok(stageTarget()>old74*5,'Heat 74 target still effectively linear');
  });

  return results;
})();
`;

context.storageMap = storageMap;
vm.runInContext(live + tests, context, { filename: 'WILDCARD live source + ChatGPT fix tests' });
const results = context.__FIX_TESTS__;
const failed = results.filter(r => !r.pass);
for (const result of results) {
  console.log(`${result.pass ? 'PASS' : 'FAIL'}  ${result.name}`);
  if (!result.pass) console.error(result.error);
}
console.log(`\n${results.length - failed.length}/${results.length} passed`);
if (failed.length) process.exitCode = 1;
