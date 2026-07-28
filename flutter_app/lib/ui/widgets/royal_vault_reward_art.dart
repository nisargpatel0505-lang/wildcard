import 'package:flutter/material.dart';

import '../../domain/joker_catalog.dart';
import '../../domain/progression_catalog.dart';
import '../wildcard_theme.dart';
import 'compact_joker_card.dart';
import 'sly_sprite.dart';
import 'table_felt_surface.dart';

enum RoyalVaultRewardArtworkKind { joker, slySkin, table, theme }

@immutable
class RoyalVaultRewardArtwork {
  const RoyalVaultRewardArtwork._({
    required this.kind,
    required this.catalogId,
    this.joker,
    this.slySkin,
    this.theme,
  });

  factory RoyalVaultRewardArtwork.forJoker(JokerDefinition joker) =>
      RoyalVaultRewardArtwork._(
        kind: RoyalVaultRewardArtworkKind.joker,
        catalogId: joker.id,
        joker: joker,
      );

  factory RoyalVaultRewardArtwork.forCosmetic(CosmeticDefinition cosmetic) {
    return switch (cosmetic.kind) {
      CosmeticKind.table when tableFeltVisuals.containsKey(cosmetic.id) =>
        RoyalVaultRewardArtwork._(
          kind: RoyalVaultRewardArtworkKind.table,
          catalogId: cosmetic.id,
        ),
      CosmeticKind.sly => RoyalVaultRewardArtwork._(
        kind: RoyalVaultRewardArtworkKind.slySkin,
        catalogId: cosmetic.id,
        slySkin: _slySkin(cosmetic.id),
      ),
      CosmeticKind.theme => RoyalVaultRewardArtwork._(
        kind: RoyalVaultRewardArtworkKind.theme,
        catalogId: cosmetic.id,
        theme: _themeId(cosmetic.id),
      ),
      _ => throw StateError(
        'No Royal Vault artwork mapping for cosmetic ${cosmetic.id}',
      ),
    };
  }

  final RoyalVaultRewardArtworkKind kind;
  final String catalogId;
  final JokerDefinition? joker;
  final SlySkin? slySkin;
  final WildcardThemeId? theme;

  static SlySkin _slySkin(String id) => switch (id) {
    'sly_classic' => SlySkin.classic,
    'sly_gold' => SlySkin.gold,
    'sly_shadow' => SlySkin.shadow,
    'sly_robot' => SlySkin.robot,
    'sly_king' => SlySkin.king,
    'sly_alien' => SlySkin.alien,
    'sly_devil' => SlySkin.devil,
    'sly_clown' => SlySkin.clown,
    'sly_block_drop' => SlySkin.blockDrop,
    'sly_abyssal' => SlySkin.abyssal,
    'sly_desert' => SlySkin.desertMirage,
    _ => throw StateError('No Royal Vault Sly preview mapping for $id'),
  };

  static WildcardThemeId _themeId(String id) => switch (id) {
    'theme_default' => WildcardThemeId.classic,
    'theme_sunset' => WildcardThemeId.sunset,
    'theme_ice' => WildcardThemeId.ice,
    'theme_neon_elite' => WildcardThemeId.neonElite,
    'theme_gold' => WildcardThemeId.midas,
    'theme_vapor' => WildcardThemeId.vaporwave,
    'theme_blood' => WildcardThemeId.bloodMoon,
    'theme_cosmic' => WildcardThemeId.cosmicWilds,
    'theme_neon_heist' => WildcardThemeId.neonHeist,
    'theme_moonlit_mask' => WildcardThemeId.moonlitMasquerade,
    'theme_ember' => WildcardThemeId.emberCasino,
    'theme_emerald_throne' => WildcardThemeId.emeraldThrone,
    'theme_haunted' => WildcardThemeId.hauntedCarnival,
    'theme_clockwork' => WildcardThemeId.clockworkRoyale,
    'theme_block_drop' => WildcardThemeId.blockDropArcade,
    'theme_abyssal' => WildcardThemeId.abyssalJackpot,
    'theme_desert_mirage' => WildcardThemeId.desertMirage,
    _ => throw StateError('No Royal Vault theme preview mapping for $id'),
  };
}

/// Renders the same visual language used by the reward elsewhere in the app.
///
/// No generic production fallback exists: an unmapped catalogue entry throws
/// during construction and is covered by a complete catalogue contract test.
class RoyalVaultRewardArtworkView extends StatelessWidget {
  const RoyalVaultRewardArtworkView({
    required this.artwork,
    required this.accent,
    super.key,
  });

  final RoyalVaultRewardArtwork artwork;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return switch (artwork.kind) {
      RoyalVaultRewardArtworkKind.joker => CompactJokerCard(
        joker: artwork.joker!,
        height: 58,
      ),
      RoyalVaultRewardArtworkKind.slySkin => Center(
        child: SlySprite(
          skin: artwork.slySkin!,
          expression: SlyExpression.idle,
          size: 58,
          borderRadius: 12,
          animate: false,
          semanticLabel: 'Unlocked Sly appearance',
        ),
      ),
      RoyalVaultRewardArtworkKind.table => TableFeltSurface(
        feltId: artwork.catalogId,
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Icon(Icons.style_rounded, color: accent, size: 22),
        ),
      ),
      RoyalVaultRewardArtworkKind.theme => _ThemePreview(
        theme: artwork.theme!,
        accent: accent,
      ),
    };
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme, required this.accent});

  final WildcardThemeId theme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = WildcardThemeTokens.forId(theme);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            tokens.homeBackgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.low,
            excludeFromSemantics: true,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tokens.pageBackground.withValues(alpha: .08),
                  tokens.violet.withValues(alpha: .34),
                ],
              ),
              border: Border.all(color: accent, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Center(
            child: Icon(Icons.palette_rounded, color: tokens.gold, size: 24),
          ),
        ],
      ),
    );
  }
}
