import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/liga_tcg_price_service.dart';
import 'liga_price_display.dart' show formatLigaPrice;

class TcgLigaPriceScope extends ConsumerStatefulWidget {
  final Iterable<String> lookupCodes;
  final Widget child;

  const TcgLigaPriceScope({
    super.key,
    required this.lookupCodes,
    required this.child,
  });

  @override
  ConsumerState<TcgLigaPriceScope> createState() => _TcgLigaPriceScopeState();
}

class _TcgLigaPriceScopeState extends ConsumerState<TcgLigaPriceScope> {
  Map<String, LigaTcgPriceSnapshot> _snapshots = const {};
  bool _loading = true;
  late String _signature;

  @override
  void initState() {
    super.initState();
    _signature = _buildSignature();
    _load();
  }

  @override
  void didUpdateWidget(covariant TcgLigaPriceScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _buildSignature();
    if (nextSignature == _signature) return;
    _signature = nextSignature;
    _load();
  }

  String _buildSignature() {
    final codes =
        widget.lookupCodes
            .map(LigaTcgPriceService.normalizeLookupCode)
            .toSet()
            .toList()
          ..sort();
    return codes.join('|');
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final snapshots = await ref
        .read(ligaTcgPriceServiceProvider)
        .fetchSnapshots(widget.lookupCodes);
    if (!mounted) return;
    setState(() {
      _snapshots = snapshots;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _TcgLigaPriceData(
      snapshots: _snapshots,
      loading: _loading,
      child: widget.child,
    );
  }
}

class TcgLigaPriceLabel extends StatelessWidget {
  final String lookupCode;

  const TcgLigaPriceLabel({super.key, required this.lookupCode});

  @override
  Widget build(BuildContext context) {
    final data = _TcgLigaPriceData.maybeOf(context);
    final snapshot =
        data?.snapshots[LigaTcgPriceService.normalizeLookupCode(lookupCode)];
    final theme = Theme.of(context);

    if (data == null || data.loading) {
      return const Text('Liga: verificando...');
    }

    final verified = snapshot != null;
    final stale = snapshot?.isStale ?? false;
    final price = snapshot?.minimumPrice;
    final color = !verified
        ? theme.colorScheme.onSurfaceVariant
        : stale
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final label = !verified
        ? 'Liga: não verificada'
        : price == null
        ? 'Liga: verificada, sem oferta'
        : stale
        ? 'Liga: ${formatLigaPrice(price)} • desatualizado'
        : 'Liga: ${formatLigaPrice(price)} • verificado';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          !verified
              ? Icons.help_outline
              : stale
              ? Icons.history
              : Icons.verified_outlined,
          size: 15,
          color: color,
        ),
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

class TcgLigaPriceDetailsPanel extends ConsumerWidget {
  final String lookupCode;
  final String gameLabel;

  const TcgLigaPriceDetailsPanel({
    super.key,
    required this.lookupCode,
    required this.gameLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.read(ligaTcgPriceServiceProvider).fetchSnapshots([
      lookupCode,
    ]);
    return FutureBuilder<Map<String, LigaTcgPriceSnapshot>>(
      future: future,
      builder: (context, result) {
        final snapshot =
            result.data?[LigaTcgPriceService.normalizeLookupCode(lookupCode)];
        final loading = result.connectionState == ConnectionState.waiting;
        final theme = Theme.of(context);
        final price = snapshot?.minimumPrice;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                loading
                    ? Icons.sync
                    : snapshot == null
                    ? Icons.help_outline
                    : Icons.verified_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menor preço na Liga $gameLabel',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (loading)
                      const Text('Verificando o cache de preços...')
                    else if (snapshot == null)
                      const Text('Esta carta ainda não foi verificada na Liga.')
                    else if (price == null)
                      const Text('Carta verificada, mas sem oferta disponível.')
                    else
                      Text(
                        formatLigaPrice(price),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TcgLigaCollectionItemReference {
  final String lookupCode;
  final int quantity;

  const TcgLigaCollectionItemReference({
    required this.lookupCode,
    required this.quantity,
  });
}

class TcgLigaDeckValuation {
  final double totalValue;
  final int totalCards;
  final int pricedCards;

  const TcgLigaDeckValuation({
    required this.totalValue,
    required this.totalCards,
    required this.pricedCards,
  });

  bool get hasPrices => pricedCards > 0;
  bool get isComplete => totalCards > 0 && pricedCards == totalCards;
}

TcgLigaDeckValuation calculateTcgLigaDeckValuation({
  required Iterable<TcgLigaCollectionItemReference> items,
  required Map<String, LigaTcgPriceSnapshot> snapshots,
}) {
  var totalValue = 0.0;
  var totalCards = 0;
  var pricedCards = 0;

  for (final item in items) {
    if (item.quantity <= 0) continue;
    totalCards += item.quantity;
    final code = LigaTcgPriceService.normalizeLookupCode(item.lookupCode);
    final price = snapshots[code]?.minimumPrice;
    if (price == null || price <= 0) continue;
    totalValue += price * item.quantity;
    pricedCards += item.quantity;
  }

  return TcgLigaDeckValuation(
    totalValue: totalValue,
    totalCards: totalCards,
    pricedCards: pricedCards,
  );
}

class TcgLigaDeckValueCard extends StatelessWidget {
  final Iterable<TcgLigaCollectionItemReference> items;
  final String gameLabel;

  const TcgLigaDeckValueCard({
    super.key,
    required this.items,
    required this.gameLabel,
  });

  @override
  Widget build(BuildContext context) {
    final data = _TcgLigaPriceData.maybeOf(context);
    final theme = Theme.of(context);
    final valuation = calculateTcgLigaDeckValuation(
      items: items,
      snapshots: data?.snapshots ?? const {},
    );
    final loading = data == null || data.loading;
    final title = loading
        ? 'Valor do deck'
        : valuation.isComplete
        ? 'Valor total do deck'
        : 'Valor parcial do deck';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(
                      Icons.price_check_outlined,
                      color: theme.colorScheme.primary,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    loading
                        ? 'Consultando a Liga...'
                        : valuation.hasPrices
                        ? formatLigaPrice(valuation.totalValue)
                        : 'Sem preços disponíveis',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    loading
                        ? 'Somando os preços das variantes escolhidas.'
                        : '${valuation.pricedCards} de ${valuation.totalCards} cartas com preço verificado na Liga $gameLabel.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TcgLigaDeckCardPrice extends StatelessWidget {
  final String lookupCode;
  final int quantity;

  const TcgLigaDeckCardPrice({
    super.key,
    required this.lookupCode,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    final data = _TcgLigaPriceData.maybeOf(context);
    final snapshot =
        data?.snapshots[LigaTcgPriceService.normalizeLookupCode(lookupCode)];
    final theme = Theme.of(context);

    if (data == null || data.loading) {
      return Text(
        'Liga: verificando preço...',
        style: theme.textTheme.bodySmall,
      );
    }

    final price = snapshot?.minimumPrice;
    if (snapshot == null || price == null || price <= 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            snapshot == null ? Icons.help_outline : Icons.info_outline,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              snapshot == null
                  ? 'Liga: preço não verificado'
                  : 'Liga: verificada, sem oferta',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    final stale = snapshot.isStale;
    final color = stale
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final unitPrice = formatLigaPrice(price);
    final label = quantity > 1
        ? '$unitPrice cada • ${formatLigaPrice(price * quantity)} no deck'
        : unitPrice;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          stale ? Icons.history : Icons.verified_outlined,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
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

class TcgLigaCollectionValueCard extends StatelessWidget {
  final Iterable<TcgLigaCollectionItemReference> items;
  final String gameLabel;

  const TcgLigaCollectionValueCard({
    super.key,
    required this.items,
    required this.gameLabel,
  });

  @override
  Widget build(BuildContext context) {
    final data = _TcgLigaPriceData.maybeOf(context);
    final theme = Theme.of(context);
    var total = 0.0;
    var pricedCards = 0;
    var totalCards = 0;

    for (final item in items) {
      if (item.quantity <= 0) continue;
      totalCards += item.quantity;
      final snapshot = data
          ?.snapshots[LigaTcgPriceService.normalizeLookupCode(item.lookupCode)];
      final price = snapshot?.minimumPrice;
      if (price == null) continue;
      total += price * item.quantity;
      pricedCards += item.quantity;
    }

    final loading = data == null || data.loading;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(
                      Icons.account_balance_wallet_outlined,
                      color: theme.colorScheme.primary,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Valor estimado da coleção',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    loading ? 'Consultando a Liga...' : formatLigaPrice(total),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    loading
                        ? 'Os preços serão somados assim que a consulta terminar.'
                        : '$pricedCards de $totalCards cartas com preço verificado na Liga $gameLabel.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TcgLigaPriceData extends InheritedWidget {
  final Map<String, LigaTcgPriceSnapshot> snapshots;
  final bool loading;

  const _TcgLigaPriceData({
    required this.snapshots,
    required this.loading,
    required super.child,
  });

  static _TcgLigaPriceData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_TcgLigaPriceData>();
  }

  @override
  bool updateShouldNotify(_TcgLigaPriceData oldWidget) {
    return loading != oldWidget.loading || snapshots != oldWidget.snapshots;
  }
}
