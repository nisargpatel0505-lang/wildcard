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

  static const String palaceBackground =
      'assets/art/backgrounds/wildcard-main-menu-palace.webp';
  static const String cosmicBackground =
      'assets/art/backgrounds/wildcard-endless-victory-cosmos.webp';

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
    );
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
        onPrimary: const Color(0xFF04120E),
        secondary: tokens.gold,
        onSecondary: const Color(0xFF251505),
        error: tokens.coral,
        onError: const Color(0xFF3D0F08),
        surface: tokens.panelStrong,
        onSurface: tokens.cream,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'SpaceGrotesk',
        bodyColor: tokens.cream,
        displayColor: tokens.cream,
      ),
      iconTheme: IconThemeData(color: tokens.cream),
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
