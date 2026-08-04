abstract final class AppConstants {
  static const appName = 'WILDCARD';
  static const firebaseProjectId = 'wildcard-31d50';
  static const firebaseRegion = 'europe-west2';
  static const androidPackageName = 'com.nisarg.wildcard';

  static const piOrigin = 'https://raspberrypi.tail20f574.ts.net';
  static const dailyBoardUrl = '$piOrigin/api/daily';
  static const analyticsUrl = '$piOrigin/api/analytics';
  static const privacyPolicyUrl = 'https://wildcard-31d50.web.app/privacy.html';
  static const accountDeletionUrl =
      'https://wildcard-31d50.web.app/account-deletion.html';

  static const playGamesProjectId = '420107184674';
  static const highScoreLeaderboardId = 'CgkIotTbgp0MEAIQAQ';

  static const productionAdMobAppId = 'ca-app-pub-3855192091371080~7622357185';
  static const productionRewardedAdId =
      'ca-app-pub-3855192091371080/3551964243';
  static const productionInterstitialAdId =
      'ca-app-pub-3855192091371080/2034300223';

  static const testAdMobAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const testRewardedAdId = 'ca-app-pub-3940256099942544/5224354917';
  static const testInterstitialAdId = 'ca-app-pub-3940256099942544/1033173712';

  static const playProductIds = <String>{
    'coins_250',
    'coins_600',
    'coins_1600',
    'coins_3600',
    'coins_8500',
    'remove_ads',
  };

  static const playCoinGrants = <String, int>{
    'coins_250': 250,
    'coins_600': 600,
    'coins_1600': 1600,
    'coins_3600': 3600,
    'coins_8500': 8500,
  };

  static const legacyAccountKey = 'wildcard_save_v1';
  static const legacyRunKey = 'wildcard_run_v1';
  static const privacyAcceptedKey = 'wildcard_privacy_accept_v1';
  static const privacyPolicyVersion = '2026-07-21-v1';
  static const cloudOwnerKey = 'wildcard_cloud_owner_v2';
  static const migrationMarkerKey = 'flutter_legacy_migration_v1';
  static const dailyScoreOutboxKey = 'flutter_daily_score_outbox_v1';
}
