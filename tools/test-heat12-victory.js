'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const html = fs.readFileSync(
  path.join(__dirname, '..', 'www', 'index.html'),
  'utf8'
);

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
      // Keep scanning until the JavaScript parser sees the complete function.
    }
  }

  assert.fail(`could not extract current source function: ${name}`);
}

const CURRENT_FUNCTIONS = [
  'setCoinBadgeForScreen',
  'showScreen',
  'playSlyTearCinematic',
  'showHeat12Choice',
  'startHeat12VictorySequence',
  'continueEndless',
  'endRunToStats',
  'gameOver',
  'showAdBreak',
  'normalizeSupplyState',
  'resumeRun'
].map(extractFunction).join('\n\n');

class FakeClock {
  constructor() {
    this.now = 0;
    this.nextId = 1;
    this.jobs = new Map();
  }

  setTimeout(fn, delay) {
    const id = this.nextId++;
    this.jobs.set(id, {
      id,
      fn,
      at: this.now + Math.max(0, Number(delay) || 0)
    });
    return id;
  }

  clearTimeout(id) {
    this.jobs.delete(id);
  }

  tick(ms) {
    const target = this.now + ms;
    for (;;) {
      const next = [...this.jobs.values()]
        .filter((job) => job.at <= target)
        .sort((a, b) => a.at - b.at || a.id - b.id)[0];
      if (!next) break;
      this.jobs.delete(next.id);
      this.now = next.at;
      next.fn();
    }
    this.now = target;
  }
}

class FakeClassList {
  constructor() {
    this.names = new Set();
  }

  add(...names) {
    names.forEach((name) => this.names.add(name));
  }

  remove(...names) {
    names.forEach((name) => this.names.delete(name));
  }

  toggle(name, force) {
    if (force === undefined) {
      if (this.names.has(name)) this.names.delete(name);
      else this.names.add(name);
      return this.names.has(name);
    }
    if (force) this.names.add(name);
    else this.names.delete(name);
    return !!force;
  }

  contains(name) {
    return this.names.has(name);
  }
}

class FakeElement {
  constructor(id) {
    this.id = id;
    this.classList = new FakeClassList();
    this.dataset = Object.create(null);
    this.attributes = Object.create(null);
    this.style = {
      display: '',
      color: '',
      setProperty(name, value) {
        this[name] = value;
      }
    };
    this.textContent = '';
    this.innerHTML = '';
  }

  setAttribute(name, value) {
    this.attributes[name] = String(value);
  }

  getAttribute(name) {
    return this.attributes[name];
  }
}

function makeRun(overrides) {
  return Object.assign({
    stage: 12,
    stagesCleared: 12,
    stageScore: 0,
    totalScore: 4321,
    bestPlay: 320,
    bestPlayType: 'Pair',
    gauntlet: false,
    endless: false,
    abandoned: false,
    animating: false,
    accountEarned: 25,
    doubleBaseCoins: 0,
    coinDoubleClaimed: false,
    heat12SequenceStarted: false,
    heat12InterstitialAttempted: false,
    victoryChoiceMade: false,
    leaderboardEligible: true,
    stake: 0,
    stakePayout: 0,
    stakeNet: 0,
    cards: Array.from({ length: 52 }, (_, i) => ({ id: i })),
    hand: [],
    destroyedCount: 0,
    copiedCount: 0,
    shatteredCount: 0,
    handTypeCounts: { Pair: 1 },
    boostsBought: 0,
    modifiersSurvived: [],
    jokers: [],
    startBoostJoker: null,
    startBoostCost: 0,
    firstLossChestPending: false,
    dailyDate: '2026-07-18',
    modifier: null
  }, overrides || {});
}

function createDocument(events) {
  const elements = new Map();
  const body = new FakeElement('body');
  const bgfx = new FakeElement('bgfx');
  const screenIds = ['menu', 'game', 'wincomplete', 'gameover', 'adbreak'];
  const screens = screenIds.map((id) => {
    const element = new FakeElement(id);
    elements.set(id, element);
    return element;
  });

  const cinematic = new FakeElement('sly-tear-cinematic');
  elements.set(cinematic.id, cinematic);

  const video = new FakeElement('sly-tear-video');
  video.currentTime = 0;
  video.readyState = 4;
  video.muted = false;
  video.onended = null;
  video.onerror = null;
  video.pause = () => events.push('cinematic:pause');
  video.play = () => {
    events.push('cinematic:play');
    return Promise.resolve();
  };
  video.addEventListener = (name, handler) => {
    video[`listener:${name}`] = handler;
  };
  elements.set(video.id, video);

  return {
    body,
    cinematic,
    video,
    getElementById(id) {
      if (!elements.has(id)) elements.set(id, new FakeElement(id));
      return elements.get(id);
    },
    querySelector(selector) {
      return selector === '.bgfx' ? bgfx : null;
    },
    querySelectorAll(selector) {
      return selector === '.screen' ? screens : [];
    }
  };
}

function createHarness(options) {
  options = options || {};
  const events = [];
  const clock = new FakeClock();
  const document = createDocument(events);
  let adCount = 0;
  let pendingAd = null;

  const account = {
    noAds: !!options.noAds,
    firstLossCoached: false,
    tutorialChestClaimed: false,
    runLog: [],
    bestHeat: 12,
    bestScore: 4321,
    dailyRunDate: '2026-07-18'
  };

  const WildcardNative = {
    showInterstitial(callback) {
      adCount += 1;
      events.push('ad:show');
      assert.equal(pendingAd, null, 'only one native interstitial may be pending');
      pendingAd = callback;
    }
  };

  const initialRun = options.initialRun === null
    ? null
    : makeRun(options.initialRun);
  const savedRun = options.savedRun || null;

  const globals = {
    console,
    Promise,
    Math,
    Date,
    JSON,
    Object,
    Array,
    Number,
    String,
    Boolean,
    RegExp,
    setTimeout: clock.setTimeout.bind(clock),
    clearTimeout: clock.clearTimeout.bind(clock),
    document,
    window: {
      WildcardNative,
      scrollTo() {}
    },
    run: initialRun,
    dailyMode: !!options.dailyMode,
    reducedMotion: false,
    account,
    JOKERS: [],
    SUPPLIES: [],
    MODIFIERS: [],
    BOSS_MOD: { id: 'boss_house' },
    RUN_FIELDS: Object.keys(makeRun()),
    SLY_LOSS_LINES: ['The house wins.'],
    saveRunState(phase) {
      events.push(`save:${phase}`);
    },
    renderWin() {
      events.push('render:win');
    },
    stopModifierAmbience() {
      events.push('ambience:stop');
    },
    syncModifierAmbience() {},
    nativeHaptic() {},
    saveAccount() {
      events.push('account:save');
    },
    updateMenuAccount() {},
    queueRunEndTelemetry() {
      events.push('telemetry:end');
    },
    hasRewardClaim() {
      return false;
    },
    doubleCoinsClaimId() {
      return 'double-test';
    },
    clearRunState() {
      events.push('save:clear');
    },
    todayStr() {
      return '2026-07-18';
    },
    removeProvisionalWinScore() {},
    recordHighScore() {
      return { placement: null };
    },
    resolveStakeContract() {},
    jokerMVP() {
      return null;
    },
    runCoachRows() {
      return '';
    },
    renderDoubleCoinsOffer() {},
    playDeathScreen(_kind, done) {
      done();
    },
    endDailyRun() {
      events.push('daily:end');
      globals.dailyMode = false;
    },
    newRunState() {
      return makeRun();
    },
    loadRunState() {
      return savedRun;
    },
    toast(message) {
      events.push(`toast:${message}`);
    },
    nextStage() {
      events.push('destination:endless');
    }
  };

  const context = vm.createContext(globals);
  vm.runInContext(CURRENT_FUNCTIONS, context, {
    filename: 'extracted www/index.html Heat-12 functions'
  });

  return {
    context,
    account,
    clock,
    document,
    events,
    get adCount() {
      return adCount;
    },
    settleAd(shown) {
      assert.equal(typeof pendingAd, 'function', 'no native interstitial is pending');
      const callback = pendingAd;
      pendingAd = null;
      callback(shown);
    }
  };
}

function startAndFinishVideo(harness, eventName) {
  harness.context.startHeat12VictorySequence();
  assert.equal(harness.context.run.heat12SequenceStarted, true);
  assert.equal(harness.document.cinematic.classList.contains('show'), true);
  assert.equal(harness.adCount, 0, 'the ad must wait for the cinematic');

  const handler = harness.document.video[eventName];
  assert.equal(typeof handler, 'function', `cinematic ${eventName} handler was not installed`);
  handler();
}

function finishAdAndReachChoice(harness, shown) {
  harness.settleAd(shown);
  harness.clock.tick(120);
  assert.equal(harness.document.body.dataset.screen, 'wincomplete');
  assert.equal(harness.context.run.victoryChoiceMade, false);
}

function testStandardEndedFlow() {
  const h = createHarness();
  startAndFinishVideo(h, 'onended');

  assert.equal(h.context.run.heat12InterstitialAttempted, true);
  assert.equal(h.adCount, 1);
  assert.equal(h.events.filter((event) => event === 'save:wincomplete').length, 2);
  finishAdAndReachChoice(h, true);
  h.clock.tick(5000);

  assert.equal(h.adCount, 1, 'standard Heat 12 may show at most one interstitial');
  assert.ok(
    h.events.indexOf('cinematic:play') < h.events.indexOf('ad:show')
      && h.events.indexOf('ad:show') < h.events.indexOf('render:win'),
    'standard flow must be cinematic, then ad, then choice'
  );
}

function testCinematicErrorStillReachesChoice() {
  const h = createHarness();
  startAndFinishVideo(h, 'onerror');
  assert.equal(h.adCount, 1);
  finishAdAndReachChoice(h, true);
  assert.equal(h.adCount, 1);
}

function testAdFailureAndTimeoutFailOpen() {
  const failed = createHarness();
  startAndFinishVideo(failed, 'onended');
  finishAdAndReachChoice(failed, false);
  assert.equal(failed.adCount, 1, 'failed interstitial callback must not retry inline');

  const stalled = createHarness();
  startAndFinishVideo(stalled, 'onended');
  stalled.clock.tick(4620);
  assert.equal(stalled.document.body.dataset.screen, 'wincomplete');
  assert.equal(stalled.adCount, 1, 'stalled interstitial must fail open without a second request');
}

function testNoAdsSkipsInterstitial() {
  const h = createHarness({ noAds: true });
  startAndFinishVideo(h, 'onended');

  assert.equal(h.adCount, 0);
  assert.equal(h.document.body.dataset.screen, 'wincomplete');
  assert.equal(h.events.filter((event) => event === 'render:win').length, 1);
}

function testResumeSkipsCinematicAndAd() {
  const savedRun = Object.assign(makeRun(), {
    v: 1,
    phase: 'wincomplete',
    jokerIds: [],
    modId: null
  });
  const h = createHarness({ initialRun: null, savedRun });

  h.context.resumeRun();

  assert.equal(h.context.run.heat12SequenceStarted, true);
  assert.equal(h.context.run.heat12InterstitialAttempted, true);
  assert.equal(h.events.includes('cinematic:play'), false);
  assert.equal(h.adCount, 0);
  assert.equal(h.document.body.dataset.screen, 'wincomplete');
}

function testEndRunDoesNotShowSecondAd() {
  const h = createHarness();
  startAndFinishVideo(h, 'onended');
  finishAdAndReachChoice(h, true);
  assert.equal(h.adCount, 1);

  h.context.endRunToStats();

  assert.equal(h.context.run.victoryChoiceMade, true);
  assert.equal(h.document.body.dataset.screen, 'gameover');
  assert.equal(h.adCount, 1, 'End Run must not show a second Heat-12 interstitial');

  h.context.endRunToStats();
  assert.equal(h.adCount, 1, 'double-tapping End Run must remain idempotent');
}

function testContinueEndlessIsSingleUse() {
  const h = createHarness();
  startAndFinishVideo(h, 'onended');
  finishAdAndReachChoice(h, true);

  h.context.continueEndless();
  h.context.continueEndless();

  assert.equal(h.context.run.endless, true);
  assert.equal(h.events.filter((event) => event === 'destination:endless').length, 1);
  assert.equal(h.adCount, 1);
}

function testDailyVictorySettlesWithoutChoiceAndKeepsCheckpoint() {
  const h = createHarness({ dailyMode: true });
  startAndFinishVideo(h, 'onended');

  assert.ok(
    h.events.filter((event) => event === 'save:wincomplete').length >= 1,
    'Daily victory must checkpoint before its cinematic/ad transition'
  );
  assert.equal(h.adCount, 1);
  h.settleAd(true);
  h.clock.tick(120);

  assert.equal(h.events.includes('daily:end'), true);
  assert.equal(h.document.body.dataset.screen, 'gameover');
  assert.equal(h.events.includes('render:win'), false, 'Daily victory must not show Endless choice');
  assert.equal(h.adCount, 1, 'Daily victory may show at most one interstitial');
}

testStandardEndedFlow();
testCinematicErrorStillReachesChoice();
testAdFailureAndTimeoutFailOpen();
testNoAdsSkipsInterstitial();
testResumeSkipsCinematicAndAd();
testEndRunDoesNotShowSecondAd();
testContinueEndlessIsSingleUse();
testDailyVictorySettlesWithoutChoiceAndKeepsCheckpoint();

console.log('Heat-12 cinematic, interstitial, choice, resume, and Daily flow tests passed.');
