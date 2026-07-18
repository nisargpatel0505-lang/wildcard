#!/usr/bin/env python3
"""WILDCARD Pi API: Daily Board plus privacy-minimised aggregate analytics.

The service is stdlib-only and listens on localhost:8090 behind nginx /api/.
Analytics are reduced to daily counters while the request is being handled;
raw events, names, IP addresses, user agents, device IDs and exact scores are
never written to the analytics database.
"""

import json
import os
import re
import threading
import time
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


BOARD_DB = os.environ.get("WILDCARD_BOARD_DB", os.path.expanduser("~/wildcard-daily-scores.json"))
ANALYTICS_DB = os.environ.get("WILDCARD_ANALYTICS_DB", os.path.expanduser("~/wildcard-analytics.json"))
LOCK = threading.Lock()
RATE_LOCK = threading.Lock()
ANALYTICS_REQUESTS = []

NAME_RE = re.compile(r"^[A-Za-z0-9]{1,8}$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

MAX_PER_DAY = 2_000
BOARD_KEEP_DAYS = 14
TOP_N = 20
ANALYTICS_KEEP_DAYS = 90
MAX_ANALYTICS_BATCH = 12
MAX_ANALYTICS_REQUESTS_PER_MINUTE = 60
MAX_ANALYTICS_EVENTS_PER_DAY = 20_000
MAX_ANALYTICS_FILE_BYTES = 262_144
MAX_COUNTER = 1_000_000_000

ANALYTICS_EVENTS = frozenset(("app_open", "run_start", "run_end"))
ANALYTICS_VERSIONS = frozenset(("6.9.10", "6.9.11"))
ANALYTICS_PLATFORMS = frozenset(("android", "web"))
ANALYTICS_MODES = frozenset(("normal", "daily", "gauntlet"))
ANALYTICS_OUTCOMES = frozenset(("won", "lost", "terminated"))
ANALYTICS_HEAT_BANDS = frozenset(("1-3", "4-6", "7-9", "10-12", "13+"))


class StoreError(Exception):
    pass


class AnalyticsCapacityError(Exception):
    pass


def load_json(path, fallback):
    try:
        with open(path, encoding="utf-8") as handle:
            value = json.load(handle)
            if not isinstance(value, dict):
                raise StoreError("JSON root is not an object")
            return value
    except FileNotFoundError:
        return fallback
    except (OSError, ValueError, TypeError) as error:
        raise StoreError("JSON store is unreadable") from error


def atomic_save(path, value, mode=0o600):
    tmp = path + ".tmp"
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(tmp, flags, mode)
    if hasattr(os, "fchmod"):
        os.fchmod(descriptor, mode)
    else:
        os.chmod(tmp, mode)
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        json.dump(value, handle, separators=(",", ":"), sort_keys=True)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, path)
    os.chmod(path, mode)
    if os.name == "posix":
        directory = os.open(os.path.dirname(path) or ".", os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)


def date_ok(date):
    now = datetime.now(timezone.utc)
    return any((now + timedelta(days=offset)).strftime("%Y-%m-%d") == date for offset in (-1, 0, 1))


def top(entries, count=TOP_N):
    best = {}
    for entry in entries:
        key = entry["n"]
        if key not in best or entry["s"] > best[key]["s"]:
            best[key] = entry
    return sorted(best.values(), key=lambda entry: -entry["s"])[:count]


def increment(mapping, key, amount=1):
    mapping[key] = min(MAX_COUNTER, int(mapping.get(key, 0)) + amount)


def increment_matrix(mapping, key, event_name):
    row = mapping.setdefault(key, {})
    increment(row, event_name)


def validate_counter(value):
    return isinstance(value, int) and not isinstance(value, bool) and 0 <= value <= MAX_COUNTER


def validate_counter_map(mapping, allowed):
    if not isinstance(mapping, dict):
        raise StoreError("analytics counter map is invalid")
    for key, value in mapping.items():
        if key not in allowed or not validate_counter(value):
            raise StoreError("analytics counter is invalid")


def validate_matrix(mapping, outer_allowed, inner_allowed):
    if not isinstance(mapping, dict):
        raise StoreError("analytics matrix is invalid")
    for key, row in mapping.items():
        if key not in outer_allowed:
            raise StoreError("analytics dimension is invalid")
        validate_counter_map(row, inner_allowed)


def validate_analytics_database(database):
    if set(database) != {"days"} or not isinstance(database.get("days"), dict):
        raise StoreError("analytics database shape is invalid")
    required = {"batches", "events", "versions", "platforms", "modes", "outcomes", "heat_bands"}
    for date, day in database["days"].items():
        if not isinstance(date, str) or not DATE_RE.fullmatch(date) or not isinstance(day, dict) or set(day) != required:
            raise StoreError("analytics day shape is invalid")
        if not validate_counter(day["batches"]):
            raise StoreError("analytics batch counter is invalid")
        validate_counter_map(day["events"], ANALYTICS_EVENTS)
        validate_matrix(day["versions"], ANALYTICS_VERSIONS, ANALYTICS_EVENTS)
        validate_matrix(day["platforms"], ANALYTICS_PLATFORMS, ANALYTICS_EVENTS)
        validate_matrix(day["modes"], ANALYTICS_MODES, ANALYTICS_EVENTS)
        validate_counter_map(day["outcomes"], ANALYTICS_OUTCOMES)
        validate_counter_map(day["heat_bands"], ANALYTICS_HEAT_BANDS)


def prune_date_keys(mapping, keep_days, now):
    cutoff = (now - timedelta(days=keep_days - 1)).strftime("%Y-%m-%d")
    for key in list(mapping):
        if not DATE_RE.fullmatch(key) or key < cutoff:
            del mapping[key]


def analytics_rate_ok(now=None):
    """Global write-rate guard that stores no client address or identifier."""
    current = time.monotonic() if now is None else now
    cutoff = current - 60.0
    with RATE_LOCK:
        while ANALYTICS_REQUESTS and ANALYTICS_REQUESTS[0] < cutoff:
            ANALYTICS_REQUESTS.pop(0)
        if len(ANALYTICS_REQUESTS) >= MAX_ANALYTICS_REQUESTS_PER_MINUTE:
            return False
        ANALYTICS_REQUESTS.append(current)
        return True


def validate_analytics(payload):
    if not isinstance(payload, dict) or set(payload) != {"v", "p", "events"}:
        raise ValueError("bad fields")
    version = payload.get("v")
    platform = payload.get("p")
    events = payload.get("events")
    if not isinstance(version, str) or version not in ANALYTICS_VERSIONS:
        raise ValueError("bad version")
    if not isinstance(platform, str) or platform not in ANALYTICS_PLATFORMS:
        raise ValueError("bad platform")
    if not isinstance(events, list) or not (1 <= len(events) <= MAX_ANALYTICS_BATCH):
        raise ValueError("bad events")

    clean = []
    for event in events:
        if not isinstance(event, dict):
            raise ValueError("bad event")
        name = event.get("n")
        if not isinstance(name, str) or name not in ANALYTICS_EVENTS:
            raise ValueError("bad event name")
        if name == "app_open":
            if set(event) != {"n"}:
                raise ValueError("bad app event")
            clean.append({"n": name})
            continue
        mode = event.get("m")
        if not isinstance(mode, str) or mode not in ANALYTICS_MODES:
            raise ValueError("bad mode")
        if name == "run_start":
            if set(event) != {"n", "m"}:
                raise ValueError("bad start event")
            clean.append({"n": name, "m": mode})
            continue
        outcome = event.get("o")
        heat_band = event.get("h")
        if set(event) != {"n", "m", "o", "h"}:
            raise ValueError("bad end event")
        if not isinstance(outcome, str) or not isinstance(heat_band, str) or outcome not in ANALYTICS_OUTCOMES or heat_band not in ANALYTICS_HEAT_BANDS:
            raise ValueError("bad result")
        clean.append({"n": name, "m": mode, "o": outcome, "h": heat_band})
    return version, platform, clean


def record_analytics(payload, now=None):
    """Validate a batch and merge it directly into anonymous daily counters."""
    version, platform, events = validate_analytics(payload)
    current = now or datetime.now(timezone.utc)
    day_key = current.strftime("%Y-%m-%d")
    with LOCK:
        try:
            if os.path.getsize(ANALYTICS_DB) > MAX_ANALYTICS_FILE_BYTES:
                raise StoreError("analytics store is unexpectedly large")
        except FileNotFoundError:
            pass
        database = load_json(ANALYTICS_DB, {"days": {}})
        validate_analytics_database(database)
        days = database.setdefault("days", {})
        prune_date_keys(days, ANALYTICS_KEEP_DAYS, current)
        day = days.setdefault(day_key, {
            "batches": 0,
            "events": {},
            "versions": {},
            "platforms": {},
            "modes": {},
            "outcomes": {},
            "heat_bands": {},
        })
        if sum(int(value) for value in day["events"].values()) + len(events) > MAX_ANALYTICS_EVENTS_PER_DAY:
            raise AnalyticsCapacityError("analytics day is full")
        increment(day, "batches")
        for event in events:
            name = event["n"]
            increment(day["events"], name)
            increment_matrix(day["versions"], version, name)
            increment_matrix(day["platforms"], platform, name)
            if "m" in event:
                increment_matrix(day["modes"], event["m"], name)
            if "o" in event:
                increment(day["outcomes"], event["o"])
            if "h" in event:
                increment(day["heat_bands"], event["h"])
        atomic_save(ANALYTICS_DB, database)
    return len(events)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def _cors(self):
        # Capacitor uses a localhost origin. These endpoints have no cookies or credentials.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Max-Age", "86400")

    def _json(self, code, value):
        body = json.dumps(value, separators=(",", ":")).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self._cors()
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _payload(self, maximum):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not (0 < length <= maximum):
                raise ValueError("bad size")
            return json.loads(self.rfile.read(length))
        except (ValueError, TypeError, json.JSONDecodeError):
            raise ValueError("bad json")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/health":
            return self._json(200, {"ok": True, "analytics": "aggregate-v1"})
        if parsed.path == "/api/daily":
            query = parse_qs(parsed.query)
            date = (query.get("date") or [datetime.now(timezone.utc).strftime("%Y-%m-%d")])[0]
            if not DATE_RE.fullmatch(date):
                return self._json(400, {"err": "bad date"})
            try:
                with LOCK:
                    board = load_json(BOARD_DB, {})
                    return self._json(200, {"date": date, "top": top(board.get(date, []))})
            except StoreError:
                return self._json(503, {"err": "store unavailable"})
        # Analytics deliberately has no public read endpoint.
        return self._json(404, {"err": "not found"})

    def do_POST(self):
        path = urlparse(self.path).path
        if path == "/api/analytics":
            try:
                payload = self._payload(4_096)
                validate_analytics(payload)
            except (ValueError, TypeError):
                return self._json(400, {"err": "bad analytics"})
            if not analytics_rate_ok():
                return self._json(429, {"err": "busy"})
            try:
                accepted = record_analytics(payload)
            except AnalyticsCapacityError:
                return self._json(429, {"err": "day full"})
            except (ValueError, TypeError):
                return self._json(400, {"err": "bad analytics"})
            except (OSError, StoreError):
                return self._json(503, {"err": "store unavailable"})
            return self._json(202, {"ok": True, "accepted": accepted})
        if path != "/api/daily":
            return self._json(404, {"err": "not found"})
        try:
            payload = self._payload(500)
            date = str(payload.get("date", ""))
            name = str(payload.get("name", "")).strip().upper()
            score = int(payload.get("score", 0))
        except (ValueError, TypeError, AttributeError):
            return self._json(400, {"err": "bad json"})
        if not DATE_RE.fullmatch(date) or not date_ok(date):
            return self._json(400, {"err": "bad date"})
        if not NAME_RE.fullmatch(name):
            return self._json(400, {"err": "bad name"})
        if not (0 <= score <= 10_000_000):
            return self._json(400, {"err": "bad score"})
        try:
            with LOCK:
                board = load_json(BOARD_DB, {})
                day = board.setdefault(date, [])
                existing = next((entry for entry in day if entry.get("n") == name), None)
                if existing:
                    existing["s"] = max(int(existing.get("s", 0)), score)
                else:
                    if len(day) >= MAX_PER_DAY:
                        return self._json(429, {"err": "day full"})
                    day.append({"n": name, "s": score})
                prune_date_keys(board, BOARD_KEEP_DAYS, datetime.now(timezone.utc))
                atomic_save(BOARD_DB, board)
                leaders = top(day)
                rank = next((index + 1 for index, entry in enumerate(leaders) if entry["n"] == name), 0)
                best_score = max(entry["s"] for entry in day if entry["n"] == name)
                return self._json(200, {
                    "date": date,
                    "top": leaders,
                    "you": {"n": name, "s": best_score},
                    "rank": rank,
                })
        except (OSError, StoreError):
            return self._json(503, {"err": "store unavailable"})


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8090), Handler).serve_forever()
