"""Build compact, reproducible economy tables from the completed Astra study.

This script deliberately does not touch game rules.  It converts the checked
run observations into the recommended payout lookup, fixed-cohort savings
paths, and a small mode comparison table for the accompanying notebook/report.
"""
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
BUILD = REPO / "flutter_app" / "build"
sys.path.insert(0, str(HERE))
from saving_paths import minimum_coin_pack_cost, saving_paths  # noqa: E402


def load_jsonl(path: Path):
    with path.open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def payout(heat: int, base: int = 4, checkpoint: int = 0,
           bonus: int = 20, band: int = 3, complete: int = 12) -> int:
    """Recommended Astra schedule; bonus is paid once on a complete Normal run."""
    return (sum(base + band * ((h - 1) // 3) for h in range(1, heat + 1))
            + (heat // 3) * checkpoint
            + (bonus if heat >= complete else 0))


def write_csv(name: str, rows: list[dict]) -> None:
    if not rows:
        return
    fields = list(dict.fromkeys(k for row in rows for k in row))
    with (HERE / name).open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def build_schedule() -> list[dict]:
    rows = []
    previous = 0
    for heat in range(1, 13):
        clear_reward = 4 + 3 * ((heat - 1) // 3)
        cumulative_before_bonus = sum(4 + 3 * ((h - 1) // 3) for h in range(1, heat + 1))
        cumulative = cumulative_before_bonus + (20 if heat == 12 else 0)
        rows.append({
            "heat": heat,
            "clearReward": clear_reward,
            "cumulativeBeforeCompletionBonus": cumulative_before_bonus,
            "completionBonusAtHeat12": 20 if heat == 12 else 0,
            "cumulativeReward": cumulative,
            "normalMode": "same schedule on Easy, Medium and Hard",
            "gauntletMode": "same first 8 heats; +10 full-clear bonus at Heat 8" if heat <= 8 else "—",
            "endlessMode": "same schedule; no extra repeatable end bonus after Heat 12" if heat >= 12 else "same schedule",
            "dailyMode": "no repeatable direct coins" if heat <= 12 else "—",
        })
        previous = cumulative_before_bonus
    return rows


def selected_rows(rows: list[dict], *parts: str) -> list[dict]:
    return [r for r in rows if r["cellId"] in parts]


def mode_comparison() -> list[dict]:
    rows = []
    raw = []
    for source_name in ["study-normal.runs.jsonl", "study-shared.runs.jsonl", "study-endless.runs.jsonl", "study-baseline.runs.jsonl"]:
        raw.extend(load_jsonl(BUILD / source_name))
    ids = [
        ("Normal Easy", "normal/easy/adaptive/full/astra", "Astra"),
        ("Normal Medium", "normal/medium/adaptive/full/astra", "Astra"),
        ("Normal Hard", "normal/hard/adaptive/full/astra", "Astra"),
        ("Gauntlet", "gauntlet/medium/adaptive/full/shared", "shared"),
        ("Daily Challenge", "daily/medium/adaptive/full/shared", "shared"),
        ("Normal Medium baseline", "normal/medium/adaptive/full/play", "Play baseline"),
    ]
    for label, cell_id, rules_label in ids:
        cohort = [r for r in raw if r["cellId"] == cell_id]
        if not cohort:
            raise ValueError(f"Missing mode cohort: {cell_id}")
        seconds = sum(r["modeledTimeSeconds"]["typicalNormal"] for r in cohort)
        current = sum(r["accountCoinsEarned"] for r in cohort)
        if label == "Gauntlet":
            rewards = [payout(r["heatsCleared"]) + (10 if r["standardModeWon"] else 0) for r in cohort]
        elif label == "Daily Challenge":
            rewards = [0 for _ in cohort]
        elif label == "Normal Medium baseline":
            rewards = [r["accountCoinsEarned"] for r in cohort]
        else:
            rewards = [payout(r["heatsCleared"]) for r in cohort]
        rows.append({
            "modeLabel": label,
            "rules": rules_label,
            "n": len(cohort),
            "winRate": round(sum(r["standardModeWon"] for r in cohort) / len(cohort), 4),
            "meanHeats": round(sum(r["heatsCleared"] for r in cohort) / len(cohort), 3),
            "currentMeanCoins": round(current / len(cohort), 3),
            "recommendedMeanCoins": round(sum(rewards) / len(rewards), 3),
            "modeledMinutes": round(seconds / len(cohort) / 60, 3),
            "recommendedCoinsPerMinute": round(sum(rewards) * 60 / seconds, 3) if seconds else 0,
            "rewardRule": {
                "Normal Easy": "recommended schedule",
                "Normal Medium": "recommended schedule",
                "Normal Hard": "recommended schedule",
                "Gauntlet": "recommended first 8 heats +10 full clear",
                "Daily Challenge": "0 repeatable direct coins; one-time/missions stay separate",
                "Normal Medium baseline": "current Play baseline, not a proposed change",
            }[label],
        })
    return rows


def lifecycle() -> list[dict]:
    rows = []
    raw = []
    for name in ["study-normal.runs.jsonl", "study-shared.runs.jsonl", "study-endless.runs.jsonl", "study-baseline.runs.jsonl"]:
        raw.extend(load_jsonl(BUILD / name))
    cohorts = [
        ("Normal Easy new", "normal/easy/adaptive/new/astra", "recommended", 0),
        ("Normal Medium new", "normal/medium/adaptive/new/astra", "recommended", 0),
        ("Normal Medium full", "normal/medium/adaptive/full/astra", "recommended", 0),
        ("Normal Hard full", "normal/hard/adaptive/full/astra", "recommended", 0),
        ("Gauntlet full", "gauntlet/medium/adaptive/full/shared", "gauntlet", 0),
        ("Normal Medium baseline", "normal/medium/adaptive/full/play", "current", 0),
    ]
    packs = [(300, 99), (600, 179), (1500, 399)]
    targets = [("Wood Vault", 100), ("Gold Vault", 300)]
    for label, cell_id, schedule, wallet in cohorts:
        cohort = [r for r in raw if r["cellId"] == cell_id]
        if schedule == "recommended":
            rewards = [payout(r["heatsCleared"]) for r in cohort]
        elif schedule == "gauntlet":
            rewards = [payout(r["heatsCleared"]) + (10 if r["standardModeWon"] else 0) for r in cohort]
        else:
            rewards = [r["accountCoinsEarned"] for r in cohort]
        for target_name, target in targets:
            result = saving_paths(rewards, target, start_wallet=wallet, paths=2000, seed=20260905 + target)
            rows.append({
                "cohort": label,
                "schedule": schedule,
                "target": target_name,
                "targetCoins": target,
                "inputRuns": len(rewards),
                "inputMeanReward": round(result["inputMeanReward"], 3),
                "paths": result["paths"],
                "completedPaths": result["completedPaths"],
                "censoredPaths": result["censoredPaths"],
                "medianRuns": result["medianRuns"],
                "p10Runs": result["p10Runs"],
                "p90Runs": result["p90Runs"],
                "meanRunsLowerBound": round(result["meanRunsLowerBound"], 3),
                "unreachable": result["unreachable"],
                "packPlanFromZero": minimum_coin_pack_cost(target, packs)["packCounts"],
            })
    return rows


def main() -> None:
    write_csv("recommended-payout-schedule.csv", build_schedule())
    write_csv("mode-comparison.csv", mode_comparison())
    write_csv("lifecycle-results.csv", lifecycle())
    (HERE / "report-data.json").write_text(json.dumps({
        "recommendedSchedule": build_schedule(),
        "modeComparison": mode_comparison(),
        "lifecycle": lifecycle(),
        "packHypothesis": [
            {"product": "Small", "coins": 300, "priceGBP": 0.99},
            {"product": "Medium", "coins": 600, "priceGBP": 1.79},
            {"product": "Large", "coins": 1500, "priceGBP": 3.99},
        ],
        "note": "No game rules, product catalogue or live service was changed by this analysis.",
    }, indent=2), encoding="utf-8")
    print("Wrote payout, mode-comparison and lifecycle tables.")


if __name__ == "__main__":
    main()
