import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/liga_one_piece_service.dart';
import 'summary_stat_card.dart';

class LigaPriceCardReference {
  final String cardName;
  final String cardCode;

  const LigaPriceCardReference({
    required this.cardName,
    required this.cardCode,
  });
}

class LigaPriceCollectionItemReference extends LigaPriceCardReference {
  final int quantity;

  const LigaPriceCollectionItemReference({
    required super.cardName,
    required super.cardCode,
    required this.quantity,
  });
}

class LigaCollectionValuation {
  final double totalValue;
  final int totalUnits;
  final int pricedUnits;
  final int totalUniqueCards;
  final int pricedUniqueCards;

  const LigaCollectionValuation({
    required this.totalValue,
    required this.totalUnits,
    required this.pricedUnits,
    required this.totalUniqueCards,
    required this.pricedUniqueCards,
  });

  int get unpricedUniqueCards => totalUniqueCards - pricedUniqueCards;
}

LigaCollectionValuation calculateLigaCollectionValuation({
  required List<LigaPriceCollectionItemReference> items,
  required Map<String, double?> prices,
  required String Function(String cardName, String cardCode) lookupCodeForCard,
}) {
  var totalValue = 0.0;
  var totalUnits = 0;
  var pricedUnits = 0;
  var pricedUniqueCards = 0;

  for (final item in items) {
    final quantity = item.quantity < 0 ? 0 : item.quantity;
    totalUnits += quantity;
    final lookupCode = lookupCodeForCard(item.cardName, item.cardCode);
    final price = prices[lookupCode];
    if (price == null) continue;
    totalValue += price * quantity;
    pricedUnits += quantity;
    pricedUniqueCards++;
  }

  return LigaCollectionValuation(
    totalValue: totalValue,
    totalUnits: totalUnits,
    pricedUnits: pricedUnits,
    totalUniqueCards: items.length,
    pricedUniqueCards: pricedUniqueCards,
  );
}

class LigaPriceScope extends ConsumerStatefulWidget {
  final List<LigaPriceCardReference> cards;
  final Widget child;

  const LigaPriceScope({super.key, required this.cards, required this.child});

  @override
  ConsumerState<LigaPriceScope> createState() => _LigaPriceScopeState();
}

class _LigaPriceScopeState extends ConsumerState<LigaPriceScope> {
  Map<String, LigaOnePieceCardSnapshot> _snapshots = const {};
  bool _loading = true;
  late String _signature;

  @override
  void initState() {
    super.initState();
    _signature = _buildSignature(widget.cards);
    _load();
  }

  @override
  void didUpdateWidget(covariant LigaPriceScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _buildSignature(widget.cards);
    if (_signature == nextSignature) return;
    _signature = nextSignature;
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }
    final service = ref.read(ligaOnePieceServiceProvider);
    final snapshots = await service.fetchCachedPublicCardSnapshotsForCards(
      widget.cards.map(
        (card) => (cardName: card.cardName, cardCode: card.cardCode),
      ),
    );
    if (!mounted) return;
    setState(() {
      _snapshots = snapshots;
      _loading = false;
    });
  }

  String _buildSignature(List<LigaPriceCardReference> cards) {
    return cards
        .map((card) => '${card.cardCode}\u0000${card.cardName}')
        .join('|');
  }

  @override
  Widget build(BuildContext context) {
    return _LigaPriceData(
      snapshots: _snapshots,
      loading: _loading,
      child: widget.child,
    );
  }
}

class LigaCollectionValueCard extends ConsumerWidget {
  final List<LigaPriceCollectionItemReference> items;

  const LigaCollectionValueCard({super.key, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = _LigaPriceData.maybeOf(context);
    if (data == null || data.loading) {
      return const SummaryStatCard(
        label: 'Valor pela Liga',
        value: 'Calculando...',
        icon: Icons.payments_outlined,
      );
    }

    final service = ref.read(ligaOnePieceServiceProvider);
    final prices = data.snapshots.map(
      (code, snapshot) => MapEntry(
        code,
        snapshot.minimumPrice ?? snapshot.lowestListing?.price,
      ),
    );
    final valuation = calculateLigaCollectionValuation(
      items: items,
      prices: prices,
      lookupCodeForCard: (cardName, cardCode) =>
          service.lookupCodeForCard(cardName: cardName, cardCode: cardCode),
    );
    final coverage =
        '${valuation.pricedUniqueCards}/${valuation.totalUniqueCards} com preço';
    final missing = valuation.unpricedUniqueCards;

    return Tooltip(
      message: missing == 0
          ? 'Todas as cartas únicas possuem preço da Liga.'
          : '$missing cartas únicas ainda estão sem preço da Liga.',
      child: SummaryStatCard(
        label: 'Valor pela Liga • $coverage',
        value: formatLigaPrice(valuation.totalValue),
        icon: Icons.payments_outlined,
      ),
    );
  }
}

class LigaPriceLabel extends ConsumerWidget {
  final String cardName;
  final String cardCode;

  const LigaPriceLabel({
    super.key,
    required this.cardName,
    required this.cardCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = _LigaPriceData.maybeOf(context);
    final service = ref.read(ligaOnePieceServiceProvider);
    final lookupCode = service.lookupCodeForCard(
      cardName: cardName,
      cardCode: cardCode,
    );
    final snapshot = data?.snapshots[lookupCode];
    final price = snapshot?.minimumPrice ?? snapshot?.lowestListing?.price;
    final theme = Theme.of(context);

    if (data?.loading ?? true) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.7,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 6),
          const Text('Liga: verificando...'),
        ],
      );
    }

    final verified = snapshot != null;
    final stale = snapshot?.isStale ?? false;
    final color = !verified
        ? theme.colorScheme.onSurfaceVariant
        : stale
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final icon = !verified
        ? Icons.help_outline
        : stale
        ? Icons.history
        : Icons.verified_outlined;
    final label = !verified
        ? 'Liga: não verificada'
        : stale
        ? price == null
              ? 'Liga: verificada, sem oferta • desatualizada'
              : 'Liga: ${formatLigaPrice(price)} • desatualizado'
        : price == null
        ? 'Liga: verificada, sem oferta'
        : 'Liga: ${formatLigaPrice(price)} • verificado';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class LigaPriceDetailsPanel extends ConsumerStatefulWidget {
  final String cardName;
  final String cardCode;

  const LigaPriceDetailsPanel({
    super.key,
    required this.cardName,
    required this.cardCode,
  });

  @override
  ConsumerState<LigaPriceDetailsPanel> createState() =>
      _LigaPriceDetailsPanelState();
}

class _LigaPriceDetailsPanelState extends ConsumerState<LigaPriceDetailsPanel> {
  late Future<LigaOnePieceCardSnapshot?> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _load();
  }

  @override
  void didUpdateWidget(covariant LigaPriceDetailsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardName != widget.cardName ||
        oldWidget.cardCode != widget.cardCode) {
      _snapshotFuture = _load();
    }
  }

  Future<LigaOnePieceCardSnapshot?> _load() {
    return ref
        .read(ligaOnePieceServiceProvider)
        .fetchCachedPublicCardSnapshotForCard(
          cardName: widget.cardName,
          cardCode: widget.cardCode,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<LigaOnePieceCardSnapshot?>(
      future: _snapshotFuture,
      builder: (context, result) {
        final snapshot = result.data;
        final price = snapshot?.minimumPrice ?? snapshot?.lowestListing?.price;
        final loading = result.connectionState == ConnectionState.waiting;
        final verified = snapshot != null;
        final stale = snapshot?.isStale ?? false;
        final statusColor = !verified
            ? theme.colorScheme.onSurfaceVariant
            : stale
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary;
        final statusIcon = loading
            ? Icons.sync
            : !verified
            ? Icons.help_outline
            : stale
            ? Icons.history
            : Icons.verified_outlined;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menor preço na Liga One Piece',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (loading)
                      const Text('Verificando o cache de preços...')
                    else if (!verified)
                      const Text(
                        'Esta carta ou variante ainda não foi verificada na Liga.',
                      )
                    else if (price == null)
                      const Text(
                        'Carta verificada na Liga, mas sem oferta disponível.',
                      )
                    else ...[
                      Text(
                        formatLigaPrice(price),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (snapshot.resolvedAt != null)
                        Text(
                          stale
                              ? 'Preço desatualizado; nova sincronização pendente.'
                              : 'Preço verificado e sincronizado automaticamente.',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        );
      },
    );
  }
}

String formatLigaPrice(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[index]);
  }
  return 'R\$ $buffer,${parts.last}';
}

class _LigaPriceData extends InheritedWidget {
  final Map<String, LigaOnePieceCardSnapshot> snapshots;
  final bool loading;

  const _LigaPriceData({
    required this.snapshots,
    required this.loading,
    required super.child,
  });

  static _LigaPriceData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_LigaPriceData>();
  }

  @override
  bool updateShouldNotify(_LigaPriceData oldWidget) {
    return loading != oldWidget.loading || snapshots != oldWidget.snapshots;
  }
}
