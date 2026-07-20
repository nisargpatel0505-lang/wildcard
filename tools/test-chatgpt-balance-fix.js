'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'www', 'index.html'), 'utf8');
assert(html.includes('const CHATGPT_FIX_2026_07_20 = true;'), 'hotfix marker missing');

function makeElement(id = '') {
  const classes = new Set();
  return {
    id,
    children: [],
    style: {},
    dataset: {},
    textContent: '',
    innerHTML: '',
    value: '',
    disabled: false,
    hidden: false,
    offsetParent: {},
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
    remove() {},
    focus() {},
    setAttribute() {},
    removeAttribute() {},
    addEventListener() {},
    querySelector() { return makeElement(); },
    querySelectorAll() { return []; },
    getBoundingClientRect() { return { x: 0, y: 0, width: 320, height: 480, bottom: 480 }; }
  };
}

const elements = new Map();
const documentStub = {
  body: makeElement('body'),
  hidden: false,
  activeElement: null,
  getElementById(id) {
    if (!elements.has(id)) elements.set(id, makeElement(id));
    return elements.get(id);
  },
  createElement() { return makeElement(); },
  querySelector() { return makeElement(); },
  querySelectorAll() { return []; },
  addEventListener() {}
};
const storage = new Map();
const localStorageStub = {
  getItem: key => storage.has(key) ? storage.get(key) : null,
  setItem: (key, value) => storage.set(key, String(value)),
  removeItem: key => storage.delete(key)
};

function mulberry(seed) {
  let a = seed >>> 0;
  return function random() {
    a |= 0;
    a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
let hostRandom = mulberry(0x56072026);
const mathStub = Object.create(Math);
mathStub.random = () => hostRandom();

const context = {
  console,
  Math: mathStub,
  JSON,
  Date,
  Set,
  Map,
  WeakMap,
  Promise,
  Object,
  Array,
  Number,
  String,
  Boolean,
  RegExp,
  Error,
  TypeError,
  Uint32Array,
  TextEncoder,
  parseInt,
  parseFloat,
  isNaN,
  Infinity,
  NaN,
  document: documentStub,
  localStorage: localStorageStub,
  navigator: {},
  location: { hostname: 'localhost' },
  history: { replaceState() {}, pushState() {} },
  screen: { width: 390, height: 844 },
  matchMedia: () => ({ matches: true }),
  getComputedStyle: () => ({}),
  confirm: () => true,
  alert() {},
  fetch: async () => ({ ok: false, json: async () => ({}) }),
  setTimeout: () => 0,
  clearTimeout() {},
  setInterval: () => 0,
  clearInterval() {},
  requestAnimationFrame: fn => { fn(0); return 0; },
  cancelAnimationFrame() {},
  addEventListener() {},
  removeEventListener() {},
  dispatchEvent() { return true; },
  performance: { now: () => Date.now() },
  structuredClone: global.structuredClone,
  btoa: value => Buffer.from(value, 'binary').toString('base64'),
  atob: value => Buffer.from(value, 'base64').toString('binary')
};
context.window = context;
context.globalThis = context;
context.scrollTo = () => {};
vm.createContext(context);

const scripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)];
assert(scripts.length, 'inline game script missing');
let live = scripts[scripts.length - 1][1];
const cutoff = live.indexOf('// ---- Global daily leaderboard');
assert(cutoff > 0, 'simulation cutoff missing');
live = live.slice(0, cutoff);

const exportsCode = String.raw`
;globalThis.__fixTest = {
  getRun:()=>run,
  setRun:value=>{run=value;},
  setPendingGauntlet:value=>{pendingGauntlet=!!value;},
  newRunState, baseCardSet, buildDeck, normalizeSculptedDeck,
  exactCardKey, exactCardCopyCount, copierCardBlockedReason,
  evaluateHand, scoreHand, stageTarget, handBase, runReward,
  makeModifierStack, modifierFromSaveId, modifierPoolForStage, assignModifier, mod,
  effHands, effDiscards, effHandSize,
  normalizeSupplyState, supplyPurchaseCount, supplySurcharge, supplyEscalationStep, supplyPrice,
  JOKERS, MODIFIERS, SUPPLIES, HAND_BASE,
  constants:{MIN_RUN_DECK_SIZE,MAX_EXACT_CARD_COPIES,ENDLESS_DOUBLE_MODIFIER_AFTER,SUPPLY_PRICE_STEP_EARLY,SUPPLY_PRICE_STEP_LATE}
};`;
vm.runInContext(live + exportsCode, context, { filename: 'wildcard-chatgpt-fix-live.js', timeout: 120000 });
const api = context.__fixTest;

function freshRun(overrides = {}) {
  api.setPendingGauntlet(false);
  const run = api.newRunState();
  Object.assign(run, overrides);
  api.setRun(run);
  return run;
}
function joker(id) {
  const found = api.JOKERS.find(j => j.id === id);
  assert(found, `missing joker ${id}`);
  return found;
}
function modifier(id) {
  const found = api.MODIFIERS.find(m => m.id === id);
  assert(found, `missing modifier ${id}`);
  return found;
}

// The reported exploit relied on Shortcut promoting a same-suit 3-card straight
// to Straight Flush. Shortcut now does exactly what its text says: Straight only.
{
  const run = freshRun({ jokers: [joker('shortcut')], modifier: null });
  const cards = [
    { rank: 'Q', value: 12, suit: '♠', red: false },
    { rank: 'K', value: 13, suit: '♠', red: false },
    { rank: 'A', value: 15, suit: '♠', red: false }
  ];
  assert.equal(api.evaluateHand(cards), 'Straight');
  run.jokers = [];
  assert.equal(api.evaluateHand(cards), 'High Card');
}

// Legacy 9-card exploit decks are repaired on load/next Heat: floor 24, no more
// than two exact copies, and only one enhanced copy of an exact card identity.
{
  const q = { rank: 'Q', value: 12, suit: '♠', red: false, enh: 'neon' };
  const k = { rank: 'K', value: 13, suit: '♠', red: false, enh: 'glass' };
  const a = { rank: 'A', value: 15, suit: '♠', red: false, enh: 'gild' };
  const run = freshRun({
    cards: [q, { ...q }, { ...q }, k, { ...k }, { ...k }, a, { ...a }, { ...a }],
    copiedCount: 6,
    destroyedCount: 49,
    shatteredCount: 0
  });
  api.normalizeSculptedDeck();
  assert.equal(run.cards.length, api.constants.MIN_RUN_DECK_SIZE);
  const counts = new Map();
  const enhancedCounts = new Map();
  for (const card of run.cards) {
    const key = api.exactCardKey(card);
    counts.set(key, (counts.get(key) || 0) + 1);
    if (card.enh) enhancedCounts.set(key, (enhancedCounts.get(key) || 0) + 1);
  }
  assert(Math.max(...counts.values()) <= api.constants.MAX_EXACT_CARD_COPIES);
  assert(Math.max(0, ...enhancedCounts.values()) <= 1);
  assert(run.copiedCount <= 3, 'trimmed copy history was not reduced');
}

// Copier eligibility is enforced by runtime helpers as well as greyed UI.
{
  const enhanced = { rank: 'A', value: 15, suit: '♥', red: true, enh: 'gild' };
  const plain = { rank: 'K', value: 13, suit: '♣', red: false };
  const run = freshRun({ cards: [enhanced, plain, { ...plain }] });
  assert.match(api.copierCardBlockedReason(enhanced), /Enhanced cards/);
  assert.match(api.copierCardBlockedReason(plain), /maximum 2 copies/);
  const unique = { rank: 'Q', value: 12, suit: '♦', red: true };
  run.cards.push(unique);
  assert.equal(api.copierCardBlockedReason(unique), '');
  assert(html.includes("if(blocked){ b.disabled=true; b.style.opacity='.35'"), 'Copier choices are not visibly greyed');
}

// Global supply surcharge survives shop changes and uses +5 through Heat 20,
// then +10 per purchase from Heat 21 onward. Old per-item counts migrate once.
{
  const run = freshRun({
    stage: 10,
    inflation: false,
    supplyPurchaseCounts: { scalpel: 2, copier: 1 },
    suppliesBoughtThisShop: []
  });
  delete run.supplyPriceEscalation;
  api.normalizeSupplyState();
  assert.equal(api.supplySurcharge(), 15);
  assert.equal(api.supplyEscalationStep(), 5);
  const scalpel = api.SUPPLIES.find(s => s.id === 'scalpel');
  const copier = api.SUPPLIES.find(s => s.id === 'copier');
  assert.equal(api.supplyPrice(scalpel), 18);
  assert.equal(api.supplyPrice(copier), 20, 'global surcharge did not carry to a different supply');
  run.stage = 21;
  assert.equal(api.supplyEscalationStep(), 10);
  run.supplyPriceEscalation += api.supplyEscalationStep();
  run.suppliesBoughtThisShop = [];
  assert.equal(api.supplyPrice(scalpel), 28, 'new Heat reset global supply surcharge');
  assert(html.includes("run.supplyPriceEscalation=supplySurcharge()+supplyEscalationStep()"));
  assert(html.includes("'supplyPriceEscalation'"), 'run save omits supply surcharge');
}

// Standard early modifiers exclude the new hard set; Endless Heat 51+ gets two
// distinct modifiers on every Heat and the stacked ID is save/resume safe.
{
  let run = freshRun({ stage: 6, endless: false, gauntlet: false, modifier: null });
  assert(!api.modifierPoolForStage().some(m => ['blackout', 'rush', 'drain', 'shakedown'].includes(m.id)));
  run = freshRun({ stage: 51, endless: true, gauntlet: false, modifier: null, rngSeed: 123456789, rngCounters: { deck: 0, shop: 0, mods: 0, luck: 0, boss: 0 } });
  api.assignModifier();
  assert(run.modifier && Array.isArray(run.modifier.mods));
  assert.equal(run.modifier.mods.length, 2);
  assert.notEqual(run.modifier.mods[0].id, run.modifier.mods[1].id);
  const restored = api.modifierFromSaveId(run.modifier.id);
  assert(restored && restored.mods && restored.mods.length === 2);
  run.modifier = restored;
  assert(api.mod(restored.mods[0].id));
  assert(api.mod(restored.mods[1].id));
}

// Hard modifier mechanics.
{
  const run = freshRun({
    stage: 9,
    jokers: [joker('copper'), joker('roller')],
    jokerState: {},
    bossBlockedJokerIds: [],
    cards: api.baseCardSet(),
    deck: [],
    handLevels: { Pair: 5 },
    handsLeft: 4,
    discardsLeft: 5,
    handsPlayedThisStage: 0,
    modifier: null
  });
  const pair = [
    { rank: 'A', value: 15, suit: '♠', red: false },
    { rank: 'A', value: 15, suit: '♥', red: true }
  ];
  const normal = api.scoreHand(pair, false);
  run.modifier = modifier('blackout');
  const blackout = api.scoreHand(pair, false);
  assert(normal.mult > blackout.mult);
  assert.equal(blackout.mult, 1.1);
  run.modifier = modifier('rush');
  assert.equal(api.effHands(), 3);
  run.modifier = modifier('drain');
  assert.equal(api.handBase('Pair'), api.HAND_BASE.Pair + 3 * 15);
}

// Endless target and income no longer scale linearly forever.
{
  const run = freshRun({ stage: 74, endless: true, gauntlet: false, modifier: null });
  assert(api.stageTarget() >= 83000, `Heat 74 target too low: ${api.stageTarget()}`);
  assert.equal(api.runReward(12), 15);
  assert(api.runReward(74) <= 24, `Heat 74 reward still unbounded: ${api.runReward(74)}`);
  assert.equal(run.stage, 74);
}

console.log(JSON.stringify({
  status: 'pass',
  source: 'www/index.html',
  sourceBytes: Buffer.byteLength(html),
  fixes: {
    shortcutThreeCardStraightFlushRemoved: true,
    deckFloor: api.constants.MIN_RUN_DECK_SIZE,
    exactCopyCap: api.constants.MAX_EXACT_CARD_COPIES,
    enhancedCopierBlockedAndGreyed: true,
    globalSupplySurcharge: { early: 5, afterHeat20: 10 },
    postHeat50DoubleModifiers: true,
    hardModifiers: ['blackout', 'rush', 'drain', 'shakedown'],
    endlessTargetAcceleration: true,
    endlessRewardCap: true
  }
}, null, 2));
