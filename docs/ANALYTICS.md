# WILDCARD Pi analytics

WILDCARD uses a deliberately small, self-hosted analytics path for directional internal-test feedback. It does not use Firebase Analytics and it is not part of scoring, saving, ads, purchases, cloud backup or leaderboard truth.

## What the game sends

The client has a fixed allowlist of three events:

- `app_open`
- `run_start`, with `normal`, `daily` or `gauntlet` mode
- `run_end`, with mode, `won`/`lost`/`terminated`, and a broad Heat band (`1-3`, `4-6`, `7-9`, `10-12`, or `13+`)

Endless is the continuation of a Normal run rather than a second run. It therefore remains `normal`; the `13+` Heat band shows that the run reached Endless without creating unmatched start/end totals.

The compact wire payload is versioned and platform-labelled:

```json
{"v":"6.9.10","p":"android","events":[{"n":"run_start","m":"normal"}]}
```

Unknown fields and values are rejected. A batch is capped at 12 events and 4 KiB.

The payload never contains a player or board name, email address, Firebase/Google/Play Games identity, advertising ID, install/device/session/run identifier, device model, IP address, user agent, cards, Jokers, coins, save data, purchase data, exact timestamp or exact score.

## Performance and failure behaviour

Events enter a bounded in-memory array. There is no disk write on the phone and no work in the scoring loop. A batch is attempted through a non-blocking `fetch` with `keepalive`, omitted credentials and no referrer during browser idle time or when the app moves to the background. Nothing awaits the request, failures are ignored, and offline play is unchanged.

The queue is intentionally not durable. Missing events are preferable to gameplay cost or hidden tracking state.

## Pi storage

`deploy/wildcard-api.py` validates each batch and immediately increments marginal daily counters in `~/wildcard-analytics.json`. It does not create a raw-event table or history. The file is written atomically with mode `0600`; aggregates older than 90 UTC days are removed on the next successful analytics write. A global identifier-free guard accepts at most 60 analytics batches per minute and 20,000 events per day. Only explicitly shipped app versions are accepted, which prevents attacker-controlled dimension growth.

There is no public analytics read endpoint. The owner can read the counters over SSH:

```bash
ssh wildcard-pi '~/wildcard-analytics-report --days 14'
```

These counters can support event totals and rough run-start/run-end ratios. They cannot support daily active users, unique installs, retention, cohorts or per-player funnels because no stable identity exists. Client events are forgeable, so they must never grant rewards or establish leaderboard results.

## Daily Board security boundary

Anonymous analytics and the custom Daily Board share one small HTTP service but
not one trust model. Public clients can read `/api/daily`; public score writes
are rejected. Authenticated, App Check protected Firebase Functions validate
the account, current UTC date, board-name ownership, rate window and
idempotency key before forwarding an HMAC-signed server-to-server write to
`/api/internal/daily`. The Pi stores only a SHA-256 account reference, board
name, best score and bounded idempotency ledger. It never receives a Firebase
UID or email address.

This prevents anonymous posting, casual name impersonation, date-window abuse,
browser CORS abuse and simple flooding. It does not make a client-computed
score authoritative. Daily Board coin prizes remain disabled until a reviewed
server-verifiable run attestation or replay design exists.

## Website page counts and transport logs

The Pi web deployer separately injects self-hosted GoatCounter for website page-load counts. GoatCounter page loads and the product events above are different measurements and must not be added together as “users”.

The current nginx installation keeps its standard rotated access log, which can temporarily contain transport/request metadata such as a browser user agent. Analytics request bodies are not written to that log or to GoatCounter. Before a public production launch, nginx should use an exact analytics location with access logging disabled, a 1 KiB body cap and an nginx rate limit; the Pi services should also be moved away from the SSH/deploy user into hardened dedicated service accounts. Those changes require administrator privileges and are tracked as release hardening, not client code.

## Privacy and release checks

The in-game and hosted privacy policies disclose the aggregate counters. Any Google Play Data Safety answers and the public privacy-policy URL must be reviewed after the final production server configuration is in place. Firebase Analytics remains disabled.

Run these checks after changing the analytics contract:

```bash
python tools/test-pi-analytics.py
npm test
```
