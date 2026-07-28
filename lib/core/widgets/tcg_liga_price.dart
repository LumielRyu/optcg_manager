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
