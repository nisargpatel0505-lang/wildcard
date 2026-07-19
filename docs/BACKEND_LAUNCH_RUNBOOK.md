# WILDCARD backend launch runbook

This runbook stages the authenticated Daily Board, account deletion and
server-verified Google Play Billing backend. Do not enable Daily Board coin
prizes: the authenticated Daily score remains client-computed.

## 1. Pre-deployment tests

From the repository root:

```powershell
npm --prefix functions install
npm --prefix functions test
python tools/test-pi-analytics.py
npm run test:rules
npx firebase-tools emulators:exec --only functions --project wildcard-31d50 "npm --prefix functions test"
```

## 2. One shared Daily Board secret

Generate one random value of at least 32 bytes. Never commit or email it.

```bash
openssl rand -hex 32
```

Enter that same value when Firebase prompts:

```powershell
npx firebase-tools login
npx firebase-tools use wildcard-31d50
npx firebase-tools functions:secrets:set WILDCARD_BOARD_HMAC_SECRET
```

On the Pi, place the same value in a private service environment file. The
current service runs as `Npatel`, so the rootless path is preferred and does
not require a systemd edit:

```bash
install -d -m 0700 /home/Npatel/.config
install -m 0600 /dev/null /home/Npatel/.config/wildcard-api.env
nano /home/Npatel/.config/wildcard-api.env
```

The file must contain one line:

```text
WILDCARD_BOARD_HMAC_SECRET=PASTE_THE_SECRET_HERE
```

`wildcard-api.py` verifies this file is a regular file with no group/world
permissions before reading it. If the service user or layout changes, use the
root-managed alternative instead:

```bash
sudo install -m 0600 /dev/null /etc/wildcard-api.env
sudoedit /etc/wildcard-api.env
```

That file contains the same one line:

```text
WILDCARD_BOARD_HMAC_SECRET=PASTE_THE_SECRET_HERE
```

Add the environment file to the existing service:

```bash
sudo systemctl edit wildcard-api.service
```

Enter:

```ini
[Service]
EnvironmentFile=/etc/wildcard-api.env
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart wildcard-api.service
curl -fsS http://127.0.0.1:8090/api/health
```

The new API reports `"board":"authenticated-v2"` and
`"boardWritesReady":true`. The source-controlled Pi updater refuses to keep the
new API if the secret is missing.

The former board contains unauthenticated rows that cannot be made trustworthy.
Version 2 deliberately starts a clean trusted board instead of migrating those
scores. The updater still makes a timestamped backup of the old JSON file for
audit/rollback; never re-import its rows into the production ranking.

## 3. Required Google/Firebase console setup

The Functions runtime is Node.js 22 in `europe-west2`. The Firebase project
must remain on Blaze.

Enable the APIs used by Functions, Scheduler, Pub/Sub and Play verification:

```powershell
gcloud services enable cloudfunctions.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com run.googleapis.com eventarc.googleapis.com pubsub.googleapis.com cloudscheduler.googleapis.com androidpublisher.googleapis.com --project=wildcard-31d50
```

Grant limited-use App Check token consumption to the second-generation default
runtime identity:

```powershell
gcloud projects add-iam-policy-binding wildcard-31d50 --member="serviceAccount:420107184674-compute@developer.gserviceaccount.com" --role="roles/firebaseappcheck.tokenVerifier"
```

In Firebase Console:

1. App Check → Apps → `com.nisarg.wildcard` → select Play Integrity.
2. Distribute an internal Play build and verify valid App Check metrics.
3. Only then enable enforcement for callable Functions.

Create the Google Play Billing notification topic:

```powershell
gcloud pubsub topics create wildcard-play-billing --project=wildcard-31d50
gcloud pubsub topics add-iam-policy-binding wildcard-play-billing --project=wildcard-31d50 --member="serviceAccount:google-play-developer-notifications@system.gserviceaccount.com" --role="roles/pubsub.publisher"
```

In Play Console:

1. Link/confirm Google Cloud project `wildcard-31d50`.
2. Give the Functions runtime service account access to the Play Developer API
   and the minimum order/purchase-view permissions required to verify one-time
   products.
3. Monetize → Monetization setup → Real-time developer notifications: enter
   `projects/wildcard-31d50/topics/wildcard-play-billing`, send a test
   notification and confirm it arrives.
4. Create and activate the exact one-time product IDs used by the server:
   `coins_250`, `coins_600`, `coins_1600`, `coins_3600`, `coins_8500`,
   `remove_ads`. Configure localized prices in Play Console; the client must
   display Play's returned offer metadata, not hardcoded GBP.

Enable expiry of Daily Board idempotency records:

```powershell
gcloud firestore fields ttls update expiresAt --collection-group=requests --enable-ttl --project=wildcard-31d50
```

## 4. Deploy Firebase resources

No deployment occurs merely by committing these files. After the console work
above and a successful internal App Check test:

```powershell
npx firebase-tools deploy --only firestore:rules --project wildcard-31d50
npx firebase-tools deploy --only functions --project wildcard-31d50
npx firebase-tools deploy --only hosting --project wildcard-31d50
```

Verify:

- the Functions list contains `submitDailyScore`, `deleteMyAccount`,
  `retryBoardDeletions`, `verifyPlayPurchase`,
  `markPlayPurchaseDelivered`, `getPlayEntitlements` and
  `playBillingNotification`;
- `https://wildcard-31d50.web.app/account-deletion.html` loads;
- that exact URL is entered in Play Console's account-deletion field;
- direct Firestore client reads/writes to board and billing collections fail.

Account deletion removes Firebase Auth, cloud saves, board records and raw
purchase tokens. The billing backend deliberately retains only a pseudonymised
product/order/token-hash ledger for fraud, duplicate-grant prevention and
accounting; this retention is disclosed on the deletion page and must also
match the final privacy policy and Play Data safety answers.

## 5. Deploy the Pi API

After review, commit and push the backend files to `main`, then run:

```powershell
ssh wildcard-pi '~/update-wildcard-from-github.sh'
```

Verify from the Pi and from Windows:

```bash
curl -fsS http://127.0.0.1:8090/api/health
curl -fsS 'http://127.0.0.1:8090/api/daily'
```

```powershell
curl.exe -fsS https://raspberrypi.tail20f574.ts.net/api/health
curl.exe -i -X POST https://raspberrypi.tail20f574.ts.net/api/daily -H "Content-Type: application/json" -d "{}"
```

The public POST must return `401 authenticated submission required`.

## 6. Required app integration before release

The production app must:

- call `submitDailyScore` with Firebase Auth and a limited-use Play Integrity
  App Check token, passing only `name`, `score` and `idempotencyKey`, and
  reusing the same idempotency key on retries. The server assigns the UTC date;
  the client must not send or choose it. A signed retry may preserve the
  preceding UTC day if an outage crosses midnight;
- call `deleteMyAccount` from a discoverable Settings control after a clear
  destructive confirmation;
- verify every Play purchase with `verifyPlayPurchase`, durably save the grant
  plus token hash, call `markPlayPurchaseDelivered`, and only then finish the
  Billing purchase;
- restore `getPlayEntitlements` and reconcile returned verified hashes without
  granting a token twice;
- continue to show no Daily Board coin prize.

App Check and Authentication attest the build/device and account. They do not
prove the submitted gameplay score. Real score prizes require a separate
server-replay or server-issued run attestation design.
