"""Build the canonical MCP report artifact from reviewed WILDCARD simulations."""

from __future__ import annotations

import json
import math
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DECISION_PATH = ROOT / "docs" / "release" / "wildcard-v6.9.13-decision-lab-results.json"
STRATEGY_PATH = ROOT / "docs" / "release" / "wildcard-v6.9.13-strategy-results.json"
ARTIFACT_PATH = ROOT / "analysis" / "wildcard-v6.9.13-strategy-fun-artifact.json"
SUMMARY_PATH = ROOT / "analysis" / "wildcard-v6.9.13-strategy-fun-summary.json"

ENGINE_SETS = {
    "Pair/rank": {
        "polish",
        "trainer",
        "copper",
        "presser",
        "retainer",
        "even",
        "acemag",
        "lowball",
        "inktrade",
        "triple3",
        "number_station",
        "frequency_meter",
    },
    "Flush/colour": {
        "flushfund",
        "uniform",
        "pocketflush",
        "color_wash",
        "prism_lens",
        "presser",
        "inktrade",
        "tailor",
    },
    "Economy": {"dividend", "piggy", "miser", "dumpster"},
    "xMult": {
        "roller",
        "lastcall",
        "couple",
        "sniper",
        "boostfiend",
        "modded",
        "survivor",
        "doubledown",
        "allin",
        "redline",
        "master_class",
        "danger_music",
        "prism_lens",
        "glass_joystick",
    },
    "Utility": {
        "royalscam",
        "lucky7",
        "shortcut",
        "pocketflush",
        "cheat",
        "tailor",
        "collector",
        "printer",
        "cleaner",
        "guillotine",
    },
}


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def has_engine_identity(final_jokers: list[str]) -> bool:
    build = set(final_jokers)
    scores = sorted((len(build & members), name) for name, members in ENGINE_SETS.items())
    top = scores[-1][0]
    second = scores[-2][0]
    return top >= 2 and top - second >= 1


def exact_two_sided_binomial(a_only: int, b_only: int) -> float:
    total = a_only + b_only
    if total == 0:
        return 1.0
    tail_n = min(a_only, b_only)
    tail = sum(math.comb(total, index) for index in range(tail_n + 1)) / (2**total)
    return min(1.0, 2 * tail)


def pp(value: float) -> str:
    return f"{value:.1f}%"


def source(
    source_id: str,
    label: str,
    path: str,
    executed_at: str,
    description: str,
    filters: list[str],
    metric_definitions: list[str],
) -> dict:
    return {
        "id": source_id,
        "label": label,
        "path": path,
        "query": {
            "language": "javascript",
            "engine": "Node.js VM simulation",
            "executed_at": executed_at,
            "description": description,
            "tables_used": [path],
            "filters": filters,
            "metric_definitions": metric_definitions,
        },
    }


def widget_source(source_id: str, label: str, dataset: str, sql: str, description: str) -> dict:
    """Attach an explicit, reproducible snapshot query to each native widget."""
    return {
        "id": source_id,
        "label": label,
        "path": f"snapshot.datasets.{dataset}",
        "query": {
            "language": "sql",
            "engine": "bounded artifact snapshot",
            "description": description,
            "sql": sql,
            "tables_used": [dataset],
        },
    }


def main() -> None:
    decision = load_json(DECISION_PATH)
    strategy = load_json(STRATEGY_PATH)
    if decision["sourceSha256"] != strategy["sourceSha256"]:
        raise RuntimeError("Simulation artifacts use different game source hashes")
    for payload in (decision, strategy):
        if payload["dataFailures"] or payload["hookErrors"] or payload["invariantFailures"]:
            raise RuntimeError("Simulation validation failures prevent report generation")

    generated_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    opening_rows = []
    for row in decision["opening"]["summaries"]:
        opening_rows.append(
            {
                "configuration": row["name"],
                "configuration_id": row["id"],
                "starter_cost": row["cost"],
                "deals": row["deals"],
                "avg_best_score": row["avgBestScore"],
                "median_best_score": row["medianBestScore"],
                "p90_best_score": row["p90BestScore"],
                "one_play_clear_rate": row["onePlayClearRate"],
                "dominant_best_hand": row["dominantBestHand"],
                "dominant_best_hand_share": row["dominantBestHandShare"],
                "tutorial_only": bool(row.get("tutorialOnly")),
            }
        )

    starter_rows = []
    for row in decision["starters"]["summaries"]:
        starter_rows.append(
            {
                "starter": row["name"],
                "starter_id": row["id"],
                "starter_cost": row["cost"],
                "runs": row["runs"],
                "wins": row["wins"],
                "win_rate": row["winRate"],
                "ci_low": row["winRate95"]["low"],
                "ci_high": row["winRate95"]["high"],
                "avg_heats_cleared": row["avgCleared"],
                "reach_heat_9": row["reachByHeat"]["9"],
                "reach_heat_12": row["reachByHeat"]["12"],
                "boss_hazard": row["fun"]["bossHazard"],
                "hand_entropy": row["fun"]["handEntropy"],
                "dominant_hand": row["fun"]["dominantHand"],
                "dominant_hand_share": row["fun"]["dominantHandShare"],
                "joker_active_play_rate": row["fun"]["jokerActivePlayRate"],
                "joker_events_per_play": row["fun"]["jokerTriggerEventsPerPlay"],
                "notable_play_rate": row["fun"]["notablePlayRate"],
                "any_callout_play_rate": row["fun"]["anyCalloutPlayRate"],
                "final_play_clear_rate": row["fun"]["finalPlayClearRate"],
                "close_clear_rate": row["fun"]["closeClearRate"],
                "build_jaccard_distance": row["fun"]["meanBuildJaccardDistance"],
                "tutorial_only": bool(row.get("tutorialOnly")),
            }
        )

    strategy_rows = []
    for row in strategy["strategies"]:
        identity_rate = 100 * sum(
            has_engine_identity(outcome["finalJokers"]) for outcome in row["outcomes"]
        ) / row["runs"]
        strategy_rows.append(
            {
                "strategy": row["name"],
                "strategy_id": row["id"],
                "runs": row["runs"],
                "wins": row["wins"],
                "win_rate": row["winRate"],
                "ci_low": row["winRate95"]["low"],
                "ci_high": row["winRate95"]["high"],
                "avg_heats_cleared": row["avgCleared"],
                "reach_heat_9": row["reachH9"],
                "reach_heat_11": row["reachH11"],
                "hand_entropy": row["fun"]["handEntropy"],
                "dominant_hand": row["fun"]["dominantHand"],
                "dominant_hand_share": row["fun"]["dominantHandShare"],
                "joker_active_play_rate": row["fun"]["jokerActivePlayRate"],
                "joker_events_per_play": row["fun"]["jokerTriggerEventsPerPlay"],
                "final_play_clear_rate": row["fun"]["finalPlayClearRate"],
                "close_clear_rate": row["fun"]["closeClearRate"],
                "comeback_clear_rate": row["fun"]["comebackClearRate"],
                "affordable_choice_shop_rate": row["fun"]["meaningfulShopRate"],
                "dead_shop_rate": row["fun"]["deadShopRate"],
                "build_jaccard_distance": row["fun"]["meanBuildJaccardDistance"],
                "build_identity_rate": round(identity_rate, 2),
                "boss_hazard": row["fun"]["bossHazard"],
            }
        )

    frontier_rows = [
        {
            "hand_type": hand_type,
            "availability_rate": values["availabilityRate"],
            "conditional_avg_score": values["conditionalAvgBestScore"],
            "conditional_median_score": values["conditionalMedianBestScore"],
            "conditional_p90_score": values["conditionalP90BestScore"],
        }
        for hand_type, values in decision["opening"]["guidedHandFrontier"].items()
    ]

    best_open = max(opening_rows, key=lambda row: row["avg_best_score"])
    best_single_open = max(
        (row for row in opening_rows if not row["tutorial_only"] and row["configuration_id"] != "none"),
        key=lambda row: row["avg_best_score"],
    )
    best_starter_depth = max(starter_rows, key=lambda row: (row["avg_heats_cleared"], row["win_rate"]))
    best_starter_win = max(starter_rows, key=lambda row: (row["win_rate"], row["avg_heats_cleared"]))
    ranked_strategies = sorted(
        strategy_rows, key=lambda row: (row["win_rate"], row["avg_heats_cleared"]), reverse=True
    )
    best_strategy = ranked_strategies[0]
    runner_up_strategy = ranked_strategies[1]
    guided = next(row for row in opening_rows if row["configuration_id"] == "guided_copper_polish")
    no_boost_open = next(row for row in opening_rows if row["configuration_id"] == "none")
    no_boost_starter = next(row for row in starter_rows if row["starter_id"] == "none")

    best_strategy_raw = next(
        row for row in strategy["strategies"] if row["id"] == best_strategy["strategy_id"]
    )
    pair_rows = {row["id"]: row for row in strategy["pairedAgainstBest"]}
    paired_significance = []
    for row in strategy_rows:
        pair = pair_rows[row["strategy_id"]]
        paired_significance.append(
            {
                "strategy_id": row["strategy_id"],
                "strategy": row["strategy"],
                "best_only": pair["bestOnly"],
                "strategy_only": pair["strategyOnly"],
                "discordant": pair["bestOnly"] + pair["strategyOnly"],
                "paired_p": round(
                    exact_two_sided_binomial(pair["bestOnly"], pair["strategyOnly"]), 6
                ),
            }
        )
    runner_pair = next(
        row for row in paired_significance if row["strategy_id"] == runner_up_strategy["strategy_id"]
    )

    sensible = [
        row
        for row in strategy_rows
        if row["strategy_id"] not in {"xmult_stacking"}
    ]
    sensible_spread = max(row["win_rate"] for row in sensible) - min(
        row["win_rate"] for row in sensible
    )

    decision_source = source(
        "decision_lab",
        "v6.9.13 paired opening and starter lab",
        "docs/release/wildcard-v6.9.13-decision-lab-results.json",
        decision["generatedAt"],
        "Exhaustive immediate opening enumeration plus paired complete starter-pool runs.",
        [
            f"{decision['counts']['openingDeals']} initial nine-card deals per opening arm",
            f"{decision['counts']['starterRunsPerArm']} complete runs per starter arm",
            "Starter-only ten-Joker shop pool",
            "Adaptive greedy shop policy held constant",
        ],
        [
            "Best opening score = maximum immediate score among legal useful one-to-five-card plays.",
            "Win rate = runs clearing Heat 12 / complete runs in the arm.",
            "Average Heats cleared = arithmetic mean of cleared Heats per complete run.",
            "Boss hazard = Heat-12 failures / runs reaching Heat 12.",
        ],
    )
    strategy_source = source(
        "strategy_lab",
        "v6.9.13 paired fixed-start strategy lab",
        "docs/release/wildcard-v6.9.13-strategy-results.json",
        strategy["generatedAt"],
        "Paired 12-Heat simulations comparing seven build/shop policies with no free start boost.",
        [
            f"{strategy['counts']['runsPerStrategy']} paired seeds per strategy",
            "All 57 Jokers available in Heat shops",
            "No free start boost",
            "Immediate-score card selector shared across strategies",
        ],
        [
            "Win rate = runs clearing Heat 12 / complete runs in the strategy.",
            "Hand entropy = normalized Shannon entropy across the ten poker hand types.",
            "Build Jaccard distance = mean one minus set overlap across sampled final builds.",
            "Joker-active play rate = plays with at least one scoring-event Joker / all scoring plays.",
            "Close clear rate = cleared Heats with winning margin at or below 10% of target.",
        ],
    )
    game_source = {
        "id": "game_source",
        "label": "Canonical WILDCARD v6.9.13 game source",
        "path": "www/index.html",
        "query": {
            "language": "javascript",
            "engine": "WILDCARD live source",
            "description": "Scoring, Joker, Heat, shop and run rules evaluated by the simulation VM.",
            "tables_used": ["www/index.html"],
            "filters": [f"SHA-256 {decision['sourceSha256']}"],
            "metric_definitions": [
                "Heat 12 clear is the standard-run win outcome.",
                "Heat 1 target is 90; hand size is nine; up to five cards can be played.",
            ],
        },
    }

    summary = {
        "version": decision["version"],
        "source_sha256": decision["sourceSha256"],
        "generated_at": generated_at,
        "opening_deals": decision["counts"]["openingDeals"],
        "full_runs": decision["counts"]["fullRuns"] + strategy["counts"]["fullRuns"],
        "best_opening_configuration": best_open,
        "best_single_opening_starter": best_single_open,
        "best_starter_by_depth": best_starter_depth,
        "best_starter_by_win_rate": best_starter_win,
        "best_strategy": best_strategy,
        "runner_up_strategy": runner_up_strategy,
        "top_strategy_paired_p": runner_pair["paired_p"],
        "no_boost_starter": no_boost_starter,
        "guided_opening": guided,
        "no_boost_opening": no_boost_open,
        "strategy_agency": strategy["agency"],
        "sensible_strategy_spread_pp": round(sensible_spread, 2),
        "paired_strategy_significance": paired_significance,
        "validation": {
            "decision_failures": 0,
            "strategy_failures": 0,
            "not_player_telemetry": True,
        },
        "chart_map": [
            {
                "section": "Opening decisions",
                "question": "How much immediate score does each start configuration expose?",
                "family": "Comparison",
                "type": "bar",
                "fields": ["configuration", "avg_best_score"],
                "source": decision_source["path"],
            },
            {
                "section": "Starter boosts",
                "question": "Which starter produces the deepest full run?",
                "family": "Comparison",
                "type": "bar",
                "fields": ["starter", "avg_heats_cleared"],
                "source": decision_source["path"],
            },
            {
                "section": "Build strategies",
                "question": "Which policy clears Heat 12 most often?",
                "family": "Ranking",
                "type": "bar",
                "fields": ["strategy", "win_rate"],
                "source": strategy_source["path"],
            },
            {
                "section": "Fun trade-off",
                "question": "How does strategy strength relate to hand variety?",
                "family": "Relationship",
                "type": "scatter",
                "fields": ["hand_entropy", "win_rate", "strategy"],
                "source": strategy_source["path"],
            },
        ],
    }

    title = "WILDCARD: Best Openings, Builds and Fun"
    executive_summary = f"""## Executive Summary

- **Play made hands; discard weak High Card.** The guided Copper Chip + Pair Polisher start finds a one-play Heat-1 clear on **{pp(guided['one_play_clear_rate'])}** of initial deals, versus **{pp(no_boost_open['one_play_clear_rate'])}** with no boost. The opening frontier shows the decisive step is Pair-or-better, not simply the highest ranks.
- **{best_starter_depth['starter']} is the most reliable starter-depth screen.** It averaged **{best_starter_depth['avg_heats_cleared']:.2f} Heats cleared** in the starter-only pool. **{best_starter_win['starter']}** had the highest observed win rate at **{pp(best_starter_win['win_rate'])}**, but rare wins and overlapping intervals make run depth the safer recommendation.
- **{best_strategy['strategy']} and {runner_up_strategy['strategy']} are statistically tied at the top.** Their observed Heat-12 clear rates were **{pp(best_strategy['win_rate'])}** and **{pp(runner_up_strategy['win_rate'])}**; the paired exact comparison is p={runner_pair['paired_p']:.3f}. The result now holds the start at no free Joker; the older comparison did not.
- **Fun comes from coherent variety, readable triggers and recoverable danger.** Keep strong sensible strategies within roughly 5–15 win-rate points, hand entropy around 0.65–0.85, and boss hazard around 35–55%; verify pace, fairness and Joker recall with people."""

    manifest = {
        "version": 1,
        "surface": "report",
        "title": title,
        "generatedAt": generated_at,
        "description": "Decision report from paired v6.9.13 simulations.",
        "charts": [
            {
                "id": "opening_score",
                "title": "Best immediate opening score",
                "subtitle": "The guided two-Joker lesson is strongest; Opening Act leads the single-starter first deal.",
                "type": "bar",
                "dataset": "opening",
                "sourceId": "decision_lab",
                "source": widget_source(
                    "decision_lab",
                    "Paired opening lab",
                    "opening",
                    "SELECT configuration, avg_best_score, median_best_score, p90_best_score, "
                    "one_play_clear_rate FROM opening ORDER BY avg_best_score DESC",
                    "Rank the paired opening configurations by mean best immediate score.",
                ),
                "valueFormat": "number",
                "encodings": {
                    "x": {"field": "configuration", "type": "nominal", "label": "Start configuration"},
                    "y": {
                        "field": "avg_best_score",
                        "type": "quantitative",
                        "label": "Mean best immediate score",
                    },
                    "tooltip": [
                        {"field": "one_play_clear_rate", "type": "quantitative", "label": "One-play Heat-1 clear", "unit": "%"},
                        {"field": "median_best_score", "type": "quantitative", "label": "Median best score"},
                        {"field": "p90_best_score", "type": "quantitative", "label": "P90 best score"},
                    ],
                },
                "referenceLines": [{"value": 90, "label": "Heat 1 target"}],
                "layout": "full",
            },
            {
                "id": "starter_depth",
                "title": "Average Heats cleared by starter boost",
                "subtitle": "Run depth is more stable than rare Heat-12 wins in the starter-only pool.",
                "type": "bar",
                "dataset": "starters",
                "sourceId": "decision_lab",
                "source": widget_source(
                    "decision_lab",
                    "Paired starter lab",
                    "starters",
                    "SELECT starter, avg_heats_cleared, win_rate, reach_heat_12, boss_hazard "
                    "FROM starters ORDER BY avg_heats_cleared DESC",
                    "Rank starter boosts by average complete-run depth with outcome context.",
                ),
                "valueFormat": "number",
                "encodings": {
                    "x": {"field": "starter", "type": "nominal", "label": "Starter boost"},
                    "y": {
                        "field": "avg_heats_cleared",
                        "type": "quantitative",
                        "label": "Average Heats cleared",
                    },
                    "tooltip": [
                        {"field": "win_rate", "type": "quantitative", "label": "Clear Heat 12", "unit": "%"},
                        {"field": "reach_heat_12", "type": "quantitative", "label": "Reach Heat 12", "unit": "%"},
                        {"field": "boss_hazard", "type": "quantitative", "label": "Boss hazard", "unit": "%"},
                    ],
                },
                "layout": "full",
            },
            {
                "id": "strategy_strength",
                "title": "Heat-12 clear rate by build policy",
                "subtitle": "Every strategy uses the same paired seeds and no free start boost.",
                "type": "bar",
                "dataset": "strategies",
                "sourceId": "strategy_lab",
                "source": widget_source(
                    "strategy_lab",
                    "Paired strategy lab",
                    "strategies",
                    "SELECT strategy, win_rate, ci_low, ci_high, avg_heats_cleared "
                    "FROM strategies ORDER BY win_rate DESC",
                    "Compare Heat-12 clear rates for paired fixed-start build policies.",
                ),
                "valueFormat": "number",
                "unit": "%",
                "encodings": {
                    "x": {"field": "strategy", "type": "nominal", "label": "Build policy"},
                    "y": {"field": "win_rate", "type": "quantitative", "label": "Clear Heat 12", "unit": "%"},
                    "tooltip": [
                        {"field": "ci_low", "type": "quantitative", "label": "Wilson CI low", "unit": "%"},
                        {"field": "ci_high", "type": "quantitative", "label": "Wilson CI high", "unit": "%"},
                        {"field": "avg_heats_cleared", "type": "quantitative", "label": "Average Heats cleared"},
                    ],
                },
                "layout": "full",
            },
            {
                "id": "strategy_variety",
                "title": "Clear rate and hand diversity",
                "subtitle": "The best experience should sit between incoherent variety and one-hand repetition.",
                "type": "scatter",
                "dataset": "strategies",
                "sourceId": "strategy_lab",
                "source": widget_source(
                    "strategy_lab",
                    "Paired strategy lab",
                    "strategies",
                    "SELECT strategy, hand_entropy, win_rate, joker_active_play_rate, dominant_hand, "
                    "dominant_hand_share, build_identity_rate, build_jaccard_distance FROM strategies",
                    "Compare strategy strength with hand diversity and build identity.",
                ),
                "encodings": {
                    "x": {"field": "hand_entropy", "type": "quantitative", "label": "Normalized hand entropy"},
                    "y": {"field": "win_rate", "type": "quantitative", "label": "Clear Heat 12", "unit": "%"},
                    "label": {"field": "strategy", "type": "text", "label": "Strategy"},
                    "size": {"field": "joker_active_play_rate", "type": "quantitative", "label": "Joker-active plays", "unit": "%"},
                    "tooltip": [
                        {"field": "dominant_hand", "type": "text", "label": "Dominant hand"},
                        {"field": "dominant_hand_share", "type": "quantitative", "label": "Dominant hand share", "unit": "%"},
                        {"field": "build_identity_rate", "type": "quantitative", "label": "Build identity", "unit": "%"},
                        {"field": "build_jaccard_distance", "type": "quantitative", "label": "Build distance"},
                    ],
                },
                "layout": "full",
            },
        ],
        "tables": [
            {
                "id": "strategy_fun_table",
                "title": "Strategy strength and fun proxies",
                "subtitle": "Paired fixed-start runs; percentages are shown as percentage points.",
                "dataset": "strategies",
                "sourceId": "strategy_lab",
                "source": widget_source(
                    "strategy_lab",
                    "Paired strategy lab",
                    "strategies",
                    "SELECT strategy, win_rate, avg_heats_cleared, hand_entropy, dominant_hand, "
                    "dominant_hand_share, joker_active_play_rate, any_callout_play_rate, "
                    "final_play_clear_rate, close_clear_rate, build_identity_rate, "
                    "build_jaccard_distance, boss_hazard FROM strategies ORDER BY win_rate DESC",
                    "Review strategy strength and fun-proxy measures together.",
                ),
                "density": "comfortable",
                "defaultSort": {"field": "win_rate", "direction": "desc"},
                "columns": [
                    {"field": "strategy", "label": "Strategy", "type": "text"},
                    {"field": "win_rate", "label": "Clear H12", "format": "number", "unit": "%"},
                    {"field": "avg_heats_cleared", "label": "Avg Heats", "format": "number"},
                    {"field": "hand_entropy", "label": "Entropy", "format": "number"},
                    {"field": "dominant_hand", "label": "Dominant hand", "type": "text"},
                    {"field": "dominant_hand_share", "label": "Dominant share", "format": "number", "unit": "%"},
                    {"field": "joker_active_play_rate", "label": "Joker-active plays", "format": "number", "unit": "%"},
                    {"field": "any_callout_play_rate", "label": "Any callout", "format": "number", "unit": "%"},
                    {"field": "final_play_clear_rate", "label": "Final-play clears", "format": "number", "unit": "%"},
                    {"field": "close_clear_rate", "label": "Close clears", "format": "number", "unit": "%"},
                    {"field": "build_identity_rate", "label": "Build identity", "format": "number", "unit": "%"},
                    {"field": "build_jaccard_distance", "label": "Build distance", "format": "number"},
                    {"field": "boss_hazard", "label": "Boss hazard", "format": "number", "unit": "%"},
                ],
            }
        ],
        "sources": [
            {"id": "game_source", "label": game_source["label"], "path": game_source["path"]},
            {"id": "decision_lab", "label": decision_source["label"], "path": decision_source["path"]},
            {"id": "strategy_lab", "label": strategy_source["label"], "path": strategy_source["path"]},
        ],
        "blocks": [
            {"id": "title", "type": "markdown", "body": f"# {title}"},
            {"id": "executive_summary", "type": "markdown", "body": executive_summary},
            {
                "id": "opening_finding",
                "type": "markdown",
                "sourceId": "decision_lab",
                "body": f"""## Made hands beat raw ranks from the first deal

**The practical opening rule is simple: bank Pair-or-better; discard weak High Card.** On {decision['counts']['openingDeals']:,} paired initial deals, the tutorial's Copper Chip + Pair Polisher start averaged **{guided['avg_best_score']:.1f}** for the best immediate play and cleared the 90-point target immediately on **{pp(guided['one_play_clear_rate'])}**. With no boost those figures fell to **{no_boost_open['avg_best_score']:.1f}** and **{pp(no_boost_open['one_play_clear_rate'])}**.

Among normal single starters, **{best_single_open['configuration']}** produced the largest first-deal burst at **{best_single_open['avg_best_score']:.1f}**. That is an opening result, not yet the long-run recommendation.""",
            },
            {"id": "opening_chart_block", "type": "chart", "chartId": "opening_score"},
            {
                "id": "starter_finding",
                "type": "markdown",
                "sourceId": "decision_lab",
                "body": f"""## {best_starter_depth['starter']} gives the deepest starter-pool runs

**Use average run depth as the primary starter screen.** Heat-12 wins are rare in the ten-Joker starter shop pool, so the stable result is **{best_starter_depth['starter']} at {best_starter_depth['avg_heats_cleared']:.2f} average Heats cleared**. The highest observed win rate was {best_starter_win['starter']} at {pp(best_starter_win['win_rate'])}; small gaps should not be called decisive when Wilson intervals overlap.

The tutorial-only two-Joker start remains useful as a teaching safety net, but it should not be compared as a normal 6-coin choice.""",
            },
            {"id": "starter_chart_block", "type": "chart", "chartId": "starter_depth"},
            {
                "id": "strategy_finding",
                "type": "markdown",
                "sourceId": "strategy_lab",
                "body": f"""## {best_strategy['strategy']} and {runner_up_strategy['strategy']} are effectively tied

**{best_strategy['strategy']} cleared Heat 12 in {pp(best_strategy['win_rate'])} of {best_strategy['runs']:,} paired runs; {runner_up_strategy['strategy']} reached {pp(runner_up_strategy['win_rate'])}.** The {best_strategy['win_rate'] - runner_up_strategy['win_rate']:.1f}-point difference is not meaningful in the paired comparison (exact p={runner_pair['paired_p']:.3f}). This comparison is cleaner than the earlier strategy report because all policies begin with no free Joker.

Policy changed the win/loss outcome on **{pp(strategy['agency']['mixedOutcomeRate'])}** of paired seeds, while **{pp(strategy['agency']['universalLossRate'])}** were lost by every tested policy. Strategy therefore matters, but a meaningful share of runs remains seed-constrained.""",
            },
            {"id": "strategy_chart_block", "type": "chart", "chartId": "strategy_strength"},
            {
                "id": "fun_finding",
                "type": "markdown",
                "sourceId": "strategy_lab",
                "body": f"""## Fun sits between random soup and one-hand repetition

**Do not optimise only for win rate.** The working target is a recognisable engine with enough hand variety to keep decisions alive: normalized entropy around **0.65–0.85**, dominant-hand share around **25–45%** overall (up to 60% for a deliberate specialist), final-build Jaccard distance around **0.55–0.80**, and boss hazard around **35–55%**.

The observed sensible-strategy win-rate spread is **{sensible_spread:.1f} points**, but xMult stacking sits **{best_strategy['win_rate'] - next(row['win_rate'] for row in strategy_rows if row['strategy_id'] == 'xmult_stacking'):.1f} points** behind the leader and behaves like a trap. Major GREAT-or-higher callouts occur on roughly half of bot plays and any callout on more than four in five, so celebration is too common to feel special. Joker activity counts scoring-event triggers only, so economy and Heat-clear effects are understated.""",
            },
            {"id": "variety_chart_block", "type": "chart", "chartId": "strategy_variety"},
            {"id": "strategy_table_block", "type": "table", "tableId": "strategy_fun_table"},
            {
                "id": "recommendations",
                "type": "markdown",
                "body": """## Recommended next steps

1. **Teach the opening rule explicitly:** “Pair-or-better: play it. Weak High Card: discard and improve.” Keep the guided Copper + Polisher safety net.
2. **Default the starter recommendation to run depth, not one lucky clear.** Keep start prices separate from run power; review cost efficiency only after the strongest starter is statistically stable.
3. **Pull sensible build policies into a 5–15 point band.** Buff trap-like policies through better support and shop availability before nerfing the strongest readable engine.
4. **Keep scoring readable and make peaks rare:** normally 1–4 visible Joker beats per play, with p95 no higher than six. Major callouts should not appear on roughly half of all plays.
5. **Run a closed-test fun check:** ask pace, fairness and “which Joker just triggered?” after sampled hands. Target at least 80% correct Joker recall.""",
            },
            {
                "id": "further_questions",
                "type": "markdown",
                "body": """## Further questions

- Does the starter ranking hold when veteran shops include all 57 Jokers?
- Does a one-step lookahead card policy outperform immediate score without slowing player decisions?
- Which strategy gaps come from Joker balance versus the bot's supply and discard heuristics?
- Do real players understand 1–4 Joker beats, and where does comprehension collapse?""",
            },
            {
                "id": "caveats",
                "type": "markdown",
                "body": f"""## Caveats and assumptions

- The results are deterministic bot simulations from source SHA-256 `{decision['sourceSha256']}`, not player telemetry.
- “Best opening score” is immediate score. It does not prove that playing immediately beats discarding for future value.
- Strategy bots share an exhaustive immediate-score selector; they differ mostly in shop/build priorities and Pair/Flush discard weighting.
- Starter account-coin prices are not deducted from run coins, matching the game's separate account/run currencies.
- Affordable-choice shops mean at least two new offers could be afforded; the measure does not prove both were upgrades.
- Simulations can identify likely fun conditions but cannot prove enjoyment, comprehension or animation quality.""",
            },
        ],
    }

    artifact = {
        "surface": "report",
        "manifest": manifest,
        "snapshot": {
            "version": 1,
            "generatedAt": generated_at,
            "status": "ready",
            "datasets": {
                "opening": opening_rows,
                "starters": starter_rows,
                "strategies": strategy_rows,
                "guided_frontier": frontier_rows,
            },
        },
        "sources": [game_source, decision_source, strategy_source],
        "package_info": {
            "artifact_name": "wildcard-v6.9.13-strategy-fun-report",
            "source_sha256": decision["sourceSha256"],
            "snapshot_note": "Paired deterministic simulation snapshot; not a live connector.",
        },
    }

    ARTIFACT_PATH.parent.mkdir(parents=True, exist_ok=True)
    ARTIFACT_PATH.write_text(json.dumps(artifact, indent=2), encoding="utf-8")
    SUMMARY_PATH.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(ARTIFACT_PATH)
    print(SUMMARY_PATH)


if __name__ == "__main__":
    main()
