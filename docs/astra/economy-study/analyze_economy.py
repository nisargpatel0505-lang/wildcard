"""Recompute study statistics and candidate payout schedules; no game mutations."""
from __future__ import annotations

import csv
import glob
import json
import math
import random
import statistics as st
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
BUILD = REPO / 'flutter_app' / 'build'


def mean(values):
    return st.mean(values) if values else 0.0


def quantile(values, p):
    if not values:
        return None
    a = sorted(values)
    index = (len(a) - 1) * p
    low = int(index)
    return a[low] + (a[min(low + 1, len(a) - 1)] - a[low]) * (index - low)


def ci_mean(values):
    m = mean(values)
    half = 1.96 * st.stdev(values) / math.sqrt(len(values)) if len(values) > 1 else 0
    return m - half, m + half


def wilson(wins, n):
    if n == 0:
        return 0, 0
    z = 1.96
    p = wins / n
    centre = (p + z*z/(2*n)) / (1 + z*z/n)
    radius = z * math.sqrt(p*(1-p)/n + z*z/(4*n*n)) / (1+z*z/n)
    return max(0, centre-radius), min(1, centre+radius)


def load_runs():
    rows, identities = [], set()
    required = ['normal','shared','endless','baseline','specialists']
    for part in required:
        if not (BUILD/f'study-{part}.summary.json').exists():
            raise ValueError(f'Incomplete required batch: {part}')
    for name in sorted(glob.glob(str(BUILD / 'study-*.runs.jsonl'))):
        manifest_path = Path(name.replace('.runs.jsonl','.summary.json'))
        if not manifest_path.exists():
            raise ValueError(f'Batch still streaming: {name}')
        manifest = json.loads(manifest_path.read_text())
        assert manifest['invariantAndFidelityFailures'] == 0
        assert manifest['sourceHead'].startswith('700372f')
        actual_counts = {}
        with open(name, encoding='utf-8') as handle:
            for line in handle:
                r = json.loads(line)
                identity = (r['cellId'], r['seed'])
                if identity in identities:
                    raise ValueError(f'Duplicate run: {identity}')
                identities.add(identity)
                actual_counts[r['cellId']] = actual_counts.get(r['cellId'],0) + 1
                assert not r['invariantFailures'] and not r['fidelityFailures']
                assert r['accountCoinsEarned'] >= 0
                assert r['heatsCleared'] <= (8 if r['mode'] == 'gauntlet' else 60)
                r.pop('heatCheckpoints', None)
                r.pop('finalJokers', None)
                r['sourceFile'] = Path(name).name
                rows.append(r)
        assert sum(actual_counts.values()) == manifest['totalRuns']
        assert actual_counts == {c['cellId']:c['runs'] for c in manifest['cells']}
    if not rows:
        raise ValueError('No final study-*.runs.jsonl inputs; pilot data is deliberately excluded')
    return rows


def write_csv(name, rows):
    if not rows:
        return
    fields = list(dict.fromkeys(k for row in rows for k in row))
    with (HERE / name).open('w', newline='', encoding='utf-8-sig') as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def summary(rows, earn=lambda r: r['accountCoinsEarned']):
    groups = {}
    for r in rows:
        groups.setdefault(r['cellId'], []).append(r)
    out = []
    for cell, records in sorted(groups.items()):
        coins = [earn(r) for r in records]
        seconds = [r['modeledTimeSeconds']['typicalNormal'] for r in records]
        wins = sum(r['standardModeWon'] for r in records)
        lo, hi = ci_mean(coins)
        wlo, whi = wilson(wins, len(records))
        r = records[0]
        out.append({
            'cellId': cell, **{k: r[k] for k in ['mode','difficulty','policy','collection','rules','discoveryCount']},
            'n': len(records), 'wins': wins, 'winRate': wins/len(records), 'winCiLow': wlo, 'winCiHigh': whi,
            'meanCleared': mean([x['heatsCleared'] for x in records]),
            'meanHands': mean([x['handsPlayed'] for x in records]),
            'meanDiscards': mean([x['discardsUsed'] for x in records]),
            'meanCoins': mean(coins), 'meanCoinsCiLow': lo, 'meanCoinsCiHigh': hi,
            'p10Coins': quantile(coins,.1), 'medianCoins': quantile(coins,.5), 'p90Coins': quantile(coins,.9),
            'modeledMeanMinutes': mean(seconds)/60,
            'modeledCoinsPerMinute': sum(coins)*60/sum(seconds),
            'wood100RunsEquivalent': 100/mean(coins) if mean(coins) else None,
            'gold300RunsEquivalent': 300/mean(coins) if mean(coins) else None,
            'censored': sum(x['censoredAtHeatCap'] for x in records),
        })
    return out


def payout(heat, base, checkpoint, bonus, complete=12, band=0):
    return sum(base + band*((h-1)//3) for h in range(1,heat+1)) + (heat//3)*checkpoint + (bonus if heat >= complete else 0)


def fit_payouts(rows):
    # Predeclared design targets, NOT empirically measured enjoyment/retention.
    # Calibration uses even seeds; odd seeds are a held-out sensitivity check.
    calibration = [r for r in rows if r['mode']=='normal' and r['rules']=='astra'
                   and r['difficulty']=='medium' and r['seed'] % 2 == 0]
    basic = [r for r in calibration if r['policy']=='handRanking' and r['collection']=='new']
    advanced = [r for r in calibration if r['policy']=='adaptive' and r['collection']=='full']
    if not basic or not advanced:
        raise ValueError('Missing primary Medium calibration cohorts')
    candidates = []
    for base,checkpoint,bonus,band in __import__('itertools').product(range(2,9),range(0,11,2),range(10,51,10),range(4)):
                win = payout(12, base, checkpoint, bonus, band=band)
                if not 85 <= win <= 125:
                    continue
                bmean = mean([payout(r['heatsCleared'],base,checkpoint,bonus,band=band) for r in basic])
                amean = mean([payout(r['heatsCleared'],base,checkpoint,bonus,band=band) for r in advanced])
                # About two Wood purchases per four basic runs; advanced ~1/run.
                loss = ((bmean-50)/10)**2 + ((amean-90)/15)**2
                farm = []
                for heat in [1,3,6,9]:
                    available = [(r, next((p for p in r['earlyExitCheckpoints'] if p['exitAfterHeat']==heat),None)) for r in advanced]
                    # An intentional exit policy also includes attempts that fail BEFORE its exit target.
                    coins, seconds, full_coins, full_seconds = 0.,0.,0.,0.
                    for r,p in available:
                        h = heat if p else r['heatsCleared']
                        coins += payout(h,base,checkpoint,bonus,band=band)
                        seconds += (p['modeledTimeSeconds'] if p else r['modeledTimeSeconds'])['typicalNormal']
                        full_coins += payout(r['heatsCleared'],base,checkpoint,bonus,band=band)
                        full_seconds += r['modeledTimeSeconds']['typicalNormal']
                    ratio = (coins/seconds)/(full_coins/full_seconds)
                    farm.append(ratio)
                loss += 8 * max(0, max(farm)-1.10)**2
                candidates.append({'basePerHeat':base,'everyThirdHeatExtra':checkpoint,'winBonus':bonus,'heatBandIncrease':band,
                    'fullWin':win,'basicCalibrationMean':bmean,'adaptiveCalibrationMean':amean,
                    'maxExitRateRatio':max(farm),'objective':loss})
    return sorted(candidates, key=lambda c:(c['objective'],c['fullWin']))


def assess_candidate(rows, candidate):
    b,c,w,band = (candidate[k] for k in ['basePerHeat','everyThirdHeatExtra','winBonus','heatBandIncrease'])
    # Selection is fixed on calibration data. This function never reranks it.
    primary = [r for r in rows if r['mode']=='normal' and r['rules']=='astra']
    checks = []
    for split in ['calibration_even','holdout_odd']:
        selected = [r for r in primary if r['seed'] % 2 == (0 if split=='calibration_even' else 1)]
        for cohort in summary(selected, lambda r:payout(r['heatsCleared'],b,c,w,band=band)):
            checks.append({**cohort,'split':split})
    farm = []
    groups = {}
    for r in primary:
        groups.setdefault(r['cellId'],[]).append(r)
    for cell, records in sorted(groups.items()):
        for scenario in ['quickFast','typicalNormal','deliberateNormal']:
            full_coins = sum(payout(r['heatsCleared'],b,c,w,band=band) for r in records)
            full_seconds = sum(r['modeledTimeSeconds'][scenario] for r in records)
            for heat in [1,3,6,9]:
                coins, seconds, reached = 0.,0.,0
                for r in records:
                    p = next((p for p in r['earlyExitCheckpoints'] if p['exitAfterHeat']==heat),None)
                    reached += p is not None
                    coins += payout(heat if p else r['heatsCleared'],b,c,w,band=band)
                    seconds += (p['modeledTimeSeconds'] if p else r['modeledTimeSeconds'])[scenario]
                farm.append({'cellId':cell,'timingScenario':scenario,'exitHeat':heat,'n':len(records),'reachedExit':reached,
                    'modeledExitCoinsPerMinute':coins*60/seconds,'modeledFullCoinsPerMinute':full_coins*60/full_seconds,
                    'exitRateRatio':(coins/seconds)/(full_coins/full_seconds) if full_coins else None})
    return checks, farm


def collection_stats():
    data = json.loads((BUILD/'astra-collection.json').read_text())
    out = []
    for strategy in sorted({r['strategy'] for r in data['rows']}):
        rows = [r for r in data['rows'] if r['strategy']==strategy]
        assert all(r['wood']+r['gold']==len(data['catalogue'])-10 for r in rows)
        out.append({'strategy':strategy,'paths':len(rows),'meanCost':mean([r['astraCost'] for r in rows]),
          'p10Cost':quantile([r['astraCost'] for r in rows],.1),'p90Cost':quantile([r['astraCost'] for r in rows],.9),
          'medianFirstWildAt':quantile([r['firstWildAt'] for r in rows],.5),
          'p90FirstWildAt':quantile([r['firstWildAt'] for r in rows],.9),
          'meanFirstWildCost':mean([r['firstWildCost'] for r in rows]),
          'meanWood':mean([r['wood'] for r in rows]),'meanGold':mean([r['gold'] for r in rows])})
    return out


def main():
    rows = load_runs()
    current = summary(rows)
    candidates = fit_payouts(rows)
    collection = collection_stats()
    holdout, farm = assess_candidate(rows,candidates[0])
    write_csv('current-mode-results.csv',current)
    write_csv('payout-grid.csv',candidates)
    write_csv('collection-results.csv',collection)
    write_csv('selected-payout-holdout.csv',holdout)
    write_csv('selected-payout-stop-sensitivity.csv',farm)
    report={'runCount':len(rows),'cellCount':len(current),'current':current,'payoutCandidates':candidates[:12],
            'collection':collection,'validation':{'duplicateRuns':0,'runInvariantFailures':0,
            'sampling':'deterministic matched seeds; coin mean normal 95% CI, win Wilson95%; not human populations',
            'grid':'Calibration even seeds; design targets50basic/90adaptive coins per Medium run, 85..125win, farming penalty above1.1x'}}
    (HERE/'analysis-summary.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({'runs':len(rows),'cells':len(current),'bestCandidates':candidates[:5]},indent=2))


if __name__=='__main__':
    main()
