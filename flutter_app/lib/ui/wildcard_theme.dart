import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The visual themes recovered from the v7.1.0 phone build.
enum WildcardThemeId {
  classic,
  sunset,
  ice,
  neonElite,
  midas,
  vaporwave,
  bloodMoon,
  cosmicWilds,
  neonHeist,
  moonlitMasquerade,
  emberCasino,
  emeraldThrone,
  hauntedCarnival,
  clockworkRoyale,
  blockDropArcade,
  abyssalJackpot,
  desertMirage,
  heartsKingdom,
  spadesKingdom,
  diamondsKingdom,
  clubsKingdom,
}

/// Every player-facing surface that must inherit the equipped UI theme.
///
/// This list is deliberately exhaustive rather than a loose collection of
/// screen names. New screens must be registered in [WildcardThemeCoverage] so
/// they cannot silently fall back to an unrelated hard-coded palette.
enum WildcardUiSurface {
  loading,
  privacyConsent,
  home,
  modePicker,
  normalGameplay,
  tutorial,
  chestVault,
  betweenHeatShop,
  accountShop,
  collection,
  wardrobe,
  settings,
  cabinet,
  achievements,
  missions,
  adBreak,
  overlay,
  dialog,
  gameOver,
  results,
  leaderboard,
  more,
}

enum WildcardBackdropRole {
  equippedTheme,
  equippedGameplayTheme,
  runSetup,
  shopRoom,
  vaultRoom,
  endlessRoom,
  houseRoom,
  none,
}

@immutable
class WildcardSurfaceThemeSpec {
  const WildcardSurfaceThemeSpec({
    required this.backdrop,
    this.usesThemePalette = true,
  });

  final WildcardBackdropRole backdrop;
  final bool usesThemePalette;
}

/// Theme-coverage contract shared by the screen frame and full-screen artwork.
///
/// Bespoke rooms (the shop, vault and boss room) retain their authored art,
/// but their tint, panels, typography, controls and overlays still come from
/// the equipped theme. Sly skins and table felts remain separate cosmetics.
abstract final class WildcardThemeCoverage {
  static const Map<WildcardUiSurface, WildcardSurfaceThemeSpec> surfaces = {
    WildcardUiSurface.loading: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.privacyConsent: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.home: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.modePicker: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.runSetup,
    ),
    WildcardUiSurface.normalGameplay: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedGameplayTheme,
    ),
    WildcardUiSurface.tutorial: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.chestVault: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.vaultRoom,
    ),
    WildcardUiSurface.betweenHeatShop: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.shopRoom,
    ),
    WildcardUiSurface.accountShop: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.shopRoom,
    ),
    WildcardUiSurface.collection: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.wardrobe: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.settings: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.cabinet: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.achievements: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.missions: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.adBreak: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.overlay: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.none,
    ),
    WildcardUiSurface.dialog: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.none,
    ),
    WildcardUiSurface.gameOver: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.results: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.leaderboard: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
    WildcardUiSurface.more: WildcardSurfaceThemeSpec(
      backdrop: WildcardBackdropRole.equippedTheme,
    ),
  };

  static WildcardSurfaceThemeSpec forSurface(WildcardUiSurface surface) =>
      surfaces[surface]!;
}

/// WILDCARD-specific colour and artwork tokens.
///
/// Keeping these in a [ThemeExtension] lets every screen use the same palette
/// without coupling widgets to a particular state-management solution.
@immutable
class WildcardThemeTokens extends ThemeExtension<WildcardThemeTokens> {
  const WildcardThemeTokens({
    required this.ink,
    required this.felt,
    required this.feltHighlight,
    required this.line,
    required this.cream,
    required this.creamDim,
    required this.gold,
    required this.mint,
    required this.coral,
    required this.violet,
    required this.rare,
    required this.wild,
    required this.panel,
    required this.panelStrong,
    required this.artTintTop,
    required this.artTintMiddle,
    required this.artTintBottom,
    required this.homeBackgroundAsset,
    this.gameplayBackgroundAsset,
  });

  final Color ink;
  final Color felt;
  final Color feltHighlight;
  final Color line;
  final Color cream;
  final Color creamDim;
  final Color gold;
  final Color mint;
  final Color coral;
  final Color violet;
  final Color rare;
  final Color wild;
  final Color panel;
  final Color panelStrong;
  final Color artTintTop;
  final Color artTintMiddle;
  final Color artTintBottom;
  final String homeBackgroundAsset;
  final String? gameplayBackgroundAsset;

  static const String palaceBackground =
      'assets/art/backgrounds/wildcard-main-menu-palace.webp';
  static const String cosmicBackground =
      'assets/art/backgrounds/wildcard-endless-victory-cosmos.webp';
  static const String shopBackground =
      'assets/art/backgrounds/wildcard-sly-shop-backroom.webp';
  static const String vaultBackground =
      'assets/art/chests/wildcard-sly-vault-room.webp';
  static const String houseBackground =
      'assets/art/backgrounds/wildcard-the-house-boss-room.webp';

  static const classic = WildcardThemeTokens(
    ink: Color(0xFF0D1A15),
    felt: Color(0xFF143028),
    feltHighlight: Color(0xFF1C4237),
    line: Color(0xFF2B5A4A),
    cream: Color(0xFFF6EFDF),
    creamDim: Color(0xFFCFC6B2),
    gold: Color(0xFFF0B94B),
    mint: Color(0xFF45E0C6),
    coral: Color(0xFFFF6B5A),
    violet: Color(0xFF9B7BFF),
    rare: Color(0xFFFF8A3D),
    wild: Color(0xFFFF4FD8),
    panel: Color(0xE60A1C19),
    panelStrong: Color(0xF5061312),
    artTintTop: Color(0x0003080C),
    artTintMiddle: Color(0x3D03080C),
    artTintBottom: Color(0xA302070A),
    homeBackgroundAsset: palaceBackground,
  );

  factory WildcardThemeTokens.forId(WildcardThemeId id) {
    switch (id) {
      case WildcardThemeId.classic:
        return classic;
      case WildcardThemeId.sunset:
        return classic.copyWith(
          mint: const Color(0xFFFF9E5C),
          gold: const Color(0xFFFFC24B),
          violet: const Color(0xFFFF6B9E),
          coral: const Color(0xFFE8564A),
          panel: const Color(0xE636161F),
          panelStrong: const Color(0xF5210D18),
          line: const Color(0x9EFF9E5C),
          artTintMiddle: const Color(0x3D381224),
          artTintBottom: const Color(0x9E160712),
        );
      case WildcardThemeId.ice:
        return classic.copyWith(
          mint: const Color(0xFF5CC8FF),
          gold: const Color(0xFFB8E3FF),
          violet: const Color(0xFF7FA8D8),
          coral: const Color(0xFF5C9BD8),
          panel: const Color(0xE60C2332),
          panelStrong: const Color(0xF5071724),
          line: const Color(0x9E5CC8FF),
          artTintMiddle: const Color(0x3D0A2E49),
          artTintBottom: const Color(0xA304121F),
        );
      case WildcardThemeId.neonElite:
        return classic.copyWith(
          mint: const Color(0xFF39FF14),
          gold: const Color(0xFFD45AFF),
          violet: const Color(0xFFC332FF),
          coral: const Color(0xFF39FF14),
          panel: const Color(0xEB0D101B),
          panelStrong: const Color(0xF705070D),
          line: const Color(0xA339FF14),
          artTintMiddle: const Color(0x47070A14),
          artTintBottom: const Color(0xA8020408),
        );
      case WildcardThemeId.midas:
        return classic.copyWith(
          mint: const Color(0xFFFFD75E),
          gold: const Color(0xFFFFC24B),
          violet: const Color(0xFFE8B04B),
          coral: const Color(0xFFFF8A3D),
          panel: const Color(0xE8302409),
          panelStrong: const Color(0xF71D1606),
          line: const Color(0xA3FFD75E),
          artTintMiddle: const Color(0x40322208),
          artTintBottom: const Color(0xA3140E04),
        );
      case WildcardThemeId.vaporwave:
        return classic.copyWith(
          mint: const Color(0xFF5CFFE0),
          gold: const Color(0xFFFF71CE),
          violet: const Color(0xFFB967FF),
          coral: const Color(0xFFFF71CE),
          panel: const Color(0xE8220E46),
          panelStrong: const Color(0xF713072D),
          line: const Color(0xA8B967FF),
          artTintMiddle: const Color(0x3D31115B),
          artTintBottom: const Color(0x9E0F0525),
        );
      case WildcardThemeId.bloodMoon:
        return classic.copyWith(
          mint: const Color(0xFFFF7676),
          gold: const Color(0xFFF2C85A),
          violet: const Color(0xFFDB3854),
          coral: const Color(0xFFFF5555),
          panel: const Color(0xE8340912),
          panelStrong: const Color(0xF71D050A),
          line: const Color(0x9EFF6B6B),
          artTintMiddle: const Color(0x45380812),
          artTintBottom: const Color(0xA3160308),
        );
      case WildcardThemeId.cosmicWilds:
        return classic.copyWith(
          mint: const Color(0xFF52F0D0),
          gold: const Color(0xFFF5BE4F),
          violet: const Color(0xFFB887FF),
          coral: const Color(0xFFFF4FD8),
          panel: const Color(0xE81A0C3B),
          panelStrong: const Color(0xF70C0622),
          line: const Color(0xA8A76BFF),
          artTintMiddle: const Color(0x3D210D4B),
          artTintBottom: const Color(0xA309041D),
          homeBackgroundAsset: cosmicBackground,
        );
      case WildcardThemeId.neonHeist:
        return classic.copyWith(
          mint: const Color(0xFF38F2FF),
          gold: const Color(0xFFFFC857),
          violet: const Color(0xFFE56AFF),
          coral: const Color(0xFFFF4F9A),
          panel: const Color(0xE80A112A),
          panelStrong: const Color(0xF7040818),
          line: const Color(0xA338F2FF),
          artTintMiddle: const Color(0x3D050E28),
          artTintBottom: const Color(0xA3020614),
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-neon-heist.webp',
        );
      case WildcardThemeId.moonlitMasquerade:
        return classic.copyWith(
          mint: const Color(0xFF9EDCFF),
          gold: const Color(0xFFF2E5B8),
          violet: const Color(0xFFB8AAFF),
          coral: const Color(0xFFE28BBB),
          panel: const Color(0xEB111830),
          panelStrong: const Color(0xF7070B1C),
          line: const Color(0xA3C1DAFF),
          artTintMiddle: const Color(0x3B0F1837),
          artTintBottom: const Color(0xA6050818),
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-moonlit-masquerade.webp',
        );
      case WildcardThemeId.emberCasino:
        return classic.copyWith(
          mint: const Color(0xFFFFAA64),
          gold: const Color(0xFFFFD76C),
          violet: const Color(0xFFF06662),
          coral: const Color(0xFFFF574D),
          panel: const Color(0xEB37100A),
          panelStrong: const Color(0xF71C0705),
          line: const Color(0xA8FF9E52),
          artTintMiddle: const Color(0x3D3A0C07),
          artTintBottom: const Color(0xA6170504),
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-ember-casino.webp',
        );
      case WildcardThemeId.emeraldThrone:
        return classic.copyWith(
          mint: const Color(0xFF67F5AA),
          gold: const Color(0xFFF7D36B),
          violet: const Color(0xFF59CDA0),
          coral: const Color(0xFFF0A052),
          panel: const Color(0xEB092D1F),
          panelStrong: const Color(0xF7041811),
          line: const Color(0xA35CF0A0),
          artTintMiddle: const Color(0x3B07301F),
          artTintBottom: const Color(0xA303140E),
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-emerald-throne.webp',
        );
      case WildcardThemeId.hauntedCarnival:
        return classic.copyWith(
          mint: const Color(0xFF7CF7DA),
          gold: const Color(0xFFF0C96C),
          violet: const Color(0xFFC482FF),
          coral: const Color(0xFFF56BBB),
          panel: const Color(0xEB1D0D32),
          panelStrong: const Color(0xF70C061A),
          line: const Color(0xA8B56BFF),
          artTintMiddle: const Color(0x3D230D3D),
          artTintBottom: const Color(0xA60A0418),
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-haunted-carnival.webp',
        );
      case WildcardThemeId.clockworkRoyale:
        return classic.copyWith(
          mint: const Color(0xFF71E2DC),
          gold: const Color(0xFFF2C864),
          violet: const Color(0xFF6894DE),
          coral: const Color(0xFFE58B5A),
          panel: const Color(0xED1F1D1B),
          panelStrong: const Color(0xFA0F0E0F),
          line: const Color(0xA3E8B953),
          artTintMiddle: const Color(0x3B221D18),
          artTintBottom: const Color(0xA80E0C0C),
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-clockwork-royale.webp',
        );
      case WildcardThemeId.blockDropArcade:
        return classic.copyWith(
          ink: const Color(0xFF090A24),
          felt: const Color(0xFF111746),
          feltHighlight: const Color(0xFF20266B),
          mint: const Color(0xFF45F4FF),
          gold: const Color(0xFFFFDF4F),
          violet: const Color(0xFF9A62FF),
          coral: const Color(0xFFFF4FB8),
          rare: const Color(0xFFFF8B42),
          wild: const Color(0xFFFF4FDB),
          panel: const Color(0xEB0B1034),
          panelStrong: const Color(0xFA05071D),
          line: const Color(0xB35AFAE8),
          artTintTop: const Color(0x0801041A),
          artTintMiddle: const Color(0x33101A58),
          artTintBottom: const Color(0x99030419),
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-block-drop-arcade.webp',
        );
      case WildcardThemeId.abyssalJackpot:
        return classic.copyWith(
          ink: const Color(0xFF06191F),
          felt: const Color(0xFF092D37),
          feltHighlight: const Color(0xFF105064),
          cream: const Color(0xFFF3F1DD),
          creamDim: const Color(0xFFBFDAD5),
          mint: const Color(0xFF65F4E3),
          gold: const Color(0xFFFFBF70),
          violet: const Color(0xFF819DFF),
          coral: const Color(0xFFFF7666),
          rare: const Color(0xFFFF9D62),
          wild: const Color(0xFFBA7DFF),
          panel: const Color(0xEB062A35),
          panelStrong: const Color(0xFA03151D),
          line: const Color(0xAD6BE8DD),
          artTintTop: const Color(0x08001A22),
          artTintMiddle: const Color(0x2E063C4A),
          artTintBottom: const Color(0x9900141C),
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-abyssal-jackpot.webp',
        );
      case WildcardThemeId.desertMirage:
        return classic.copyWith(
          ink: const Color(0xFF172A2D),
          felt: const Color(0xFF164B4D),
          feltHighlight: const Color(0xFF237170),
          cream: const Color(0xFFFFF4D8),
          creamDim: const Color(0xFFE2CFA7),
          mint: const Color(0xFF4CE0D1),
          gold: const Color(0xFFFFC85D),
          violet: const Color(0xFF4F87C8),
          coral: const Color(0xFFE36E4B),
          rare: const Color(0xFFFF9653),
          wild: const Color(0xFFB768C7),
          panel: const Color(0xEB123D3F),
          panelStrong: const Color(0xFA092426),
          line: const Color(0xADE7B956),
          artTintTop: const Color(0x05FFF1C9),
          artTintMiddle: const Color(0x241A5B5A),
          artTintBottom: const Color(0x96112629),
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-desert-mirage.webp',
        );
      case WildcardThemeId.heartsKingdom:
        return WildcardThemeTokens.forId(WildcardThemeId.emberCasino).copyWith(
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-hearts-kingdom-home.webp',
          gameplayBackgroundAsset:
              'assets/art/backgrounds/wildcard-kingdom-hearts-gameplay.webp',
        );
      case WildcardThemeId.spadesKingdom:
        return WildcardThemeTokens.forId(
          WildcardThemeId.moonlitMasquerade,
        ).copyWith(
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-spades-kingdom-home.webp',
          gameplayBackgroundAsset:
              'assets/art/backgrounds/wildcard-kingdom-spades-gameplay.webp',
        );
      case WildcardThemeId.diamondsKingdom:
        return WildcardThemeTokens.forId(
          WildcardThemeId.clockworkRoyale,
        ).copyWith(
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-diamonds-kingdom-home.webp',
          gameplayBackgroundAsset:
              'assets/art/backgrounds/wildcard-kingdom-diamonds-gameplay.webp',
        );
      case WildcardThemeId.clubsKingdom:
        return WildcardThemeTokens.forId(
          WildcardThemeId.emeraldThrone,
        ).copyWith(
          homeBackgroundAsset:
              'assets/art/backgrounds/wildcard-theme-clubs-kingdom-home.webp',
          gameplayBackgroundAsset:
              'assets/art/backgrounds/wildcard-kingdom-clubs-gameplay.webp',
        );
    }
  }

  @override
  WildcardThemeTokens copyWith({
    Color? ink,
    Color? felt,
    Color? feltHighlight,
    Color? line,
    Color? cream,
    Color? creamDim,
    Color? gold,
    Color? mint,
    Color? coral,
    Color? violet,
    Color? rare,
    Color? wild,
    Color? panel,
    Color? panelStrong,
    Color? artTintTop,
    Color? artTintMiddle,
    Color? artTintBottom,
    String? homeBackgroundAsset,
    String? gameplayBackgroundAsset,
  }) {
    return WildcardThemeTokens(
      ink: ink ?? this.ink,
      felt: felt ?? this.felt,
      feltHighlight: feltHighlight ?? this.feltHighlight,
      line: line ?? this.line,
      cream: cream ?? this.cream,
      creamDim: creamDim ?? this.creamDim,
      gold: gold ?? this.gold,
      mint: mint ?? this.mint,
      coral: coral ?? this.coral,
      violet: violet ?? this.violet,
      rare: rare ?? this.rare,
      wild: wild ?? this.wild,
      panel: panel ?? this.panel,
      panelStrong: panelStrong ?? this.panelStrong,
      artTintTop: artTintTop ?? this.artTintTop,
      artTintMiddle: artTintMiddle ?? this.artTintMiddle,
      artTintBottom: artTintBottom ?? this.artTintBottom,
      homeBackgroundAsset: homeBackgroundAsset ?? this.homeBackgroundAsset,
      gameplayBackgroundAsset:
          gameplayBackgroundAsset ?? this.gameplayBackgroundAsset,
    );
  }

  @override
  WildcardThemeTokens lerp(covariant WildcardThemeTokens? other, double t) {
    if (other == null) return this;
    return WildcardThemeTokens(
      ink: Color.lerp(ink, other.ink, t)!,
      felt: Color.lerp(felt, other.felt, t)!,
      feltHighlight: Color.lerp(feltHighlight, other.feltHighlight, t)!,
      line: Color.lerp(line, other.line, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      creamDim: Color.lerp(creamDim, other.creamDim, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      rare: Color.lerp(rare, other.rare, t)!,
      wild: Color.lerp(wild, other.wild, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelStrong: Color.lerp(panelStrong, other.panelStrong, t)!,
      artTintTop: Color.lerp(artTintTop, other.artTintTop, t)!,
      artTintMiddle: Color.lerp(artTintMiddle, other.artTintMiddle, t)!,
      artTintBottom: Color.lerp(artTintBottom, other.artTintBottom, t)!,
      homeBackgroundAsset: t < 0.5
          ? homeBackgroundAsset
          : other.homeBackgroundAsset,
      gameplayBackgroundAsset: t < 0.5
          ? gameplayBackgroundAsset
          : other.gameplayBackgroundAsset,
    );
  }

  /// Shared semantic colours for controls and overlays.
  ///
  /// They are derived from the authored palette so adding a new theme does not
  /// require another set of hard-coded Material component colours.
  Color get pageBackground => ink;
  Color get surface => panel;
  Color get surfaceStrong => panelStrong;
  Color get surfaceMuted =>
      Color.alphaBlend(cream.withValues(alpha: .045), panelStrong);
  Color get fieldFill =>
      Color.alphaBlend(feltHighlight.withValues(alpha: .34), panelStrong);
  Color get overlayScrim =>
      Color.alphaBlend(ink.withValues(alpha: .94), Colors.black);
  Color get shadow => Colors.black.withValues(alpha: .58);
  Color get disabledFill =>
      Color.alphaBlend(creamDim.withValues(alpha: .08), panelStrong);
  Color get disabledContent => creamDim.withValues(alpha: .58);
  Color get onPrimaryAccent =>
      _highestContrastText(mint, const Color(0xFF04120E));
  Color get onSecondaryAccent =>
      _highestContrastText(gold, const Color(0xFF251505));
  Color get onDangerAccent =>
      _highestContrastText(coral, const Color(0xFF3D0F08));

  Color _highestContrastText(Color background, Color dark) {
    double contrast(Color foreground) {
      final foregroundLuminance = foreground.computeLuminance();
      final backgroundLuminance = background.computeLuminance();
      final lighter = math.max(foregroundLuminance, backgroundLuminance);
      final darker = math.min(foregroundLuminance, backgroundLuminance);
      return (lighter + .05) / (darker + .05);
    }

    return contrast(dark) >= contrast(cream) ? dark : cream;
  }

  String? backgroundAssetFor(WildcardUiSurface surface) {
    return switch (WildcardThemeCoverage.forSurface(surface).backdrop) {
      WildcardBackdropRole.equippedTheme => homeBackgroundAsset,
      WildcardBackdropRole.equippedGameplayTheme =>
        gameplayBackgroundAsset ?? homeBackgroundAsset,
      WildcardBackdropRole.runSetup => null,
      WildcardBackdropRole.shopRoom => shopBackground,
      WildcardBackdropRole.vaultRoom => vaultBackground,
      WildcardBackdropRole.endlessRoom => cosmicBackground,
      WildcardBackdropRole.houseRoom => houseBackground,
      WildcardBackdropRole.none => null,
    };
  }
}

abstract final class WildcardTheme {
  static ThemeData build({WildcardThemeId themeId = WildcardThemeId.classic}) {
    final tokens = WildcardThemeTokens.forId(themeId);
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: tokens.ink,
      colorScheme: ColorScheme.dark(
        primary: tokens.mint,
        onPrimary: tokens.onPrimaryAccent,
        secondary: tokens.gold,
        onSecondary: tokens.onSecondaryAccent,
        error: tokens.coral,
        onError: tokens.onDangerAccent,
        surface: tokens.panelStrong,
        onSurface: tokens.cream,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'SpaceGrotesk',
        bodyColor: tokens.cream,
        displayColor: tokens.cream,
      ),
      iconTheme: IconThemeData(color: tokens.cream),
      canvasColor: tokens.pageBackground,
      cardColor: tokens.surface,
      dividerColor: tokens.line,
      disabledColor: tokens.disabledContent,
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceStrong,
        surfaceTintColor: Colors.transparent,
        shadowColor: tokens.shadow,
        titleTextStyle: TextStyle(
          color: tokens.gold,
          fontFamily: 'Bungee',
          fontSize: 19,
          height: 1.1,
        ),
        contentTextStyle: TextStyle(
          color: tokens.cream,
          fontFamily: 'SpaceGrotesk',
          fontSize: 14,
          height: 1.35,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.line, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceStrong,
        modalBackgroundColor: tokens.surfaceStrong,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: tokens.overlayScrim.withValues(alpha: .78),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          side: BorderSide(color: tokens.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.fieldFill,
        labelStyle: TextStyle(color: tokens.creamDim),
        hintStyle: TextStyle(color: tokens.disabledContent),
        prefixIconColor: tokens.mint,
        suffixIconColor: tokens.creamDim,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: tokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: tokens.mint, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: tokens.disabledFill),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.mint,
        linearTrackColor: tokens.disabledFill,
        circularTrackColor: tokens.disabledFill,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tokens.gold,
        unselectedLabelColor: tokens.creamDim,
        indicatorColor: tokens.mint,
        dividerColor: tokens.line,
        labelStyle: const TextStyle(fontFamily: 'Bungee', fontSize: 11),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: tokens.surfaceMuted,
        selectedColor: tokens.feltHighlight,
        disabledColor: tokens.disabledFill,
        side: BorderSide(color: tokens.line),
        labelStyle: TextStyle(color: tokens.cream),
        secondaryLabelStyle: TextStyle(color: tokens.cream),
        checkmarkColor: tokens.mint,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surfaceStrong,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: tokens.cream),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: tokens.line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surfaceStrong,
        contentTextStyle: TextStyle(color: tokens.cream),
        actionTextColor: tokens.gold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: tokens.line),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.surfaceStrong,
          border: Border.all(color: tokens.line),
          borderRadius: BorderRadius.circular(9),
        ),
        textStyle: TextStyle(color: tokens.cream),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.mint,
          foregroundColor: tokens.onPrimaryAccent,
          disabledBackgroundColor: tokens.disabledFill,
          disabledForegroundColor: tokens.disabledContent,
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.cream,
          disabledForegroundColor: tokens.disabledContent,
          side: BorderSide(color: tokens.line),
          minimumSize: const Size(48, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.mint,
          disabledForegroundColor: tokens.disabledContent,
          minimumSize: const Size(48, 48),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.mint
              : tokens.creamDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.mint.withValues(alpha: .34)
              : tokens.disabledFill,
        ),
        trackOutlineColor: WidgetStatePropertyAll(tokens.line),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.mint
              : tokens.fieldFill,
        ),
        checkColor: WidgetStatePropertyAll(tokens.onPrimaryAccent),
        side: BorderSide(color: tokens.line),
      ),
      splashFactory: InkRipple.splashFactory,
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }
}

extension WildcardThemeContext on BuildContext {
  WildcardThemeTokens get wildcard =>
      Theme.of(this).extension<WildcardThemeTokens>() ??
      WildcardThemeTokens.classic;
}

/// A thin dark outline for text that sits directly on room artwork.
///
/// Home and menu text previously relied on the art being dark enough, which
/// broke over the brighter themes. Four offset shadows read as a hairline
/// stroke at any size and cost far less than a stroked TextPainter.
const List<Shadow> wildcardTextOutline = <Shadow>[
  Shadow(color: Color(0xE6000000), offset: Offset(0, 1)),
  Shadow(color: Color(0xE6000000), offset: Offset(1, 0)),
  Shadow(color: Color(0xE6000000), offset: Offset(-1, 0)),
  Shadow(color: Color(0xE6000000), offset: Offset(0, -1)),
  Shadow(color: Color(0x99000000), blurRadius: 5, offset: Offset(0, 2)),
];
