'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const html = fs.readFileSync(
  path.join(__dirname, '..', 'www', 'index.html'),
  'utf8'
);

function block(startMarker, endMarker) {
  const start = html.indexOf(startMarker);
  const end = html.indexOf(endMarker, start + startMarker.length);
  assert.notEqual(start, -1, `missing current source block: ${startMarker}`);
  assert.notEqual(end, -1, `missing current source block terminator: ${endMarker}`);
  return html.slice(start, end);
}

function statement(startMarker, endMarker) {
  const start = html.indexOf(startMarker);
  const end = html.indexOf(endMarker, start + startMarker.length);
  assert.notEqual(start, -1, `missing current source statement: ${startMarker}`);
  assert.notEqual(end, -1, `missing current source statement terminator: ${endMarker}`);
  return html.slice(start, end + endMarker.length);
}

function extractFunction(name) {
  const marker = `function ${name}(`;
  const start = html.indexOf(marker);
  assert.notEqual(start, -1, `missing current source function: ${name}`);

  for (let end = html.indexOf('}', start); end !== -1; end = html.indexOf('}', end + 1)) {
    const candidate = html.slice(start, end + 1);
    try {
      new vm.Script(candidate);
      return candidate;
    } catch (_) {
      // Continue until the parser sees the complete live function.
    }
  }

  assert.fail(`could not extract current source function: ${name}`);
}

const SUPPLIES_CODE = block(
  'const SUPPLIES = [',
  '// ---------- Card enhancements'
);

const SUPPLY_FUNCTIONS = [
  'shopPrice',
  'normalizeSupplyState',
  'supplyPurchaseCount',
  'supplyBoughtInShop',
  'supplyPrice',
  'openShop',
  'useSupply',
  'finishSupply'
].map(extractFunction).join('\n\n');

class FakeElement {
  constructor(id) {
    this.id = id;
    this._innerHTML = '';
    this.textContent = '';
    this.children = [];
    this.disabled = false;
    this.style = {};
  }

  get innerHTML() {
    return this._innerHTML;
  }

  set innerHTML(value) {
    this._innerHTML = String(value);
    if (value === '') this.children = [];
  }

  appendChild(child) {
    this.children.push(child);
    return child;
  }
}

function makeDocument() {
  const elements = new Map();
  return {
    getElementById(id) {
      if (!elements.has(id)) elements.set(id, new FakeElement(id));
      return elements.get(id);
    }
  };
}

function makeCards(count = 12) {
  return Array.from({ length: count }, (_, i) => ({
    rank: String((i % 9) + 2),
    value: (i % 9) + 2,
    suit: i % 2 ? '♠' : '♥',
    red: i % 2 === 0
  }));
}

function makeRun(overrides = {}) {
  return {
    stage: 3,
    endless: false,
    gauntlet: false,
    inflation: false,
    runCoins: 100,
    jokers: [],
    jokerState: {},
    cards: makeCards(),
    destroyedCount: 0,
    copiedCount: 0,
    handLevels: {},
    boostsBought: 0,
    pendingShopJoker: null,
    supplyPurchaseCounts: {},
    suppliesBoughtThisShop: [],
    boughtThisShop: false,
    shopBuysUsed: 0,
    guidedFirstRun: false,
    shopGuideShown: false,
    lastRunReward: 0,
    lastAcctReward: 0,
    lastInterest: 0,
    lastWildPityForced: false,
    wildMissShops: 0,
    abandoned: false,
    modifier: null,
    hand: [],
    ...overrides
  };
}

function createSupplyHarness(runOverrides = {}) {
  const events = {
    cardPickers: 0,
    boostPickers: 0,
    closes: 0,
    renders: 0,
    shopUpdates: 0,
    saves: 0,
    screens: [],
    achievements: 0
  };
  const context = {
    console,
    Math,
    Number,
    Object,
    Array,
    Set,
    String,
    Boolean,
    document: makeDocument(),
    run: makeRun(runOverrides),
    dailyMode: false,
    setTimeout(fn) {
      fn();
      return 1;
    },
    rollJokerOffers() {},
    rollSupplyOffers() {},
    updateShopSub() {
      events.shopUpdates += 1;
    },
    renderShop() {
      events.renders += 1;
    },
    showScreen(id) {
      events.screens.push(id);
    },
    showGradeStamp() {},
    showFirstShopGuide() {},
    saveRunState() {
      events.saves += 1;
    },
    openCardPicker() {
      events.cardPickers += 1;
    },
    openBoostPicker() {
      events.boostPickers += 1;
    },
    chord() {},
    closeOverlay() {
      events.closes += 1;
    },
    checkAchievements() {
      events.achievements += 1;
    }
  };
  context.window = context;
  context.globalThis = context;
  vm.createContext(context);
  vm.runInContext(
    `${SUPPLIES_CODE}
${SUPPLY_FUNCTIONS}
globalThis.__supplies = {
  SUPPLIES,
  shopPrice,
  normalizeSupplyState,
  supplyPurchaseCount,
  supplyBoughtInShop,
  supplyPrice,
  openShop,
  useSupply,
  finishSupply
};`,
    context,
    { filename: 'extracted www/index.html supply functions' }
  );

  return { context, events, api: context.__supplies };
}

function supply(api, id) {
  const found = api.SUPPLIES.find((item) => item.id === id);
  assert.ok(found, `missing live supply: ${id}`);
  return found;
}

function testIndependentPersistentPricesAndShopLocks() {
  const h = createSupplyHarness();
  const scalpel = supply(h.api, 'scalpel');
  const copier = supply(h.api, 'copier');
  let destroyed = 0;
  let copied = 0;

  h.api.normalizeSupplyState();
  assert.equal(h.api.supplyPrice(scalpel), 3);
  assert.equal(h.api.supplyPrice(copier), 5);

  assert.equal(
    h.api.finishSupply(scalpel, 'first Scalpel', () => { destroyed += 1; }),
    true
  );
  assert.equal(h.context.run.runCoins, 97);
  assert.equal(destroyed, 1);
  assert.equal(h.api.supplyPurchaseCount(scalpel), 1);
  assert.equal(h.api.supplyBoughtInShop(scalpel), true);
  assert.equal(h.api.supplyPrice(scalpel), 5);
  assert.equal(h.api.supplyPrice(copier), 5, 'Scalpel must not raise Copier');

  const rendersAfterFirstPurchase = h.events.renders;
  assert.equal(
    h.api.finishSupply(scalpel, 'double tap', () => { destroyed += 1; }),
    false
  );
  assert.equal(h.context.run.runCoins, 97);
  assert.equal(destroyed, 1, 'a stale/double completion mutated the deck twice');
  assert.equal(h.api.supplyPurchaseCount(scalpel), 1);
  assert.equal(
    h.events.renders,
    rendersAfterFirstPurchase,
    'a rejected double completion rerendered or re-ran purchase side effects'
  );

  h.api.openShop();
  assert.deepEqual(Array.from(h.context.run.suppliesBoughtThisShop), []);
  assert.equal(h.api.supplyPrice(scalpel), 5, 'new shop reset persistent Scalpel price');
  assert.equal(h.api.supplyPrice(copier), 5);

  assert.equal(
    h.api.finishSupply(scalpel, 'second Scalpel', () => { destroyed += 1; }),
    true
  );
  assert.equal(h.context.run.runCoins, 92);
  assert.equal(destroyed, 2);
  assert.equal(h.api.supplyPurchaseCount(scalpel), 2);
  assert.equal(h.api.supplyPrice(scalpel), 7);
  assert.equal(h.api.supplyPrice(copier), 5, 'second Scalpel raised Copier');

  assert.equal(
    h.api.finishSupply(copier, 'first Copier', () => { copied += 1; }),
    true,
    'a second distinct offer was incorrectly blocked in the same shop'
  );
  assert.equal(h.context.run.runCoins, 87);
  assert.equal(copied, 1);
  assert.equal(h.api.supplyPurchaseCount(copier), 1);
  assert.equal(h.api.supplyPrice(copier), 7);
  assert.equal(
    h.api.finishSupply(copier, 'Copier double tap', () => { copied += 1; }),
    false
  );
  assert.equal(copied, 1);
  assert.equal(h.context.run.runCoins, 87);

  h.context.run.inflation = true;
  assert.equal(h.api.supplyPrice(scalpel), 9);
  assert.equal(h.api.supplyPrice(copier), 9);
  h.context.run.inflation = false;
  assert.equal(h.api.supplyPrice(scalpel), 7, 'temporary Inflation became permanent');
  assert.equal(h.api.supplyPrice(copier), 7, 'temporary Inflation changed purchase history');

  h.api.openShop();
  assert.equal(h.api.supplyBoughtInShop(scalpel), false);
  assert.equal(h.api.supplyBoughtInShop(copier), false);
  assert.equal(h.api.supplyPrice(scalpel), 7);
  assert.equal(h.api.supplyPrice(copier), 7);
}

function testGuardsAndCancellation() {
  const insufficient = createSupplyHarness({ runCoins: 2 });
  const scalpel = supply(insufficient.api, 'scalpel');
  let effects = 0;
  assert.equal(
    insufficient.api.finishSupply(scalpel, 'cannot afford', () => { effects += 1; }),
    false
  );
  assert.equal(insufficient.context.run.runCoins, 2);
  assert.equal(effects, 0);
  assert.equal(insufficient.api.supplyPurchaseCount(scalpel), 0);
  assert.equal(insufficient.api.supplyBoughtInShop(scalpel), false);
  insufficient.api.useSupply(scalpel);
  assert.equal(insufficient.events.cardPickers, 0, 'unaffordable supply opened its picker');

  const pendingSwap = createSupplyHarness({ pendingShopJoker: { id: 'pending' } });
  const pendingScalpel = supply(pendingSwap.api, 'scalpel');
  assert.equal(
    pendingSwap.api.finishSupply(pendingScalpel, 'blocked', () => { effects += 1; }),
    false
  );
  pendingSwap.api.useSupply(pendingScalpel);
  assert.equal(pendingSwap.events.cardPickers, 0, 'pending Joker swap opened a supply picker');
  assert.equal(pendingSwap.context.run.runCoins, 100);
  assert.equal(pendingSwap.api.supplyPurchaseCount(pendingScalpel), 0);

  const cancelled = createSupplyHarness();
  const cancelledScalpel = supply(cancelled.api, 'scalpel');
  cancelled.api.useSupply(cancelledScalpel);
  assert.equal(cancelled.events.cardPickers, 1);
  // Cancelling means no finalizer runs. Opening the picker must not reserve,
  // charge, or permanently lock the offer.
  assert.equal(cancelled.context.run.runCoins, 100);
  assert.equal(cancelled.api.supplyPurchaseCount(cancelledScalpel), 0);
  assert.equal(cancelled.api.supplyBoughtInShop(cancelledScalpel), false);
  cancelled.api.useSupply(cancelledScalpel);
  assert.equal(cancelled.events.cardPickers, 2, 'cancelled supply remained reserved');
  assert.equal(
    cancelled.api.finishSupply(cancelledScalpel, 'after cancel', () => { effects += 1; }),
    true
  );
  assert.equal(cancelled.context.run.runCoins, 97);

  const failedEffect = createSupplyHarness();
  const failedScalpel = supply(failedEffect.api, 'scalpel');
  assert.throws(
    () => failedEffect.api.finishSupply(failedScalpel, 'throws', () => {
      throw new Error('effect failed');
    }),
    /effect failed/
  );
  assert.equal(failedEffect.context.run.runCoins, 100);
  assert.equal(failedEffect.api.supplyPurchaseCount(failedScalpel), 0);
  assert.equal(failedEffect.api.supplyBoughtInShop(failedScalpel), false);
}

function testNormalizationAndLegacyDefaults() {
  const h = createSupplyHarness();
  const scalpel = supply(h.api, 'scalpel');
  const copier = supply(h.api, 'copier');

  h.context.run.supplyPurchaseCounts = {
    scalpel: '2.9',
    copier: -4,
    bogus: 999
  };
  h.context.run.suppliesBoughtThisShop = [
    'scalpel',
    'scalpel',
    'bogus'
  ];
  h.api.normalizeSupplyState();
  assert.deepEqual(
    JSON.parse(JSON.stringify(h.context.run.supplyPurchaseCounts)),
    { scalpel: 2 }
  );
  assert.deepEqual(Array.from(h.context.run.suppliesBoughtThisShop), ['scalpel']);
  assert.equal(h.api.supplyPrice(scalpel), 7);
  assert.equal(h.api.supplyPrice(copier), 5);

  const legacy = makeRun();
  delete legacy.supplyPurchaseCounts;
  delete legacy.suppliesBoughtThisShop;
  legacy.suppliesBought = 4;
  h.context.run = legacy;
  h.api.normalizeSupplyState();
  assert.deepEqual(
    JSON.parse(JSON.stringify(h.context.run.supplyPurchaseCounts)),
    {}
  );
  assert.deepEqual(Array.from(h.context.run.suppliesBoughtThisShop), []);
  assert.equal(
    h.api.supplyPrice(scalpel),
    3,
    'legacy per-shop scalar was incorrectly treated as persistent per-ID history'
  );
}

function testSaveFieldsAndRoundTrip() {
  const runKeyCode = statement("const RUN_KEY='wildcard_run_v1'", ';');
  const runFieldsCode = statement('const RUN_FIELDS=[', '];');
  const saveFunctions = [
    'saveRunState',
    'loadRunState'
  ].map(extractFunction).join('\n\n');
  const storage = new Map();
  let nativeCopy = null;
  const context = {
    console,
    Date,
    JSON,
    run: makeRun({
      runCoins: 87,
      supplyPurchaseCounts: { scalpel: 2, copier: 1 },
      suppliesBoughtThisShop: ['scalpel', 'copier']
    }),
    shopOffers: [],
    supplyOffers: [
      { id: 'scalpel' },
      { id: 'copier' }
    ],
    localStorage: {
      setItem(key, value) {
        storage.set(key, String(value));
      },
      getItem(key) {
        return storage.has(key) ? storage.get(key) : null;
      }
    },
    nativePersist(_key, value) {
      nativeCopy = value;
    },
    scheduleCloudSave() {}
  };
  vm.createContext(context);
  vm.runInContext(
    `${runKeyCode}
${runFieldsCode}
${saveFunctions}
globalThis.__save = { RUN_FIELDS, saveRunState, loadRunState };`,
    context,
    { filename: 'extracted www/index.html run-save functions' }
  );

  assert.ok(context.__save.RUN_FIELDS.includes('supplyPurchaseCounts'));
  assert.ok(context.__save.RUN_FIELDS.includes('suppliesBoughtThisShop'));
  context.__save.saveRunState('shop');
  const saved = context.__save.loadRunState();
  assert.deepEqual(
    JSON.parse(JSON.stringify(saved.supplyPurchaseCounts)),
    { scalpel: 2, copier: 1 }
  );
  assert.deepEqual(
    Array.from(saved.suppliesBoughtThisShop),
    ['scalpel', 'copier']
  );
  assert.deepEqual(saved.supplyOfferIds, ['scalpel', 'copier']);
  assert.equal(nativeCopy, storage.get('wildcard_run_v1'));

  const resumedHarness = createSupplyHarness();
  const resumed = makeRun();
  for (const key of context.__save.RUN_FIELDS) {
    if (saved[key] !== undefined) resumed[key] = saved[key];
  }
  resumedHarness.context.run = resumed;
  resumedHarness.api.normalizeSupplyState();
  const scalpel = supply(resumedHarness.api, 'scalpel');
  const copier = supply(resumedHarness.api, 'copier');
  assert.equal(resumedHarness.api.supplyPrice(scalpel), 7);
  assert.equal(resumedHarness.api.supplyPrice(copier), 7);
  assert.equal(resumedHarness.api.supplyBoughtInShop(scalpel), true);
  assert.equal(resumedHarness.api.supplyBoughtInShop(copier), true);
  assert.equal(
    resumedHarness.api.finishSupply(scalpel, 'resume double', () => {}),
    false,
    'resuming a shop allowed an already-bought supply to be bought again'
  );
}

function testDailyAndGauntletUseSameRuntimeRules() {
  const daily = createSupplyHarness();
  const dailyScalpel = supply(daily.api, 'scalpel');
  daily.context.dailyMode = true;
  assert.equal(daily.api.finishSupply(dailyScalpel, 'Daily', () => {}), true);
  assert.equal(daily.api.supplyPrice(dailyScalpel), 5);
  daily.api.openShop();
  assert.equal(daily.api.supplyBoughtInShop(dailyScalpel), false);
  assert.equal(daily.api.supplyPrice(dailyScalpel), 5);
  assert.equal(daily.events.saves, 1, 'Daily shop did not create its resumable checkpoint');

  const gauntlet = createSupplyHarness({ gauntlet: true });
  const gauntletScalpel = supply(gauntlet.api, 'scalpel');
  assert.equal(gauntlet.api.finishSupply(gauntletScalpel, 'Gauntlet', () => {}), true);
  assert.equal(gauntlet.api.supplyPrice(gauntletScalpel), 5);
  gauntlet.api.openShop();
  assert.equal(gauntlet.api.supplyBoughtInShop(gauntletScalpel), false);
  assert.equal(gauntlet.api.supplyPrice(gauntletScalpel), 5);
  assert.equal(gauntlet.events.saves, 1, 'Gauntlet shop did not checkpoint normally');
}

testIndependentPersistentPricesAndShopLocks();
testGuardsAndCancellation();
testNormalizationAndLegacyDefaults();
testSaveFieldsAndRoundTrip();
testDailyAndGauntletUseSameRuntimeRules();

console.log(JSON.stringify({
  supplies: {
    independentPerIdPrices: true,
    persistentAcrossShops: true,
    oncePerOfferPerShop: true,
    atomicDoubleFinish: true,
    temporaryInflation: true,
    guardedAndCancellable: true,
    saveResumeAndLegacyNormalization: true,
    dailyAndGauntletParity: true
  }
}, null, 2));
