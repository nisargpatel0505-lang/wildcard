#!/usr/bin/env node
'use strict';

/*
 * WILDCARD gameplay/UI hardening regression contract.
 *
 * This test intentionally reads the shipped www/index.html instead of copying
 * game logic into a second implementation.  Most checks are semantic source
 * contracts because the production file is a browser application with native
 * bridges; the Prism Lens and Glass Joystick checks execute the real Joker
 * definitions in a small VM.  Every check is collected so one run reports the
 * full remaining hardening backlog.
 *
 * Deliberate exclusions from this contract:
 *   - scoring pace/timing
 *   - Joker trigger animation styling/timing
 *   - 320x568 layout work
 *   - first-loss chest behaviour
 */

const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const ROOT = path.resolve(__dirname, '..');
const HTML_PATH = path.join(ROOT, 'www', 'index.html');
const html = fs.readFileSync(HTML_PATH, 'utf8');
const css = (html.match(/<style\b[^>]*>([\s\S]*?)<\/style>/i) || [null, ''])[1];

const results = [];
let currentGroup = '';

function group(name) {
  currentGroup = name;
  process.stdout.write(`\n[${name}]\n`);
}

function check(name, assertion) {
  try {
    assertion();
    results.push({ ok: true, group: currentGroup, name });
    process.stdout.write(`  PASS  ${name}\n`);
  } catch (error) {
    results.push({ ok: false, group: currentGroup, name, error });
    process.stdout.write(`  FAIL  ${name}\n        ${error.message}\n`);
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function matches(text, pattern) {
  return pattern.test(text);
}

function requirePattern(text, pattern, message) {
  assert(matches(text, pattern), message);
}

function forbidPattern(text, pattern, message) {
  assert(!matches(text, pattern), message);
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function balancedSlice(source, openIndex, openChar, closeChar) {
  assert(openIndex >= 0 && source[openIndex] === openChar,
    `Could not find opening ${openChar}`);
  let depth = 0;
  let quote = null;
  let lineComment = false;
  let blockComment = false;
  let escaped = false;

  for (let i = openIndex; i < source.length; i += 1) {
    const ch = source[i];
    const next = source[i + 1];

    if (lineComment) {
      if (ch === '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (ch === '*' && next === '/') {
        blockComment = false;
        i += 1;
      }
      continue;
    }
    if (quote) {
      if (escaped) {
        escaped = false;
      } else if (ch === '\\') {
        escaped = true;
      } else if (ch === quote) {
        quote = null;
      }
      continue;
    }
    if (ch === '/' && next === '/') {
      lineComment = true;
      i += 1;
      continue;
    }
    if (ch === '/' && next === '*') {
      blockComment = true;
      i += 1;
      continue;
    }
    if (ch === '"' || ch === "'" || ch === '`') {
      quote = ch;
      continue;
    }
    if (ch === openChar) depth += 1;
    if (ch === closeChar) {
      depth -= 1;
      if (depth === 0) return source.slice(openIndex, i + 1);
    }
  }
  throw new Error(`Unbalanced ${openChar}${closeChar} block`);
}

function functionSource(name) {
  const match = new RegExp(`(?:async\\s+)?function\\s+${escapeRegExp(name)}\\s*\\(`).exec(html);
  assert(match, `Missing function ${name}()`);
  const open = html.indexOf('{', match.index);
  const body = balancedSlice(html, open, '{', '}');
  return html.slice(match.index, open) + body;
}

function declarationArray(name) {
  const match = new RegExp(`\\b(?:const|let|var)\\s+${escapeRegExp(name)}\\s*=\\s*\\[`).exec(html);
  assert(match, `Missing ${name} array`);
  const open = html.indexOf('[', match.index);
  return balancedSlice(html, open, '[', ']');
}

function cssPxValues(selector, property) {
  const values = [];
  const rule = new RegExp(`[^{}]*${escapeRegExp(selector)}[^{}]*\\{([^}]*)\\}`, 'gi');
  let match;
  while ((match = rule.exec(css))) {
    const prop = new RegExp(`${escapeRegExp(property)}\\s*:\\s*([0-9.]+)px`, 'gi');
    let value;
    while ((value = prop.exec(match[1]))) values.push(Number(value[1]));
  }
  return values;
}

function requireFunctionUses(name, pattern, reason) {
  const source = functionSource(name);
  requirePattern(source, pattern, `${name}() ${reason}`);
}

function forbidFunctionUses(name, pattern, reason) {
  const source = functionSource(name);
  forbidPattern(source, pattern, `${name}() ${reason}`);
}

function jokerDefinitions() {
  const context = {
    run: {
      jokerState: {},
      jokers: [],
      handLevels: {},
      cards: [],
      discardsLeft: 0,
      stageScore: 0,
      runCoins: 0,
    },
    rnd: () => 0.5,
    setTimeout: callback => callback(),
    toast: () => {},
    mod: () => false,
    stageTarget: () => 100,
    mostCommonRank: () => null,
    allSameColor: cards => Boolean(cards && cards.length)
      && (cards.every(card => card.red) || cards.every(card => !card.red)),
    Object,
    Math,
  };
  const jokers = vm.runInNewContext(`(${declarationArray('JOKERS')})`, context, {
    timeout: 1000,
    filename: 'index.html#JOKERS',
  });
  return { jokers, context };
}

group('Heat 12 boss: exactly two blocked Jokers');

check('Boss copy describes two blocked Jokers, not a blanket xMult jam', () => {
  const boss = html.match(/const\s+BOSS_MOD\s*=\s*\{[\s\S]*?\};/);
  assert(boss, 'Missing BOSS_MOD');
  requirePattern(boss[0], /\b2\b|two/i, 'BOSS_MOD must disclose two blocked Jokers');
  forbidPattern(boss[0], /jams?\s+every|every\s+[×x]?\s*mult/i,
    'BOSS_MOD still advertises the removed blanket xMult jam');
});

check('Blocked Joker IDs are part of new-run state and RUN_FIELDS', () => {
  requireFunctionUses('newRunState', /bossBlockedJokerIds\s*:/,
    'must initialise bossBlockedJokerIds');
  const fields = declarationArray('RUN_FIELDS');
  requirePattern(fields, /['"]bossBlockedJokerIds['"]/,
    'RUN_FIELDS must persist bossBlockedJokerIds');
});

check('Boss block selection is explicit, stable, and invoked by modifier assignment', () => {
  const ensure = functionSource('ensureBossBlocks');
  requirePattern(ensure, /slice\s*\(\s*0\s*,\s*2\s*\)|length\s*<\s*2/,
    'ensureBossBlocks() must select exactly two equipped Jokers');
  requirePattern(ensure, /bossBlockedJokerIds/,
    'ensureBossBlocks() must persist the chosen IDs');
  requireFunctionUses('assignModifier', /ensureBossBlocks\s*\(/,
    'must initialise boss blocks when THE HOUSE is assigned');
});

check('A shared blocked-Joker predicate controls all scoring hooks', () => {
  requirePattern(html, /function\s+(?:isJokerBlocked|activeJokers)\s*\(/,
    'Missing shared isJokerBlocked()/activeJokers() helper');
  for (const name of ['cardEffectiveRankForScoring', 'scoreHand', 'playHand', 'clearStage']) {
    requireFunctionUses(name, /isJokerBlocked\s*\(|activeJokers\s*\(/,
      'must exclude blocked Jokers');
  }
});

check('The old blanket boss xMult suppression is gone', () => {
  const score = functionSource('scoreHand');
  forbidPattern(score, /!\s*\(\s*run\.modifier\s*&&\s*run\.modifier\.boss\s*\)/,
    'scoreHand() still suppresses every xMult Joker');
  forbidPattern(score, /modifier\.boss[\s\S]{0,100}(?:xMult|jm\.x)/,
    'scoreHand() still special-cases boss xMult suppression');
});

check('Blocked Jokers are visibly labelled and included in render signatures', () => {
  const render = functionSource('renderGame');
  requirePattern(render, /bossBlockedJokerIds/,
    'renderGame() must include boss block state in its reconciliation signature');
  requirePattern(render, /blocked|jammed/i,
    'renderGame() must visibly label blocked Joker cards');
});

group('Joker rules: Prism Lens and Glass Joystick');

check('Prism Lens triggers for any five cards of one colour', () => {
  const { jokers } = jokerDefinitions();
  const prism = jokers.find(joker => joker.id === 'prism_lens');
  assert(prism && typeof prism.xMult === 'function', 'Prism Lens xMult hook is missing');
  const red = n => Array.from({ length: n }, () => ({ red: true }));
  const black = n => Array.from({ length: n }, () => ({ red: false }));
  assert(prism.xMult({ cards: [...red(5), ...black(1)] }) === 1.35,
    'Prism Lens did not trigger for five red plus one black');
  assert(prism.xMult({ cards: [...black(5), ...red(1)] }) === 1.35,
    'Prism Lens did not trigger for five black plus one red');
  assert(prism.xMult({ cards: [...red(4), ...black(2)] }) === 1,
    'Prism Lens incorrectly triggered with only four matching colours');
});

check('Glass Joystick discloses and uses one-in-six shatter odds', () => {
  const { jokers, context } = jokerDefinitions();
  const glass = jokers.find(joker => joker.id === 'glass_joystick');
  assert(glass && typeof glass.onHeatClear === 'function',
    'Glass Joystick clear hook is missing');
  requirePattern(glass.desc, /1\s+in\s+6|16(?:\.6+|\.7)?%/i,
    'Glass Joystick description must disclose one-in-six odds');

  context.run.jokers = [glass];
  context.run.jokerState = {};
  context.rnd = () => 0.999;
  glass.onHeatClear();
  assert(context.run.jokers.length === 1 && context.run.jokerState.glass_joystick_armed,
    'Glass Joystick must always survive and arm after its first clear');

  context.rnd = () => 0.20;
  glass.onHeatClear();
  assert(context.run.jokers.length === 1,
    'A 0.20 roll must not shatter a one-in-six Glass Joystick');

  context.rnd = () => 0.16;
  glass.onHeatClear();
  assert(context.run.jokers.length === 0,
    'A 0.16 roll must shatter an armed Glass Joystick');
});

group('Deck view: Ace encoding');

check('Deck matrix enumerates the real 2..13,15 rank values', () => {
  const deck = functionSource('openDeckView');
  const valuesMatch = /const\s+VALUES\s*=\s*(\[[^\]]+\])/.exec(deck);
  assert(valuesMatch, 'openDeckView() must declare VALUES');
  const values = vm.runInNewContext(valuesMatch[1], {}, { timeout: 100 });
  assert(values.length === 13, `Expected 13 rank values, found ${values.length}`);
  assert(values.includes(15), 'Deck matrix omits Ace value 15');
  assert(!values.includes(14), 'Deck matrix still includes unused value 14');
  requirePattern(deck, /15\s*:\s*['"]A['"]|v\s*===\s*15\s*\?\s*['"]A['"]/,
    'Deck matrix must label value 15 as Ace');
  forbidPattern(deck, /14\s*:\s*['"]A['"]|v\s*===\s*14\s*\?\s*['"]A['"]/,
    'Deck matrix still labels value 14 as Ace');
});

group('Daily mode: deterministic, resumable, isolated');

check('Run state persists Daily identity and deterministic RNG state', () => {
  const state = functionSource('newRunState');
  for (const field of ['dailyDate', 'rngSeed', 'rngCounters', 'pendingTransition']) {
    requirePattern(state, new RegExp(`${field}\\s*:`),
      `newRunState() must initialise ${field}`);
  }
  const fields = declarationArray('RUN_FIELDS');
  for (const field of ['dailyDate', 'rngSeed', 'rngCounters', 'pendingTransition']) {
    requirePattern(fields, new RegExp(`['"]${field}['"]`),
      `RUN_FIELDS must persist ${field}`);
  }
});

check('Random streams advance persisted per-run counters', () => {
  const random = functionSource('rnd');
  requirePattern(random, /run\.rngSeed|rngSeed/,
    'rnd() must derive results from the saved run seed');
  requirePattern(random, /run\.rngCounters|rngCounters/,
    'rnd() must advance saved stream counters');
  forbidPattern(html, /const\s+RNG\s*=\s*\{\s*deck\s*:/,
    'Legacy closure-only Daily RNG remains');
});

check('Daily checkpoints are saved in game, shop, and app lifecycle paths', () => {
  for (const name of ['renderGame', 'openShop', 'updateShopSub', 'bankCurrentState']) {
    const source = functionSource(name);
    requirePattern(source, /saveRunState\s*\(/,
      `${name}() must checkpoint the active run`);
    forbidPattern(source, /!\s*dailyMode[\s\S]{0,100}saveRunState|saveRunState[\s\S]{0,100}!\s*dailyMode/,
      `${name}() must not suppress Daily checkpoints`);
  }
});

check('Starting and resuming a Daily restores its identity', () => {
  const launch = functionSource('launchDailyRun');
  requirePattern(launch, /saveRunState\s*\(\s*['"]game['"]\s*\)/,
    'launchDailyRun() must save an immediate resumable checkpoint');
  const resume = functionSource('resumeRun');
  requirePattern(resume, /dailyMode\s*=/,
    'resumeRun() must restore dailyMode');
  requirePattern(resume, /dailyChallengeDate\s*=|dailyDate/,
    'resumeRun() must restore the Daily date');
});

check('Daily play cannot advance normal-run progression or rewards', () => {
  requireFunctionUses('beginRun', /progressionEnabled|!\s*dailyMode/,
    'must avoid incrementing normal run stats for Daily');
  requireFunctionUses('clearStage', /progressionEnabled|!\s*dailyMode/,
    'must isolate normal Heat/unlock progression from Daily');
  requireFunctionUses('creditRunAccountOnce', /isDailyRun|dailyMode|telemetryMode\s*===\s*['"]daily['"]/,
    'must reject Daily account-coin credit');
  const over = functionSource('gameOver');
  requirePattern(over, /_wasDaily|progressionEnabled/,
    'gameOver() must retain Daily identity while finalising');
  requirePattern(over, /if\s*\(\s*!\s*_wasDaily|if\s*\(\s*progressionEnabled/,
    'gameOver() must guard normal best scores and run history');
});

check('A scoring transaction can resume without rerolling luck', () => {
  const play = functionSource('playHand');
  requirePattern(play, /pendingTransition/,
    'playHand() must persist a transaction/transition marker');
  requirePattern(play, /saveRunState\s*\(/,
    'playHand() must checkpoint the scoring transaction');
  requireFunctionUses('resumeRun', /pendingTransition/,
    'must finish or recover an interrupted scoring transaction');
});

group('Royal Vault: truthful odds and newcomer price');

check('Chest pools do not hide available fallback rarities', () => {
  const pool = functionSource('chestPool');
  forbidPattern(pool, /\.primary\b/,
    'chestPool() still disables Wood while Rare rewards remain');
});

check('Effective odds are recalculated from the remaining pool', () => {
  const odds = functionSource('effectiveChestOdds');
  requirePattern(odds, /rarity|tier/,
    'effectiveChestOdds() must group remaining rewards by rarity');
  requirePattern(odds, /reduce|total|sum/i,
    'effectiveChestOdds() must renormalise remaining weights');
  requireFunctionUses('rollChest', /effectiveChestOdds\s*\(/,
    'must select rewards using the same effective odds that are displayed');
});

check('Wood costs 60 until 15 Jokers, then 100; Gold remains 300', () => {
  const fnSource = functionSource('chestPrice');
  const account = { unlocked: new Set(Array.from({ length: 14 }, (_, i) => `j${i}`)) };
  const context = {
    account,
    CHESTS: {
      wood: { price: 100 },
      gold: { price: 300 },
    },
    Math,
  };
  const price = vm.runInNewContext(`(${fnSource})`, context, { timeout: 500 });
  assert(price('wood') === 60, `Wood price at 14 unlocks was ${price('wood')}, expected 60`);
  account.unlocked.add('j14');
  assert(price('wood') === 100, `Wood price at 15 unlocks was ${price('wood')}, expected 100`);
  assert(price('gold') === 300, `Gold price was ${price('gold')}, expected 300`);
});

check('Rendering, affordability, deduction, and roll share dynamic helpers', () => {
  const render = functionSource('renderChest');
  requirePattern(render, /chestPrice\s*\(/,
    'renderChest() must display/check the dynamic price');
  requirePattern(render, /chestOddsText\s*\([\s\S]*pool|effectiveChestOdds\s*\(/,
    'renderChest() must display effective odds for the current pool');
  requirePattern(render, /cosmeticVaultOddsText\s*\(|cosmetic[\s\S]{0,80}odds/i,
    'Cosmetic Vault must disclose its actual odds');
  requireFunctionUses('spinChest', /chestPrice\s*\(/,
    'must deduct the same dynamic price shown to the player');
});

group('Privacy gate and removed haptic setting');

check('Viewport zoom remains available', () => {
  const viewport = (html.match(/<meta\s+name=["']viewport["'][^>]*>/i) || [''])[0];
  forbidPattern(viewport, /user-scalable\s*=\s*no|maximum-scale\s*=\s*1(?:[."',\s>]|$)/i,
    'Viewport still disables pinch zoom');
});

check('First-launch privacy acceptance is an accessible blocking dialog', () => {
  requirePattern(html, /id=["']privacy-gate["'][^>]*role=["']dialog["'][^>]*aria-modal=["']true["']/i,
    'Privacy gate needs role=dialog and aria-modal=true');
  requirePattern(html, /id=["']privacy-gate["'][^>]*aria-labelledby=["'][^"']+["']/i,
    'Privacy gate needs an accessible label');
  for (const symbol of [
    'PRIVACY_POLICY_VERSION',
    'hasAcceptedCurrentPrivacyPolicy',
    'showPrivacyAcceptanceGate',
    'acceptCurrentPrivacyPolicy',
    'startConsentGatedServices',
  ]) {
    requirePattern(html, new RegExp(`\\b${symbol}\\b`), `Missing ${symbol}`);
  }
});

check('Ads, billing, cloud, and telemetry start only after consent', () => {
  const gated = functionSource('startConsentGatedServices');
  requirePattern(gated, /enableAds|Ad/i, 'Consent gate must start ads');
  requirePattern(gated, /enableBilling|Purchase|Billing/i, 'Consent gate must start billing');
  requirePattern(gated, /initCloudAccount/, 'Consent gate must start cloud account services');
  requirePattern(gated, /queueTelemetry/, 'Consent gate must start telemetry');
  const startup = functionSource('finishWildcardStartup');
  requirePattern(startup, /hasAcceptedCurrentPrivacyPolicy\s*\(\)/,
    'Startup must test the current consent marker');
  requirePattern(startup, /showPrivacyAcceptanceGate\s*\(\)/,
    'Startup must block first launch until acceptance');
});

check('The non-working Haptic Feedback setting is removed', () => {
  forbidPattern(html, /Haptic\s+Feedback/i,
    'Settings still exposes Haptic Feedback');
  forbidPattern(html, /\btoggleHaptic\s*\(/,
    'Legacy toggleHaptic() remains');
  forbidPattern(html, /\bhapticsEnabled\b|\bhapticEnabled\b|\bhaptic\s*:\s*(?:true|false)/,
    'Legacy haptic preference remains in account state');
});

group('Theme coverage and accessibility');

check('Equipped room art reaches every requested screen', () => {
  const screens = [
    'settings', 'achievements', 'cabinet', 'missions', 'unlocks', 'howto',
    'wardrobe', 'store', 'tutorial', 'startboost', 'adbreak', 'gameover',
  ];
  for (const screen of screens) {
    const themedRule = new RegExp(
      `[^{}]*data-screen\\s*=\\s*['"]${screen}['"][^{}]*\\.bgfx[^{}]*\\{[^}]*` +
      `var\\(--theme-home-art\\s*,\\s*var\\(--art-menu-palace\\)\\)`,
      'i',
    );
    requirePattern(css, themedRule,
      `${screen} must use --theme-home-art with the palace fallback`);
  }
});

check('Overlay panels inherit equipped theme tokens', () => {
  requirePattern(css,
    /(?:#overlay|\.overlay)[^{}]*\.panel[^{}]*\{[^}]*(?:--ui-panel|var\(--ui-panel|--theme-home-art)/i,
    'Overlay panel styling does not inherit the equipped theme');
});

check('Generic overlays use dialog semantics and all four safe areas', () => {
  const overlayMarkup = html.match(/<div[^>]+id=["']overlay["'][^>]*>/i);
  assert(overlayMarkup, 'Missing generic #overlay markup');
  requirePattern(overlayMarkup[0], /role=["']dialog["']/i,
    '#overlay needs role=dialog');
  requirePattern(overlayMarkup[0], /aria-modal=["']true["']/i,
    '#overlay needs aria-modal=true');
  requirePattern(overlayMarkup[0], /aria-labelledby=["'][^"']+["']/i,
    '#overlay needs aria-labelledby');
  const safeRule = css.match(/(?:#overlay|\.overlay)[^{}]*\{[^}]*\}/gi)?.join('\n') || '';
  for (const inset of ['sat', 'sab', 'sal', 'sar']) {
    requirePattern(safeRule, new RegExp(`var\\(--${inset}\\)`),
      `Overlay CSS does not apply --${inset}`);
  }
});

check('Overlay focus is trapped, Escape closes, and focus returns', () => {
  const open = functionSource('openOverlay');
  const close = functionSource('closeOverlay');
  requirePattern(open, /document\.activeElement/,
    'openOverlay() must remember the invoking control');
  requirePattern(open, /\.focus\s*\(/,
    'openOverlay() must move focus into the dialog');
  requirePattern(html, /keydown[\s\S]{0,1200}(?:key\s*===?\s*['"]Escape['"]|key\s*===?\s*['"]Esc['"])/,
    'Missing Escape handling for overlays');
  requirePattern(html, /keydown[\s\S]{0,1600}key\s*===?\s*['"]Tab['"]/,
    'Missing Tab focus trap for overlays');
  requirePattern(close, /\.focus\s*\(/,
    'closeOverlay() must restore focus to its invoking control');
});

check('Critical mobile controls expose at least 44px targets', () => {
  const abandon = cssPxValues('#btn-abandon', 'min-height');
  assert(abandon.some(value => value >= 44),
    `Abandon max declared min-height is ${Math.max(0, ...abandon)}px; expected at least 44px`);
  requirePattern(css,
    /@media\s*\([^)]*pointer\s*:\s*coarse[^)]*\)[\s\S]{0,5000}(?:button|\.btn)[^{}]*\{[^}]*(?:min-height|height)\s*:\s*(?:4[4-9]|[5-9]\d)px/i,
    'Coarse-pointer controls need a general 44px minimum target');
  const playDiscard = [
    ...cssPxValues('#btn-play', 'min-height'),
    ...cssPxValues('#btn-discard', 'min-height'),
  ];
  assert(playDiscard.some(value => value >= 48),
    `Play/Discard max declared min-height is ${Math.max(0, ...playDiscard)}px; expected at least 48px`);
});

check('Equation labels and Deck headings remain readable', () => {
  const equationSizes = [
    ...cssPxValues('.eq-lbl', 'font-size'),
    ...cssPxValues('.equation-label', 'font-size'),
    ...cssPxValues('.equation .eq-chip .small', 'font-size'),
  ];
  assert(equationSizes.some(value => value >= 9),
    `Equation label max font-size is ${Math.max(0, ...equationSizes)}px; expected at least 9px`);
  const deck = functionSource('openDeckView');
  forbidPattern(deck, /font-size\s*:\s*[0-8](?:\.\d+)?px/i,
    'Deck view still creates sub-9px inline text');
});

check('Large collections provide search and progressive disclosure', () => {
  requirePattern(html, /type\s*=\s*['"]search['"]|collectionSearch|collection-search/i,
    'Collection needs a search control');
  requirePattern(html, /show\s+more|load\s+more|collectionPage|visibleCollection/i,
    'Collection needs Show More/pagination rather than a 57-card wall');
  requirePattern(html, /position\s*:\s*sticky[\s\S]{0,500}(?:collection|filter)|(?:collection|filter)[\s\S]{0,500}position\s*:\s*sticky/i,
    'Collection filters should remain sticky on long lists');
});

const passed = results.filter(result => result.ok).length;
const failed = results.length - passed;
process.stdout.write(`\nGameplay hardening: ${passed}/${results.length} passed, ${failed} failed.\n`);

if (failed) {
  process.stdout.write('\nRemaining failures by group:\n');
  const grouped = new Map();
  for (const result of results.filter(item => !item.ok)) {
    if (!grouped.has(result.group)) grouped.set(result.group, []);
    grouped.get(result.group).push(result.name);
  }
  for (const [name, failures] of grouped) {
    process.stdout.write(`  ${name}: ${failures.length}\n`);
    for (const failure of failures) process.stdout.write(`    - ${failure}\n`);
  }
  process.exitCode = 1;
}
