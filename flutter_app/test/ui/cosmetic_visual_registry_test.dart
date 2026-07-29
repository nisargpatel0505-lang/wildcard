import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/progression_catalog.dart';
import 'package:wildcard/ui/cosmetic_visual_registry.dart';
import 'package:wildcard/ui/widgets/sly_sprite.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

void main() {
  test('every theme and Sly cosmetic has one centralized visual mapping', () {
    final themeIds = cosmeticCatalog
        .where((cosmetic) => cosmetic.kind == CosmeticKind.theme)
        .map((cosmetic) => cosmetic.id)
        .toSet();
    final slyIds = cosmeticCatalog
        .where((cosmetic) => cosmetic.kind == CosmeticKind.sly)
        .map((cosmetic) => cosmetic.id)
        .toSet();

    expect(wildcardThemeByCosmeticId.keys.toSet(), themeIds);
    expect(slySkinByCosmeticId.keys.toSet(), slyIds);
    expect(wildcardThemeByCosmeticId.values.toSet(), WildcardThemeId.values);
    expect(slySkinByCosmeticId.values.toSet(), SlySkin.values);
  });

  test('kingdom UI themes have dedicated selectable cosmetic IDs', () {
    expect(
      wildcardThemeByCosmeticId['theme_hearts_kingdom'],
      WildcardThemeId.heartsKingdom,
    );
    expect(
      wildcardThemeByCosmeticId['theme_spades_kingdom'],
      WildcardThemeId.spadesKingdom,
    );
    expect(
      wildcardThemeByCosmeticId['theme_diamonds_kingdom'],
      WildcardThemeId.diamondsKingdom,
    );
    expect(
      wildcardThemeByCosmeticId['theme_clubs_kingdom'],
      WildcardThemeId.clubsKingdom,
    );
  });

  test('kingdom Sly skins resolve expression and stage atlases', () {
    const packs = <String, (SlySkin, String, String)>{
      'sly_hearts': (
        SlySkin.hearts,
        slyHeartsExpressionSpriteAsset,
        slyHeartsStageSpriteAsset,
      ),
      'sly_spades': (
        SlySkin.spades,
        slySpadesExpressionSpriteAsset,
        slySpadesStageSpriteAsset,
      ),
      'sly_diamonds': (
        SlySkin.diamonds,
        slyDiamondsExpressionSpriteAsset,
        slyDiamondsStageSpriteAsset,
      ),
      'sly_clubs': (
        SlySkin.clubs,
        slyClubsExpressionSpriteAsset,
        slyClubsStageSpriteAsset,
      ),
    };

    for (final entry in packs.entries) {
      final skin = resolveSlySkin(entry.key);
      expect(skin, entry.value.$1);
      expect(slyExpressionAssetForSkin(skin), entry.value.$2);
      expect(slyStageAssetForSkin(skin), entry.value.$3);
    }
  });

  test('fallback and strict resolver semantics remain explicit', () {
    expect(resolveWildcardThemeId('missing'), WildcardThemeId.classic);
    expect(resolveSlySkin('missing'), SlySkin.classic);
    expect(() => requireWildcardThemeId('missing'), throwsStateError);
    expect(() => requireSlySkin('missing'), throwsStateError);
  });
}
