import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/marketplace_listing.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/services/op_api_service.dart';
import '../../core/widgets/home_navigation_button.dart';

class SharedSaleCardScreen extends ConsumerWidget {
  final String shareCode;

  const SharedSaleCardScreen({
    super.key,
    required this.shareCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(marketplaceRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carta \u00E0 venda'),
        actions: const [HomeNavigationButton()],
      ),
      body: FutureBuilder<MarketplaceListing?>(
        future: repo.getPublicListingByShareCode(shareCode),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro ao carregar carta: ${snapshot.error}'),
              ),
            );
          }

          final item = snapshot.data;

          if (item == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Carta n\u00E3o encontrada ou n\u00E3o est\u00E1 p\u00FAblica.'),
              ),
            );
          }


          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.name,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(item.cardCode),
                        const SizedBox(height: 16),
                        Center(
                          child: SizedBox(
                            height: 320,
                            child: AspectRatio(
                              aspectRatio: 63 / 88,
                              child: _SharedSaleCardImage(
                                imageUrl: item.imageUrl,
                                cardCode: item.cardCode,
                                cardName: item.name,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toque na imagem para ampliar',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                              ),
                        ),
                        const SizedBox(height: 16),
                        _row('Quantidade', '${item.quantity}x'),
                        _row('Set', item.setName),
                        _row('Raridade', item.rarity),
                        _row('Cor', item.color),
                        _row('Tipo', item.type),
                        _row('Atributo', item.attribute),
                        _row('Preço', item.formattedPrice),
                        _row('Status', item.statusLabel),
                        _row('Condição', item.conditionLabel),
                        if (item.hasContactInfo)
                          _row('Contato', item.contactInfo),
                        if (item.hasNotes)
                          _row('Observações', item.notes),
                        if (item.hasContactInfo) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: item.contactInfo),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Contato copiado.'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy_outlined),
                                  label: const Text('Copiar contato'),
                                ),
                              ),
                              if (item.hasWhatsAppContact) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: () async {
                                      final uri = Uri.parse(item.whatsappUrl);
                                      final launched = await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                      if (!launched && context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'N\u00E3o foi poss\u00EDvel abrir o WhatsApp.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('WhatsApp'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.text.trim().isEmpty ? 'Sem texto.' : item.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    final safeValue = value.trim().isEmpty ? '-' : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(safeValue)),
        ],
      ),
    );
  }
}

class _SharedSaleCardImage extends ConsumerWidget {
  final String imageUrl;
  final String cardCode;
  final String cardName;

  const _SharedSaleCardImage({
    required this.imageUrl,
    required this.cardCode,
    required this.cardName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ZoomableCardImage(
      imageUrl: imageUrl,
      cardCode: cardCode,
      title: cardName,
      fit: BoxFit.contain,
    );
  }
}

class _ZoomableCardImage extends ConsumerWidget {
  final String imageUrl;
  final String cardCode;
  final String title;
  final BoxFit fit;
  final double? height;

  const _ZoomableCardImage({
    required this.imageUrl,
    required this.cardCode,
    required this.title,
    this.fit = BoxFit.contain,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directUrl = imageUrl.trim();

    if (directUrl.isNotEmpty) {
      return _buildTapWrapper(
        context,
        _buildNetworkImage(
          url: directUrl,
          fit: fit,
          height: height,
          onError: () => _fallback(ref),
        ),
        directUrl,
      );
    }

    return _fallback(ref);
  }

  Widget _fallback(WidgetRef ref) {
    final api = ref.read(opApiServiceProvider);

    return FutureBuilder(
      future: api.findCardByCode(cardCode),
      builder: (context, snapshot) {
        final url = snapshot.data?.image.trim() ?? '';

        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: height,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (url.isEmpty) {
          return SizedBox(
            height: height,
            child: const Center(
              child: Icon(Icons.image_not_supported),
            ),
          );
        }

        return _buildTapWrapper(
          context,
          _buildNetworkImage(
            url: url,
            fit: fit,
            height: height,
            onError: () => const Center(
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
          url,
        );
      },
    );
  }

  Widget _buildTapWrapper(BuildContext context, Widget child, String resolvedUrl) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.black.withOpacity(0.92),
            builder: (_) => _CardImageFullscreenDialog(
              imageUrl: resolvedUrl,
              title: title,
              cardCode: cardCode,
            ),
          );
        },
        child: child,
      ),
    );
  }

  Widget _buildNetworkImage({
    required String url,
    required BoxFit fit,
    required Widget Function() onError,
    double? height,
  }) {
    return Image.network(
      url,
      height: height,
      fit: fit,
      gaplessPlayback: false,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (_, __, ___) => onError(),
    );
  }
}

class _CardImageFullscreenDialog extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String cardCode;

  const _CardImageFullscreenDialog({
    required this.imageUrl,
    required this.title,
    required this.cardCode,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              panEnabled: true,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (_, __, ___) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 56,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cardCode,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
