#!/usr/bin/env python3
"""Print WILDCARD's anonymous Pi analytics counters. No network access required."""

import argparse
import json
import os


DEFAULT_DB = os.environ.get("WILDCARD_ANALYTICS_DB", os.path.expanduser("~/wildcard-analytics.json"))


def count(day, event):
    return int(day.get("events", {}).get(event, 0))


def total_rows(days, key):
    totals = {}
    for day in days:
        for label, row in day.get(key, {}).items():
            target = totals.setdefault(label, {})
            if isinstance(row, dict):
                for event, value in row.items():
                    target[event] = target.get(event, 0) + int(value)
            else:
                target["count"] = target.get("count", 0) + int(row)
    return totals


def summary_line(label, row):
    parts = [f"{event}={value}" for event, value in sorted(row.items())]
    return f"  {label}: " + ", ".join(parts)


def main():
    parser = argparse.ArgumentParser(description="Read WILDCARD anonymous aggregate analytics")
    parser.add_argument("--days", type=int, default=14, help="number of stored UTC days to show")
    parser.add_argument("--db", default=DEFAULT_DB, help="analytics JSON path")
    parser.add_argument("--json", action="store_true", help="print the stored aggregate JSON")
    args = parser.parse_args()

    try:
        with open(args.db, encoding="utf-8") as handle:
            database = json.load(handle)
    except FileNotFoundError:
        print("No analytics have arrived yet.")
        return

    if args.json:
        print(json.dumps(database, indent=2, sort_keys=True))
        return

    all_days = database.get("days", {})
    selected_keys = sorted(all_days)[-max(1, args.days):]
    selected = [all_days[key] for key in selected_keys]
    print("WILDCARD anonymous analytics (UTC; aggregate counters only)")
    print("Date        Opens  Starts  Ends   Won  Lost  Terminated")
    for key, day in zip(selected_keys, selected):
        outcomes = day.get("outcomes", {})
        print(
            f"{key:<10}  {count(day, 'app_open'):>5}  {count(day, 'run_start'):>6}  "
            f"{count(day, 'run_end'):>4}  {int(outcomes.get('won', 0)):>4}  "
            f"{int(outcomes.get('lost', 0)):>4}  {int(outcomes.get('terminated', 0)):>10}"
        )
    for title, key in (("Versions", "versions"), ("Platforms", "platforms"), ("Run modes", "modes")):
        rows = total_rows(selected, key)
        if rows:
            print(f"\n{title}")
            for label, row in sorted(rows.items()):
                print(summary_line(label, row))
    outcomes = total_rows(selected, "outcomes")
    heat_bands = total_rows(selected, "heat_bands")
    if outcomes:
        print("\nOutcomes")
        for label, row in sorted(outcomes.items()):
            print(summary_line(label, row))
    if heat_bands:
        print("\nHeat bands reached")
        for label, row in sorted(heat_bands.items()):
            print(summary_line(label, row))


if __name__ == "__main__":
    main()
