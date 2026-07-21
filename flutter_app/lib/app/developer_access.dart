import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../domain/account_state.dart';

/// Local developer state is deliberately stored as an unknown legacy-save
/// field so a debug install can keep its tools across restarts without
/// changing the public save schema.
const String developerUnlockedField = 'flutterDeveloperUnlocked';
const String developerGauntletField = 'flutterDeveloperGauntlet';
const String developerBaselineField = 'flutterDeveloperBaseline';
const String developerCoinGrantField = 'flutterDeveloperCoinGrant';
const String developerJokerGrantField = 'flutterDeveloperJokerGrant';

// This is the SHA-256 of the existing local tester code. The code itself is
// intentionally never stored in Flutter source. All references to this value
// are behind kDebugMode and are tree-shaken from release builds.
const String _developerCodeDigest =
    '7df11fa33b21c72c35d01b5b5606b28c4ec7028a29b2f5c3aa0796e17f744108';

bool developerToolsUnlocked(AccountState account) =>
    kDebugMode && account.unknownFields[developerUnlockedField] == true;

bool developerGauntletUnlocked(AccountState account) =>
    developerToolsUnlocked(account) &&
    account.unknownFields[developerGauntletField] == true;

bool developerCodeMatches(String input) {
  if (!kDebugMode) return false;
  return digestMatches(input: input, expectedDigest: _developerCodeDigest);
}

/// Captures the real player account immediately before local test tools can
/// mutate it. Debug gameplay then stays useful across restarts, while a later
/// Play/release upgrade can restore the exact pre-test account instead of
/// uploading granted coins, Jokers or test statistics to Firebase.
void captureDeveloperBaseline(AccountState account) {
  if (!kDebugMode || account.unknownFields[developerBaselineField] is String) {
    return;
  }
  account.unknownFields[developerBaselineField] = account.encode();
}

/// Returns a release-safe account. The returned object differs from [account]
/// only when developer metadata is present and [releaseBuild] is true.
///
/// The grant ledgers are a fallback for early debug builds that predate the
/// full baseline snapshot.
AccountState releaseSafeDeveloperAccount(
  AccountState account, {
  bool releaseBuild = !kDebugMode,
}) {
  if (!releaseBuild) return account;
  final fields = account.unknownFields;
  final hasDeveloperState =
      fields.containsKey(developerUnlockedField) ||
      fields.containsKey(developerGauntletField) ||
      fields.containsKey(developerBaselineField) ||
      fields.containsKey(developerCoinGrantField) ||
      fields.containsKey(developerJokerGrantField);
  if (!hasDeveloperState) return account;

  AccountState restored = account;
  final baseline = fields[developerBaselineField];
  if (baseline is String && baseline.isNotEmpty) {
    try {
      restored = AccountState.decode(baseline);
    } on FormatException {
      // Fall through to the bounded grant ledger below.
    }
  }
  if (identical(restored, account)) {
    final grantedCoins = switch (fields[developerCoinGrantField]) {
      int value => value,
      num value => value.floor(),
      _ => 0,
    };
    restored.coins = (restored.coins - grantedCoins.clamp(0, 9999999)).clamp(
      0,
      9999999,
    );
    final grantedJokers = fields[developerJokerGrantField];
    if (grantedJokers is List) {
      restored.unlockedJokerIds.removeAll(grantedJokers.whereType<String>());
    }
  }
  restored.unknownFields.remove(developerUnlockedField);
  restored.unknownFields.remove(developerGauntletField);
  restored.unknownFields.remove(developerBaselineField);
  restored.unknownFields.remove(developerCoinGrantField);
  restored.unknownFields.remove(developerJokerGrantField);
  return restored;
}

void resetDeveloperFirstRunState(AccountState account) {
  if (!developerToolsUnlocked(account)) return;
  account.tutorialDone = false;
  account.firstRunStarted = false;
  account.firstLossCoached = false;
  account.tutorialChestClaimed = false;
  // Keep the one-time grant marker so this reset can never mint that reward.
  account.starterGiftClaimed = true;
}

@visibleForTesting
bool digestMatches({required String input, required String expectedDigest}) {
  final normalized = input.trim().toLowerCase();
  if (normalized.isEmpty || expectedDigest.length != 64) return false;
  final actual = sha256.convert(utf8.encode(normalized)).toString();

  // Avoid an early-return comparison even though this is only a local debug
  // gate. It keeps validation behavior stable for differently placed errors.
  var mismatch = 0;
  for (var index = 0; index < actual.length; index++) {
    mismatch |= actual.codeUnitAt(index) ^ expectedDigest.codeUnitAt(index);
  }
  return mismatch == 0;
}
