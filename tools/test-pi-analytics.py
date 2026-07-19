#!/usr/bin/env python3
"""Regression tests for the privacy-minimised Pi analytics aggregator."""

import importlib.util
import json
import os
import stat
import tempfile
import threading
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from http.server import ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "deploy" / "wildcard-api.py"
spec = importlib.util.spec_from_file_location("wildcard_api", SOURCE)
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)

if os.name != "nt":
    with tempfile.TemporaryDirectory() as directory:
        env_path = Path(directory) / "wildcard-api.env"
        env_path.write_text(
            "WILDCARD_BOARD_HMAC_SECRET=test-file-" + ("x" * 32) + "\n",
            encoding="utf-8",
        )
        os.chmod(env_path, 0o600)
        old_path = os.environ.get("WILDCARD_API_ENV_FILE")
        old_secret = os.environ.pop("WILDCARD_BOARD_HMAC_SECRET", None)
        os.environ["WILDCARD_API_ENV_FILE"] = str(env_path)
        api.load_private_environment()
        assert os.environ["WILDCARD_BOARD_HMAC_SECRET"].startswith("test-file-")
        os.environ.pop("WILDCARD_BOARD_HMAC_SECRET", None)
        os.chmod(env_path, 0o644)
        try:
            api.load_private_environment()
            raise AssertionError("insecure private environment permissions were accepted")
        except RuntimeError:
            pass
        if old_path is None:
            os.environ.pop("WILDCARD_API_ENV_FILE", None)
        else:
            os.environ["WILDCARD_API_ENV_FILE"] = old_path
        if old_secret is not None:
            os.environ["WILDCARD_BOARD_HMAC_SECRET"] = old_secret


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
        "v": "6.9.14",
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
    assert day["versions"]["6.9.14"] == {"app_open": 1, "run_end": 1, "run_start": 1}
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

with tempfile.TemporaryDirectory() as directory:
    api.BOARD_DB = os.path.join(directory, "board.json")
    api.BOARD_HMAC_SECRET = "test-secret-" + ("x" * 32)
    now_seconds = int(datetime.now(timezone.utc).timestamp())
    today = api.utc_date()
    uid_a = "a" * 64
    uid_b = "b" * 64

    first = {
        "date": today,
        "name": "ALICE",
        "score": 1250,
        "uidHash": uid_a,
        "idempotencyKey": "request_0000000001",
        "issuedAt": now_seconds * 1000,
    }
    raw = json.dumps(first, separators=(",", ":")).encode("utf-8")
    timestamp = str(now_seconds)
    import hashlib
    import hmac
    signature = hmac.new(
        api.BOARD_HMAC_SECRET.encode("utf-8"),
        timestamp.encode("ascii") + b"." + raw,
        hashlib.sha256,
    ).hexdigest()
    api.validate_signed_request(raw, timestamp, signature, now=now_seconds)
    for bad_signature in ("0" * 64, "", "not-hex"):
        try:
            api.validate_signed_request(raw, timestamp, bad_signature, now=now_seconds)
            raise AssertionError("invalid board signature was accepted")
        except ValueError:
            pass
    try:
        api.validate_signed_request(raw, str(now_seconds - 121), signature, now=now_seconds)
        raise AssertionError("expired board signature was accepted")
    except ValueError:
        pass

    leaders, entry, replayed = api.record_board_submission(first)
    assert leaders == [{"n": "ALICE", "s": 1250}]
    assert entry["s"] == 1250 and not replayed
    leaders, entry, replayed = api.record_board_submission(first)
    assert replayed and entry["s"] == 1250

    higher = dict(first, score=2000, idempotencyKey="request_0000000002")
    leaders, entry, replayed = api.record_board_submission(higher)
    assert not replayed and entry["s"] == 2000
    assert leaders == [{"n": "ALICE", "s": 2000}]

    conflicting_name = dict(
        first,
        uidHash=uid_b,
        score=3000,
        idempotencyKey="request_0000000003",
    )
    try:
        api.record_board_submission(conflicting_name)
        raise AssertionError("a second account impersonated an existing board name")
    except api.BoardConflictError:
        pass

    wrong_day = dict(
        first,
        date=(datetime.now(timezone.utc) + timedelta(days=1)).strftime("%Y-%m-%d"),
        idempotencyKey="request_0000000004",
    )
    try:
        api.validate_board_submission(wrong_day)
        raise AssertionError("a future Daily score was accepted")
    except ValueError:
        pass
    yesterday = dict(
        first,
        date=(datetime.now(timezone.utc) - timedelta(days=1)).strftime("%Y-%m-%d"),
        idempotencyKey="request_0000000005",
    )
    assert api.validate_board_submission(yesterday)[0] == yesterday["date"]

    api.BOARD_REQUESTS.clear()
    api.BOARD_REQUESTS_BY_USER.clear()
    assert all(
        api.board_rate_ok(uid_a, float(index) / 10)
        for index in range(api.MAX_BOARD_REQUESTS_PER_USER_MINUTE)
    )
    assert not api.board_rate_ok(uid_a, 12.1)
    assert api.board_rate_ok(uid_b, 12.1)

    removed = api.delete_board_user({
        "uidHash": uid_a,
        "idempotencyKey": "delete_0000000001",
        "issuedAt": now_seconds * 1000,
    })
    assert removed == 1
    assert api.load_board_database()["days"][today]["entries"] == {}
    if os.name != "nt":
        assert stat.S_IMODE(os.stat(api.BOARD_DB).st_mode) == 0o600

with tempfile.TemporaryDirectory() as directory:
    api.BOARD_DB = os.path.join(directory, "legacy-board.json")
    Path(api.BOARD_DB).write_text(
        json.dumps({"2026-07-18": [{"n": "FORGED", "s": 9999999}]}),
        encoding="utf-8",
    )
    assert api.load_board_database() == api.empty_board_database()

with tempfile.TemporaryDirectory() as directory:
    api.BOARD_DB = os.path.join(directory, "http-board.json")
    api.BOARD_HMAC_SECRET = "http-test-secret-" + ("x" * 32)
    server = ThreadingHTTPServer(("127.0.0.1", 0), api.Handler)
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    base = f"http://127.0.0.1:{server.server_address[1]}"
    try:
        public_post = urllib.request.Request(
            base + "/api/daily",
            data=b"{}",
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            urllib.request.urlopen(public_post, timeout=2)
            raise AssertionError("public Daily POST was accepted")
        except urllib.error.HTTPError as error:
            assert error.code == 401

        allowed_origin = urllib.request.Request(
            base + "/api/daily",
            headers={"Origin": "https://localhost"},
        )
        with urllib.request.urlopen(allowed_origin, timeout=2) as response:
            assert response.headers["Access-Control-Allow-Origin"] == "https://localhost"
        denied_origin = urllib.request.Request(
            base + "/api/daily",
            headers={"Origin": "https://evil.example"},
        )
        with urllib.request.urlopen(denied_origin, timeout=2) as response:
            assert response.headers.get("Access-Control-Allow-Origin") is None

        timestamp = str(int(datetime.now(timezone.utc).timestamp()))
        signed_payload = {
            "date": api.utc_date(),
            "name": "SERVER",
            "score": 4321,
            "uidHash": "c" * 64,
            "idempotencyKey": "request_http_000001",
            "issuedAt": int(timestamp) * 1000,
        }
        raw = json.dumps(signed_payload, separators=(",", ":")).encode("utf-8")
        signature = hmac.new(
            api.BOARD_HMAC_SECRET.encode("utf-8"),
            timestamp.encode("ascii") + b"." + raw,
            hashlib.sha256,
        ).hexdigest()
        internal_post = urllib.request.Request(
            base + "/api/internal/daily",
            data=raw,
            headers={
                "Content-Type": "application/json",
                "X-Wildcard-Timestamp": timestamp,
                "X-Wildcard-Signature": signature,
            },
            method="POST",
        )
        with urllib.request.urlopen(internal_post, timeout=2) as response:
            result = json.load(response)
        assert result["you"] == {"n": "SERVER", "s": 4321}
        assert result["replayed"] is False
    finally:
        server.shutdown()
        server.server_close()
        server_thread.join(timeout=2)

print("Pi board security and analytics aggregate/privacy tests passed")
