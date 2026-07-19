#!/usr/bin/env python3
"""WILDCARD Pi API: Daily Board plus privacy-minimised aggregate analytics.

The service is stdlib-only and listens on localhost:8090 behind nginx /api/.
Analytics are reduced to daily counters while the request is being handled;
raw events, names, IP addresses, user agents, device IDs and exact scores are
never written to the analytics database.
"""

import hashlib
import hmac
import json
import os
import re
import stat
import threading
import time
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


def load_private_environment():
    """Load the service user's mode-0600 config once, before reading settings."""
    path = os.path.expanduser(
        os.environ.get(
            "WILDCARD_API_ENV_FILE",
            "~/.config/wildcard-api.env",
        )
    )
    try:
        file_stat = os.stat(path, follow_symlinks=False)
        if not stat.S_ISREG(file_stat.st_mode) or file_stat.st_mode & 0o077:
            raise RuntimeError("private environment file must be a regular mode-0600 file")
        with open(path, encoding="utf-8") as handle:
            for raw_line in handle:
                line = raw_line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                key = key.strip()
                if key in {
                    "WILDCARD_BOARD_HMAC_SECRET",
                    "WILDCARD_BOARD_DB",
                    "WILDCARD_ANALYTICS_DB",
                    "WILDCARD_ALLOWED_ORIGINS",
                }:
                    os.environ.setdefault(key, value.strip())
    except FileNotFoundError:
        return


load_private_environment()


BOARD_DB = os.environ.get("WILDCARD_BOARD_DB", os.path.expanduser("~/wildcard-daily-scores.json"))
ANALYTICS_DB = os.environ.get("WILDCARD_ANALYTICS_DB", os.path.expanduser("~/wildcard-analytics.json"))
BOARD_HMAC_SECRET = os.environ.get("WILDCARD_BOARD_HMAC_SECRET", "")
LOCK = threading.Lock()
RATE_LOCK = threading.Lock()
ANALYTICS_REQUESTS = []
BOARD_REQUESTS = []
BOARD_REQUESTS_BY_USER = {}

NAME_RE = re.compile(r"^[A-Za-z0-9]{1,8}$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
UID_HASH_RE = re.compile(r"^[a-f0-9]{64}$")
IDEMPOTENCY_RE = re.compile(r"^[A-Za-z0-9_-]{16,80}$")
SIGNATURE_RE = re.compile(r"^[a-f0-9]{64}$")

MAX_PER_DAY = 2_000
BOARD_KEEP_DAYS = 14
TOP_N = 20
MAX_BOARD_REQUESTS_PER_MINUTE = 120
MAX_BOARD_REQUESTS_PER_USER_MINUTE = 10
MAX_BOARD_SEEN_PER_DAY = 8_000
MAX_SIGNATURE_AGE_SECONDS = 120
ANALYTICS_KEEP_DAYS = 90
MAX_ANALYTICS_BATCH = 12
MAX_ANALYTICS_REQUESTS_PER_MINUTE = 60
MAX_ANALYTICS_EVENTS_PER_DAY = 20_000
MAX_ANALYTICS_FILE_BYTES = 262_144
MAX_COUNTER = 1_000_000_000

ANALYTICS_EVENTS = frozenset(("app_open", "run_start", "run_end"))
ANALYTICS_VERSIONS = frozenset(("6.9.10", "6.9.11", "6.9.12", "6.9.13", "6.9.14"))
ANALYTICS_PLATFORMS = frozenset(("android", "web"))
ANALYTICS_MODES = frozenset(("normal", "daily", "gauntlet"))
ANALYTICS_OUTCOMES = frozenset(("won", "lost", "terminated"))
ANALYTICS_HEAT_BANDS = frozenset(("1-3", "4-6", "7-9", "10-12", "13+"))

DEFAULT_ALLOWED_ORIGINS = frozenset((
    "https://localhost",
    "http://localhost",
    "capacitor://localhost",
    "https://raspberrypi.tail20f574.ts.net",
    "https://wildcard-31d50.web.app",
    "https://wildcard-31d50.firebaseapp.com",
))
ALLOWED_ORIGINS = frozenset(
    origin.strip()
    for origin in os.environ.get(
        "WILDCARD_ALLOWED_ORIGINS",
        ",".join(sorted(DEFAULT_ALLOWED_ORIGINS)),
    ).split(",")
    if origin.strip()
)


class StoreError(Exception):
    pass


class AnalyticsCapacityError(Exception):
    pass


class BoardCapacityError(Exception):
    pass


class BoardConflictError(Exception):
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


def utc_date(now=None):
    return (now or datetime.now(timezone.utc)).strftime("%Y-%m-%d")


def top(entries, count=TOP_N):
    best = {}
    for entry in entries:
        key = entry.get("u", entry["n"])
        if key not in best or entry["s"] > best[key]["s"]:
            best[key] = entry
    return [
        {"n": entry["n"], "s": entry["s"]}
        for entry in sorted(
            best.values(),
            key=lambda entry: (-entry["s"], entry["n"], entry.get("u", "")),
        )[:count]
    ]


def empty_board_database():
    return {"schemaVersion": 2, "days": {}}


def validate_board_database(database):
    if (
        set(database) != {"schemaVersion", "days"}
        or database.get("schemaVersion") != 2
        or not isinstance(database.get("days"), dict)
    ):
        raise StoreError("board database shape is invalid")
    for date, day in database["days"].items():
        if (
            not isinstance(date, str)
            or not DATE_RE.fullmatch(date)
            or not isinstance(day, dict)
            or set(day) != {"entries", "seen"}
            or not isinstance(day["entries"], dict)
            or not isinstance(day["seen"], dict)
        ):
            raise StoreError("board day shape is invalid")
        if len(day["entries"]) > MAX_PER_DAY or len(day["seen"]) > MAX_BOARD_SEEN_PER_DAY:
            raise StoreError("board day exceeds capacity")
        claimed_names = set()
        for uid_hash, entry in day["entries"].items():
            if (
                not isinstance(uid_hash, str)
                or not UID_HASH_RE.fullmatch(uid_hash)
                or not isinstance(entry, dict)
                or set(entry) != {"n", "s", "updatedAt"}
                or not isinstance(entry["n"], str)
                or not NAME_RE.fullmatch(entry["n"])
                or not isinstance(entry["s"], int)
                or isinstance(entry["s"], bool)
                or not (0 <= entry["s"] <= 10_000_000)
                or not isinstance(entry["updatedAt"], int)
                or entry["updatedAt"] < 0
                or entry["n"] in claimed_names
            ):
                raise StoreError("board entry is invalid")
            claimed_names.add(entry["n"])
        for request_id, seen in day["seen"].items():
            if (
                not isinstance(request_id, str)
                or not IDEMPOTENCY_RE.fullmatch(request_id)
                or not isinstance(seen, dict)
                or set(seen) != {"u", "at"}
                or not isinstance(seen["u"], str)
                or not UID_HASH_RE.fullmatch(seen["u"])
                or not isinstance(seen["at"], int)
                or seen["at"] < 0
            ):
                raise StoreError("board idempotency record is invalid")


def load_board_database():
    database = load_json(BOARD_DB, empty_board_database())
    # The former schema contained unauthenticated, unverified rows. It is
    # intentionally not migrated into the trusted board.
    if "schemaVersion" not in database:
        return empty_board_database()
    validate_board_database(database)
    return database


def board_rate_ok(uid_hash, now=None):
    """Bound trusted writes globally and per authenticated account."""
    current = time.monotonic() if now is None else now
    cutoff = current - 60.0
    with RATE_LOCK:
        while BOARD_REQUESTS and BOARD_REQUESTS[0] < cutoff:
            BOARD_REQUESTS.pop(0)
        user_requests = BOARD_REQUESTS_BY_USER.setdefault(uid_hash, [])
        while user_requests and user_requests[0] < cutoff:
            user_requests.pop(0)
        if (
            len(BOARD_REQUESTS) >= MAX_BOARD_REQUESTS_PER_MINUTE
            or len(user_requests) >= MAX_BOARD_REQUESTS_PER_USER_MINUTE
        ):
            return False
        BOARD_REQUESTS.append(current)
        user_requests.append(current)
        for key in list(BOARD_REQUESTS_BY_USER):
            if not BOARD_REQUESTS_BY_USER[key]:
                del BOARD_REQUESTS_BY_USER[key]
        return True


def validate_signed_request(raw_body, timestamp_text, signature, now=None):
    if not BOARD_HMAC_SECRET or len(BOARD_HMAC_SECRET.encode("utf-8")) < 32:
        raise StoreError("board signing secret is not configured")
    if not isinstance(timestamp_text, str) or not timestamp_text.isdigit():
        raise ValueError("bad timestamp")
    if not isinstance(signature, str) or not SIGNATURE_RE.fullmatch(signature):
        raise ValueError("bad signature")
    issued_at = int(timestamp_text)
    current = int(time.time() if now is None else now)
    if abs(current - issued_at) > MAX_SIGNATURE_AGE_SECONDS:
        raise ValueError("expired signature")
    expected = hmac.new(
        BOARD_HMAC_SECRET.encode("utf-8"),
        timestamp_text.encode("ascii") + b"." + raw_body,
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected, signature):
        raise ValueError("bad signature")


def validate_board_submission(payload, now=None):
    required = {"date", "name", "score", "uidHash", "idempotencyKey", "issuedAt"}
    if not isinstance(payload, dict) or set(payload) != required:
        raise ValueError("bad fields")
    date = payload["date"]
    name = payload["name"]
    score = payload["score"]
    uid_hash = payload["uidHash"]
    request_id = payload["idempotencyKey"]
    issued_at = payload["issuedAt"]
    current = now or datetime.now(timezone.utc)
    allowed_dates = {
        current.strftime("%Y-%m-%d"),
        (current - timedelta(days=1)).strftime("%Y-%m-%d"),
    }
    # Only an HMAC-authenticated Firebase server can reach this validator.
    # Yesterday is accepted solely so an idempotent retry can cross midnight.
    if not isinstance(date, str) or not DATE_RE.fullmatch(date) or date not in allowed_dates:
        raise ValueError("bad date")
    if not isinstance(name, str) or not NAME_RE.fullmatch(name):
        raise ValueError("bad name")
    if not isinstance(score, int) or isinstance(score, bool) or not (0 <= score <= 10_000_000):
        raise ValueError("bad score")
    if not isinstance(uid_hash, str) or not UID_HASH_RE.fullmatch(uid_hash):
        raise ValueError("bad uid")
    if not isinstance(request_id, str) or not IDEMPOTENCY_RE.fullmatch(request_id):
        raise ValueError("bad idempotency key")
    if not isinstance(issued_at, int) or isinstance(issued_at, bool) or issued_at < 0:
        raise ValueError("bad issue time")
    return date, name, score, uid_hash, request_id, issued_at


def record_board_submission(payload):
    date, name, score, uid_hash, request_id, issued_at = validate_board_submission(payload)
    with LOCK:
        database = load_board_database()
        days = database["days"]
        prune_date_keys(days, BOARD_KEEP_DAYS, datetime.now(timezone.utc))
        day = days.setdefault(date, {"entries": {}, "seen": {}})
        seen = day["seen"].get(request_id)
        if seen:
            if seen["u"] != uid_hash:
                raise BoardConflictError("idempotency key belongs to another account")
            existing = day["entries"].get(uid_hash)
            return top(day["entries"].values()), existing, True
        if len(day["seen"]) >= MAX_BOARD_SEEN_PER_DAY:
            raise BoardCapacityError("daily request ledger is full")
        existing_owner = next(
            (
                owner
                for owner, entry in day["entries"].items()
                if entry["n"] == name and owner != uid_hash
            ),
            None,
        )
        if existing_owner:
            raise BoardConflictError("board name belongs to another account")
        entry = day["entries"].get(uid_hash)
        if entry is None:
            if len(day["entries"]) >= MAX_PER_DAY:
                raise BoardCapacityError("board is full")
            entry = {"n": name, "s": score, "updatedAt": issued_at}
            day["entries"][uid_hash] = entry
        else:
            entry["n"] = name
            entry["s"] = max(entry["s"], score)
            entry["updatedAt"] = max(entry["updatedAt"], issued_at)
        day["seen"][request_id] = {"u": uid_hash, "at": issued_at}
        atomic_save(BOARD_DB, database)
        return top(day["entries"].values()), dict(entry), False


def delete_board_user(payload):
    required = {"uidHash", "idempotencyKey", "issuedAt"}
    if not isinstance(payload, dict) or set(payload) != required:
        raise ValueError("bad fields")
    uid_hash = payload["uidHash"]
    request_id = payload["idempotencyKey"]
    issued_at = payload["issuedAt"]
    if not isinstance(uid_hash, str) or not UID_HASH_RE.fullmatch(uid_hash):
        raise ValueError("bad uid")
    if not isinstance(request_id, str) or not IDEMPOTENCY_RE.fullmatch(request_id):
        raise ValueError("bad idempotency key")
    if not isinstance(issued_at, int) or isinstance(issued_at, bool) or issued_at < 0:
        raise ValueError("bad issue time")
    removed = 0
    with LOCK:
        database = load_board_database()
        for day in database["days"].values():
            if uid_hash in day["entries"]:
                del day["entries"][uid_hash]
                removed += 1
            day["seen"] = {
                key: value for key, value in day["seen"].items()
                if value["u"] != uid_hash
            }
        atomic_save(BOARD_DB, database)
    return removed


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
        origin = self.headers.get("Origin", "")
        if origin in ALLOWED_ORIGINS:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.send_header("Access-Control-Max-Age", "600")

    def _json(self, code, value):
        body = json.dumps(value, separators=(",", ":")).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self._cors()
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _payload_raw(self, maximum):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not (0 < length <= maximum):
                raise ValueError("bad size")
            raw_body = self.rfile.read(length)
            return raw_body, json.loads(raw_body)
        except (ValueError, TypeError, UnicodeDecodeError, json.JSONDecodeError):
            raise ValueError("bad json")

    def _payload(self, maximum):
        return self._payload_raw(maximum)[1]

    def do_OPTIONS(self):
        origin = self.headers.get("Origin", "")
        if origin and origin not in ALLOWED_ORIGINS:
            return self._json(403, {"err": "origin denied"})
        self.send_response(204)
        self._cors()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/health":
            return self._json(200, {
                "ok": True,
                "analytics": "aggregate-v1",
                "board": "authenticated-v2",
                "boardWritesReady": bool(BOARD_HMAC_SECRET),
            })
        if parsed.path == "/api/daily":
            query = parse_qs(parsed.query)
            date = (query.get("date") or [utc_date()])[0]
            if not DATE_RE.fullmatch(date):
                return self._json(400, {"err": "bad date"})
            try:
                with LOCK:
                    board = load_board_database()
                    day = board["days"].get(date, {"entries": {}})
                    return self._json(200, {
                        "date": date,
                        "top": top(day["entries"].values()),
                    })
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
        if path == "/api/daily":
            # Public client-authored scores are intentionally disabled. New
            # clients call the Auth + App Check protected Firebase function.
            return self._json(401, {"err": "authenticated submission required"})
        if path not in ("/api/internal/daily", "/api/internal/delete-user"):
            return self._json(404, {"err": "not found"})
        try:
            raw_body, payload = self._payload_raw(1_024)
            timestamp_text = self.headers.get("X-Wildcard-Timestamp", "")
            signature = self.headers.get("X-Wildcard-Signature", "")
            validate_signed_request(raw_body, timestamp_text, signature)
            if payload.get("issuedAt") != int(timestamp_text) * 1000:
                raise ValueError("timestamp mismatch")
        except ValueError:
            return self._json(401, {"err": "invalid signature"})
        except StoreError:
            return self._json(503, {"err": "board writes unavailable"})
        if path == "/api/internal/delete-user":
            try:
                removed = delete_board_user(payload)
                return self._json(200, {"ok": True, "removedDays": removed})
            except ValueError:
                return self._json(400, {"err": "bad deletion request"})
            except (OSError, StoreError):
                return self._json(503, {"err": "store unavailable"})
        try:
            _date, _name, _score, uid_hash, request_id, _issued_at = validate_board_submission(payload)
        except ValueError:
            return self._json(400, {"err": "bad submission"})
        # Let exact retries reach the idempotency ledger even if the caller has
        # reached the per-minute cap; Firebase also independently rate-limits.
        try:
            with LOCK:
                board = load_board_database()
                duplicate = request_id in board["days"].get(
                    payload["date"], {"seen": {}}
                )["seen"]
        except StoreError:
            return self._json(503, {"err": "store unavailable"})
        if not duplicate and not board_rate_ok(uid_hash):
            return self._json(429, {"err": "busy"})
        try:
            leaders, entry, replayed = record_board_submission(payload)
            rank = next(
                (
                    index + 1
                    for index, leader in enumerate(leaders)
                    if leader["n"] == entry["n"]
                ),
                0,
            )
            return self._json(200, {
                "date": payload["date"],
                "top": leaders,
                "you": {"n": entry["n"], "s": entry["s"]},
                "rank": rank,
                "replayed": replayed,
            })
        except BoardConflictError:
            return self._json(409, {"err": "name or request conflict"})
        except BoardCapacityError:
            return self._json(429, {"err": "day full"})
        except (OSError, StoreError):
            return self._json(503, {"err": "store unavailable"})


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8090), Handler).serve_forever()
