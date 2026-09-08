"""Summarize the bounded official-promotion runs without rerunning the engine.

All rewards come from the revised Dart helper. Timings are an explicit model,
not phone measurements; bootstrap intervals are uncertainty across bot seeds.
"""
from __future__ import annotations

import csv
import hashlib
import json
import math
import random
import statistics
import zipfile
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
BUILD = REPO / "flutter_app" / "build"
RAW = BUILD / "v9.1.0-economy"
BATCHES = ["normal-medium", "normal-extremes", "gauntlet", "endless"]
ARCHIVE = REPO.parent / "WILDCARD-v9.1.0-economy-raw-data.zip"


def read_rows(path):
    with path.open(encoding="utf-8") as stream:
        return [json.loads(line) for line in stream if line.strip()]


def quantile(values, q):
    values = sorted(values)
    point = (len(values) - 1) * q
    lo = math.floor(point)
    hi = math.ceil(point)
    return values[lo] + (values[hi] - values[lo]) * (point - lo)


def wilson(wins, n):
    z = 1.959963984540054
    p = wins / n
    den = 1 + z * z / n
    center = (p + z * z / (2 * n)) / den
    margin = z * math.sqrt((p * (1 - p) + z * z / (4 * n)) / n) / den
    return center - margin, center + margin


def bootstrap_mean(values, seed=91001, reps=2000):
    rng = random.Random(seed)
    n = len(values)
    means = [sum(rng.choices(values, k=n)) / n for _ in range(reps)]
    return quantile(means, 0.025), quantile(means, 0.975)


def write_csv(name, rows):
    with (HERE / name).open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def expected_reward(row):
    if row["mode"] == "daily":
        return 0
    heat = row["heatsCleared"]
    amount = sum(4 + 3 * min((h - 1) // 3, 3) for h in range(1, heat + 1))
    completion, bonus = (8, 10) if row["mode"] == "gauntlet" else (12, 20)
    return amount + (bonus if heat >= completion else 0)


def main():
    rows, batches = [], []
    for name in BATCHES:
        report = json.loads((RAW / f"{name}.summary.json").read_text(encoding="utf-8"))
        observations = read_rows(RAW / f"{name}.runs.jsonl")
        assert len(observations) == report["totalRuns"]
        assert report["invariantAndFidelityFailures"] == 0
        assert report["sourceHashesUnchangedAtCompletion"] is True
        rows.extend(observations)
        batches.append(report)
    assert len(rows) == 3000, len(rows)
    assert len({(r["cellId"], r["seed"]) for r in rows}) == len(rows)
    assert all(not r["invariantFailures"] and not r["fidelityFailures"] for r in rows)
    assert all(r["accountCoinsEarned"] == expected_reward(r) for r in rows)
    source_hashes = batches[0]["sourceGitBlobHashes"]
    assert all(b["sourceGitBlobHashes"] == source_hashes for b in batches)

    groups = defaultdict(list)
    for row in rows:
        groups[row["cellId"]].append(row)
    old = json.loads((REPO / "docs/astra/economy-study/analysis-summary.json").read_text(encoding="utf-8"))
    prior = {r["cellId"]: r for r in old["current"]}
    stats, comparisons, stops = [], [], []
    for index, (cell, cohort) in enumerate(sorted(groups.items())):
        rewards = [r["accountCoinsEarned"] for r in cohort]
        seconds = sum(r["modeledTimeSeconds"]["typicalNormal"] for r in cohort)
        n, wins = len(cohort), sum(r["standardModeWon"] for r in cohort)
        ci = bootstrap_mean(rewards, seed=91001 + index)
        wci = wilson(wins, n)
        stats.append({
            "cellId": cell, "runs": n, "firstSeed": min(r["seed"] for r in cohort),
            "lastSeed": max(r["seed"] for r in cohort), "wins": wins,
            "winRate": wins / n, "win95Low": wci[0], "win95High": wci[1],
            "meanClearedHeats": statistics.mean(r["heatsCleared"] for r in cohort),
            "meanCoins": statistics.mean(rewards), "meanCoins95Low": ci[0],
            "meanCoins95High": ci[1], "medianCoins": statistics.median(rewards),
            "p10Coins": quantile(rewards, 0.1), "p90Coins": quantile(rewards, 0.9),
            "modeledMinutes": seconds / n / 60,
            "modeledCoinsPerMinute": sum(rewards) * 60 / seconds,
            "oneOptionalAdMeanBonus": statistics.mean(min(25, v) for v in rewards),
            "censoredAt24": sum(r["censoredAtHeatCap"] for r in cohort),
            "invariantFailures": 0, "rewardFormulaMismatches": 0,
        })
        previous = prior.get(cell)
        if previous:
            comparisons.append({
                "cellId": cell, "oldRuns": previous["n"], "newRuns": n,
                "oldMeanCoins": previous["meanCoins"], "newMeanCoins": statistics.mean(rewards),
                "oldWinRate": previous["winRate"], "newWinRate": wins / n,
                "comparison": "Different seed ranges; prior actual rewards versus implemented promotion, not paired causal estimate",
            })
        if cohort[0]["mode"] != "normal":
            continue
        for scenario in ["quickFast", "typicalNormal", "deliberateNormal"]:
            full_seconds = sum(r["modeledTimeSeconds"][scenario] for r in cohort)
            full_rate = sum(rewards) / full_seconds
            for exit_heat in [1, 3, 6, 9]:
                retained, elapsed, reached = 0, 0, 0
                for row in cohort:
                    point = next((p for p in row["earlyExitCheckpoints"] if p["exitAfterHeat"] == exit_heat), None)
                    retained += point["accountCoinsRetained"] if point else row["accountCoinsEarned"]
                    elapsed += (point if point else row)["modeledTimeSeconds"][scenario]
                    reached += point is not None
                stops.append({"cellId": cell, "timingScenario": scenario,
                              "exitAfterHeat": exit_heat, "runs": n, "reached": reached,
                              "exitCoinsPerMinute": retained * 60 / elapsed,
                              "fullAttemptCoinsPerMinute": full_rate * 60,
                              "exitToFullRate": (retained / elapsed) / full_rate})

    seed_rows = [{"cellId": r["cellId"], "seed": r["seed"], "starter": r["starter"],
                  "clearedHeats": r["heatsCleared"], "wonNormalOrGauntlet": r["standardModeWon"],
                  "coins": r["accountCoinsEarned"], "score": r["totalScore"],
                  "hands": r["handsPlayed"], "discards": r["discardsUsed"],
                  "censoredAtCap": r["censoredAtHeatCap"]} for r in rows]
    write_csv("cohort-results.csv", stats)
    write_csv("seed-results.csv", seed_rows)
    write_csv("prior-study-comparison.csv", comparisons)
    write_csv("early-stop-sensitivity.csv", stops)
    worst = max(stops, key=lambda r: r["exitToFullRate"])
    summary = {"generatedAtUtc": datetime.now(timezone.utc).isoformat(),
               "actualEngineRuns": len(rows), "pilotRunsExcluded": 40,
               "cohorts": stats, "invariantAndFidelityFailures": 0,
               "rewardFormulaMismatches": 0, "sourceGitBlobHashes": source_hashes,
               "economyVersion": batches[0]["economyVersion"],
               "sumWorkerEngineSeconds": sum(b["elapsedSeconds"] for b in batches),
               "bootstrapReplicates": 2000, "bootstrapSeedBase": 91001,
               "worstFixedStop": worst,
               "adSensitivity": {"maxPerPlacement": 25, "sharedDailyPlacements": 5, "maximumPerDay": 125},
               "finiteJourneyCoins": 780,
               "rawDataArchive": str(ARCHIVE)}
    (HERE / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    table = ["| Cohort | Runs | Win rate (95% interval) | Mean coins (95% interval) | Median coins |",
             "| --- | ---: | ---: | ---: | ---: |"]
    for row in stats:
        label = row["cellId"].removesuffix("/astra").removesuffix("/shared")
        table.append(f"| {label} | {row['runs']} | {row['winRate']:.1%} ({row['win95Low']:.1%}–{row['win95High']:.1%}) | "
                     f"{row['meanCoins']:.1f} ({row['meanCoins95Low']:.1f}–{row['meanCoins95High']:.1f}) | {row['medianCoins']:g} |")
    text = f"""# WILDCARD v9.1.0 economy implementation and confirmation

The official promotion implements the recommended Astra earned-progression schedule. **3,000 fresh-seed actual Dart engine runs across eight cohorts passed, with zero engine invariant failures, scorer-fidelity failures, or reward-formula mismatches.** A separate 40-run native pilot is archived but excluded from the results below. The prior 7,550-run study remains preserved.

## Implemented rules

- Normal: 4 coins per cleared Heat 1–3, 7 for 4–6, 10 for 7–9, 13 for 10–12; +20 once at Heat 12. Full clear **122 coins** on every difficulty.
- Gauntlet: the first eight Heat rewards plus +10 once at completion. Full clear **63 coins**. The free Normal starter/early shop rules do not affect Gauntlet.
- Endless: +13 per clear after Heat 12; no additional repeated completion bonus. The earlier study's indefinite +3-per-three-Heat extrapolation is intentionally capped, preventing quadratic total currency growth. A clear through Heat 24 pays 278; a clear through Heat 100 pays 1,266. This is a reward cap per Heat, not a gameplay Heat limit.
- Daily: zero direct repeatable run coins; existing Daily achievements and weekly missions remain. Board-prize proposals are not activated.
- Normal keeps the free three-route starter choice, +3 run coins on each of the first three clears, three early Joker offers, and one free reroll in each of those shops. Run coins cannot be exported into the account wallet.
- Wood Vault: 60 while owning fewer than 15 public Jokers, then 100; Gold 300. Duplicate protection and disclosed dynamic rarity odds are unchanged.
- New stake wagers are disabled. A legacy saved run retains its already-paid stake and original settlement terms.
- The optional run-end ad grants the lesser of earned account coins and 25. Coin-reward ad placements share the five-per-day allowance: **at most 125 ad coins/day**, not five whole-run doubles. This is a separate sensitivity, excluded from engine earnings below.
- Journey contributes **780 one-time coins**, guarded by its persistent claim ledger. Tutorial, achievements, missions, daily login, ads, purchases, and cosmetic spending are outside repeatable direct-run means.

## Fresh-seed confirmation

{chr(10).join(table)}

Normal wins mean reaching Heat 12; Gauntlet wins mean eight clears. Endless “win” still means reaching Heat 12, not beating Endless. Its measurement stops at Heat 24 and records survivors as censored. New/full means ten starter discoveries versus the full public catalogue. `handRanking` and `adaptive` are bot policies, not measured novice/expert people.

Win-rate intervals use Wilson 95% intervals. Mean-coin intervals use 2,000 deterministic bootstrap resamples of whole runs per cohort. These describe seed uncertainty for a fixed bot/pool, not uncertainty about real player behavior. The candidate was selected in the earlier study; these fresh seeds did not retune it.

## Early exit, affordability and purchasing

The largest fixed-stop rate ratio across these Normal cohorts and three modeled timing scenarios is **{worst['exitToFullRate']:.3f}×**, at Heat {worst['exitAfterHeat']} for `{worst['cellId']}` under `{worst['timingScenario']}`. Attempts that fail before the planned stopping point remain included. This is a diagnostic from assumed decision/shop timing; it is not measured phone playtime or proof that humans prefer farming.

A 100-coin Wood Vault is reachable from a good Normal run. We deliberately retain the shorter 60-coin introduction and the finite Journey rewards for people who struggle early. Easy and Hard use the same payouts; easier wins can yield a higher modeled earning rate. This is visible difficulty choice, with fair unchanged card RNG.

The prior pack ladder (300/£0.99, 600/£1.79, 1,500/£3.99) remains a research hypothesis. This promotion does not rename existing products, alter backend purchase grants, or replace localized Play prices. Current paid quantities and completed/pending purchase entitlements are preserved. Bots cannot establish willingness to pay or retention.

## Save and release evidence

Focused controller tests verify full Normal payouts at all difficulties, a resumed victory entering Endless with one completion credit, Gauntlet terminal payment, Daily zero direct payout, persisted free rerolls, and legacy stake settlement. Each Heat and completion retains its existing run-specific idempotency claim. The app-level official upgrade tests cover save backup and cloud/Journey behavior separately.

All fingerprinted simulation source hashes were identical between the four batch starts and completions. Raw per-seed outcomes, Heat checkpoints, seeds, summaries, the domain/game source snapshot and the prior study raw outputs are in `{ARCHIVE.name}` beside the project folder. SHA-256 manifests accompany the report. No simulation process needs to remain running after this report.

Reproduce: compile `flutter_app/tool/astra_mode_economy_study.dart`; use 500 runs/cell for Medium Normal × (handRanking,adaptive) × (new,full), 250 each for adaptive/full Easy Normal, Hard Normal, Gauntlet Medium, and Endless Medium (cap24), all with `--seed-offset=20000`; then run this analysis script. Archive contains the exact batch metadata and source hashes.
"""
    (HERE / "ECONOMY-UPDATE.md").write_text(text, encoding="utf-8")

    raw_paths = sorted(RAW.glob("*.json*"))
    raw_paths += sorted(BUILD.glob("study-*.runs.jsonl"))
    raw_paths += sorted(BUILD.glob("study-*.summary.json"))
    raw_paths += [p for p in [BUILD / "astra-collection.json"] if p.exists()]
    manifest = [{"path": str(p.relative_to(REPO)), "bytes": p.stat().st_size,
                 "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in raw_paths]
    (HERE / "raw-data-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    with zipfile.ZipFile(ARCHIVE, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in raw_paths:
            archive.write(path, str(path.relative_to(REPO)))
        source_paths = {REPO / "flutter_app" / relative for relative in source_hashes}
        source_paths.update((REPO / "flutter_app/lib/domain").rglob("*.dart"))
        source_paths.update((REPO / "flutter_app/lib/game").rglob("*.dart"))
        source_paths.update([REPO / "flutter_app/pubspec.yaml", REPO / "flutter_app/pubspec.lock"])
        for path in sorted(source_paths):
            archive.write(path, f"source-snapshot/{path.relative_to(REPO)}")
        for path in sorted(HERE.glob("*")):
            if path.is_file() and path.name != "raw-archive-sha256.txt":
                archive.write(path, str(path.relative_to(REPO)))
    digest = hashlib.sha256(ARCHIVE.read_bytes()).hexdigest()
    (HERE / "raw-archive-sha256.txt").write_text(f"{digest}  {ARCHIVE.name}\n", encoding="utf-8")
    print(json.dumps({"runs": len(rows), "cohorts": len(stats), "failures": 0,
                      "worstStop": worst, "archive": str(ARCHIVE), "archiveSha256": digest,
                      "archiveBytes": ARCHIVE.stat().st_size}, indent=2))


if __name__ == "__main__":
    main()
