#!/usr/bin/env python3
"""Deterministic WILDCARD v8.4 account-economy collection simulator.

This is a meta-economy model, not a gameplay bot. It converts an externally
measured run-depth summary into account-coin income, then follows a rational
collection plan:

1. claim the current tutorial starter gift;
2. optionally claim the current first-loss Joker;
3. unlock every remaining non-WILD Joker through no-duplicate Wooden Vaults;
4. unlock the remaining WILD Jokers through Gold Vaults; and
5. buy the remaining cosmetics at their direct listed prices.

The chest plan mirrors the Flutter rules in ``lib/domain/economy.dart``:

* Wood costs 60 only while the public owned-Joker count is below 15, otherwise
  100. A 10-starter account therefore receives five discounted opens, or four
  after the current first-loss Joker. The old v8.3 script incorrectly granted
  fifteen discounted opens.
* Wood has zero WILD weight. Its available non-WILD tiers renormalize as tiers
  empty, so it can deterministically finish the entire non-WILD pool.
* Gold costs 300. Waiting until only WILD Jokers remain makes its effective
  no-duplicate odds 100% WILD.

No smart-bot results are embedded here. The default run depths are explicitly
PROVISIONAL planning inputs. Supply a measured JSON summary with
``--depth-summary`` once the real strategic Flutter harness has completed.

Expected depth-summary shape (histograms are preferred):

.. code-block:: json

  {
    "profiles": {
      "casual": {
        "runs_per_day": 2,
        "terminal_heat_histogram": {"6": 20, "7": 35, "8": 30, "12": 15}
      },
      "dedicated": {
        "runs_per_day": 8,
        "terminal_heat_histogram": {"8": 10, "9": 25, "10": 30, "12": 35}
      }
    }
  }

Instead of a histogram, a profile can provide ``mean_heats_cleared`` and
``win_rate``. A nested ``post_collection`` object can provide improved depth
after the Joker collection is complete. Accepted histogram aliases are
``terminalHeatHistogram`` and ``histogram``.

The simulation intentionally excludes paid coin packs, stakes, Daily Board
prizes (currently inactive), and the randomized Cosmetic Vault. It includes
heat-clear rewards, the standard Heat-12 completion bonus, the exact daily
login streak curve, an expected weekly-mission value, gradually realized
one-time achievements, and the shared rewarded-ad cap.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence


RARITIES = ("common", "uncommon", "rare", "wild")

# Intended final percentile split for 102 public Jokers:
# top 8 WILD, next 20 Rare, next 32 Uncommon, remaining 42 Common.
DEFAULT_RARITY_COUNTS = {
    "common": 42,
    "uncommon": 32,
    "rare": 20,
    "wild": 8,
}
DEFAULT_STARTER_RARITY_COUNTS = {
    "common": 8,
    "uncommon": 2,
    "rare": 0,
    "wild": 0,
}

PUBLIC_JOKERS = 102
STARTER_JOKERS = 10
WOOD_NEWCOMER_PRICE = 60
WOOD_BASE_PRICE = 100
WOOD_NEWCOMER_OWNED_THRESHOLD = 15
GOLD_PRICE = 300

REWARDED_COIN_AMOUNT = 25
REWARDED_DAILY_CAP = 5
STANDARD_COMPLETION_BONUS = 10
STARTER_GIFT_COINS = 200
ACHIEVEMENT_REWARDS_TOTAL = 2797

DAILY_LOGIN_BASE = 30
DAILY_LOGIN_STEP = 18
DAILY_LOGIN_CAP = 192

# Three missions are drawn without replacement from rewards
# [200, 150, 150, 400, 300, 200]. Their expected sum is 700.
VISIBLE_WEEKLY_MISSIONS_EXPECTED_REWARD = 700.0

DEFAULT_TABLES_TOTAL = 18_050
DEFAULT_THEMES_TOTAL = 35_500
DEFAULT_SLY_TOTAL = 19_100


def account_reward(heat: int) -> int:
    """Account coins granted for clearing one Heat."""

    return 2 + heat // 3


CUMULATIVE_HEAT_REWARDS = [0]
for _heat in range(1, 13):
    CUMULATIVE_HEAT_REWARDS.append(
        CUMULATIVE_HEAT_REWARDS[-1] + account_reward(_heat)
    )


@dataclass(frozen=True)
class DepthEstimate:
    """Expected run performance supplied by a measured or provisional source."""

    mean_heats_cleared: float
    win_rate: float
    source: str
    histogram: dict[int, float] | None = None

    @property
    def account_coins_per_run(self) -> float:
        if self.histogram:
            total_weight = sum(self.histogram.values())
            if total_weight <= 0:
                raise ValueError("terminal Heat histogram must have positive weight")
            total = 0.0
            for heat, weight in self.histogram.items():
                cleared = max(0, min(12, int(heat)))
                reward = CUMULATIVE_HEAT_REWARDS[cleared]
                if cleared == 12:
                    reward += STANDARD_COMPLETION_BONUS
                total += reward * weight
            return total / total_weight

        lower = max(0, min(12, math.floor(self.mean_heats_cleared)))
        upper = max(0, min(12, math.ceil(self.mean_heats_cleared)))
        fraction = self.mean_heats_cleared - lower
        heat_reward = (
            CUMULATIVE_HEAT_REWARDS[lower] * (1.0 - fraction)
            + CUMULATIVE_HEAT_REWARDS[upper] * fraction
        )
        return heat_reward + self.win_rate * STANDARD_COMPLETION_BONUS


@dataclass(frozen=True)
class PlayerProfile:
    name: str
    runs_per_day: int
    before_collection: DepthEstimate
    after_collection: DepthEstimate
    weekly_completion_rate: float
    achievement_fraction: float
    achievement_realization_days: int


@dataclass(frozen=True)
class JokerSink:
    public_jokers: int
    starter_jokers: int
    free_joker_rarity: str | None
    locked_nonwild_after_free: int
    locked_wild_after_free: int
    discounted_wood_opens: int
    regular_wood_opens: int
    gold_opens: int
    wood_cost: int
    gold_cost: int
    total_cost: int
    purchase_prices: tuple[int, ...]


@dataclass(frozen=True)
class SimulationResult:
    profile: str
    ads: bool
    runs_per_day: int
    account_coins_per_run_before: float
    account_coins_per_run_after: float
    joker_collection_day: int | None
    full_collection_day: int | None
    total_sink: int
    total_income_at_completion: float
    ad_income_at_completion: float
    daily_login_income_at_completion: float
    weekly_income_at_completion: float
    achievement_income_at_completion: float
    unspent_coins: float


def parse_rarity_counts(value: str) -> dict[str, int]:
    """Parse ``common=42,uncommon=32,rare=20,wild=8``."""

    result = {rarity: 0 for rarity in RARITIES}
    if not value.strip():
        raise argparse.ArgumentTypeError("rarity counts cannot be empty")
    for raw_item in value.split(","):
        item = raw_item.strip()
        if "=" not in item:
            raise argparse.ArgumentTypeError(
                f"invalid rarity item {item!r}; expected name=count"
            )
        raw_name, raw_count = item.split("=", 1)
        name = raw_name.strip().lower()
        if name not in result:
            raise argparse.ArgumentTypeError(
                f"unknown rarity {name!r}; expected one of {', '.join(RARITIES)}"
            )
        try:
            count = int(raw_count)
        except ValueError as error:
            raise argparse.ArgumentTypeError(
                f"invalid count for {name}: {raw_count!r}"
            ) from error
        if count < 0:
            raise argparse.ArgumentTypeError(f"{name} count cannot be negative")
        result[name] = count
    return result


def _validate_collection_inputs(
    *,
    public_jokers: int,
    starter_jokers: int,
    rarity_counts: Mapping[str, int],
    starter_rarity_counts: Mapping[str, int],
) -> None:
    if public_jokers <= 0:
        raise ValueError("public Joker count must be positive")
    if starter_jokers < 0 or starter_jokers > public_jokers:
        raise ValueError("starter Joker count must be within the public catalogue")
    if sum(rarity_counts.values()) != public_jokers:
        raise ValueError(
            "rarity counts sum to "
            f"{sum(rarity_counts.values())}, expected {public_jokers}"
        )
    if sum(starter_rarity_counts.values()) != starter_jokers:
        raise ValueError(
            "starter rarity counts sum to "
            f"{sum(starter_rarity_counts.values())}, expected {starter_jokers}"
        )
    for rarity in RARITIES:
        if starter_rarity_counts[rarity] > rarity_counts[rarity]:
            raise ValueError(
                f"starter {rarity} count exceeds the public {rarity} count"
            )


def build_joker_sink(
    *,
    public_jokers: int,
    starter_jokers: int,
    rarity_counts: Mapping[str, int],
    starter_rarity_counts: Mapping[str, int],
    free_joker_rarity: str | None,
) -> JokerSink:
    """Return the exact cheapest no-duplicate chest purchase sequence."""

    _validate_collection_inputs(
        public_jokers=public_jokers,
        starter_jokers=starter_jokers,
        rarity_counts=rarity_counts,
        starter_rarity_counts=starter_rarity_counts,
    )
    locked = {
        rarity: rarity_counts[rarity] - starter_rarity_counts[rarity]
        for rarity in RARITIES
    }
    owned = starter_jokers
    applied_free_rarity: str | None = None
    if free_joker_rarity is not None:
        if free_joker_rarity not in RARITIES:
            raise ValueError(f"unknown free Joker rarity: {free_joker_rarity}")
        if locked[free_joker_rarity] <= 0:
            raise ValueError(
                f"cannot grant a free {free_joker_rarity} Joker: none are locked"
            )
        locked[free_joker_rarity] -= 1
        owned += 1
        applied_free_rarity = free_joker_rarity

    locked_nonwild = sum(locked[rarity] for rarity in RARITIES[:-1])
    locked_wild = locked["wild"]
    discounted_wood_opens = min(
        locked_nonwild,
        max(0, WOOD_NEWCOMER_OWNED_THRESHOLD - owned),
    )
    regular_wood_opens = locked_nonwild - discounted_wood_opens
    wood_cost = (
        discounted_wood_opens * WOOD_NEWCOMER_PRICE
        + regular_wood_opens * WOOD_BASE_PRICE
    )
    gold_cost = locked_wild * GOLD_PRICE
    purchase_prices = (
        (WOOD_NEWCOMER_PRICE,) * discounted_wood_opens
        + (WOOD_BASE_PRICE,) * regular_wood_opens
        + (GOLD_PRICE,) * locked_wild
    )
    return JokerSink(
        public_jokers=public_jokers,
        starter_jokers=starter_jokers,
        free_joker_rarity=applied_free_rarity,
        locked_nonwild_after_free=locked_nonwild,
        locked_wild_after_free=locked_wild,
        discounted_wood_opens=discounted_wood_opens,
        regular_wood_opens=regular_wood_opens,
        gold_opens=locked_wild,
        wood_cost=wood_cost,
        gold_cost=gold_cost,
        total_cost=wood_cost + gold_cost,
        purchase_prices=purchase_prices,
    )


def daily_login_reward(day: int) -> int:
    """Exact reward for a player who claims on every consecutive day."""

    return min(
        DAILY_LOGIN_CAP,
        DAILY_LOGIN_BASE + DAILY_LOGIN_STEP * max(0, day - 1),
    )


def optimal_daily_ad_income(runs_per_day: int, per_run_coins: float) -> float:
    """Best use of the shared five-view cap.

    Five direct +25 placements are the baseline. A player replaces a direct
    placement with a run-double placement only when the run earned more than
    25 account coins.
    """

    direct_baseline = REWARDED_DAILY_CAP * REWARDED_COIN_AMOUNT
    replaceable = min(max(0, runs_per_day), REWARDED_DAILY_CAP)
    return direct_baseline + replaceable * max(
        0.0, per_run_coins - REWARDED_COIN_AMOUNT
    )


def _depth_from_mapping(
    raw: Mapping[str, Any],
    *,
    fallback: DepthEstimate,
    source_label: str,
) -> DepthEstimate:
    histogram_raw = (
        raw.get("terminal_heat_histogram")
        or raw.get("terminalHeatHistogram")
        or raw.get("histogram")
    )
    if isinstance(histogram_raw, Mapping):
        histogram: dict[int, float] = {}
        for raw_heat, raw_weight in histogram_raw.items():
            heat = int(raw_heat)
            weight = float(raw_weight)
            if heat < 0 or heat > 12 or weight < 0:
                raise ValueError(
                    "terminal Heat histograms require Heat 0..12 and "
                    "non-negative weights"
                )
            histogram[heat] = histogram.get(heat, 0.0) + weight
        total = sum(histogram.values())
        if total <= 0:
            raise ValueError("terminal Heat histogram has no positive samples")
        mean = sum(heat * weight for heat, weight in histogram.items()) / total
        win_rate = histogram.get(12, 0.0) / total
        return DepthEstimate(
            mean_heats_cleared=mean,
            win_rate=win_rate,
            source=f"{source_label}: measured histogram",
            histogram=histogram,
        )

    mean = float(
        raw.get(
            "mean_heats_cleared",
            raw.get("expected_heats_cleared", fallback.mean_heats_cleared),
        )
    )
    win_rate = float(raw.get("win_rate", fallback.win_rate))
    if not 0 <= mean <= 12:
        raise ValueError("mean_heats_cleared must be within 0..12")
    if not 0 <= win_rate <= 1:
        raise ValueError("win_rate must be within 0..1")
    return DepthEstimate(
        mean_heats_cleared=mean,
        win_rate=win_rate,
        source=f"{source_label}: supplied aggregate",
    )


def default_profiles() -> dict[str, PlayerProfile]:
    """Planning defaults, deliberately not described as bot measurements."""

    casual_depth = DepthEstimate(
        mean_heats_cleared=7.5,
        win_rate=0.03,
        source="PROVISIONAL input (replace with strategic-harness JSON)",
    )
    dedicated_depth = DepthEstimate(
        mean_heats_cleared=9.5,
        win_rate=0.18,
        source="PROVISIONAL input (replace with strategic-harness JSON)",
    )
    return {
        "casual": PlayerProfile(
            name="casual",
            runs_per_day=2,
            before_collection=casual_depth,
            after_collection=casual_depth,
            weekly_completion_rate=0.45,
            achievement_fraction=0.75,
            achievement_realization_days=120,
        ),
        "dedicated": PlayerProfile(
            name="dedicated",
            runs_per_day=8,
            before_collection=dedicated_depth,
            after_collection=dedicated_depth,
            weekly_completion_rate=0.90,
            achievement_fraction=0.95,
            achievement_realization_days=60,
        ),
    }


def load_profiles(path: Path | None) -> dict[str, PlayerProfile]:
    defaults = default_profiles()
    if path is None:
        return defaults
    raw_root = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw_root, Mapping):
        raise ValueError("depth summary must be a JSON object")
    raw_profiles = raw_root.get("profiles", raw_root)
    if not isinstance(raw_profiles, Mapping):
        raise ValueError("depth summary 'profiles' must be a JSON object")

    result: dict[str, PlayerProfile] = {}
    for name in ("casual", "dedicated"):
        fallback = defaults[name]
        raw = raw_profiles.get(name)
        if raw is None:
            result[name] = fallback
            continue
        if not isinstance(raw, Mapping):
            raise ValueError(f"profile {name!r} must be a JSON object")
        before_raw = raw.get("before_collection", raw.get("before", raw))
        if not isinstance(before_raw, Mapping):
            raise ValueError(f"profile {name!r} before_collection is invalid")
        before = _depth_from_mapping(
            before_raw,
            fallback=fallback.before_collection,
            source_label=str(path),
        )
        after_raw = raw.get("post_collection", raw.get("after_collection"))
        after = (
            _depth_from_mapping(
                after_raw,
                fallback=before,
                source_label=str(path),
            )
            if isinstance(after_raw, Mapping)
            else before
        )
        runs = int(raw.get("runs_per_day", fallback.runs_per_day))
        weekly_rate = float(
            raw.get("weekly_completion_rate", fallback.weekly_completion_rate)
        )
        achievement_fraction = float(
            raw.get("achievement_fraction", fallback.achievement_fraction)
        )
        achievement_days = int(
            raw.get(
                "achievement_realization_days",
                fallback.achievement_realization_days,
            )
        )
        if runs < 0:
            raise ValueError("runs_per_day cannot be negative")
        if not 0 <= weekly_rate <= 1:
            raise ValueError("weekly_completion_rate must be within 0..1")
        if not 0 <= achievement_fraction <= 1:
            raise ValueError("achievement_fraction must be within 0..1")
        if achievement_days <= 0:
            raise ValueError("achievement_realization_days must be positive")
        result[name] = PlayerProfile(
            name=name,
            runs_per_day=runs,
            before_collection=before,
            after_collection=after,
            weekly_completion_rate=weekly_rate,
            achievement_fraction=achievement_fraction,
            achievement_realization_days=achievement_days,
        )
    return result


def simulate_collection(
    *,
    profile: PlayerProfile,
    ads: bool,
    joker_sink: JokerSink,
    cosmetic_sink: int,
    max_days: int,
    daily_login: bool,
) -> SimulationResult:
    """Run the expected-value day ledger and spend in fixed priority order."""

    balance = float(STARTER_GIFT_COINS)
    joker_index = 0
    cosmetic_spent = 0.0
    joker_day: int | None = None
    full_day: int | None = None
    total_income = float(STARTER_GIFT_COINS)
    total_ad_income = 0.0
    total_login_income = 0.0
    total_weekly_income = 0.0
    total_achievement_income = 0.0
    achievement_pool = (
        ACHIEVEMENT_REWARDS_TOTAL * profile.achievement_fraction
    )
    achievement_per_day = achievement_pool / profile.achievement_realization_days

    for day in range(1, max_days + 1):
        jokers_complete = joker_index >= len(joker_sink.purchase_prices)
        depth = (
            profile.after_collection
            if jokers_complete
            else profile.before_collection
        )
        per_run = depth.account_coins_per_run
        run_income = profile.runs_per_day * per_run
        login_income = float(daily_login_reward(day)) if daily_login else 0.0
        ad_income = (
            optimal_daily_ad_income(profile.runs_per_day, per_run) if ads else 0.0
        )
        weekly_income = (
            VISIBLE_WEEKLY_MISSIONS_EXPECTED_REWARD
            * profile.weekly_completion_rate
            if day % 7 == 0
            else 0.0
        )
        achievement_income = (
            achievement_per_day
            if day <= profile.achievement_realization_days
            else 0.0
        )
        income = (
            run_income
            + login_income
            + ad_income
            + weekly_income
            + achievement_income
        )
        balance += income
        total_income += income
        total_ad_income += ad_income
        total_login_income += login_income
        total_weekly_income += weekly_income
        total_achievement_income += achievement_income

        while joker_index < len(joker_sink.purchase_prices):
            price = joker_sink.purchase_prices[joker_index]
            if balance + 1e-9 < price:
                break
            balance -= price
            joker_index += 1
        if joker_index >= len(joker_sink.purchase_prices) and joker_day is None:
            joker_day = day

        if joker_day is not None and cosmetic_spent < cosmetic_sink:
            spend = min(balance, cosmetic_sink - cosmetic_spent)
            balance -= spend
            cosmetic_spent += spend
            if cosmetic_spent + 1e-9 >= cosmetic_sink:
                full_day = day
                break

    before = profile.before_collection.account_coins_per_run
    after = profile.after_collection.account_coins_per_run
    return SimulationResult(
        profile=profile.name,
        ads=ads,
        runs_per_day=profile.runs_per_day,
        account_coins_per_run_before=before,
        account_coins_per_run_after=after,
        joker_collection_day=joker_day,
        full_collection_day=full_day,
        total_sink=joker_sink.total_cost + cosmetic_sink,
        total_income_at_completion=total_income,
        ad_income_at_completion=total_ad_income,
        daily_login_income_at_completion=total_login_income,
        weekly_income_at_completion=total_weekly_income,
        achievement_income_at_completion=total_achievement_income,
        unspent_coins=balance,
    )


def _steady_daily_income(
    profile: PlayerProfile,
    *,
    ads: bool,
    daily_login: bool,
) -> float:
    per_run = profile.after_collection.account_coins_per_run
    result = (
        profile.runs_per_day * per_run
        + (DAILY_LOGIN_CAP if daily_login else 0)
        + VISIBLE_WEEKLY_MISSIONS_EXPECTED_REWARD
        * profile.weekly_completion_rate
        / 7
    )
    if ads:
        result += optimal_daily_ad_income(profile.runs_per_day, per_run)
    return result


def recommended_sink_range(
    profiles: Mapping[str, PlayerProfile],
    *,
    daily_login: bool,
) -> dict[str, Any]:
    """Find the total-sink overlap for two explicit collection-time goals."""

    casual_daily = _steady_daily_income(
        profiles["casual"],
        ads=True,
        daily_login=daily_login,
    )
    dedicated_daily = _steady_daily_income(
        profiles["dedicated"],
        ads=True,
        daily_login=daily_login,
    )
    # Broad collection goals, not item-level price recommendations.
    casual_interval = (casual_daily * 180, casual_daily * 365)
    dedicated_interval = (dedicated_daily * 120, dedicated_daily * 180)
    low = max(casual_interval[0], dedicated_interval[0])
    high = min(casual_interval[1], dedicated_interval[1])
    feasible = low <= high
    if not feasible:
        # Preserve both constraints in the report rather than inventing a price.
        return {
            "feasible_overlap": False,
            "recommended_min": None,
            "recommended_max": None,
            "casual_target_interval": [
                round(casual_interval[0]),
                round(casual_interval[1]),
            ],
            "dedicated_target_interval": [
                round(dedicated_interval[0]),
                round(dedicated_interval[1]),
            ],
            "basis": (
                "No common total sink satisfies both ad-engaged goals: "
                "casual 180-365 days and dedicated 120-180 days."
            ),
        }
    return {
        "feasible_overlap": True,
        "recommended_min": int(math.ceil(low / 1000) * 1000),
        "recommended_max": int(math.floor(high / 1000) * 1000),
        "casual_target_interval": [
            round(casual_interval[0]),
            round(casual_interval[1]),
        ],
        "dedicated_target_interval": [
            round(dedicated_interval[0]),
            round(dedicated_interval[1]),
        ],
        "basis": (
            "Combined account-coin sink supporting ad-engaged collection goals: "
            "casual 180-365 days and dedicated 120-180 days. Uses steady-state "
            f"income {'with' if daily_login else 'without'} daily login and "
            "excludes one-time achievements."
        ),
    }


def _jsonable_joker_sink(sink: JokerSink) -> dict[str, Any]:
    data = asdict(sink)
    data.pop("purchase_prices", None)
    return data


def _jsonable_depth(depth: DepthEstimate) -> dict[str, Any]:
    return {
        "mean_heats_cleared": depth.mean_heats_cleared,
        "win_rate": depth.win_rate,
        "source": depth.source,
        "account_coins_per_run": depth.account_coins_per_run,
        "terminal_heat_histogram": (
            {str(heat): weight for heat, weight in sorted(depth.histogram.items())}
            if depth.histogram
            else None
        ),
    }


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    rarity_counts = args.rarity_counts
    starter_rarity_counts = args.starter_rarity_counts
    free_rarity = None if args.free_joker_rarity == "none" else args.free_joker_rarity
    joker_sink = build_joker_sink(
        public_jokers=args.public_jokers,
        starter_jokers=args.starter_jokers,
        rarity_counts=rarity_counts,
        starter_rarity_counts=starter_rarity_counts,
        free_joker_rarity=free_rarity,
    )
    profiles = load_profiles(args.depth_summary)
    cosmetic_sink = args.tables_total + args.themes_total + args.sly_total
    simulations: dict[str, dict[str, Any]] = {}
    for name, profile in profiles.items():
        simulations[name] = {}
        for ads in (False, True):
            result = simulate_collection(
                profile=profile,
                ads=ads,
                joker_sink=joker_sink,
                cosmetic_sink=cosmetic_sink,
                max_days=args.max_days,
                daily_login=not args.no_daily_login,
            )
            simulations[name]["with_ads" if ads else "without_ads"] = asdict(
                result
            )

    assumptions = [
        (
            "Gameplay depth is measured only when --depth-summary supplies a "
            "histogram; otherwise the prominently labelled provisional means "
            "are planning inputs, not smart-bot findings."
        ),
        (
            "A rational collector buys Wood until all non-WILD Jokers are "
            "owned, then Gold. No-duplicate rarity renormalization makes this "
            "the deterministic minimum chest sink."
        ),
        (
            "The current first genuine Normal loss grants one free Joker. "
            f"This run models it as {free_rarity or 'disabled'}; use "
            "--free-joker-rarity to change it."
        ),
        (
            "All remaining cosmetics are bought directly at listed prices. "
            "The randomized 750-coin Cosmetic Vault is excluded."
        ),
        (
            "Rewarded ads share one five-view daily cap. The model chooses the "
            "better of +25 coins or doubling a run; it never counts both for "
            "the same view, and assumes no view is spent refreshing missions."
        ),
        (
            "Daily login assumes an uninterrupted streak: 30 coins on day 1, "
            "+18 per day, capped at 192. Disable with --no-daily-login."
        ),
        (
            "Weekly income is the 700-coin expected value of three catalogue "
            "missions multiplied by each profile's completion rate."
        ),
        (
            "The 2,797 one-time achievement pool is realized gradually and "
            "partially according to each profile instead of being granted on "
            "day zero."
        ),
        (
            "Paid coin packs, stakes, inactive Daily Board prizes, Daily "
            "Challenge coins, and unmodeled promotional grants are excluded."
        ),
    ]
    return {
        "meta": {
            "model": "WILDCARD v8.4 deterministic account economy",
            "smart_bot_claims_embedded": False,
            "depth_summary": str(args.depth_summary) if args.depth_summary else None,
        },
        "inputs": {
            "public_jokers": args.public_jokers,
            "starter_jokers": args.starter_jokers,
            "rarity_counts": rarity_counts,
            "starter_rarity_counts": starter_rarity_counts,
            "first_loss_free_joker_rarity": free_rarity,
            "cosmetic_direct_price_totals": {
                "tables": args.tables_total,
                "themes": args.themes_total,
                "sly": args.sly_total,
                "all": cosmetic_sink,
            },
            "profiles": {
                name: {
                    "runs_per_day": profile.runs_per_day,
                    "weekly_completion_rate": profile.weekly_completion_rate,
                    "achievement_fraction": profile.achievement_fraction,
                    "achievement_realization_days": (
                        profile.achievement_realization_days
                    ),
                    "before_collection": _jsonable_depth(
                        profile.before_collection
                    ),
                    "after_collection": _jsonable_depth(
                        profile.after_collection
                    ),
                }
                for name, profile in profiles.items()
            },
        },
        "joker_sink": _jsonable_joker_sink(joker_sink),
        "total_current_sink": joker_sink.total_cost + cosmetic_sink,
        "collection_days": simulations,
        "recommended_total_sink_range": recommended_sink_range(
            profiles,
            daily_login=not args.no_daily_login,
        ),
        "assumptions": assumptions,
    }


def _fmt_day(value: int | None) -> str:
    return f"{value}d" if value is not None else "not reached"


def print_text_report(report: Mapping[str, Any]) -> None:
    inputs = report["inputs"]
    joker = report["joker_sink"]
    cosmetics = inputs["cosmetic_direct_price_totals"]
    print("=" * 78)
    print("WILDCARD v8.4 DETERMINISTIC ACCOUNT-ECONOMY SIM")
    print("Gameplay depths: supplied measurements only when explicitly loaded.")
    if report["meta"]["depth_summary"] is None:
        print("DEFAULT DEPTHS ARE PROVISIONAL - NOT SMART-BOT RESULTS.")
    print("=" * 78)
    print("COLLECTION SINK (account coins)")
    print(
        f"  Jokers: {inputs['public_jokers']} public / "
        f"{inputs['starter_jokers']} starters"
    )
    print(
        "  Wood opens: "
        f"{joker['discounted_wood_opens']} x {WOOD_NEWCOMER_PRICE} newcomer + "
        f"{joker['regular_wood_opens']} x {WOOD_BASE_PRICE} standard"
    )
    print(f"  Gold opens: {joker['gold_opens']} x {GOLD_PRICE}")
    print(f"  All Joker unlocks: {joker['total_cost']:>8,}")
    print(f"  Tables direct:     {cosmetics['tables']:>8,}")
    print(f"  Themes direct:     {cosmetics['themes']:>8,}")
    print(f"  Sly looks direct:  {cosmetics['sly']:>8,}")
    print(f"  EVERYTHING:        {report['total_current_sink']:>8,}")
    print("=" * 78)
    print("TIME TO COLLECTION (expected-value days)")
    print(f"{'profile':13s} {'ads':12s} {'Jokers':>12s} {'Everything':>14s}")
    for profile_name in ("casual", "dedicated"):
        rows = report["collection_days"][profile_name]
        for ads_key in ("without_ads", "with_ads"):
            row = rows[ads_key]
            print(
                f"{profile_name:13s} "
                f"{ads_key.replace('_', ' '):12s} "
                f"{_fmt_day(row['joker_collection_day']):>12s} "
                f"{_fmt_day(row['full_collection_day']):>14s}"
            )
    print("=" * 78)
    print("DEPTH INPUTS")
    for name, profile in inputs["profiles"].items():
        depth = profile["before_collection"]
        print(
            f"  {name:9s}: {profile['runs_per_day']} runs/day, "
            f"{depth['mean_heats_cleared']:.2f} mean cleared, "
            f"{depth['win_rate']:.1%} wins, "
            f"{depth['account_coins_per_run']:.1f} account coins/run"
        )
        print(f"             source: {depth['source']}")
    print("=" * 78)
    recommended = report["recommended_total_sink_range"]
    print("RECOMMENDED COMBINED SINK RANGE (no item prices changed)")
    if recommended["feasible_overlap"]:
        print(
            f"  {recommended['recommended_min']:,}-"
            f"{recommended['recommended_max']:,} account coins"
        )
    else:
        print("  No feasible overlap under the supplied depth assumptions.")
    print(f"  {recommended['basis']}")
    print("=" * 78)
    print("TRANSPARENT ASSUMPTIONS")
    for index, assumption in enumerate(report["assumptions"], start=1):
        print(f"  {index}. {assumption}")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Model WILDCARD v8.4 Joker/full-collection time from measured or "
            "provisional run-depth inputs."
        )
    )
    parser.add_argument("--public-jokers", type=int, default=PUBLIC_JOKERS)
    parser.add_argument("--starter-jokers", type=int, default=STARTER_JOKERS)
    parser.add_argument(
        "--rarity-counts",
        type=parse_rarity_counts,
        default=DEFAULT_RARITY_COUNTS,
        metavar="common=N,uncommon=N,rare=N,wild=N",
        help="final public rarity counts (default: 42,32,20,8)",
    )
    parser.add_argument(
        "--starter-rarity-counts",
        type=parse_rarity_counts,
        default=DEFAULT_STARTER_RARITY_COUNTS,
        metavar="common=N,uncommon=N,rare=N,wild=N",
        help="rarities among the ten starters (default: 8,2,0,0)",
    )
    parser.add_argument(
        "--free-joker-rarity",
        choices=("none",) + RARITIES,
        default="rare",
        help=(
            "rarity of the current first-loss free Joker; use none to model "
            "an account that never claims it (default: rare)"
        ),
    )
    parser.add_argument(
        "--tables-total",
        type=int,
        default=DEFAULT_TABLES_TOTAL,
        help="sum of direct prices for all non-default tables",
    )
    parser.add_argument(
        "--themes-total",
        type=int,
        default=DEFAULT_THEMES_TOTAL,
        help="sum of direct prices for all non-default UI themes",
    )
    parser.add_argument(
        "--sly-total",
        type=int,
        default=DEFAULT_SLY_TOTAL,
        help="sum of direct prices for all non-default Sly looks",
    )
    parser.add_argument(
        "--depth-summary",
        type=Path,
        help="JSON file containing measured casual/dedicated run-depth data",
    )
    parser.add_argument(
        "--max-days",
        type=int,
        default=5000,
        help="simulation horizon (default: 5000)",
    )
    parser.add_argument(
        "--no-daily-login",
        action="store_true",
        help="exclude the daily-login streak from both profiles",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="emit machine-readable JSON only",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = _parser()
    args = parser.parse_args(argv)
    if args.max_days <= 0:
        parser.error("--max-days must be positive")
    for name in ("tables_total", "themes_total", "sly_total"):
        if getattr(args, name) < 0:
            parser.error(f"--{name.replace('_', '-')} cannot be negative")
    try:
        report = build_report(args)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        parser.error(str(error))
    if args.json:
        json.dump(report, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    else:
        print_text_report(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
