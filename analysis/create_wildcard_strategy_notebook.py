"""Build and execute the WILDCARD v6.9.13 strategy/fun analysis notebook."""

from __future__ import annotations

import json
import math
from pathlib import Path

import nbformat as nbf
from nbclient import NotebookClient


ROOT = Path(__file__).resolve().parents[1]
DECISION_PATH = ROOT / "docs" / "release" / "wildcard-v6.9.13-decision-lab-results.json"
STRATEGY_PATH = ROOT / "docs" / "release" / "wildcard-v6.9.13-strategy-results.json"
OUTPUT_PATH = ROOT / "analysis" / "wildcard-v6.9.13-strategy-fun-lab.ipynb"


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def pct(value: float) -> str:
    return f"{value:.1f}%"


def main() -> None:
    decision = load_json(DECISION_PATH)
    strategy = load_json(STRATEGY_PATH)
    if decision["sourceSha256"] != strategy["sourceSha256"]:
        raise RuntimeError("Decision and strategy results use different game source hashes")

    starter_rows = decision["starters"]["summaries"]
    strategy_rows = strategy["strategies"]
    best_starter_win = max(starter_rows, key=lambda row: (row["winRate"], row["avgCleared"]))
    best_starter_depth = max(starter_rows, key=lambda row: (row["avgCleared"], row["winRate"]))
    ranked_strategy_rows = sorted(
        strategy_rows, key=lambda row: (row["winRate"], row["avgCleared"]), reverse=True
    )
    best_strategy = ranked_strategy_rows[0]
    runner_up_strategy = ranked_strategy_rows[1]
    runner_pair = next(
        row
        for row in strategy["pairedAgainstBest"]
        if row["id"] == runner_up_strategy["id"]
    )
    discordant = runner_pair["bestOnly"] + runner_pair["strategyOnly"]
    if discordant:
        tail_n = min(runner_pair["bestOnly"], runner_pair["strategyOnly"])
        runner_p = min(
            1.0,
            2
            * sum(math.comb(discordant, index) for index in range(tail_n + 1))
            / (2**discordant),
        )
    else:
        runner_p = 1.0
    guided_open = next(
        row for row in decision["opening"]["summaries"] if row["id"] == "guided_copper_polish"
    )
    no_open = next(row for row in decision["opening"]["summaries"] if row["id"] == "none")

    notebook = nbf.v4.new_notebook()
    notebook.metadata["kernelspec"] = {
        "display_name": "Python 3",
        "language": "python",
        "name": "python3",
    }
    notebook.metadata["language_info"] = {"name": "python", "version": "3.12"}

    cells = []
    cells.append(
        nbf.v4.new_markdown_cell(
            f"""# WILDCARD v6.9.13 Strategy and Fun Lab

## tl;dr

- **Best opening rule:** on the guided first run, exhaustive enumeration clears the 90-point Heat 1 target in one play on {pct(guided_open['onePlayClearRate'])} of initial deals, versus {pct(no_open['onePlayClearRate'])} with no boost. Pair-or-better is the practical floor; High Card is normally a discard signal.
- **Starter result:** **{best_starter_depth['name']}** produced the deepest average run ({best_starter_depth['avgCleared']:.2f} Heats). The highest observed Heat-12 clear rate was **{best_starter_win['name']}** at {pct(best_starter_win['winRate'])}, but the paired confidence intervals decide whether that lead is meaningful.
- **Full-run strategy:** **{best_strategy['name']}** and **{runner_up_strategy['name']}** are effectively tied at {pct(best_strategy['winRate'])} and {pct(runner_up_strategy['winRate'])} (paired exact p={runner_p:.3f}). Strength is reviewed alongside hand entropy, build identity, Joker activity, dramatic clears and failure walls rather than collapsed into one “fun score.”
- **Scope:** {decision['counts']['openingDeals']:,} paired opening deals and {decision['counts']['fullRuns'] + strategy['counts']['fullRuns']:,} complete 12-Heat runs from the exact v6.9.13 source hash `{decision['sourceSha256']}`.
"""
        )
    )
    cells.append(
        nbf.v4.new_markdown_cell(
            """## Context & Methods

This notebook supports three product decisions: what a player should do with the first nine cards, which starter boost is strongest in the starter collection, and which full-run build policy is strongest without making play repetitive or opaque.

### Key Assumptions

- “Best opening” means the highest immediate legal score among useful one-to-five-card plays. It does **not** prove that playing immediately is better than discarding.
- Starter comparisons use the same adaptive shop bot, paired run seeds and the real ten-Joker starter shop pool. Account-coin starter prices are descriptive; they do not change run coins.
- Strategy comparisons use all 57 Jokers in shops, the same exhaustive immediate-score card selector and **no free start boost**. Differences mainly measure shop/build priorities plus Pair/Flush discard priorities.
- Fun is represented by separate proxies: hand variety, build identity, Joker activity, dramatic close clears, affordable shop choice and failure hazards. A bot cannot measure enjoyment.
"""
        )
    )
    cells.append(
        nbf.v4.new_code_cell(
            """from pathlib import Path
import json, math
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from IPython.display import display, Markdown

ROOT = Path.cwd()
DECISION_PATH = ROOT / "docs" / "release" / "wildcard-v6.9.13-decision-lab-results.json"
STRATEGY_PATH = ROOT / "docs" / "release" / "wildcard-v6.9.13-strategy-results.json"

decision = json.loads(DECISION_PATH.read_text(encoding="utf-8"))
strategy = json.loads(STRATEGY_PATH.read_text(encoding="utf-8"))

assert decision["version"] == "6.9.13"
assert strategy["version"] == "6.9.13"
assert decision["sourceSha256"] == strategy["sourceSha256"]
assert not decision["dataFailures"] and not decision["hookErrors"] and not decision["invariantFailures"]
assert not strategy["dataFailures"] and not strategy["hookErrors"] and not strategy["invariantFailures"]

SOURCE_SHA = decision["sourceSha256"]
TOTAL_FULL_RUNS = decision["counts"]["fullRuns"] + strategy["counts"]["fullRuns"]
print(f"Source SHA-256: {SOURCE_SHA}")
print(f"Opening deals: {decision['counts']['openingDeals']:,}")
print(f"Complete runs: {TOTAL_FULL_RUNS:,}")"""
        )
    )
    cells.append(nbf.v4.new_markdown_cell("## Data"))
    cells.append(
        nbf.v4.new_code_cell(
            """opening = pd.DataFrame(decision["opening"]["summaries"])
starters = pd.DataFrame([
    {
        "id": row["id"], "starter": row["name"], "cost": row["cost"],
        "win_rate": row["winRate"], "ci_low": row["winRate95"]["low"], "ci_high": row["winRate95"]["high"],
        "avg_cleared": row["avgCleared"], "reach_h9": row["reachByHeat"]["9"],
        "reach_h12": row["reachByHeat"]["12"], "boss_hazard": row["fun"]["bossHazard"],
        "entropy": row["fun"]["handEntropy"], "dominant_share": row["fun"]["dominantHandShare"],
        "active_play_rate": row["fun"]["jokerActivePlayRate"],
        "triggers_per_play": row["fun"]["jokerTriggerEventsPerPlay"],
        "notable_play_rate": row["fun"]["notablePlayRate"],
        "any_callout_play_rate": row["fun"]["anyCalloutPlayRate"],
        "final_play_clears": row["fun"]["finalPlayClearRate"],
        "close_clears": row["fun"]["closeClearRate"],
        "build_distance": row["fun"]["meanBuildJaccardDistance"],
    }
    for row in decision["starters"]["summaries"]
])
strategies = pd.DataFrame([
    {
        "id": row["id"], "strategy": row["name"], "win_rate": row["winRate"],
        "ci_low": row["winRate95"]["low"], "ci_high": row["winRate95"]["high"],
        "avg_cleared": row["avgCleared"], "reach_h9": row["reachH9"], "reach_h11": row["reachH11"],
        "entropy": row["fun"]["handEntropy"], "dominant_hand": row["fun"]["dominantHand"],
        "dominant_share": row["fun"]["dominantHandShare"],
        "active_play_rate": row["fun"]["jokerActivePlayRate"],
        "triggers_per_play": row["fun"]["jokerTriggerEventsPerPlay"],
        "notable_play_rate": row["fun"]["notablePlayRate"],
        "any_callout_play_rate": row["fun"]["anyCalloutPlayRate"],
        "final_play_clears": row["fun"]["finalPlayClearRate"],
        "close_clears": row["fun"]["closeClearRate"],
        "comeback_clears": row["fun"]["comebackClearRate"],
        "affordable_choice_shops": row["fun"]["meaningfulShopRate"],
        "dead_shops": row["fun"]["deadShopRate"],
        "build_distance": row["fun"]["meanBuildJaccardDistance"],
        "boss_hazard": row["fun"]["bossHazard"],
    }
    for row in strategy["strategies"]
])

display(opening[["name", "avgBestScore", "medianBestScore", "p90BestScore", "onePlayClearRate"]])
display(starters.sort_values(["avg_cleared", "win_rate"], ascending=False).head(12))
display(strategies.sort_values("win_rate", ascending=False))"""
        )
    )
    cells.append(nbf.v4.new_markdown_cell("## Results"))
    cells.append(
        nbf.v4.new_markdown_cell(
            """### The opening decision is about made-hand quality, not raw rank

The first chart compares the highest immediate score available from the same initial deals under each starter configuration. The guided two-Joker start is intentionally a tutorial-only arm.
"""
        )
    )
    cells.append(
        nbf.v4.new_code_cell(
            """plot_open = opening.sort_values("avgBestScore")
fig, ax = plt.subplots(figsize=(10, 6))
ax.barh(plot_open["name"], plot_open["avgBestScore"], color="#6f4bd8")
ax.axvline(90, color="#222222", linestyle="--", linewidth=1.5, label="Heat 1 target")
ax.set(title="Best immediate opening score", xlabel="Mean best score across paired initial deals", ylabel="")
ax.legend(frameon=False)
ax.grid(axis="x", alpha=.2)
plt.tight_layout()
plt.show()

frontier = pd.DataFrame(decision["opening"]["guidedHandFrontier"]).T
frontier.index.name = "hand_type"
frontier = frontier.reset_index().sort_values("conditionalAvgBestScore", ascending=False)
display(frontier)"""
        )
    )
    cells.append(
        nbf.v4.new_markdown_cell(
            """### Starter strength should be judged by depth as well as rare wins

Heat-12 clears are uncommon in the starter-only shop pool, so average Heats cleared and reach to the boss are more stable screening measures than win rate alone.
"""
        )
    )
    cells.append(
        nbf.v4.new_code_cell(
            """plot_starters = starters.sort_values("avg_cleared")
fig, ax = plt.subplots(figsize=(10, 6))
ax.barh(plot_starters["starter"], plot_starters["avg_cleared"], color="#d8a53a")
ax.set(title="Starter boost run depth", xlabel="Average Heats cleared over paired full runs", ylabel="")
ax.grid(axis="x", alpha=.2)
plt.tight_layout()
plt.show()"""
        )
    )
    cells.append(
        nbf.v4.new_markdown_cell(
            """### Strategy strength and variety are separate axes

All strategies below start with no free Joker. The scatter shows why the strongest build policy is not automatically the most enjoyable: specialist engines can win while compressing most plays into one hand type.
"""
        )
    )
    cells.append(
        nbf.v4.new_code_cell(
            """fig, ax = plt.subplots(figsize=(10, 6))
sizes = 40 + strategies["active_play_rate"] * 2
ax.scatter(strategies["entropy"], strategies["win_rate"], s=sizes, color="#2db9a3", edgecolor="#1b1b1b", alpha=.85)
for _, row in strategies.iterrows():
    ax.annotate(row["strategy"], (row["entropy"], row["win_rate"]), xytext=(5, 4), textcoords="offset points", fontsize=8)
ax.axvspan(.65, .85, color="#d8a53a", alpha=.10, label="Working hand-diversity range")
ax.set(title="Strategy clear rate and hand diversity", xlabel="Normalized hand-type entropy", ylabel="Clear Heat 12 (%)")
ax.grid(alpha=.2)
ax.legend(frameon=False)
plt.tight_layout()
plt.show()

display(strategies.sort_values("win_rate", ascending=False)[[
    "strategy", "win_rate", "ci_low", "ci_high", "avg_cleared", "entropy",
    "dominant_hand", "dominant_share", "active_play_rate", "triggers_per_play",
    "notable_play_rate", "any_callout_play_rate", "final_play_clears",
    "close_clears", "build_distance", "boss_hazard"
]])"""
        )
    )
    cells.append(
        nbf.v4.new_markdown_cell(
            """### Paired uncertainty checks

Wilson intervals describe each arm. Exact paired sign tests below use only discordant win/loss seeds, which is the correct comparison for shared seeds.
"""
        )
    )
    cells.append(
        nbf.v4.new_code_cell(
            """def exact_two_sided_binomial(discordant_a: int, discordant_b: int) -> float:
    n = discordant_a + discordant_b
    if n == 0:
        return 1.0
    k = min(discordant_a, discordant_b)
    tail = sum(math.comb(n, i) for i in range(k + 1)) / (2 ** n)
    return min(1.0, 2 * tail)

strategy_pairs = pd.DataFrame(strategy["pairedAgainstBest"])
strategy_pairs["discordant"] = strategy_pairs["bestOnly"] + strategy_pairs["strategyOnly"]
strategy_pairs["paired_p"] = strategy_pairs.apply(
    lambda row: exact_two_sided_binomial(int(row["bestOnly"]), int(row["strategyOnly"])), axis=1
)
starter_pairs = pd.DataFrame(decision["starters"]["pairedAgainstBest"])
starter_pairs["discordant"] = starter_pairs["bestOnly"] + starter_pairs["armOnly"]
starter_pairs["paired_p"] = starter_pairs.apply(
    lambda row: exact_two_sided_binomial(int(row["bestOnly"]), int(row["armOnly"])), axis=1
)
display(strategy_pairs)
display(starter_pairs)"""
        )
    )
    cells.append(
        nbf.v4.new_markdown_cell(
            """### Build identity and fun guardrails

Engine identity means a final build has at least two pieces from one engine and that engine leads the next-best family by at least one piece. These are working design guardrails, not universal laws.
"""
        )
    )
    cells.append(
        nbf.v4.new_code_cell(
            """ENGINE_SETS = {
    "pair_rank": {"polish", "trainer", "copper", "presser", "retainer", "even", "acemag", "lowball", "inktrade", "triple3", "number_station", "frequency_meter"},
    "flush_colour": {"flushfund", "uniform", "pocketflush", "color_wash", "prism_lens", "presser", "inktrade", "tailor"},
    "economy": {"dividend", "piggy", "miser", "dumpster"},
    "xmult": {"roller", "lastcall", "couple", "sniper", "boostfiend", "modded", "survivor", "doubledown", "allin", "redline", "master_class", "danger_music", "prism_lens", "glass_joystick"},
    "utility": {"royalscam", "lucky7", "shortcut", "pocketflush", "cheat", "tailor", "collector", "printer", "cleaner", "guillotine"},
}

def has_engine_identity(final_jokers):
    build = set(final_jokers)
    scores = sorted((len(build & members), name) for name, members in ENGINE_SETS.items())[::-1]
    top, second = scores[0][0], scores[1][0]
    return top >= 2 and top - second >= 1

identity_rows = []
for row in strategy["strategies"]:
    identities = [has_engine_identity(outcome["finalJokers"]) for outcome in row["outcomes"]]
    identity_rows.append({"strategy": row["name"], "build_identity_rate": 100 * np.mean(identities)})
identity = pd.DataFrame(identity_rows).sort_values("build_identity_rate", ascending=False)
display(identity)

guardrails = pd.DataFrame([
    ["Hand diversity", "Normalized Shannon entropy", "0.65–0.85 overall"],
    ["Dominant hand", "Largest hand share", "25–45%; up to 60% specialist"],
    ["Build variety", "Mean final-build Jaccard distance", "0.55–0.80"],
    ["Build identity", "Late builds with a clear ≥2-piece engine", "60–85%"],
    ["Joker activity", "Plays with ≥1 scoring Joker event", "55–80% after early game"],
    ["Callout frequency", "Plays at NICE-or-higher / GREAT-or-higher", "Keep major moments uncommon"],
    ["Final-play clears", "Clears scored with one play left", "15–30%"],
    ["Close clears", "Winning margin ≤10% of target", "20–40%"],
    ["Boss hazard", "Heat-12 failures / runs reaching Heat 12", "35–55%"],
    ["Strong-strategy spread", "Best vs other sensible archetypes", "5–15 points"],
], columns=["area", "definition", "working_range"])
display(guardrails)"""
        )
    )
    cells.append(
        nbf.v4.new_markdown_cell(
            f"""## Takeaways

1. **Teach Pair-or-better, not “play the highest cards.”** The guided opening frontier shows a large score step from High Card to Pair, then another from Pair to Two Pair. A weak High Card should normally be discarded; made hands should normally be banked.
2. **Separate opening burst from full-run value.** Opening Act, Full Table and Pair Polisher can lead the first-deal score table, but the paired 12-Heat comparison determines the durable starter recommendation.
3. **Use the fixed-start strategy result—and treat the top two as tied.** The old report gave different bots different free premium Jokers. This notebook uses no free starter for every strategy, making the comparison substantially cleaner.
4. **Tune toward coherent variety.** A strong engine should be recognisable without forcing one hand type on nearly every play. The useful target is a specialist with clear identity, entropy around 0.65–0.85 and a best-versus-sensible-strategy gap around 5–15 points.
5. **Confirm fun with people.** Closed testers should rate pace and fairness and answer “which Joker just triggered?” Target at least 80% correct trigger recall; simulation cannot verify comprehension.

### Validation status

Both simulation artifacts use the same v6.9.13 source hash, paired deterministic seeds, and report zero data/scoring failures, hook errors and run invariant failures. Conclusions remain **simulation evidence**, not player telemetry or causal proof of enjoyment.
"""
        )
    )

    notebook["cells"] = cells
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_PATH.open("w", encoding="utf-8") as handle:
        nbf.write(notebook, handle)

    with OUTPUT_PATH.open("r", encoding="utf-8") as handle:
        executable = nbf.read(handle, as_version=4)
    client = NotebookClient(
        executable,
        timeout=600,
        kernel_name="python3",
        resources={"metadata": {"path": str(ROOT)}},
    )
    client.execute(cwd=str(ROOT))
    with OUTPUT_PATH.open("w", encoding="utf-8") as handle:
        nbf.write(executable, handle)
    print(OUTPUT_PATH)


if __name__ == "__main__":
    main()
