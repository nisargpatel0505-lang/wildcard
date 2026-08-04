import 'package:flutter/material.dart';

enum RoyalVaultVisualTier { wooden, golden, cosmetic }

enum RoyalVaultChestLayerType { body, lid, lock, crest }

@immutable
class RoyalVaultChestAssetSet {
  const RoyalVaultChestAssetSet({
    required this.body,
    required this.lid,
    required this.lock,
    required this.crest,
  });

  final String body;
  final String lid;
  final String lock;
  final String crest;

  static RoyalVaultChestAssetSet forTier(RoyalVaultVisualTier tier) {
    final prefix = switch (tier) {
      RoyalVaultVisualTier.wooden => 'wood',
      RoyalVaultVisualTier.golden => 'gold',
      RoyalVaultVisualTier.cosmetic => 'cosmetic',
    };
    const root = 'assets/art/chests';
    return RoyalVaultChestAssetSet(
      body: '$root/wildcard-$prefix-vault-body.webp',
      lid: '$root/wildcard-$prefix-vault-lid.webp',
      lock: '$root/wildcard-$prefix-vault-lock.webp',
      crest: '$root/wildcard-$prefix-vault-crest.webp',
    );
  }
}

/// One generated, animation-ready Royal Vault art layer.
///
/// Keeping each layer in its own repaint boundary lets the ceremony animate
/// only transforms and opacity. The decoded bitmap is cached independently
/// from the timeline and is never repainted by a custom painter.
class RoyalVaultChestLayer extends StatelessWidget {
  const RoyalVaultChestLayer({
    required this.tier,
    required this.layer,
    this.fit = BoxFit.contain,
    this.semanticLabel,
    super.key,
  });

  final RoyalVaultVisualTier tier;
  final RoyalVaultChestLayerType layer;
  final BoxFit fit;
  final String? semanticLabel;

  String get _asset {
    final assets = RoyalVaultChestAssetSet.forTier(tier);
    return switch (layer) {
      RoyalVaultChestLayerType.body => assets.body,
      RoyalVaultChestLayerType.lid => assets.lid,
      RoyalVaultChestLayerType.lock => assets.lock,
      RoyalVaultChestLayerType.crest => assets.crest,
    };
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Image.asset(
      _asset,
      fit: fit,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    ),
  );
}
