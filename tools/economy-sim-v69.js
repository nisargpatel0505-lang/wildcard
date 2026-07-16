const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const vm = require('vm');

const ROOT = path.resolve(__dirname, '..');
const HTML_PATH = path.join(ROOT, 'www', 'index.html');
const RELEASE_DIR = path.join(ROOT, 'docs', 'release');
const REPORT_VERSION = '6.9.9';
const HORIZON_DAYS = 180;
const TRIALS_PER_COHORT = 1000;
const VAULT_AUDIT_TRIALS = 20000;
const STARTER_GIFT = 200;
const MILESTONES = [0.25, 0.5, 0.75, 1];

const BASELINE = Object.freeze({
  label: 'v6.9.7 baseline',
  dailyLogin: Object.freeze({ base: 50, step: 30, cap: 320 }),
  jokerVaultPrice: Object.freeze({ wood: 35, gold: 100 }),
  rewardedCoin: Object.freeze({ amount: 25, dailyCap: 5 })
});

const COHORTS = Object.freeze([
  Object.freeze({ id: 'casual', label: 'Casual', loginChance: 4 / 7, weeklyRunDays: [0, 2, 5], runsPerRunDay: 1, adViewsPerActiveDay: 0 }),
  Object.freeze({ id: 'regular', label: 'Regular F2P', loginChance: 6 / 7, weeklyRunDays: [0, 1, 2, 3, 4, 5, 6], runsPerRunDay: 1, adViewsPerActiveDay: 2 }),
  Object.freeze({ id: 'grinder', label: 'Grinder F2P', loginChance: 1, weeklyRunDays: [0, 1, 2, 3, 4, 5, 6], runsPerRunDay: 3, adViewsPerActiveDay: 5 })
]);

function invariant(ok, message) {
  if (!ok) throw new Error(message);
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function scanJavaScript(source, start, stopWhen) {
  let quote = '';
  let escaped = false;
  let lineComment = false;
  let blockComment = false;
  let paren = 0;
  let bracket = 0;
  let brace = 0;

  for (let i = start; i < source.length; i++) {
    const ch = source[i];
    const next = source[i + 1] || '';

    if (lineComment) {
      if (ch === '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (ch === '*' && next === '/') {
        blockComment = false;
        i++;
      }
      continue;
    }
    if (quote) {
      if (escaped) {
        escaped = false;
      } else if (ch === '\\') {
        escaped = true;
      } else if (ch === quote) {
        quote = '';
      }
      continue;
    }
    if (ch === '/' && next === '/') {
      lineComment = true;
      i++;
      continue;
    }
    if (ch === '/' && next === '*') {
      blockComment = true;
      i++;
      continue;
    }
    if (ch === '\'' || ch === '"' || ch === '`') {
      quote = ch;
      continue;
    }

    if (ch === '(') paren++;
    else if (ch === ')') paren--;
    else if (ch === '[') bracket++;
    else if (ch === ']') bracket--;
    else if (ch === '{') brace++;
    else if (ch === '}') brace--;

    if (stopWhen({ ch, index: i, paren, bracket, brace })) return i;
  }
  return -1;
}

function extractConst(source, marker) {
  const start = source.indexOf(marker);
  invariant(start >= 0, `Missing live declaration: ${marker}`);
  const end = scanJavaScript(source, start, state => state.ch === ';' && state.paren === 0 && state.bracket === 0 && state.brace === 0);
  invariant(end >= 0, `Unterminated live declaration: ${marker}`);
  return source.slice(start, end + 1);
}

function extractFunction(source, marker) {
  const start = source.indexOf(marker);
  invariant(start >= 0, `Missing live function: ${marker}`);
  const open = source.indexOf('{', start);
  invariant(open >= 0, `Missing function body: ${marker}`);
  const end = scanJavaScript(source, open, state => state.index > open && state.brace === 0);
  invariant(end >= 0, `Unterminated live function: ${marker}`);
  return source.slice(start, end + 1);
}

function loadLiveEconomy(html) {
  const snippets = [
    extractConst(html, 'const WIN_BONUS_ACCOUNT ='),
    extractFunction(html, 'function acctReward('),
    extractConst(html, 'const ECONOMY ='),
    extractConst(html, 'const JOKERS ='),
    extractFunction(html, 'function jokerUnlockCost('),
    extractConst(html, 'const CHESTS='),
    extractFunction(html, 'function dailyReward(')
  ];
  const exportScript = `
    globalThis.__ECONOMY_EXPORT__ = {
      economy: JSON.parse(JSON.stringify(ECONOMY)),
      winBonus: WIN_BONUS_ACCOUNT,
      accountRewards: Array.from({length:12}, (_,i) => acctReward(i+1)),
      dailyRewards: Array.from({length:${HORIZON_DAYS}}, (_,i) => dailyReward(i+1)),
      jokers: JOKERS.map(j => ({
        id:j.id, name:j.name, rarity:j.rarity, unlock:j.unlock,
        liveCost:jokerUnlockCost(j),
        hasXMult:typeof j.xMult === 'function',
        hasAddMult:typeof j.addMult === 'function',
        hasOnScored:typeof j.onScored === 'function',
        hasOnHeatClear:typeof j.onHeatClear === 'function'
      })),
      chests: JSON.parse(JSON.stringify(CHESTS))
    };
  `;
  const context = { Math, Object, Array, JSON };
  vm.createContext(context);
  vm.runInContext(`${snippets.join('\n')}\n${exportScript}`, context, {
    filename: 'wildcard-economy-extract.js',
    timeout: 1500
  });
  invariant(context.__ECONOMY_EXPORT__, 'Live economy extraction returned no data');
  return JSON.parse(JSON.stringify(context.__ECONOMY_EXPORT__));
}

function baselineJokerCost(joker) {
  if (joker.unlock === 0) return 0;
  const base = { common: 32, uncommon: 62, rare: 105, wild: 190 }[joker.rarity] || 55;
  const powerBump =
    (joker.hasXMult ? 10 : 0) +
    (joker.hasAddMult ? 6 : 0) +
    (joker.hasOnScored ? 8 : 0) +
    (joker.hasOnHeatClear ? 8 : 0) +
    (['allin', 'lastcall', 'butcher', 'printer', 'shortcut', 'pocketflush', 'cheat'].includes(joker.id) ? 12 : 0);
  return Math.round((base + powerBump) / 5) * 5;
}

function dailyReward(config, streak) {
  return Math.min(config.cap, config.base + config.step * Math.max(0, streak - 1));
}

function dailyTotal(config, days) {
  let total = 0;
  for (let streak = 1; streak <= days; streak++) total += dailyReward(config, streak);
  return total;
}

function mulberry32(seed) {
  let a = seed >>> 0;
  return function random() {
    a |= 0;
    a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

function seedFor(label) {
  let h = 2166136261;
  for (let i = 0; i < label.length; i++) h = Math.imul(h ^ label.charCodeAt(i), 16777619);
  return h >>> 0;
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function weightedChestDraw(remaining, chest, random) {
  const weights = {};
  for (const joker of remaining.values()) {
    const weight = Number(chest.odds[joker.rarity]) || 0;
    if (weight > 0) weights[joker.rarity] = weight;
  }
  const rarities = Object.keys(weights);
  invariant(rarities.length > 0, 'Chest had no eligible rarity');
  const total = rarities.reduce((sum, rarity) => sum + weights[rarity], 0);
  let roll = random() * total;
  let chosenRarity = rarities[rarities.length - 1];
  for (const rarity of rarities) {
    roll -= weights[rarity];
    if (roll <= 0) {
      chosenRarity = rarity;
      break;
    }
  }
  const candidates = [...remaining.values()].filter(joker => joker.rarity === chosenRarity);
  invariant(candidates.length > 0, `No candidate for chest rarity ${chosenRarity}`);
  return candidates[Math.floor(random() * candidates.length)];
}

function chestAvailable(remaining, chest) {
  const eligible = [...remaining.values()].filter(joker => (Number(chest.odds[joker.rarity]) || 0) > 0);
  if (!eligible.length) return false;
  const primary = Array.isArray(chest.primary) ? chest.primary : [];
  return !primary.length || eligible.some(joker => primary.includes(joker.rarity));
}

function auditVaultRoute(jokers, chests, trialCount, seedLabel) {
  const costs = [];
  const pulls = [];
  for (let trial = 0; trial < trialCount; trial++) {
    const random = mulberry32(seedFor(`${seedLabel}|${trial}`));
    const remaining = new Map(jokers.filter(joker => joker.unlock !== 0).map(joker => [joker.id, joker]));
    let cost = 0;
    const counts = { wood: 0, gold: 0 };
    while (remaining.size) {
      const tier = chestAvailable(remaining, chests.wood) ? 'wood' : 'gold';
      invariant(chestAvailable(remaining, chests[tier]), `Vault route stalled with ${remaining.size} Jokers left`);
      const won = weightedChestDraw(remaining, chests[tier], random);
      remaining.delete(won.id);
      cost += chests[tier].price;
      counts[tier]++;
    }
    costs.push(cost);
    pulls.push(counts);
  }
  costs.sort((a, b) => a - b);
  const mean = costs.reduce((sum, value) => sum + value, 0) / costs.length;
  const meanPulls = {
    wood: pulls.reduce((sum, value) => sum + value.wood, 0) / pulls.length,
    gold: pulls.reduce((sum, value) => sum + value.gold, 0) / pulls.length
  };
  return {
    trials: trialCount,
    mean: round(mean, 2),
    p05: quantile(costs, 0.05),
    p10: quantile(costs, 0.10),
    p50: quantile(costs, 0.50),
    p90: quantile(costs, 0.90),
    p95: quantile(costs, 0.95),
    min: costs[0],
    max: costs[costs.length - 1],
    meanPulls: { wood: round(meanPulls.wood, 2), gold: round(meanPulls.gold, 2) }
  };
}

function quantile(sorted, q) {
  if (!sorted.length) return null;
  return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * q))];
}

function round(value, digits = 1) {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function loadRunDistributions() {
  const candidates = [
    path.join(RELEASE_DIR, 'wildcard-v6.9.9-sim-results.json'),
    path.join(RELEASE_DIR, 'wildcard-v6.9.8-sim-results.json'),
    path.join(RELEASE_DIR, 'wildcard-v6.9.7-sim-results.json'),
    path.join(RELEASE_DIR, 'wildcard-v6.9.1-sim-results.json')
  ];
  const file = candidates.find(candidate => fs.existsSync(candidate));
  invariant(file, 'No gameplay simulation report found for run-depth inputs');
  const report = JSON.parse(fs.readFileSync(file, 'utf8'));

  function expand(name, finalHeat) {
    const cohort = report.cohorts.find(item => item.name === name);
    invariant(cohort, `Missing gameplay cohort ${name}`);
    const outcomes = [];
    for (const [failedAt, count] of Object.entries(cohort.failAt || {})) {
      for (let i = 0; i < count; i++) outcomes.push({ cleared: Number(failedAt) - 1, won: false });
    }
    for (let i = 0; i < cohort.wins; i++) outcomes.push({ cleared: finalHeat, won: true });
    invariant(outcomes.length === cohort.runs, `${name} run-depth expansion mismatch`);
    return { name, sourceRuns: cohort.runs, outcomes };
  }

  return {
    file: path.relative(ROOT, file).replace(/\\/g, '/'),
    version: report.version,
    allUnlocked: expand('standard_all_unlocked', 12),
    freePool: expand('standard_free_pool', 12)
  };
}

function runAccountCoins(outcome, live) {
  let total = 0;
  for (let heat = 1; heat <= outcome.cleared; heat++) total += live.accountRewards[heat - 1];
  if (outcome.won) total += live.winBonus;
  return total;
}

function scenarioFromLive(live) {
  return {
    id: 'proposed',
    label: 'v6.9.9 current',
    dailyLogin: clone(live.economy.dailyLogin),
    jokerVaultPrice: clone(live.economy.jokerVaultPrice),
    rewardedCoin: clone(live.economy.rewardedCoin),
    jokerCosts: Object.fromEntries(live.jokers.map(joker => [joker.id, joker.liveCost]))
  };
}

function baselineScenario(live) {
  return {
    id: 'baseline',
    label: BASELINE.label,
    dailyLogin: clone(BASELINE.dailyLogin),
    jokerVaultPrice: clone(BASELINE.jokerVaultPrice),
    rewardedCoin: clone(BASELINE.rewardedCoin),
    jokerCosts: Object.fromEntries(live.jokers.map(joker => [joker.id, baselineJokerCost(joker)]))
  };
}

function chestsForScenario(live, scenario) {
  const chests = clone(live.chests);
  chests.wood.price = scenario.jokerVaultPrice.wood;
  chests.gold.price = scenario.jokerVaultPrice.gold;
  return chests;
}

function buyDirect(remaining, coins, scenario) {
  let spent = 0;
  let bought = 0;
  while (remaining.size) {
    const affordable = [...remaining.values()]
      .map(joker => ({ joker, cost: scenario.jokerCosts[joker.id] }))
      .filter(item => item.cost <= coins)
      .sort((a, b) => a.cost - b.cost || a.joker.id.localeCompare(b.joker.id));
    if (!affordable.length) break;
    const pick = affordable[0];
    coins -= pick.cost;
    spent += pick.cost;
    bought++;
    remaining.delete(pick.joker.id);
  }
  return { coins, spent, bought };
}

function buyVault(remaining, coins, chests, random) {
  let spent = 0;
  let bought = 0;
  while (remaining.size) {
    const tier = chestAvailable(remaining, chests.wood) ? 'wood' : 'gold';
    if (!chestAvailable(remaining, chests[tier]) || coins < chests[tier].price) break;
    const won = weightedChestDraw(remaining, chests[tier], random);
    remaining.delete(won.id);
    coins -= chests[tier].price;
    spent += chests[tier].price;
    bought++;
  }
  return { coins, spent, bought };
}

function tutorialChestUnlock(remaining) {
  const preferred = ['trainer', 'flushfund', 'wire', 'piggy', 'acemag'];
  for (const id of preferred) {
    if (remaining.has(id)) {
      remaining.delete(id);
      return id;
    }
  }
  const fallback = [...remaining.values()].find(joker => joker.rarity === 'common' || joker.rarity === 'uncommon');
  if (fallback) {
    remaining.delete(fallback.id);
    return fallback.id;
  }
  return '';
}

function simulateTrial({ trial, cohort, route, scenario, live, distributions, paidJokers }) {
  const activityRandom = mulberry32(seedFor(`activity|${cohort.id}|${trial}`));
  const gameplayRandom = mulberry32(seedFor(`gameplay|${cohort.id}|${trial}`));
  const purchaseRandom = mulberry32(seedFor(`purchase|${cohort.id}|${route}|${trial}`));
  const remaining = new Map(paidJokers.map(joker => [joker.id, joker]));
  const totalPaid = paidJokers.length;
  const chests = chestsForScenario(live, scenario);
  const milestoneTargets = MILESTONES.map(value => Math.ceil(totalPaid * value));
  const milestoneDays = Object.fromEntries(MILESTONES.map(value => [String(value), null]));
  const sources = { starter: STARTER_GIFT, daily: 0, runs: 0, ads: 0 };
  let coins = STARTER_GIFT;
  let spent = 0;
  let lastLoginDay = -99;
  let loginStreak = 0;
  let tutorialChestClaimed = false;
  let minimumBalance = coins;

  function recordMilestones(day) {
    const owned = totalPaid - remaining.size;
    for (let i = 0; i < MILESTONES.length; i++) {
      const key = String(MILESTONES[i]);
      if (milestoneDays[key] === null && owned >= milestoneTargets[i]) milestoneDays[key] = day;
    }
  }

  function spend() {
    const purchase = route === 'direct'
      ? buyDirect(remaining, coins, scenario)
      : buyVault(remaining, coins, chests, purchaseRandom);
    coins = purchase.coins;
    spent += purchase.spent;
    invariant(coins >= 0, `${scenario.id}/${route}/${cohort.id} produced a negative balance`);
    minimumBalance = Math.min(minimumBalance, coins);
  }

  for (let day = 1; day <= HORIZON_DAYS; day++) {
    const weekday = (day - 1) % 7;
    const runsToday = cohort.weeklyRunDays.includes(weekday) ? cohort.runsPerRunDay : 0;
    const loggedIn = activityRandom() < cohort.loginChance;
    if (loggedIn) {
      loginStreak = lastLoginDay === day - 1 ? loginStreak + 1 : 1;
      lastLoginDay = day;
      const reward = dailyReward(scenario.dailyLogin, loginStreak);
      coins += reward;
      sources.daily += reward;
    }

    for (let runIndex = 0; runIndex < runsToday; runIndex++) {
      const ownedFraction = (totalPaid - remaining.size) / totalPaid;
      const useAllUnlocked = gameplayRandom() < ownedFraction;
      const pool = useAllUnlocked ? distributions.allUnlocked.outcomes : distributions.freePool.outcomes;
      const outcome = pool[Math.floor(gameplayRandom() * pool.length)];
      const reward = runAccountCoins(outcome, live);
      coins += reward;
      sources.runs += reward;
      if (!tutorialChestClaimed && !outcome.won) {
        tutorialChestClaimed = true;
        tutorialChestUnlock(remaining);
      }
    }

    if (loggedIn || runsToday > 0) {
      const views = Math.min(cohort.adViewsPerActiveDay, scenario.rewardedCoin.dailyCap);
      const reward = views * scenario.rewardedCoin.amount;
      coins += reward;
      sources.ads += reward;
    }

    spend();
    recordMilestones(day);
  }

  return {
    milestoneDays,
    completed: remaining.size === 0,
    ownedPaid: totalPaid - remaining.size,
    balance: coins,
    minimumBalance,
    spent,
    earned: Object.values(sources).reduce((sum, value) => sum + value, 0),
    sources
  };
}

function censoredQuantile(values, q, horizon) {
  const ranked = values.map(value => value === null ? Infinity : value).sort((a, b) => a - b);
  const selected = ranked[Math.min(ranked.length - 1, Math.floor(ranked.length * q))];
  return Number.isFinite(selected) && selected <= horizon ? selected : null;
}

function mean(values) {
  return values.reduce((sum, value) => sum + value, 0) / Math.max(1, values.length);
}

function summarizeTrials(trials) {
  const completionDays = trials.map(trial => trial.milestoneDays['1']);
  const milestones = {};
  for (const value of MILESTONES) {
    const days = trials.map(trial => trial.milestoneDays[String(value)]);
    milestones[String(value)] = {
      p10: censoredQuantile(days, 0.10, HORIZON_DAYS),
      p50: censoredQuantile(days, 0.50, HORIZON_DAYS),
      p90: censoredQuantile(days, 0.90, HORIZON_DAYS),
      reachedPct: round(100 * days.filter(day => day !== null).length / days.length, 2)
    };
  }
  const balances = trials.map(trial => trial.balance).sort((a, b) => a - b);
  const owned = trials.map(trial => trial.ownedPaid).sort((a, b) => a - b);
  const sourceKeys = Object.keys(trials[0].sources);
  return {
    trials: trials.length,
    completionRatePct: round(100 * trials.filter(trial => trial.completed).length / trials.length, 2),
    completionDay: {
      p10: censoredQuantile(completionDays, 0.10, HORIZON_DAYS),
      p50: censoredQuantile(completionDays, 0.50, HORIZON_DAYS),
      p90: censoredQuantile(completionDays, 0.90, HORIZON_DAYS)
    },
    milestones,
    paidOwnedDay180: { p10: quantile(owned, 0.10), p50: quantile(owned, 0.50), p90: quantile(owned, 0.90) },
    balanceDay180: { p10: quantile(balances, 0.10), p50: quantile(balances, 0.50), p90: quantile(balances, 0.90) },
    meanSpent: round(mean(trials.map(trial => trial.spent)), 2),
    meanEarned: round(mean(trials.map(trial => trial.earned)), 2),
    minimumBalance: Math.min(...trials.map(trial => trial.minimumBalance)),
    meanSources: Object.fromEntries(sourceKeys.map(key => [key, round(mean(trials.map(trial => trial.sources[key])), 2)]))
  };
}

function simulateEconomy(live, distributions, scenarios) {
  const paidJokers = live.jokers.filter(joker => joker.unlock !== 0);
  const results = {};
  for (const scenario of scenarios) {
    results[scenario.id] = {};
    for (const route of ['direct', 'vault']) {
      results[scenario.id][route] = {};
      for (const cohort of COHORTS) {
        const trials = [];
        for (let trial = 0; trial < TRIALS_PER_COHORT; trial++) {
          trials.push(simulateTrial({ trial, cohort, route, scenario, live, distributions, paidJokers }));
        }
        results[scenario.id][route][cohort.id] = summarizeTrials(trials);
      }
    }
  }
  return results;
}

function formatDay(value) {
  return value === null ? `>${HORIZON_DAYS}` : String(value);
}

function markdownReport(result) {
  const rows = [];
  for (const scenario of ['baseline', 'proposed']) {
    for (const route of ['direct', 'vault']) {
      for (const cohort of COHORTS) {
        const item = result.cohorts[scenario][route][cohort.id];
        rows.push(`| ${scenario} | ${route} | ${cohort.label} | ${formatDay(item.milestones['0.25'].p50)} | ${formatDay(item.milestones['0.5'].p50)} | ${formatDay(item.milestones['0.75'].p50)} | ${formatDay(item.milestones['1'].p50)} | ${item.completionRatePct}% | ${item.paidOwnedDay180.p50} | ${item.balanceDay180.p50.toLocaleString()} |`);
      }
    }
  }
  const gates = result.gates.map(gate => `- ${gate.pass ? 'PASS' : 'FAIL'} — ${gate.name}: ${gate.detail}`).join('\n');
  return `# WILDCARD v${REPORT_VERSION} Economy Simulation

Deterministic 180-day progression model generated from the live \`www/index.html\` Joker catalogue and economy configuration.

## Live inputs

- Source SHA-256: \`${result.source.sha256}\`
- Source UI version label: ${result.source.detectedVersion}
- Gameplay depth input: \`${result.gameplayInput.file}\` (${result.gameplayInput.allUnlockedRuns} all-unlocked runs; ${result.gameplayInput.freePoolRuns} starter-pool runs)
- Economy trials: ${TRIALS_PER_COHORT.toLocaleString()} per cohort, route and scenario (${(TRIALS_PER_COHORT * COHORTS.length * 2 * 2).toLocaleString()} total player timelines)
- Free / paid Jokers: ${result.catalog.freeJokers} / ${result.catalog.paidJokers}

The two gameplay cohorts use the same bot. They bound collection strength, not human skill. Each simulated run blends those distributions by the percentage of paid Jokers already owned.

## Before and after

| Measure | v6.9.7 baseline | v6.9.9 current |
| --- | ---: | ---: |
| Direct paid-Joker catalogue | ${result.scenarios.baseline.directTotal.toLocaleString()} | ${result.scenarios.proposed.directTotal.toLocaleString()} |
| Vault completion, mean | ${result.scenarios.baseline.vaultRoute.mean.toLocaleString()} | ${result.scenarios.proposed.vaultRoute.mean.toLocaleString()} |
| Vault discount vs direct | ${result.scenarios.baseline.vaultDiscountPct}% | ${result.scenarios.proposed.vaultDiscountPct}% |
| Daily rewards, 7 days | ${result.scenarios.baseline.dailyTotals.day7.toLocaleString()} | ${result.scenarios.proposed.dailyTotals.day7.toLocaleString()} |
| Daily rewards, 30 days | ${result.scenarios.baseline.dailyTotals.day30.toLocaleString()} | ${result.scenarios.proposed.dailyTotals.day30.toLocaleString()} |
| Daily rewards, 180 days | ${result.scenarios.baseline.dailyTotals.day180.toLocaleString()} | ${result.scenarios.proposed.dailyTotals.day180.toLocaleString()} |

Proposed Vault-route distribution: p05 ${result.scenarios.proposed.vaultRoute.p05.toLocaleString()}, p50 ${result.scenarios.proposed.vaultRoute.p50.toLocaleString()}, p95 ${result.scenarios.proposed.vaultRoute.p95.toLocaleString()} coins. It remains duplicate-free; variance comes from occasional Rare Jokers appearing in the Wooden Vault.

## Progression cohorts

| Scenario | Route | Cohort | 25% p50 day | 50% p50 day | 75% p50 day | 100% p50 day | Complete by day 180 | Paid owned p50 | Wallet p50 |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
${rows.join('\n')}

Assumptions: Casual = three runs/week, four expected login days/week, no ads; Regular = one run/day, six expected login days/week and two coin ads on active days; Grinder = three runs/day, daily login and five coin ads. Every profile starts with the real 200-coin tutorial gift and receives the real duplicate-free first-loss comeback Joker.

## Release gates

${gates}

## Interpretation limits

This is a deterministic scenario model, not retention or revenue telemetry. Ad usage and login frequency are explicit assumptions. The gameplay run-depth samples come from bots, so live Firebase cohorts should replace those assumptions once enough players exist.
`;
}

function main() {
  const started = Date.now();
  const html = fs.readFileSync(HTML_PATH, 'utf8');
  const live = loadLiveEconomy(html);
  const distributions = loadRunDistributions();
  const detectedVersion = (html.match(/>v(\d+\.\d+(?:\.\d+)?)<\/b>/) || [])[1] || 'unknown';
  const freeJokers = live.jokers.filter(joker => joker.unlock === 0);
  const paidJokers = live.jokers.filter(joker => joker.unlock !== 0);
  const baseline = baselineScenario(live);
  const proposed = scenarioFromLive(live);
  const scenarios = [baseline, proposed];

  const scenarioAudit = {};
  for (const scenario of scenarios) {
    const directTotal = paidJokers.reduce((sum, joker) => sum + scenario.jokerCosts[joker.id], 0);
    const vaultRoute = auditVaultRoute(paidJokers, chestsForScenario(live, scenario), VAULT_AUDIT_TRIALS, `vault-audit|${scenario.id}`);
    scenarioAudit[scenario.id] = {
      label: scenario.label,
      directTotal,
      vaultRoute,
      vaultDiscountPct: round(100 * (1 - vaultRoute.mean / directTotal), 2),
      dailyConfig: clone(scenario.dailyLogin),
      dailyTotals: {
        day7: dailyTotal(scenario.dailyLogin, 7),
        day30: dailyTotal(scenario.dailyLogin, 30),
        day180: dailyTotal(scenario.dailyLogin, 180)
      },
      vaultPrices: clone(scenario.jokerVaultPrice),
      rewardedCoin: clone(scenario.rewardedCoin)
    };
  }

  const cohorts = simulateEconomy(live, distributions, scenarios);
  const gates = [
    { name: 'Joker catalogue', pass: freeJokers.length === 10 && paidJokers.length === 47, detail: `${freeJokers.length} free / ${paidJokers.length} paid` },
    { name: 'Proposed direct sink band', pass: scenarioAudit.proposed.directTotal >= 10000 && scenarioAudit.proposed.directTotal <= 12000, detail: `${scenarioAudit.proposed.directTotal.toLocaleString()} coins` },
    { name: 'Proposed direct target', pass: scenarioAudit.proposed.directTotal === 10875, detail: `${scenarioAudit.proposed.directTotal.toLocaleString()} / 10,875 coins` },
    { name: 'Daily curve', pass: proposed.dailyLogin.base === 30 && proposed.dailyLogin.step === 18 && proposed.dailyLogin.cap === 192, detail: `${proposed.dailyLogin.base} + ${proposed.dailyLogin.step}/day, cap ${proposed.dailyLogin.cap}` },
    { name: 'Daily totals', pass: scenarioAudit.proposed.dailyTotals.day7 === 588 && scenarioAudit.proposed.dailyTotals.day30 === 4950 && scenarioAudit.proposed.dailyTotals.day180 === 33750, detail: `${scenarioAudit.proposed.dailyTotals.day7} / ${scenarioAudit.proposed.dailyTotals.day30.toLocaleString()} / ${scenarioAudit.proposed.dailyTotals.day180.toLocaleString()}` },
    { name: 'Vault prices', pass: proposed.jokerVaultPrice.wood === 100 && proposed.jokerVaultPrice.gold === 300, detail: `${proposed.jokerVaultPrice.wood} Wooden / ${proposed.jokerVaultPrice.gold} Golden` },
    { name: 'Vault discount', pass: scenarioAudit.proposed.vaultDiscountPct >= 15 && scenarioAudit.proposed.vaultDiscountPct <= 22, detail: `${scenarioAudit.proposed.vaultDiscountPct}% mean discount` },
    { name: 'Non-negative balances', pass: Object.values(cohorts).every(routes => Object.values(routes).every(items => Object.values(items).every(item => item.minimumBalance >= 0))), detail: 'minimum simulated wallet >= 0' },
    { name: 'Trial count', pass: Object.values(cohorts).every(routes => Object.values(routes).every(items => Object.values(items).every(item => item.trials >= 1000))), detail: `${TRIALS_PER_COHORT.toLocaleString()} per cohort/route/scenario` }
  ];

  const deterministicPayload = {
    reportVersion: REPORT_VERSION,
    sourceSha256: sha256(html),
    catalog: { freeJokers: freeJokers.length, paidJokers: paidJokers.length },
    scenarios: scenarioAudit,
    cohorts
  };
  const result = {
    reportVersion: REPORT_VERSION,
    generatedAt: new Date().toISOString(),
    durationMs: Date.now() - started,
    modelHash: sha256(JSON.stringify(deterministicPayload)),
    source: { file: 'www/index.html', detectedVersion, sha256: sha256(html) },
    gameplayInput: {
      file: distributions.file,
      version: distributions.version,
      allUnlockedRuns: distributions.allUnlocked.sourceRuns,
      freePoolRuns: distributions.freePool.sourceRuns
    },
    assumptions: {
      horizonDays: HORIZON_DAYS,
      trialsPerCohort: TRIALS_PER_COHORT,
      starterGift: STARTER_GIFT,
      cohortDefinitions: COHORTS
    },
    catalog: deterministicPayload.catalog,
    scenarios: scenarioAudit,
    cohorts,
    gates,
    passed: gates.every(gate => gate.pass)
  };

  fs.mkdirSync(RELEASE_DIR, { recursive: true });
  const jsonPath = path.join(RELEASE_DIR, `wildcard-v${REPORT_VERSION}-economy-results.json`);
  const reportPath = path.join(RELEASE_DIR, `wildcard-v${REPORT_VERSION}-economy-report.md`);
  fs.writeFileSync(jsonPath, `${JSON.stringify(result, null, 2)}\n`);
  fs.writeFileSync(reportPath, markdownReport(result));

  console.log(JSON.stringify({
    passed: result.passed,
    durationMs: result.durationMs,
    modelHash: result.modelHash,
    jsonPath,
    reportPath,
    direct: { baseline: scenarioAudit.baseline.directTotal, proposed: scenarioAudit.proposed.directTotal },
    vault: { baseline: scenarioAudit.baseline.vaultRoute.mean, proposed: scenarioAudit.proposed.vaultRoute.mean, proposedDiscountPct: scenarioAudit.proposed.vaultDiscountPct },
    daily180: { baseline: scenarioAudit.baseline.dailyTotals.day180, proposed: scenarioAudit.proposed.dailyTotals.day180 },
    gates: gates.map(gate => ({ name: gate.name, pass: gate.pass }))
  }, null, 2));

  if (!result.passed) process.exitCode = 1;
}

main();
