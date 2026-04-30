import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/services/liga_one_piece_service.dart';

class LigaOnePieceTestScreen extends ConsumerStatefulWidget {
  const LigaOnePieceTestScreen({super.key});

  @override
  ConsumerState<LigaOnePieceTestScreen> createState() =>
      _LigaOnePieceTestScreenState();
}

class _LigaOnePieceTestScreenState
    extends ConsumerState<LigaOnePieceTestScreen> {
  static const _initialUrl = LigaOnePieceService.defaultCardUrl;
  final _urlController = TextEditingController(text: _initialUrl);
  late Future<LigaOnePieceCardSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<LigaOnePieceCardSnapshot> _loadSnapshot() {
    return ref
        .read(ligaOnePieceServiceProvider)
        .fetchPublicCardSnapshot(url: _urlController.text.trim());
  }

  void _reload() {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teste LigaOnePiece'),
        actions: [
          IconButton(
            tooltip: 'Atualizar teste',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<LigaOnePieceCardSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao executar o teste:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(
              child: Text('Nenhum dado foi retornado pelo teste.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Teste real da carta na LigaOnePiece',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Esta tela usa os dados publicos embutidos na pagina da carta. O endpoint de historico foi identificado, mas exige login.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'URL da carta',
                  hintText: LigaOnePieceService.defaultCardUrl,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Executar teste',
                    onPressed: _reload,
                    icon: const Icon(Icons.play_arrow),
                  ),
                ),
                onSubmitted: (_) => _reload(),
              ),
              const SizedBox(height: 16),
              if (data.usedVerifiedFallback && data.note != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    data.note!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        crossAxisAlignment: WrapCrossAlignment.start,
                        children: [
                          _CardPreview(
                            imageUrl: data.imageUrl,
                            name: data.cardName,
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.cardName,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Codigo: ${data.cardCode}  |  Edicao: ${data.editionCode}',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 16),
                                _PriceStatCard(
                                  label: 'Menor valor publico',
                                  value: _formatPrice(data.minimumPrice),
                                  icon: Icons.local_offer_outlined,
                                  color: theme.colorScheme.primaryContainer,
                                ),
                                const SizedBox(height: 16),
                                _InfoRow(
                                  label: 'Ofertas publicas lidas',
                                  value: '${data.listingCount}',
                                ),
                                _InfoRow(
                                  label: 'Origem',
                                  value:
                                      'cards_editions + cards_stock + cards_stores',
                                ),
                                _InfoRow(
                                  label: 'Historico',
                                  value:
                                      data.historyEndpointRequiresLogin
                                          ? 'Endpoint identificado, mas bloqueado sem login'
                                          : 'Disponivel',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Menor oferta encontrada',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _LowestOfferPanel(snapshot: data),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conclusao do teste',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A pagina publica ja fornece o menor valor da carta sem depender de login. Para a Porche (OP07-072), o menor preco retornado nesta leitura e ${_formatPrice(data.minimumPrice)} em uma loja publica.',
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              'URL testada: ${data.sourceUrl}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatPrice(double? value) {
    if (value == null) return '-';
    return NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    ).format(value);
  }
}

class _CardPreview extends StatelessWidget {
  final String imageUrl;
  final String name;

  const _CardPreview({
    required this.imageUrl,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 220,
      child: AspectRatio(
        aspectRatio: 0.72,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.45,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                imageUrl.isEmpty
                    ? Center(
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                      ),
                    )
                    : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                      errorBuilder: (_, _, _) {
                        return Center(
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
          ),
        ),
      ),
    );
  }
}

class _PriceStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _PriceStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _LowestOfferPanel extends StatelessWidget {
  final LigaOnePieceCardSnapshot snapshot;

  const _LowestOfferPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final listing = snapshot.lowestListing;
    final store = snapshot.lowestStore;

    if (listing == null) {
      return const Text('Nenhuma oferta publica foi encontrada para essa carta.');
    }

    final price = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    ).format(listing.price);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 18,
          runSpacing: 12,
          children: [
            _OfferInfo(label: 'Preco', value: price),
            _OfferInfo(label: 'Quantidade', value: '${listing.quantity}'),
            _OfferInfo(label: 'Loja', value: store?.name ?? '-'),
            _OfferInfo(
              label: 'Local',
              value: _formatLocation(store?.city, store?.state, listing.state),
            ),
            _OfferInfo(label: 'Telefone', value: store?.phone ?? '-'),
          ],
        ),
      ),
    );
  }

  String _formatLocation(String? city, String? storeState, String fallbackState) {
    final normalizedCity = (city ?? '').trim();
    final normalizedState = (storeState ?? fallbackState).trim();
    if (normalizedCity.isEmpty && normalizedState.isEmpty) return '-';
    if (normalizedCity.isEmpty) return normalizedState;
    if (normalizedState.isEmpty) return normalizedCity;
    return '$normalizedCity/$normalizedState';
  }
}

class _OfferInfo extends StatelessWidget {
  final String label;
  final String value;

  const _OfferInfo({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
