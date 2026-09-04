import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/core/app_constants.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/astra_journey.dart';
import 'package:wildcard/domain/astra_progression.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wildcard/services/pi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!astraEnabled) return;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Journey claim survives restart and cannot double-award', () async {
    final app = await AppController.bootstrap();
    addTearDown(app.dispose);
    expect(await app.claimAstraMilestone('first_heat'), 0);
    app.account.bestClearedHeat = 1;
    final rewards = await Future.wait([
      app.claimAstraMilestone('first_heat'),
      app.claimAstraMilestone('first_heat'),
    ]);
    expect(rewards.reduce((a, b) => a + b), 20);
    expect(app.account.coins, 20);
    final preferences = await SharedPreferences.getInstance();
    final saved = AccountState.decode(
      preferences.getString(AppConstants.legacyAccountKey)!,
    );
    expect(saved.coins, 20);
    expect(saved.unknownFields[astraJourneyClaimKey], contains('first_heat'));
    final restored = await AppController.bootstrap();
    addTearDown(restored.dispose);
    expect(await restored.claimAstraMilestone('first_heat'), 0);
    expect(restored.account.coins, 20);
  });

  test('full developer wallet does not consume a Journey claim', () async {
    final app = await AppController.bootstrap();
    addTearDown(app.dispose);
    app.account.coins = 9999999;
    app.account.bestClearedHeat = 1;
    await expectLater(app.claimAstraMilestone('first_heat'), throwsStateError);
    expect(app.astraJourney.first.claimed, isFalse);
    expect(app.account.coins, 9999999);
  });

  test(
    'Astra services never initialize production SDKs or analytics',
    () async {
      final app = await AppController.bootstrap();
      addTearDown(app.dispose);
      await app.startConsentGatedServices();
      expect(app.onlineServicesStarted, isFalse);
      expect(await app.firebase.initializeAfterPrivacyAcceptance(), isFalse);
      expect(await app.billing.initializeAfterPrivacyAcceptance(), isFalse);
      expect(await app.billing.buy('coins_250'), isFalse);
      expect(await app.ads.initializeAfterPrivacyAcceptance(), isFalse);
      expect(await app.playGames.initializeAfterPrivacyAcceptance(), isFalse);
      expect(await app.playGames.signIn(), isFalse);
      expect(app.rewardedViewsLeftToday, 0);
      expect(app.effectiveNoAds, isTrue);
      expect(app.account.noAds, isFalse); // No forged paid entitlement.
      var requests = 0;
      final pi = PiService(
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(pi.dispose);
      pi.queueAppOpen();
      pi.queueRunStart('normal');
      await pi.flushAnalytics();
      expect((await pi.fetchDailyBoard()).entries, isEmpty);
      expect(requests, 0);
    },
  );
}
