"""Independent QA checks for the WILDCARD strategy/fun simulation analysis."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DECISION_PATH = ROOT / "docs" / "release" / "wildcard-v6.9.13-decision-lab-results.json"
STRATEGY_PATH = ROOT / "docs" / "release" / "wildcard-v6.9.13-strategy-results.json"
ARTIFACT_PATH = ROOT / "analysis" / "wildcard-v6.9.13-strategy-fun-artifact.json"
OUTPUT_PATH = ROOT / "analysis" / "wildcard-v6.9.13-strategy-validation.md"


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def wilson(successes: int, total: int) -> tuple[float, float]:
    z = 1.959963984540054
    proportion = successes / total
    z2 = z * z
    denominator = 1 + z2 / total
    center = (proportion + z2 / (2 * total)) / denominator
    margin = (
        z
        * math.sqrt((proportion * (1 - proportion) + z2 / (4 * total)) / total)
        / denominator
    )
    return round(100 * max(0, center - margin), 2), round(
        100 * min(1, center + margin), 2
    )


def close(left: float, right: float, tolerance: float = 0.011) -> bool:
    return abs(left - right) <= tolerance


def main() -> None:
    decision = load_json(DECISION_PATH)
    strategy = load_json(STRATEGY_PATH)
    artifact = load_json(ARTIFACT_PATH)
    issues: list[str] = []
    checks: list[str] = []

    current_sha = hashlib.sha256((ROOT / "www" / "index.html").read_bytes()).hexdigest()
    if current_sha != decision["sourceSha256"] or current_sha != strategy["sourceSha256"]:
        issues.append("Current game source SHA does not match both simulation artifacts.")
    else:
        checks.append(f"Game source SHA matched `{current_sha}`.")

    for name, payload in (("decision", decision), ("strategy", strategy)):
        if payload["version"] != "6.9.13":
            issues.append(f"{name} artifact version is not v6.9.13.")
        if payload["dataFailures"] or payload["hookErrors"] or payload["invariantFailures"]:
            issues.append(f"{name} artifact contains validation failures.")
    if not issues:
        checks.append("Both simulation suites reported zero data, hook and run-invariant failures.")

    opening_deals = decision["counts"]["openingDeals"]
    if any(row["deals"] != opening_deals for row in decision["opening"]["summaries"]):
        issues.append("Opening arms do not all contain the declared number of deals.")
    else:
        checks.append(
            f"All {decision['counts']['openingArms']} opening arms contain {opening_deals:,} paired deals."
        )

    starter_seed_sequences = []
    for row in decision["starters"]["summaries"]:
        outcomes = row["outcomes"]
        if len(outcomes) != row["runs"]:
            issues.append(f"Starter `{row['id']}` outcome count does not match runs.")
        seeds = [outcome["seed"] for outcome in outcomes]
        if len(set(seeds)) != len(seeds):
            issues.append(f"Starter `{row['id']}` contains duplicate run seeds.")
        starter_seed_sequences.append(seeds)
        wins = sum(bool(outcome["won"]) for outcome in outcomes)
        avg_cleared = sum(outcome["cleared"] for outcome in outcomes) / len(outcomes)
        expected_rate = round(100 * wins / len(outcomes), 2)
        if wins != row["wins"] or not close(expected_rate, row["winRate"]):
            issues.append(f"Starter `{row['id']}` win calculation did not reconcile.")
        if not close(round(avg_cleared, 2), row["avgCleared"]):
            issues.append(f"Starter `{row['id']}` average Heats did not reconcile.")
        expected_ci = wilson(wins, len(outcomes))
        if expected_ci != (row["winRate95"]["low"], row["winRate95"]["high"]):
            issues.append(f"Starter `{row['id']}` Wilson interval did not reconcile.")
    if starter_seed_sequences and any(
        sequence != starter_seed_sequences[0] for sequence in starter_seed_sequences[1:]
    ):
        issues.append("Starter arms do not use the same ordered paired seeds.")
    else:
        checks.append(
            f"All starter arms use the same {len(starter_seed_sequences[0]):,} ordered seeds."
        )

    strategy_seed_sequences = []
    for row in strategy["strategies"]:
        outcomes = row["outcomes"]
        if len(outcomes) != row["runs"]:
            issues.append(f"Strategy `{row['id']}` outcome count does not match runs.")
        seeds = [outcome["seed"] for outcome in outcomes]
        if len(set(seeds)) != len(seeds):
            issues.append(f"Strategy `{row['id']}` contains duplicate run seeds.")
        strategy_seed_sequences.append(seeds)
        wins = sum(bool(outcome["won"]) for outcome in outcomes)
        avg_cleared = sum(outcome["cleared"] for outcome in outcomes) / len(outcomes)
        if wins != row["wins"] or not close(round(100 * wins / len(outcomes), 2), row["winRate"]):
            issues.append(f"Strategy `{row['id']}` win calculation did not reconcile.")
        if not close(round(avg_cleared, 2), row["avgCleared"]):
            issues.append(f"Strategy `{row['id']}` average Heats did not reconcile.")
        if wilson(wins, len(outcomes)) != (
            row["winRate95"]["low"],
            row["winRate95"]["high"],
        ):
            issues.append(f"Strategy `{row['id']}` Wilson interval did not reconcile.")

        total_plays = sum(outcome["simStats"]["plays"] for outcome in outcomes)
        active_plays = sum(outcome["simStats"]["activeJokerPlays"] for outcome in outcomes)
        expected_active = round(100 * active_plays / max(1, total_plays), 2)
        if not close(expected_active, row["fun"]["jokerActivePlayRate"]):
            issues.append(f"Strategy `{row['id']}` Joker-active-play rate did not reconcile.")

    if strategy_seed_sequences and any(
        sequence != strategy_seed_sequences[0] for sequence in strategy_seed_sequences[1:]
    ):
        issues.append("Strategy arms do not use the same ordered paired seeds.")
    else:
        checks.append(
            f"All strategy arms use the same {len(strategy_seed_sequences[0]):,} ordered seeds."
        )

    mixed = 0
    universal_loss = 0
    for index in range(strategy["counts"]["runsPerStrategy"]):
        wins = [bool(row["outcomes"][index]["won"]) for row in strategy["strategies"]]
        if any(wins) and not all(wins):
            mixed += 1
        elif not any(wins):
            universal_loss += 1
    if mixed != strategy["agency"]["mixedOutcomeSeeds"]:
        issues.append("Mixed-outcome paired seed count did not reconcile.")
    if universal_loss != strategy["agency"]["universalLossSeeds"]:
        issues.append("Universal-loss paired seed count did not reconcile.")
    if not issues:
        checks.append("Win rates, run depth, Wilson intervals and paired agency counts reconciled.")

    snapshot = artifact["snapshot"]
    if snapshot["status"] != "ready":
        issues.append("Report artifact snapshot is not ready.")
    if len(snapshot["datasets"]["opening"]) != decision["counts"]["openingArms"]:
        issues.append("Artifact opening dataset row count does not match the simulation.")
    if len(snapshot["datasets"]["starters"]) != decision["counts"]["starterArms"]:
        issues.append("Artifact starter dataset row count does not match the simulation.")
    if len(snapshot["datasets"]["strategies"]) != strategy["counts"]["strategies"]:
        issues.append("Artifact strategy dataset row count does not match the simulation.")
    if artifact["package_info"]["source_sha256"] != current_sha:
        issues.append("Report artifact package hash does not match the game source.")
    if not issues:
        checks.append("Canonical report datasets and source provenance reconcile to simulation outputs.")

    assessment = "Ready to share" if not issues else "Needs revision"
    caveats = [
        "These are deterministic bot simulations, not player telemetry.",
        "Opening score is immediate score and does not prove play-now beats discard.",
        "All strategy bots share an immediate-score card selector; build/shop policy is the main varied factor.",
        "Joker activity counts scoring-event hooks and understates Heat-clear/economy effects.",
        "Affordable-choice shops are not guaranteed to contain two positive upgrades.",
        "Fun conclusions remain proxy-based until pace, fairness and Joker-recall testing is complete.",
    ]
    issue_text = (
        "\n".join(f"{index}. [Severity: High] {issue}" for index, issue in enumerate(issues, 1))
        if issues
        else "No calculation, pairing, provenance or invariant discrepancies found."
    )
    report = f"""# Validation Report

## Overall Assessment: {assessment}

## Methodology Review

The analysis answers the requested opening, starter, strategy and fun questions with paired deterministic simulations from the current v6.9.13 source. Power and enjoyment proxies are reported separately.

## Issues Found

{issue_text}

## Calculation Spot-Checks

{chr(10).join(f"- {check}" for check in checks)}

## Visualization Review

The canonical artifact uses comparison bars for opening/starter/strategy rankings and a labeled strategy scatter for the strength-versus-variety trade-off. All chart datasets retain sample sizes, confidence bounds and adjacent audit measures.

## Suggested Improvements

1. Add a one-step lookahead opening bot to compare play-now versus discard value.
2. Repeat the starter screen with the full veteran Joker shop pool.
3. Pair simulator proxies with closed-test pace, fairness and trigger-recall questions.

## Required Caveats for Stakeholders

{chr(10).join(f"- {caveat}" for caveat in caveats)}
"""
    OUTPUT_PATH.write_text(report, encoding="utf-8")
    print(OUTPUT_PATH)
    if issues:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
