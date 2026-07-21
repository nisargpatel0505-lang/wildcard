import 'package:flutter/material.dart';

import '../../domain/account_state.dart';
import '../../domain/joker_catalog.dart';
import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';

enum JokerCollectionFilter { all, locked, owned, common, uncommon, rare, wild }

enum JokerCollectionSort { rarity, cost, name, status }

const int jokerCollectionPageSize = 24;

List<JokerDefinition> filteredJokerCollection({
  required Iterable<JokerDefinition> jokers,
  required Set<String> ownedIds,
  JokerCollectionFilter filter = JokerCollectionFilter.all,
  JokerCollectionSort sort = JokerCollectionSort.rarity,
  String search = '',
}) {
  final query = search.trim().toLowerCase();
  final result = jokers.where((joker) {
    final owned = ownedIds.contains(joker.id);
    final filterMatches = switch (filter) {
      JokerCollectionFilter.all => true,
      JokerCollectionFilter.locked => !owned,
      JokerCollectionFilter.owned => owned,
      JokerCollectionFilter.common => joker.rarity == JokerRarity.common,
      JokerCollectionFilter.uncommon => joker.rarity == JokerRarity.uncommon,
      JokerCollectionFilter.rare => joker.rarity == JokerRarity.rare,
      JokerCollectionFilter.wild => joker.rarity == JokerRarity.wild,
    };
    if (!filterMatches) return false;
    if (query.isEmpty) return true;
    return '${joker.name} ${joker.description} ${joker.rarity.name} ${jokerCollectionTagline(joker)}'
        .toLowerCase()
        .contains(query);
  }).toList();

  int compare(JokerDefinition left, JokerDefinition right) {
    final rarity = _rarityOrder(
      left.rarity,
    ).compareTo(_rarityOrder(right.rarity));
    final cost = left.collectionUnlockCost.compareTo(
      right.collectionUnlockCost,
    );
    final name = left.name.compareTo(right.name);
    return switch (sort) {
      JokerCollectionSort.name => name,
      JokerCollectionSort.cost =>
        cost != 0
            ? cost
            : rarity != 0
            ? rarity
            : name,
      JokerCollectionSort.status =>
        ownedIds.contains(left.id) != ownedIds.contains(right.id)
            ? (ownedIds.contains(left.id) ? -1 : 1)
            : rarity != 0
            ? rarity
            : name,
      JokerCollectionSort.rarity =>
        rarity != 0
            ? rarity
            : cost != 0
            ? cost
            : name,
    };
  }

  result.sort(compare);
  return result;
}

String jokerCollectionTagline(JokerDefinition joker) {
  if (joker.rarity == JokerRarity.wild) return 'Rule-breaker';
  final description = joker.description.toLowerCase();
  if (description.contains('×') || description.contains('multiplier')) {
    return 'Multiplier engine';
  }
  if (description.contains('mult')) return 'Scaling mult';
  if (description.contains('rank')) return 'Rank booster';
  if (description.contains('heat') || description.contains('score')) {
    return 'Growth engine';
  }
  return 'Utility joker';
}

class JokerCollectionSection extends StatefulWidget {
  const JokerCollectionSection({
    required this.account,
    required this.onUnlock,
    super.key,
  });

  final AccountState account;
  final Future<bool> Function(String id) onUnlock;

  @override
  State<JokerCollectionSection> createState() => _JokerCollectionSectionState();
}

class _JokerCollectionSectionState extends State<JokerCollectionSection> {
  final TextEditingController _searchController = TextEditingController();
  JokerCollectionFilter _filter = JokerCollectionFilter.all;
  JokerCollectionSort _sort = JokerCollectionSort.rarity;
  int _visible = jokerCollectionPageSize;
  final Set<String> _unlocking = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredJokerCollection(
      jokers: jokerCatalog,
      ownedIds: widget.account.unlockedJokerIds,
      filter: _filter,
      sort: _sort,
      search: _searchController.text,
    );
    final shown = filtered.take(_visible).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenSectionTitle('Collection'),
        _CollectionSummary(ownedIds: widget.account.unlockedJokerIds),
        const SizedBox(height: 10),
        TextField(
          key: const Key('collection-search'),
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() => _visible = jokerCollectionPageSize),
          style: TextStyle(color: context.wildcard.cream, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search name, effect or rarity',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    key: const Key('collection-clear-search'),
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _visible = jokerCollectionPageSize);
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: context.wildcard.panelStrong.withValues(alpha: .94),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: context.wildcard.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: context.wildcard.line),
            ),
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 48,
          child: ListView.separated(
            key: const Key('collection-filter-strip'),
            scrollDirection: Axis.horizontal,
            itemCount: JokerCollectionFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final filter = JokerCollectionFilter.values[index];
              return _CollectionChoice(
                key: Key('collection-filter-${filter.name}'),
                label: _filterLabel(filter),
                selected: filter == _filter,
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() {
                    _filter = filter;
                    _visible = jokerCollectionPageSize;
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<JokerCollectionSort>(
          key: const Key('collection-sort'),
          initialValue: _sort,
          isExpanded: true,
          dropdownColor: context.wildcard.panelStrong,
          style: TextStyle(color: context.wildcard.cream, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Sort Jokers',
            filled: true,
            fillColor: context.wildcard.panelStrong.withValues(alpha: .94),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 11,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          ),
          items: JokerCollectionSort.values
              .map(
                (sort) => DropdownMenuItem<JokerCollectionSort>(
                  value: sort,
                  child: Text(_sortLabel(sort)),
                ),
              )
              .toList(growable: false),
          onChanged: (sort) {
            if (sort == null) return;
            FocusManager.instance.primaryFocus?.unfocus();
            setState(() {
              _sort = sort;
              _visible = jokerCollectionPageSize;
            });
          },
        ),
        const SizedBox(height: 9),
        Text(
          'Showing ${shown.length} of ${filtered.length} Jokers',
          key: const Key('collection-result-count'),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.wildcard.creamDim, fontSize: 12),
        ),
        const SizedBox(height: 9),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Nothing in this filter yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.wildcard.creamDim),
            ),
          )
        else
          for (final joker in shown) _jokerCard(joker),
        if (shown.length < filtered.length) ...[
          const SizedBox(height: 2),
          WildcardButton(
            key: const Key('collection-load-more'),
            label:
                'Load More (${(filtered.length - shown.length).clamp(0, jokerCollectionPageSize)})',
            onPressed: () =>
                setState(() => _visible += jokerCollectionPageSize),
            variant: WildcardButtonVariant.ghost,
          ),
        ],
      ],
    );
  }

  Widget _jokerCard(JokerDefinition joker) {
    final owned = widget.account.unlockedJokerIds.contains(joker.id);
    final busy = _unlocking.contains(joker.id);
    final canAfford = widget.account.coins >= joker.collectionUnlockCost;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: WildcardCard(
        key: Key('collection-joker-${joker.id}'),
        accent: owned
            ? _rarityAccent(joker.rarity)
            : WildcardCardAccent.neutral,
        onTap: () => _inspectJoker(joker),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        joker.name.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _rarityColor(context, joker.rarity),
                          fontFamily: 'Bungee',
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_rarityName(joker.rarity)} · ${jokerCollectionTagline(joker)}',
                        style: TextStyle(
                          color: context.wildcard.creamDim,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(owned: owned, starter: joker.starter),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              owned ? joker.description : 'Unlock to reveal this Joker effect.',
              style: TextStyle(
                color: owned
                    ? context.wildcard.cream
                    : context.wildcard.creamDim,
                fontSize: 12,
                height: 1.25,
              ),
            ),
            if (!owned) ...[
              const SizedBox(height: 10),
              Semantics(
                button: true,
                enabled: canAfford && !busy,
                label:
                    'Unlock ${joker.name} for ${joker.collectionUnlockCost} coins',
                child: SizedBox(
                  height: 48,
                  child: FilledButton.tonal(
                    key: Key('collection-unlock-${joker.id}'),
                    onPressed: !busy && canAfford ? () => _unlock(joker) : null,
                    child: Text(
                      busy
                          ? 'SAVING…'
                          : 'UNLOCK · ${joker.collectionUnlockCost} COINS',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Bungee',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _unlock(JokerDefinition joker) async {
    if (_unlocking.contains(joker.id)) return false;
    setState(() => _unlocking.add(joker.id));
    var unlocked = false;
    try {
      unlocked = await widget.onUnlock(joker.id);
    } catch (_) {
      unlocked = false;
    } finally {
      if (mounted) setState(() => _unlocking.remove(joker.id));
    }
    if (!mounted) return unlocked;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          unlocked
              ? '${joker.name} permanently unlocked.'
              : 'Could not unlock ${joker.name}. Please try again.',
        ),
      ),
    );
    return unlocked;
  }

  Future<void> _inspectJoker(JokerDefinition joker) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) {
          final owned = widget.account.unlockedJokerIds.contains(joker.id);
          final busy = _unlocking.contains(joker.id);
          final canAfford = widget.account.coins >= joker.collectionUnlockCost;
          return AlertDialog(
            key: Key('collection-inspect-${joker.id}'),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 20,
            ),
            backgroundColor: context.wildcard.panelStrong,
            title: Text(
              joker.name.toUpperCase(),
              style: TextStyle(
                color: _rarityColor(context, joker.rarity),
                fontFamily: 'Bungee',
                fontSize: 18,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_rarityName(joker.rarity)} · ${jokerCollectionTagline(joker)}',
                    style: TextStyle(color: context.wildcard.creamDim),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'EFFECT',
                    style: TextStyle(
                      color: context.wildcard.gold,
                      fontFamily: 'Bungee',
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(joker.description),
                  const SizedBox(height: 14),
                  Text(
                    owned
                        ? (joker.starter ? 'STARTER SET' : 'IN COLLECTION')
                        : 'LOCKED',
                    style: TextStyle(
                      color: owned
                          ? context.wildcard.mint
                          : context.wildcard.creamDim,
                      fontFamily: 'Bungee',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!owned)
                TextButton(
                  key: Key('collection-inspect-unlock-${joker.id}'),
                  onPressed: !busy && canAfford
                      ? () async {
                          final unlocked = await _unlock(joker);
                          if (dialogContext.mounted) updateDialog(() {});
                          if (unlocked && mounted) setState(() {});
                        }
                      : null,
                  child: Text(
                    busy
                        ? 'SAVING…'
                        : 'UNLOCK · ${joker.collectionUnlockCost} COINS',
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CLOSE'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CollectionSummary extends StatelessWidget {
  const _CollectionSummary({required this.ownedIds});

  final Set<String> ownedIds;

  @override
  Widget build(BuildContext context) {
    final groups = <(String, JokerRarity?)>[
      ('Total', null),
      ('Common', JokerRarity.common),
      ('Uncommon', JokerRarity.uncommon),
      ('Rare', JokerRarity.rare),
      ('WILD', JokerRarity.wild),
    ];
    return SizedBox(
      height: 63,
      child: ListView.separated(
        key: const Key('collection-summary'),
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final group = groups[index];
          final pool = group.$2 == null
              ? jokerCatalog
              : jokerCatalog
                    .where((joker) => joker.rarity == group.$2)
                    .toList(growable: false);
          final have = pool
              .where((joker) => ownedIds.contains(joker.id))
              .length;
          final color = group.$2 == null
              ? context.wildcard.gold
              : _rarityColor(context, group.$2!);
          return Container(
            width: 91,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: context.wildcard.panelStrong.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: context.wildcard.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$have/${pool.length}',
                  style: TextStyle(
                    color: color,
                    fontFamily: 'Bungee',
                    fontSize: 14,
                  ),
                ),
                Text(
                  group.$1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.wildcard.creamDim,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CollectionChoice extends StatelessWidget {
  const _CollectionChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label filter',
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: selected
            ? context.wildcard.violet.withValues(alpha: .38)
            : context.wildcard.panelStrong.withValues(alpha: .9),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? context.wildcard.violet : context.wildcard.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 58, minHeight: 48),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: selected
                        ? context.wildcard.cream
                        : context.wildcard.creamDim,
                    fontFamily: 'Bungee',
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.owned, required this.starter});

  final bool owned;
  final bool starter;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 28),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: owned
          ? context.wildcard.mint.withValues(alpha: .12)
          : context.wildcard.panelStrong,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: owned ? context.wildcard.mint : context.wildcard.line,
      ),
    ),
    child: Text(
      owned ? (starter ? 'STARTER' : 'OWNED') : 'LOCKED',
      style: TextStyle(
        color: owned ? context.wildcard.mint : context.wildcard.creamDim,
        fontFamily: 'Bungee',
        fontSize: 9,
      ),
    ),
  );
}

int _rarityOrder(JokerRarity rarity) => switch (rarity) {
  JokerRarity.common => 1,
  JokerRarity.uncommon => 2,
  JokerRarity.rare => 3,
  JokerRarity.wild => 4,
};

String _rarityName(JokerRarity rarity) => switch (rarity) {
  JokerRarity.common => 'Common',
  JokerRarity.uncommon => 'Uncommon',
  JokerRarity.rare => 'Rare',
  JokerRarity.wild => 'WILD',
};

String _filterLabel(JokerCollectionFilter filter) => switch (filter) {
  JokerCollectionFilter.all => 'All',
  JokerCollectionFilter.locked => 'Locked',
  JokerCollectionFilter.owned => 'Owned',
  JokerCollectionFilter.common => 'Common',
  JokerCollectionFilter.uncommon => 'Uncommon',
  JokerCollectionFilter.rare => 'Rare',
  JokerCollectionFilter.wild => 'WILD',
};

String _sortLabel(JokerCollectionSort sort) => switch (sort) {
  JokerCollectionSort.rarity => 'Rarity',
  JokerCollectionSort.cost => 'Cost',
  JokerCollectionSort.name => 'Name',
  JokerCollectionSort.status => 'Status',
};

WildcardCardAccent _rarityAccent(JokerRarity rarity) => switch (rarity) {
  JokerRarity.common => WildcardCardAccent.neutral,
  JokerRarity.uncommon => WildcardCardAccent.mint,
  JokerRarity.rare => WildcardCardAccent.rare,
  JokerRarity.wild => WildcardCardAccent.violet,
};

Color _rarityColor(BuildContext context, JokerRarity rarity) =>
    switch (rarity) {
      JokerRarity.common => context.wildcard.creamDim,
      JokerRarity.uncommon => context.wildcard.mint,
      JokerRarity.rare => context.wildcard.rare,
      JokerRarity.wild => context.wildcard.wild,
    };
