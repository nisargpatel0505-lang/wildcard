import 'wildcard_theme.dart';
import 'widgets/sly_sprite.dart';

/// The single visual mapping for every UI-theme cosmetic.
///
/// Keeping this separate from the progression catalogue avoids coupling domain
/// state to Flutter while preventing the home screen, Wardrobe and Vault from
/// silently disagreeing about a cosmetic's artwork.
const Map<String, WildcardThemeId> wildcardThemeByCosmeticId =
    <String, WildcardThemeId>{
      'theme_default': WildcardThemeId.classic,
      'theme_sunset': WildcardThemeId.sunset,
      'theme_ice': WildcardThemeId.ice,
      'theme_neon_elite': WildcardThemeId.neonElite,
      'theme_gold': WildcardThemeId.midas,
      'theme_vapor': WildcardThemeId.vaporwave,
      'theme_blood': WildcardThemeId.bloodMoon,
      'theme_cosmic': WildcardThemeId.cosmicWilds,
      'theme_neon_heist': WildcardThemeId.neonHeist,
      'theme_moonlit_mask': WildcardThemeId.moonlitMasquerade,
      'theme_ember': WildcardThemeId.emberCasino,
      'theme_emerald_throne': WildcardThemeId.emeraldThrone,
      'theme_haunted': WildcardThemeId.hauntedCarnival,
      'theme_clockwork': WildcardThemeId.clockworkRoyale,
      'theme_block_drop': WildcardThemeId.blockDropArcade,
      'theme_abyssal': WildcardThemeId.abyssalJackpot,
      'theme_desert_mirage': WildcardThemeId.desertMirage,
      'theme_hearts_kingdom': WildcardThemeId.heartsKingdom,
      'theme_spades_kingdom': WildcardThemeId.spadesKingdom,
      'theme_diamonds_kingdom': WildcardThemeId.diamondsKingdom,
      'theme_clubs_kingdom': WildcardThemeId.clubsKingdom,
    };

/// The single visual mapping for every Sly cosmetic.
const Map<String, SlySkin> slySkinByCosmeticId = <String, SlySkin>{
  'sly_classic': SlySkin.classic,
  'sly_gold': SlySkin.gold,
  'sly_shadow': SlySkin.shadow,
  'sly_robot': SlySkin.robot,
  'sly_king': SlySkin.king,
  'sly_alien': SlySkin.alien,
  'sly_devil': SlySkin.devil,
  'sly_clown': SlySkin.clown,
  'sly_block_drop': SlySkin.blockDrop,
  'sly_abyssal': SlySkin.abyssal,
  'sly_desert': SlySkin.desertMirage,
  'sly_hearts': SlySkin.hearts,
  'sly_spades': SlySkin.spades,
  'sly_diamonds': SlySkin.diamonds,
  'sly_clubs': SlySkin.clubs,
};

WildcardThemeId resolveWildcardThemeId(String cosmeticId) =>
    wildcardThemeByCosmeticId[cosmeticId] ?? WildcardThemeId.classic;

SlySkin resolveSlySkin(String cosmeticId) =>
    slySkinByCosmeticId[cosmeticId] ?? SlySkin.classic;

WildcardThemeId requireWildcardThemeId(String cosmeticId) =>
    wildcardThemeByCosmeticId[cosmeticId] ??
    (throw StateError('No UI-theme visual mapping for $cosmeticId'));

SlySkin requireSlySkin(String cosmeticId) =>
    slySkinByCosmeticId[cosmeticId] ??
    (throw StateError('No Sly visual mapping for $cosmeticId'));
