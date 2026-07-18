const fs = require('fs');

const expected = {
  packageName: 'com.nisarg.wildcard',
  versionName: '6.9.11',
  versionCode: 31,
  projectId: 'wildcard-31d50',
  projectNumber: '420107184674',
  leaderboardId: 'CgkIotTbgp0MEAIQAQ',
  directSha1: 'E05C179491ACEE689AA1E03A63D979DED95B05C0',
  playSha1: '25EC6C50C281981E59A79F2923CAE1B6DA04349D'
};

const gradle = fs.readFileSync('android/app/build.gradle', 'utf8');
const strings = fs.readFileSync('android/app/src/main/res/values/strings.xml', 'utf8');
const manifest = fs.readFileSync('android/app/src/main/AndroidManifest.xml', 'utf8');
const services = JSON.parse(fs.readFileSync('android/app/google-services.json', 'utf8'));

function match(text, pattern) {
  const found = text.match(pattern);
  return found ? found[1] : '';
}
function normalizeSha(value) {
  return String(value || '').replace(/[^a-f0-9]/gi, '').toUpperCase();
}
function collectOauth(value, out = []) {
  if (Array.isArray(value)) value.forEach(item => collectOauth(item, out));
  else if (value && typeof value === 'object') {
    if (Object.prototype.hasOwnProperty.call(value, 'client_type')) out.push(value);
    Object.values(value).forEach(item => collectOauth(item, out));
  }
  return out;
}

const androidOauth = collectOauth(services).filter(client =>
  Number(client.client_type) === 1 && client.android_info
);
const sha1s = [...new Set(androidOauth.map(client => normalizeSha(client.android_info.certificate_hash)))];
const packageName = match(gradle, /applicationId\s+["']([^"']+)["']/);
const versionName = match(gradle, /versionName\s+["']([^"']+)["']/);
const versionCode = Number(match(gradle, /versionCode\s+(\d+)/));
const appId = match(strings, /name="game_services_project_id"[^>]*>([^<]+)</);
const leaderboardId = match(strings, /name="leaderboard_high_score"[^>]*>([^<]+)</);
const firebasePackages = (services.client || []).map(client =>
  client.client_info && client.client_info.android_client_info && client.client_info.android_client_info.package_name
).filter(Boolean);

const hardChecks = {
  packageName: packageName === expected.packageName,
  releaseVersion: versionName === expected.versionName && versionCode === expected.versionCode,
  firebasePackage: firebasePackages.includes(expected.packageName),
  firebaseProject: services.project_info && services.project_info.project_id === expected.projectId,
  projectNumber: services.project_info && services.project_info.project_number === expected.projectNumber,
  playGamesAppId: appId === expected.projectNumber,
  leaderboardId: leaderboardId === expected.leaderboardId,
  manifestAppIdReference: manifest.includes('android:name="com.google.android.gms.games.APP_ID"') && manifest.includes('android:value="@string/game_services_project_id"')
};

const report = {
  repositoryRelease: { versionName, versionCode },
  identifiers: {
    packageName,
    firebaseProject: services.project_info && services.project_info.project_id,
    projectNumber: services.project_info && services.project_info.project_number,
    playGamesAppId: appId,
    leaderboardId
  },
  firebaseAndroidOauth: {
    clientCount: androidOauth.length,
    directSigningSha1Present: sha1s.includes(expected.directSha1),
    playSigningSha1Present: sha1s.includes(expected.playSha1),
    note: 'google-services.json supports Firebase Google Auth. Play Games Services credentials must be checked separately in Play Console.'
  },
  playGamesConsole: {
    state: 'not-verifiable-from-repository',
    requiredChecks: [
      'Android credential linked for direct/upload signing SHA-1',
      'Android credential linked for Google Play app-signing SHA-1',
      'leaderboard published or available to testers',
      'owner/test account or Internal testing track enabled in Play Games Services Testers',
      'Play Games Services draft changes published to testers'
    ]
  },
  hardChecks,
  failures: Object.entries(hardChecks).filter(([, ok]) => !ok).map(([name]) => name),
  warnings: []
};

if (!report.firebaseAndroidOauth.playSigningSha1Present) {
  report.warnings.push('The committed google-services.json does not contain the Play app-signing SHA-1 Android OAuth client; add that SHA-1 to the Firebase Android app and download a fresh file before testing Firebase Auth in a Play-signed build.');
}
console.log(JSON.stringify(report, null, 2));
if (report.failures.length) process.exitCode = 1;
