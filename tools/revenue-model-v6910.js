const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = path.resolve(__dirname, '..');
const htmlPath = path.join(root, 'www', 'index.html');
const bridgePath = path.join(root, 'www', 'native-bridge.js');
const html = fs.readFileSync(htmlPath, 'utf8');
const bridge = fs.readFileSync(bridgePath, 'utf8');
const version = (html.match(/>v(\d+\.\d+(?:\.\d+)?)<\/b>/) || [])[1] || 'unknown';
const sourceSha256 = crypto.createHash('sha256').update(Buffer.from(html)).digest('hex');
const scriptSha256 = crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex');

function assert(ok, message) { if (!ok) throw new Error(message); }
function money(value) { return Math.round(value * 100) / 100; }

const rewardedDemoId = 'ca-app-pub-3940256099942544/5224354917';
const interstitialDemoId = 'ca-app-pub-3940256099942544/1033173712';
const appDemoId = 'ca-app-pub-3940256099942544~3347511713';
const manifest = fs.readFileSync(path.join(root, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'), 'utf8');
const demoAds = html.includes(rewardedDemoId) && html.includes(interstitialDemoId) &&
  bridge.includes(rewardedDemoId) && bridge.includes(interstitialDemoId) &&
  manifest.includes(appDemoId) && html.includes('var AD_TESTING = true') && bridge.includes('var AD_TESTING = true');
assert(demoAds, 'Expected Google demo AdMob configuration was not found; review the model before using it');

const bundleBlock = html.match(/const COIN_BUNDLES=\[([\s\S]*?)\];/);
assert(bundleBlock, 'Coin bundle catalogue missing');
const bundles = [...bundleBlock[1].matchAll(/\{coins:(\d+),\s*gbp:'([\d.]+)',\s*label:'([^']+)'/g)]
  .map(match => ({ productId: `coins_${match[1]}`, coins: Number(match[1]), gbp: Number(match[2]), label: match[3] }));
assert(bundles.length === 5, 'Expected five coin bundles');
const removeAds = { productId: 'remove_ads', gbp: 2.99 };

// These are explicit planning sensitivities, not observed WILDCARD telemetry or
// guaranteed AdMob rates. Update them once the internal test has real cohort data.
const scenarios = [
  {
    id: 'low', label: 'Low', fillRate: 0.75,
    rewardedViewsPerDauDay: 1.0, rewardedEcpmGbp: 5,
    interstitialViewsPerDauDay: 1.5, interstitialEcpmGbp: 1.5,
    mauPerDau: 2.0, monthlyPayerRate: 0.003, grossMonthlyArppuGbp: 3,
    playFeeRate: 0.30
  },
  {
    id: 'base', label: 'Base', fillRate: 0.90,
    rewardedViewsPerDauDay: 1.8, rewardedEcpmGbp: 10,
    interstitialViewsPerDauDay: 2.5, interstitialEcpmGbp: 4,
    mauPerDau: 3.0, monthlyPayerRate: 0.008, grossMonthlyArppuGbp: 5,
    playFeeRate: 0.25
  },
  {
    id: 'high', label: 'High', fillRate: 0.95,
    rewardedViewsPerDauDay: 2.5, rewardedEcpmGbp: 15,
    interstitialViewsPerDauDay: 3.5, interstitialEcpmGbp: 8,
    mauPerDau: 4.0, monthlyPayerRate: 0.015, grossMonthlyArppuGbp: 7,
    playFeeRate: 0.15
  }
];

const dauLevels = [50, 200, 1000, 10000];
function project(dau, scenario) {
  const dailyRewarded = dau * scenario.rewardedViewsPerDauDay * scenario.fillRate * scenario.rewardedEcpmGbp / 1000;
  const dailyInterstitial = dau * scenario.interstitialViewsPerDauDay * scenario.fillRate * scenario.interstitialEcpmGbp / 1000;
  const monthlyAds = 30 * (dailyRewarded + dailyInterstitial);
  const estimatedMau = dau * scenario.mauPerDau;
  const monthlyPayers = estimatedMau * scenario.monthlyPayerRate;
  const grossIap = monthlyPayers * scenario.grossMonthlyArppuGbp;
  const iapAfterPlayFee = grossIap * (1 - scenario.playFeeRate);
  return {
    scenario: scenario.id, dau, estimatedMau: money(estimatedMau), monthlyPayers: money(monthlyPayers),
    monthlyRewardedAdsGbp: money(30 * dailyRewarded),
    monthlyInterstitialAdsGbp: money(30 * dailyInterstitial),
    monthlyAdsGbp: money(monthlyAds), grossMonthlyIapGbp: money(grossIap),
    monthlyIapAfterPlayFeeGbp: money(iapAfterPlayFee),
    monthlyTotalBeforeTaxRefundsGbp: money(monthlyAds + iapAfterPlayFee),
    monthlyRevenuePerDauGbp: money((monthlyAds + iapAfterPlayFee) / dau)
  };
}

const projections = scenarios.flatMap(scenario => dauLevels.map(dau => project(dau, scenario)));
const result = {
  model: 'scenario-sensitivity-v1', version, generatedAt: new Date().toISOString(),
  source: 'www/index.html', sourceSha256,
  script: 'tools/revenue-model-v6910.js', scriptSha256,
  currentConfiguration: {
    demoAdMobIds: demoAds,
    adTesting: true,
    currentProductionAdRevenueGbp: 0,
    billingProductsConfiguredInSource: [...bundles, removeAds],
    playConsoleProductActivationVerified: false
  },
  caveats: [
    'Ad eCPMs, fill, view frequency, MAU/DAU, payer conversion and ARPPU are planning assumptions, not WILDCARD telemetry.',
    'IAP projections apply the scenario Play fee but exclude VAT/tax, refunds, chargebacks and foreign exchange.',
    'The app currently uses Google demo AdMob IDs with test mode enabled, so current production ad revenue is zero.',
    'Play Console activation and live pricing of the six billing products cannot be proven from repository source.'
  ],
  officialReferences: {
    admobTestAds: 'https://developers.google.com/admob/android/test-ads',
    playFees: 'https://support.google.com/googleplay/android-developer/answer/112622',
    playClosedTesting: 'https://support.google.com/googleplay/android-developer/answer/14151465',
    admobThresholds: 'https://support.google.com/admob/answer/2772208'
  },
  scenarios, dauLevels, projections
};

const tableRows = dauLevels.map(dau => {
  const values = scenarios.map(s => projections.find(p => p.dau === dau && p.scenario === s.id).monthlyTotalBeforeTaxRefundsGbp);
  return `| ${dau.toLocaleString()} | £${values[0].toLocaleString()} | £${values[1].toLocaleString()} | £${values[2].toLocaleString()} |`;
}).join('\n');
const report = `# WILDCARD v${version} Revenue Sensitivity

This is a planning model, not a forecast. The current build uses Google's demo AdMob IDs and test mode, so its production ad revenue is **£0** until owner-created AdMob IDs are configured and approved.

## Monthly scenario output

| Daily active players | Low | Base | High |
| ---: | ---: | ---: | ---: |
${tableRows}

Totals combine modeled rewarded/interstitial ads and modeled IAP proceeds after the scenario Play fee, but before VAT/tax, refunds, chargebacks and foreign exchange.

## Assumptions

${scenarios.map(s => `- **${s.label}:** ${s.fillRate*100}% fill; ${s.rewardedViewsPerDauDay} rewarded views at £${s.rewardedEcpmGbp} eCPM; ${s.interstitialViewsPerDauDay} interstitial views at £${s.interstitialEcpmGbp} eCPM per DAU/day; MAU/DAU ${s.mauPerDau}; ${(s.monthlyPayerRate*100).toFixed(1)}% monthly payer conversion; £${s.grossMonthlyArppuGbp} gross monthly ARPPU; ${(s.playFeeRate*100).toFixed(0)}% Play fee.`).join('\n')}

## Source catalogue

${bundles.map(b => `- ${b.productId}: ${b.coins.toLocaleString()} coins at £${b.gbp.toFixed(2)} in source`).join('\n')}
- remove_ads: £${removeAds.gbp.toFixed(2)} in source

Source SHA-256: \`${sourceSha256}\`

Model SHA-256: \`${scriptSha256}\`
`;

const releaseDir = path.join(root, 'docs', 'release');
const jsonPath = path.join(releaseDir, `wildcard-v${version}-revenue-sensitivity.json`);
const reportPath = path.join(releaseDir, `wildcard-v${version}-revenue-sensitivity.md`);
fs.writeFileSync(jsonPath, JSON.stringify(result, null, 2));
fs.writeFileSync(reportPath, report);
const downloads = path.join(process.env.USERPROFILE || path.dirname(root), 'Downloads');
fs.writeFileSync(path.join(downloads, path.basename(jsonPath)), JSON.stringify(result, null, 2));
fs.writeFileSync(path.join(downloads, path.basename(reportPath)), report);
console.log(JSON.stringify({ jsonPath, reportPath, currentAdRevenueGbp: 0, projections }, null, 2));
