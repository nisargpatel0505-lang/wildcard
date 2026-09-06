"""Small, deterministic economy arithmetic helpers; no game or file mutation.

Saving paths resample a fixed cohort's per-run reward observations independently.
This is a fixed-collection scenario, not a simulated player career or prediction
of human play. There are no one-time gifts, ads, purchases or intervening spends.
Each path carries its wallet forward until the target can be afforded.

Run ``python saving_paths.py`` for small deterministic self-checks only.
"""

from __future__ import annotations

import math
import random
import statistics
from typing import Sequence


def _integer(value: int, name: str, *, minimum: int = 0) -> None:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        raise ValueError(f"{name} must be an integer >= {minimum}")


def _quantile_with_censoring(
    completed: list[int], total_paths: int, probability: float
) -> float | None:
    """Return an empirical quantile only when its required ranks are observed.

    All right-censored paths occur after every completed observation. A quantile
    involving any censored rank is unknown, rather than the run cap or a statistic
    conditional on completion. Interpolation uses the (n - 1) convention.
    """
    rank = (total_paths - 1) * probability
    low, high = math.floor(rank), math.ceil(rank)
    if high >= len(completed):
        return None
    return completed[low] + (completed[high] - completed[low]) * (rank - low)


def saving_paths(
    rewards: list[int],
    target: int,
    start_wallet: int = 0,
    paths: int = 5000,
    seed: int = 20260905,
    max_runs: int = 10000,
) -> dict[str, object]:
    """Estimate first-passage runs by independent empirical reward resampling.

    Rewards must be non-negative whole coins. ``medianRuns``, ``p10Runs`` and
    ``p90Runs`` refer to the whole sample, never only the successful paths.
    ``meanRuns`` is unknown if any path is censored by ``max_runs``; in that case
    ``meanRunsLowerBound`` is provided. An all-zero reward distribution is marked
    unreachable unless the starting wallet already covers the purchase.

    These percentiles describe variability within this resampling scenario.
    They are not confidence intervals and do not include uncertainty about the
    input reward distribution or changes in player skill/collection.
    """
    _integer(target, "target")
    _integer(start_wallet, "start_wallet")
    _integer(paths, "paths", minimum=1)
    _integer(max_runs, "max_runs", minimum=1)
    if max_runs > 10000:
        raise ValueError("max_runs cannot exceed the 10,000-run guard")
    if not rewards:
        raise ValueError("rewards must contain at least one observed run")
    for reward in rewards:
        _integer(reward, "reward")
    if isinstance(seed, bool) or not isinstance(seed, int):
        raise ValueError("seed must be an integer")

    result: dict[str, object] = {
        "targetCoins": target,
        "startWalletCoins": start_wallet,
        "paths": paths,
        "seed": seed,
        "maxRuns": max_runs,
        "inputRuns": len(rewards),
        "inputMeanReward": statistics.mean(rewards),
        "model": "fixed-collection independent empirical reward draws",
        "oneTimeRewardsAdsPurchasesIncluded": False,
        "unreachable": False,
        "completedPaths": 0,
        "censoredPaths": 0,
        "censoredFraction": 0.0,
        "meanRuns": None,
        "meanRunsLowerBound": None,
        "medianRuns": None,
        "p10Runs": None,
        "p90Runs": None,
    }
    if start_wallet >= target:
        result.update(
            completedPaths=paths,
            meanRuns=0.0,
            meanRunsLowerBound=0.0,
            medianRuns=0.0,
            p10Runs=0.0,
            p90Runs=0.0,
        )
        return result
    if not any(rewards):
        result["unreachable"] = True
        return result

    rng = random.Random(seed)
    completed: list[int] = []
    censored = 0
    for _ in range(paths):
        wallet = start_wallet
        for run in range(1, max_runs + 1):
            wallet += rewards[rng.randrange(len(rewards))]
            if wallet >= target:
                completed.append(run)
                break
        else:
            censored += 1

    completed.sort()
    result.update(
        completedPaths=len(completed),
        censoredPaths=censored,
        censoredFraction=censored / paths,
        meanRuns=statistics.mean(completed) if not censored else None,
        meanRunsLowerBound=(sum(completed) + censored * max_runs) / paths,
        medianRuns=_quantile_with_censoring(completed, paths, 0.5),
        p10Runs=_quantile_with_censoring(completed, paths, 0.1),
        p90Runs=_quantile_with_censoring(completed, paths, 0.9),
    )
    return result


def minimum_coin_pack_cost(
    target_coins: int,
    packs: Sequence[tuple[int, int]],
    start_wallet: int = 0,
) -> dict[str, object]:
    """Exact cheapest unlimited-pack plan, with prices supplied in integer pence.

    Each pack is ``(coin_quantity, price_pence)``. This arithmetic does not imply
    that the offers are active, available, desirable, or commercially optimal.
    Equal-cost solutions prefer fewer leftover coins, then fewer packs. The
    finite DP is bounded to 2 million states to prevent accidental large jobs.
    """
    _integer(target_coins, "target_coins")
    _integer(start_wallet, "start_wallet")
    if not packs:
        raise ValueError("packs must contain at least one offer")
    for quantity, price in packs:
        _integer(quantity, "pack coin quantity", minimum=1)
        _integer(price, "pack price in pence", minimum=1)
    needed = max(0, target_coins - start_wallet)
    if not needed:
        return {
            "targetCoins": target_coins,
            "startWalletCoins": start_wallet,
            "coinsPurchased": 0,
            "pricePence": 0,
            "leftoverCoins": start_wallet - target_coins,
            "packCounts": [0] * len(packs),
        }
    # Any purchase >= needed + largest pack contains a removable pack while
    # still covering the target; all prices are positive, so it cannot be best.
    upper = needed + max(quantity for quantity, _ in packs) - 1
    if upper + 1 > 2_000_000:
        raise ValueError("Requested pack plan exceeds the 2-million-state guard")
    best: list[tuple[int, int] | None] = [None] * (upper + 1)
    previous: list[tuple[int, int] | None] = [None] * (upper + 1)
    best[0] = (0, 0)
    for coins in range(upper + 1):
        current = best[coins]
        if current is None:
            continue
        for index, (quantity, price) in enumerate(packs):
            next_coins = coins + quantity
            if next_coins > upper:
                continue
            candidate = (current[0] + price, current[1] + 1)
            if best[next_coins] is None or candidate < best[next_coins]:
                best[next_coins] = candidate
                previous[next_coins] = (coins, index)
    purchased = min(
        (coins for coins in range(needed, upper + 1) if best[coins] is not None),
        key=lambda coins: (best[coins][0], coins, best[coins][1]),
    )
    counts = [0] * len(packs)
    cursor = purchased
    while cursor:
        prior = previous[cursor]
        assert prior is not None
        cursor, index = prior
        counts[index] += 1
    return {
        "targetCoins": target_coins,
        "startWalletCoins": start_wallet,
        "coinsPurchased": purchased,
        "pricePence": best[purchased][0],
        "leftoverCoins": start_wallet + purchased - target_coins,
        "packCounts": counts,
    }


def _self_checks() -> None:
    for rewards, target, wallet, expected in [
        ([50], 100, 0, 2),
        ([40], 100, 0, 3),
        ([40], 100, 60, 1),
        ([100], 100, 0, 1),
        ([0], 100, 100, 0),
    ]:
        result = saving_paths(rewards, target, wallet, paths=8)
        assert result["meanRuns"] == expected
        assert result["medianRuns"] == expected
        assert result["p10Runs"] == expected
        assert result["p90Runs"] == expected
        assert result["censoredPaths"] == 0
    unreachable = saving_paths([0, 0], 100, paths=8)
    assert unreachable["unreachable"] is True
    assert unreachable["meanRuns"] is None
    assert unreachable["medianRuns"] is None
    censored = saving_paths([1], 100, paths=8, max_runs=5)
    assert censored["unreachable"] is False
    assert censored["censoredPaths"] == 8
    assert censored["meanRuns"] is None
    assert censored["p90Runs"] is None
    assert censored["meanRunsLowerBound"] == 5
    assert saving_paths([0, 40, 100], 300, paths=32, seed=7) == saving_paths(
        [0, 40, 100], 300, paths=32, seed=7
    )
    packs = [(300, 99), (600, 179), (1500, 399)]
    for target, expected_cost, expected_coins in [
        (100, 99, 300),
        (7500, 1995, 7500),
        (9800, 2672, 9900),
        (10400, 2793, 10500),
        (11700, 3151, 11700),
    ]:
        result = minimum_coin_pack_cost(target, packs)
        assert result["pricePence"] == expected_cost
        assert result["coinsPurchased"] == expected_coins
    assert minimum_coin_pack_cost(100, packs, start_wallet=100)["pricePence"] == 0
    print("Saving-path and integer-pence pack-plan self-checks passed.")


if __name__ == "__main__":
    _self_checks()
