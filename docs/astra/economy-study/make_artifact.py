"""Create the bounded MCP Data Analytics report artifact for the economy study."""
from __future__ import annotations

import csv
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def csv_rows(name: str) -> list[dict[str, object]]:
    with (HERE / name).open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    numeric = {
        "n", "winRate", "meanHeats", "currentMeanCoins", "recommendedMeanCoins",
        "modeledMinutes", "recommendedCoinsPerMinute", "paths", "meanCost",
        "p10Cost", "p90Cost", "medianFirstWildAt", "p90FirstWildAt", "meanFirstWildCost",
        "meanWood", "meanGold", "heat", "clearReward", "cumulativeBeforeCompletionBonus",
        "completionBonusAtHeat12", "cumulativeReward", "targetCoins", "inputRuns",
        "inputMeanReward", "completedPaths", "censoredPaths", "medianRuns", "p10Runs",
        "p90Runs", "meanRunsLowerBound", "winRate", "currentMeanCoins",
    }
    out = []
    for row in rows:
        converted: dict[str, object] = {}
        for key, value in row.items():
            if key in numeric and value not in (None, ""):
                try:
                    converted[key] = float(value) if any(ch in value for ch in ".eE") else int(value)
                    continue
                except ValueError:
                    pass
            if value == "True":
                converted[key] = True
            elif value == "False":
                converted[key] = False
            else:
                converted[key] = value
        out.append(converted)
    return out


def source(source_id: str, label: str, path: str, description: str) -> dict:
    if path.endswith(".json"):
        sql = f"SELECT * FROM read_json_auto('{path}')"
    else:
        sql = f"SELECT * FROM read_csv_auto('{path}', header=true)"
    return {
        "id": source_id,
        "label": label,
        "path": path,
        "query": {
            "engine": "DuckDB",
            "sql": sql,
            "language": "Python",
            "description": description,
            "tables_used": [path],
            "metric_definitions": [
                "Mean coins is the arithmetic mean of per-run accountCoinsEarned or the specified recommended schedule.",
                "Coins per minute is total modeled coins divided by total typicalNormal seconds, times 60.",
            ],
        },
    }


def main() -> None:
    mode = csv_rows("mode-comparison.csv")
    schedule = csv_rows("recommended-payout-schedule.csv")
    collection = csv_rows("collection-results.csv")
    life = csv_rows("lifecycle-results.csv")
    # Keep the report snapshot small while preserving every cohort/target row.
    snapshot = {
        "version": 1,
        "generatedAt": "2026-09-06T00:00:00Z",
        "status": "ready",
        "datasets": {
            "mode_comparison": mode,
            "payout_schedule": schedule,
            "collection_paths": collection,
            "lifecycle_preview": life,
            "metric_runs": [{"value": 7550, "label": "runs"}],
            "metric_normal": [{"value": 122, "label": "coins"}],
            "metric_gauntlet": [{"value": 63, "label": "coins"}],
            "metric_collection": [{"value": 10400, "label": "coins"}],
        },
    }
    sources = [
        source("analysis", "Validated simulation summary", "docs/astra/economy-study/analysis-summary.json", "Recomputed summary over all completed simulation batches and validation checks."),
        source("mode", "Mode comparison output", "docs/astra/economy-study/mode-comparison.csv", "Mode-level win rates, modeled durations and recommended account-coin rates."),
        source("payout", "Recommended payout schedule", "docs/astra/economy-study/recommended-payout-schedule.csv", "Transparent per-Heat and completion payout lookup selected from the candidate grid."),
        source("collection", "Collection simulation output", "docs/astra/economy-study/collection-results.csv", "One-thousand-path Joker Vault collection routes using the actual catalogue and chest roll logic."),
        source("lifecycle", "Savings-path output", "docs/astra/economy-study/lifecycle-results.csv", "Two-thousand fixed-cohort empirical savings paths to Wood and Gold Vault thresholds."),
    ]
    charts = [
        {
            "id": "mode-rate",
            "title": "Modeled account coins per typical minute",
            "subtitle": "The proposed table keeps Daily at zero repeatable direct coins and leaves the Play baseline unchanged.",
            "intent": "comparison",
            "question": "How does modeled reward rate differ by mode and reference cohort?",
            "rationale": "Compares the proposed Astra schedule with the existing Play baseline without treating modeled bot time as a phone benchmark.",
            "type": "bar",
            "dataset": "mode_comparison",
            "sourceId": "mode",
            "encodings": {
                "x": {"field": "modeLabel", "type": "nominal", "label": "Mode"},
                "y": {"field": "recommendedCoinsPerMinute", "type": "quantitative", "format": "number", "label": "Coins per minute"},
                "tooltip": [
                    {"field": "winRate", "label": "Win rate", "format": "percent"},
                    {"field": "recommendedMeanCoins", "label": "Mean coins", "format": "number"},
                    {"field": "modeledMinutes", "label": "Typical minutes", "format": "number"},
                    {"field": "n", "label": "Runs", "format": "number"},
                ],
            },
            "layout": "full",
        },
        {
            "id": "payout-curve",
            "title": "Cumulative account coins by cleared Heat",
            "subtitle": "The Heat-12 completion bonus is shown separately from the Heat clear reward.",
            "intent": "trend",
            "question": "How does a run's account-coin payout accumulate across Heats?",
            "rationale": "Makes the recommended lookup legible and keeps the one-time completion bonus auditable.",
            "type": "line",
            "dataset": "payout_schedule",
            "sourceId": "payout",
            "encodings": {
                "x": {"field": "heat", "type": "ordinal", "label": "Cleared Heat"},
                "y": {"field": "cumulativeReward", "type": "quantitative", "format": "number", "label": "Cumulative coins"},
                "tooltip": [
                    {"field": "clearReward", "label": "Clear reward", "format": "number"},
                    {"field": "completionBonusAtHeat12", "label": "Completion bonus", "format": "number"},
                ],
            },
            "layout": "full",
        },
    ]
    tables = [
        {
            "id": "mode-table",
            "title": "Mode results and recommended reward rate",
            "dataset": "mode_comparison",
            "sourceId": "mode",
            "defaultSort": {"field": "recommendedCoinsPerMinute", "direction": "desc"},
            "density": "spacious",
            "columns": [
                {"field": "modeLabel", "label": "Mode", "type": "text"},
                {"field": "rules", "label": "Rules", "type": "text"},
                {"field": "n", "label": "Runs", "format": "number"},
                {"field": "winRate", "label": "Win rate", "format": "percent"},
                {"field": "meanHeats", "label": "Mean Heats", "format": "number"},
                {"field": "currentMeanCoins", "label": "Current mean coins", "format": "number"},
                {"field": "recommendedMeanCoins", "label": "Recommended mean coins", "format": "number"},
                {"field": "modeledMinutes", "label": "Typical minutes", "format": "number"},
                {"field": "recommendedCoinsPerMinute", "label": "Coins/min", "format": "number"},
                {"field": "rewardRule", "label": "Reward rule", "type": "text"},
            ],
        },
        {
            "id": "payout-table",
            "title": "Recommended Normal payout lookup",
            "dataset": "payout_schedule",
            "sourceId": "payout",
            "defaultSort": {"field": "heat", "direction": "asc"},
            "density": "spacious",
            "columns": [
                {"field": "heat", "label": "Heat", "format": "number"},
                {"field": "clearReward", "label": "Clear reward", "format": "number"},
                {"field": "cumulativeBeforeCompletionBonus", "label": "Cumulative before bonus", "format": "number"},
                {"field": "completionBonusAtHeat12", "label": "Completion bonus", "format": "number"},
                {"field": "cumulativeReward", "label": "Cumulative reward", "format": "number"},
            ],
        },
        {
            "id": "collection-table",
            "title": "Joker Vault collection routes",
            "dataset": "collection_paths",
            "sourceId": "collection",
            "defaultSort": {"field": "meanCost", "direction": "asc"},
            "density": "spacious",
            "columns": [
                {"field": "strategy", "label": "Purchase strategy", "type": "text"},
                {"field": "paths", "label": "Paths", "format": "number"},
                {"field": "meanCost", "label": "Mean Astra cost", "format": "number"},
                {"field": "meanWood", "label": "Mean Wood Vaults", "format": "number"},
                {"field": "meanGold", "label": "Mean Gold Vaults", "format": "number"},
                {"field": "medianFirstWildAt", "label": "Median first WILD Vault", "format": "number"},
            ],
        },
        {
            "id": "lifecycle-table",
            "title": "Fixed-cohort savings paths",
            "dataset": "lifecycle_preview",
            "sourceId": "lifecycle",
            "defaultSort": {"field": "targetCoins", "direction": "asc"},
            "density": "dense",
            "columns": [
                {"field": "cohort", "label": "Cohort", "type": "text"},
                {"field": "target", "label": "Target", "type": "text"},
                {"field": "targetCoins", "label": "Target coins", "format": "number"},
                {"field": "inputMeanReward", "label": "Mean reward", "format": "number"},
                {"field": "medianRuns", "label": "Median runs", "format": "number"},
                {"field": "p10Runs", "label": "P10 runs", "format": "number"},
                {"field": "p90Runs", "label": "P90 runs", "format": "number"},
                {"field": "meanRunsLowerBound", "label": "Mean lower bound", "format": "number"},
            ],
        },
    ]
    cards = [
        {"id": "clean-runs", "description": "All checked simulator rows across the completed batches.", "dataset": "metric_runs", "sourceId": "analysis", "metrics": [{"label": "Clean runs", "field": "value", "format": "number"}]},
        {"id": "normal-full", "description": "Candidate Astra payout on a complete 12-Heat Normal run.", "dataset": "metric_normal", "sourceId": "payout", "metrics": [{"label": "Normal full clear", "field": "value", "format": "number"}]},
        {"id": "gauntlet-full", "description": "Candidate payout for an eight-Heat Gauntlet full clear.", "dataset": "metric_gauntlet", "sourceId": "payout", "metrics": [{"label": "Gauntlet full clear", "field": "value", "format": "number"}]},
        {"id": "collection-cost", "description": "Wood-first cost to discover the remaining catalogue after the ten starter discoveries.", "dataset": "metric_collection", "sourceId": "collection", "metrics": [{"label": "Wood-first collection", "field": "value", "format": "number"}]},
    ]
    manifest = {
        "version": 1,
        "surface": "report",
        "title": "WILDCARD coin economy study",
        "description": "A bounded simulation report for Astra economy decisions. No game, phone, Play or live service was changed.",
        "generatedAt": "2026-09-06T00:00:00Z",
        "sources": sources,
        "cards": cards,
        "charts": charts,
        "tables": tables,
        "blocks": [
            {"id": "title", "type": "markdown", "body": "# WILDCARD coin economy study"},
            {"id": "summary", "type": "markdown", "body": "## Executive Summary\n\nThis is a measured economy recommendation, not a claim that the game is addictive or that any price will convert. The corrected study covers 7,550 deterministic runs in 35 cells with zero invariant or scorer-fidelity failures. The best candidate is a legible 4/4/4 → 7/7/7 → 10/10/10 → 13/13/13 clear schedule, plus 20 coins once on a Heat-12 Normal completion (122 total). Keep Easy, Medium and Hard payout-identical. Use the first eight Heats plus a 10-coin full-clear bonus for Gauntlet (63 total), and keep Endless on the same table. Daily should remain at zero repeatable direct coins until score attestation and an idempotent reward ledger exist."},
            {"id": "headline-metrics", "type": "metric-strip", "cardIds": ["clean-runs", "normal-full", "gauntlet-full", "collection-cost"]},
            {"id": "mode-heading", "type": "markdown", "body": "## Mode results\n\nThe modeled reward-rate comparison below applies the candidate schedule to Astra cohorts. It is useful for relative economy shape, not a device-performance benchmark.", "sourceId": "mode"},
            {"id": "mode-chart", "type": "chart", "chartId": "mode-rate"},
            {"id": "mode-table-block", "type": "table", "tableId": "mode-table"},
            {"id": "payout-heading", "type": "markdown", "body": "## Payout recommendation\n\nEach row shows the reward for clearing that Heat and the cumulative wallet balance before and after the Heat-12 completion bonus. The same first eight rows are used by Gauntlet; Endless continues the table without another completion multiplier.", "sourceId": "payout"},
            {"id": "payout-chart", "type": "chart", "chartId": "payout-curve"},
            {"id": "payout-table-block", "type": "table", "tableId": "payout-table"},
            {"id": "collection-heading", "type": "markdown", "body": "## Collection and pack context\n\nThe actual Vault sampler completes the remaining catalogue at 10,400 coins on a wood-first route. Mixed and gold-first choices cost more because WILD rewards are Gold-only. A provisional 300/600/1,500 coin pack ladder at £0.99/£1.79/£3.99 is therefore a small, testable hypothesis—not a simulated revenue optimum and not a live catalogue change.", "sourceId": "collection"},
            {"id": "collection-table-block", "type": "table", "tableId": "collection-table"},
            {"id": "lifecycle-heading", "type": "markdown", "body": "## Savings-path checks\n\nThese 2,000-path calculations carry a fixed collection state forward and exclude one-time gifts, ads, spending and purchases. They show affordability variability, not a complete player-career forecast.", "sourceId": "lifecycle"},
            {"id": "lifecycle-table-block", "type": "table", "tableId": "lifecycle-table"},
            {"id": "limitations", "type": "markdown", "body": "## Limitations and next action\n\nThe bots are stronger and more consistent than most people; the cells are samples rather than confidence intervals for a population; modeled minutes use explicit decision-time assumptions; and no willingness-to-pay, retention or purchase data exists. The next evidence step is a small human playtest with reward telemetry and localized Play offer data. This branch contains analysis artifacts only; the game rules, phone, Play Console, ads, billing, Firebase and Google Play release were not changed."},
        ],
    }
    payload = {"surface": "report", "manifest": manifest, "snapshot": snapshot, "sources": sources}
    (HERE / "artifact.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(HERE / "artifact.json")


if __name__ == "__main__":
    main()
