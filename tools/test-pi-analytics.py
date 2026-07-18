#!/usr/bin/env python3
"""Regression tests for the privacy-minimised Pi analytics aggregator."""

import importlib.util
import json
import os
import stat
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "deploy" / "wildcard-api.py"
spec = importlib.util.spec_from_file_location("wildcard_api", SOURCE)
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)


def rejected(payload):
    try:
        api.validate_analytics(payload)
        return False
    except ValueError:
        return True


with tempfile.TemporaryDirectory() as directory:
    api.ANALYTICS_DB = os.path.join(directory, "analytics.json")
    now = datetime(2026, 7, 17, 12, 0, tzinfo=timezone.utc)
    accepted = api.record_analytics({
        "v": "6.9.12",
        "p": "android",
        "events": [
            {"n": "app_open"},
            {"n": "run_start", "m": "daily"},
            {"n": "run_end", "m": "daily", "o": "lost", "h": "4-6"},
        ],
    }, now=now)
    assert accepted == 3
    with open(api.ANALYTICS_DB, encoding="utf-8") as handle:
        saved = json.load(handle)
    day = saved["days"]["2026-07-17"]
    assert day["events"] == {"app_open": 1, "run_end": 1, "run_start": 1}
    assert day["versions"]["6.9.12"] == {"app_open": 1, "run_end": 1, "run_start": 1}
    assert day["modes"]["daily"] == {"run_end": 1, "run_start": 1}
    assert day["outcomes"] == {"lost": 1}
    assert day["heat_bands"] == {"4-6": 1}
    if os.name != "nt":
        assert stat.S_IMODE(os.stat(api.ANALYTICS_DB).st_mode) == 0o600
    flattened = json.dumps(saved)
    for forbidden in ("playerName", "score", "cards", "email", "uid", "device"):
        assert forbidden not in flattened
    old_day = (now - timedelta(days=api.ANALYTICS_KEEP_DAYS + 10)).strftime("%Y-%m-%d")
    saved["days"][old_day] = dict(day)
    api.atomic_save(api.ANALYTICS_DB, saved)
    api.record_analytics({"v": "6.9.10", "p": "web", "events": [{"n": "app_open"}]}, now=now)
    with open(api.ANALYTICS_DB, encoding="utf-8") as handle:
        assert old_day not in json.load(handle)["days"]
    with open(api.ANALYTICS_DB, "w", encoding="utf-8") as handle:
        handle.write("{broken")
    try:
        api.record_analytics({"v": "6.9.10", "p": "web", "events": [{"n": "app_open"}]}, now=now)
        raise AssertionError("corrupt analytics store was silently replaced")
    except api.StoreError:
        pass
    with open(api.ANALYTICS_DB, encoding="utf-8") as handle:
        assert handle.read() == "{broken"

assert rejected({"v": "6.9.10", "p": "android", "events": [{"n": "app_open", "uid": "x"}]})
assert rejected({"v": "6.9.10", "p": "android", "events": [{"n": "run_end", "m": "normal", "o": "lost", "h": "6"}]})
assert rejected({"v": "6.9.10", "p": "android", "events": [{"n": "score", "score": 999}]})
assert rejected({"v": "6.9.10", "p": "other", "events": [{"n": "app_open"}]})
assert rejected({"v": "6.9.10", "p": "android", "events": [{"n": "run_start", "m": "endless"}]})
assert rejected({"v": "9.9.9", "p": "android", "events": [{"n": "app_open"}]})
assert rejected({"v": "6.9.10", "p": [], "events": [{"n": "app_open"}]})
assert rejected({"v": "6.9.10", "p": "android", "events": [{"n": []}]})
assert rejected({"v": "6.9.10", "p": "android", "events": [{"n": "run_start", "m": {}}]})
assert rejected({"v": "6.9.10", "p": "android", "events": [{"n": "run_end", "m": "normal", "o": [], "h": "1-3"}]})

with tempfile.TemporaryDirectory() as directory:
    api.ANALYTICS_DB = os.path.join(directory, "analytics.json")
    api.atomic_save(api.ANALYTICS_DB, {"days": []})
    original = Path(api.ANALYTICS_DB).read_text(encoding="utf-8")
    try:
        api.record_analytics({"v": "6.9.10", "p": "web", "events": [{"n": "app_open"}]})
        raise AssertionError("structurally corrupt analytics store was replaced")
    except api.StoreError:
        pass
    assert Path(api.ANALYTICS_DB).read_text(encoding="utf-8") == original

with tempfile.TemporaryDirectory() as directory:
    api.ANALYTICS_DB = os.path.join(directory, "analytics.json")
    current = datetime(2026, 7, 17, 12, 0, tzinfo=timezone.utc)
    full_day = {
        "batches": 1,
        "events": {"app_open": api.MAX_ANALYTICS_EVENTS_PER_DAY},
        "versions": {"6.9.10": {"app_open": api.MAX_ANALYTICS_EVENTS_PER_DAY}},
        "platforms": {"web": {"app_open": api.MAX_ANALYTICS_EVENTS_PER_DAY}},
        "modes": {}, "outcomes": {}, "heat_bands": {},
    }
    api.atomic_save(api.ANALYTICS_DB, {"days": {"2026-07-17": full_day}})
    try:
        api.record_analytics({"v": "6.9.10", "p": "web", "events": [{"n": "app_open"}]}, now=current)
        raise AssertionError("daily analytics cap was not enforced")
    except api.AnalyticsCapacityError:
        pass

with tempfile.TemporaryDirectory() as directory:
    api.ANALYTICS_DB = os.path.join(directory, "analytics.json")
    oversized = (" " * api.MAX_ANALYTICS_FILE_BYTES) + '{"days":{}}'
    Path(api.ANALYTICS_DB).write_text(oversized, encoding="utf-8")
    try:
        api.record_analytics({"v": "6.9.10", "p": "web", "events": [{"n": "app_open"}]})
        raise AssertionError("analytics file-size cap was not enforced")
    except api.StoreError:
        pass

api.ANALYTICS_REQUESTS.clear()
assert all(api.analytics_rate_ok(float(index) / 10) for index in range(api.MAX_ANALYTICS_REQUESTS_PER_MINUTE))
assert not api.analytics_rate_ok(12.1)

print("Pi analytics aggregate/privacy tests passed")
