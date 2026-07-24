// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/share_link_helper.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../data/models/op_card.dart';
import '../../data/services/liga_one_piece_service.dart';
import '../../data/services/op_api_service.dart';
import '../../data/services/translation_service.dart';

class LibraryCardDetailsScreen extends ConsumerWidget {
  final String cardCode;
  final String? preferredImageUrl;
  final String? preferredName;
  final OpCard? initialCard;

  const LibraryCardDetailsScreen({
    super.key,
    required this.cardCode,
    this.preferredImageUrl,
    this.preferredName,
    this.initialCard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(opApiServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carta da Biblioteca'),
        actions: [
          const HomeNavigationButton(),
          IconButton(
            tooltip: 'Compartilhar carta',
            onPressed: () => _shareCardLink(context),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: FutureBuilder<OpCard?>(
        future: _resolveCard(api),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar a carta:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final card = snapshot.data;
          if (card == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Carta nao encontrada na biblioteca.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Center(
            child: LibraryCardDetailsPanel(
              card: card,
              maxWidth: 560,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            ),
          );
        },
      ),
    );
  }

  Future<void> _shareCardLink(BuildContext context) async {
    final base = Uri.base;
    final origin = '${base.scheme}://${base.authority}';
    final usesHashRouting = base.hasFragment && base.fragment.startsWith('/');
    final normalizedCode = Uri.encodeComponent(cardCode);
    final query = <String, String>{};
    if ((preferredImageUrl ?? '').trim().isNotEmpty) {
      query['image'] = preferredImageUrl!.trim();
    }
    if ((preferredName ?? '').trim().isNotEmpty) {
      query['name'] = preferredName!.trim();
    }
    final queryString = query.isEmpty
        ? ''
        : '?${Uri(queryParameters: query).query}';
    final link = usesHashRouting
        ? '$origin/#/library/card/$normalizedCode$queryString'
        : '$origin/library/card/$normalizedCode$queryString';

    try {
      final action = await shareOrCopyText(
        link,
        subject: 'Carta da Biblioteca One Piece',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'shared'
                ? 'Link da carta aberto para compartilhamento.'
                : 'Link da carta copiado.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel compartilhar o link da carta.'),
        ),
      );
    }
  }

  Future<OpCard?> _resolveCard(OpApiService api) async {
    if (initialCard != null) {
      return initialCard;
    }

    final allVariants = await api.findAllByCode(cardCode);
    if (allVariants.isEmpty) return null;

    final targetImage = (preferredImageUrl ?? '').trim();
    final targetName = (preferredName ?? '').trim().toLowerCase();

    if (targetImage.isNotEmpty) {
      for (final card in allVariants) {
        if (card.image.trim() == targetImage) {
          return card;
        }
      }
    }

    if (targetName.isNotEmpty) {
      for (final card in allVariants) {
        if (card.name.trim().toLowerCase() == targetName) {
          return card;
        }
      }
    }

    return allVariants.first;
  }
}

class LibraryCardDetailsDialog extends StatelessWidget {
  final OpCard card;

  const LibraryCardDetailsDialog({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.96,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          children: [
            Expanded(
              child: LibraryCardDetailsPanel(
                card: card,
                maxWidth: size.width * 0.96,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                label: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LibraryCardDetailsPanel extends ConsumerStatefulWidget {
  final OpCard card;
  final double? maxWidth;
  final EdgeInsetsGeometry padding;

  const LibraryCardDetailsPanel({
    super.key,
    required this.card,
    this.maxWidth,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  @override
  ConsumerState<LibraryCardDetailsPanel> createState() =>
      _LibraryCardDetailsPanelState();
}

class _LibraryCardDetailsPanelState
    extends ConsumerState<LibraryCardDetailsPanel> {
  final TranslationService _translationService = TranslationService();
  bool _isTranslating = false;
  String? _translatedText;
  bool _showTranslated = false;

  Future<void> _translateText() async {
    if (widget.card.text.trim().isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      final translated = await _translationService.translateToPortuguese(
        widget.card.text,
      );

      setState(() {
        _translatedText = translated;
        _showTranslated = true;
      });
    } catch (_) {
      setState(() {
        _translatedText = 'Nao foi possivel traduzir o texto da carta.';
        _showTranslated = true;
      });
    } finally {
      setState(() {
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth ?? double.infinity),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;

          if (!wide) {
            return SingleChildScrollView(
              padding: widget.padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailsHeader(card: card),
                  const SizedBox(height: 16),
                  Center(child: _CardImagePreview(card: card, height: 420)),
                  const SizedBox(height: 8),
                  const Text(
                    'Toque na imagem para ampliar',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _DetailsInfo(
                    card: card,
                    isTranslating: _isTranslating,
                    showTranslated: _showTranslated,
                    translatedText: _translatedText,
                    onTranslate: _translateText,
                  ),
                ],
              ),
            );
          }

          final imagePaneWidth = constraints.maxWidth * 0.48;
          final imageHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight - 32
              : 720.0;

          return Padding(
            padding: widget.padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: imagePaneWidth,
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: _CardImagePreview(
                            card: card,
                            height: imageHeight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Toque na imagem para ampliar',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DetailsHeader(card: card),
                        const SizedBox(height: 18),
                        _DetailsInfo(
                          card: card,
                          isTranslating: _isTranslating,
                          showTranslated: _showTranslated,
                          translatedText: _translatedText,
                          onTranslate: _translateText,
                        ),
                      ],
                    ),
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

class _DetailsHeader extends StatelessWidget {
  final OpCard card;

  const _DetailsHeader({required this.card});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          card.name,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          card.code,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _CardImagePreview extends StatelessWidget {
  final OpCard card;
  final double height;

  const _CardImagePreview({required this.card, required this.height});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openImagePreview(context),
      borderRadius: BorderRadius.circular(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height),
        child: AspectRatio(
          aspectRatio: 63 / 88,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _LibraryCardImage(
                    imageUrl: card.image,
                    cardCode: card.code,
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.zoom_in,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openImagePreview(BuildContext context) {
    if (card.image.trim().isEmpty) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Image.network(
                    card.image,
                    fit: BoxFit.contain,
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    errorBuilder: (_, _, _) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 60,
                        ),
                      );
                    },
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: SafeArea(
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 20,
                right: 20,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${card.name} - ${card.code}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsInfo extends StatelessWidget {
  final OpCard card;
  final bool isTranslating;
  final bool showTranslated;
  final String? translatedText;
  final VoidCallback onTranslate;

  const _DetailsInfo({
    required this.card,
    required this.isTranslating,
    required this.showTranslated,
    required this.translatedText,
    required this.onTranslate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoRow('Set', card.setName),
        _infoRow('Raridade', card.rarity),
        _infoRow('Cor', card.color),
        _infoRow('Categoria', card.type),
        _infoRow('Tipo', card.subTypes),
        _infoRow('Atributo', card.attribute),
        const SizedBox(height: 16),
        _LibraryCardPriceSection(card: card),
        const SizedBox(height: 16),
        const Text(
          'Texto da carta',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(card.text.trim().isEmpty ? 'Sem texto.' : card.text),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isTranslating ? null : onTranslate,
          icon: isTranslating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.translate),
          label: Text(
            isTranslating
                ? 'Traduzindo...'
                : (showTranslated ? 'Traduzir novamente' : 'Traduzir texto'),
          ),
        ),
        if (showTranslated) ...[
          const SizedBox(height: 16),
          const Text(
            'Texto traduzido',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            (translatedText == null || translatedText!.trim().isEmpty)
                ? 'Sem traducao disponivel.'
                : translatedText!,
          ),
        ],
      ],
    );
  }

  Widget _infoRow(String label, String value) {
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

class _LibraryCardPriceSection extends ConsumerStatefulWidget {
  final OpCard card;

  const _LibraryCardPriceSection({required this.card});

  @override
  ConsumerState<_LibraryCardPriceSection> createState() =>
      _LibraryCardPriceSectionState();
}

class _LibraryCardPriceSectionState
    extends ConsumerState<_LibraryCardPriceSection> {
  late Future<LigaOnePieceCardSnapshot?> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  @override
  void didUpdateWidget(covariant _LibraryCardPriceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.code != widget.card.code ||
        oldWidget.card.name != widget.card.name ||
        oldWidget.card.image != widget.card.image) {
      _snapshotFuture = _loadSnapshot();
    }
  }

  Future<LigaOnePieceCardSnapshot?> _loadSnapshot() {
    return ref
        .read(ligaOnePieceServiceProvider)
        .fetchCachedPublicCardSnapshotForCard(
          cardName: widget.card.name,
          cardCode: widget.card.code,
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LigaOnePieceCardSnapshot?>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _LibraryMarketplaceInfoCard.loading();
        }

        final data = snapshot.data;
        final price = data?.minimumPrice ?? data?.lowestListing?.price;
        if (snapshot.hasError || data == null) {
          return _LibraryMarketplaceInfoCard.unavailable(
            message: 'Esta carta ou variante ainda nao foi verificada na Liga.',
          );
        }
        if (price == null) {
          return _LibraryMarketplaceInfoCard.verifiedWithoutOffer(
            snapshot: data,
          );
        }

        return _LibraryMarketplaceInfoCard.data(
          snapshot: data,
          formattedPrice: _formatCurrency(price),
        );
      },
    );
  }

  String _formatCurrency(double value) {
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
}

class _LibraryCardImage extends StatelessWidget {
  final String imageUrl;
  final String cardCode;

  const _LibraryCardImage({required this.imageUrl, required this.cardCode});

  @override
  Widget build(BuildContext context) {
    final directUrl = imageUrl.trim();
    if (directUrl.isEmpty) return const _LibraryImagePlaceholder();

    return Image.network(
      directUrl,
      key: ValueKey('library-details-image-$cardCode-$directUrl'),
      fit: BoxFit.contain,
      gaplessPlayback: false,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => const _LibraryImagePlaceholder(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }
}

class _LibraryImagePlaceholder extends StatelessWidget {
  const _LibraryImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
    );
  }
}

class _LibraryMarketplaceInfoCard extends StatelessWidget {
  final String title;
  final String message;
  final String? price;
  final String? storeName;
  final String? note;
  final Future<String>? linkUrlFuture;
  final VoidCallback? onManualRegister;
  final bool loading;

  const _LibraryMarketplaceInfoCard._({
    required this.title,
    required this.message,
    required this.loading,
    this.price,
    this.storeName,
    this.note,
    this.linkUrlFuture,
    this.onManualRegister,
  });

  factory _LibraryMarketplaceInfoCard.loading() {
    return const _LibraryMarketplaceInfoCard._(
      title: 'Menor valor publico na LigaOnePiece',
      message: 'Consultando a menor oferta publica desta carta...',
      loading: true,
    );
  }

  factory _LibraryMarketplaceInfoCard.unavailable({
    required String message,
    Future<String>? linkUrlFuture,
    VoidCallback? onManualRegister,
  }) {
    return _LibraryMarketplaceInfoCard._(
      title: 'Menor valor publico na LigaOnePiece',
      message: message,
      loading: false,
      linkUrlFuture: linkUrlFuture,
      onManualRegister: onManualRegister,
    );
  }

  factory _LibraryMarketplaceInfoCard.verifiedWithoutOffer({
    required LigaOnePieceCardSnapshot snapshot,
  }) {
    final updatedAt = snapshot.resolvedAt;
    final updatedLabel = updatedAt == null
        ? 'Horário da verificação indisponível.'
        : 'Verificada em ${_formatDateTime(updatedAt.toLocal())}.';
    return _LibraryMarketplaceInfoCard._(
      title: 'Carta verificada na LigaOnePiece',
      message:
          'A carta foi encontrada e verificada, mas não havia oferta com preço disponível.',
      loading: false,
      note: snapshot.isStale
          ? '$updatedLabel Esta verificação está desatualizada.'
          : updatedLabel,
      linkUrlFuture: Future<String>.value(snapshot.sourceUrl),
    );
  }

  factory _LibraryMarketplaceInfoCard.data({
    required LigaOnePieceCardSnapshot snapshot,
    required String formattedPrice,
  }) {
    final store = snapshot.lowestStore?.name ?? 'Base publica da Liga';
    final updatedAt = snapshot.resolvedAt;
    final updatedLabel = updatedAt == null
        ? 'Horario da coleta indisponivel.'
        : 'Atualizado em ${_formatDateTime(updatedAt.toLocal())}.';
    final note = [
      if (snapshot.isStale) 'Atencao: este preco pode estar desatualizado.',
      updatedLabel,
      if ((snapshot.note ?? '').trim().isNotEmpty) snapshot.note!.trim(),
    ].join(' ');

    return _LibraryMarketplaceInfoCard._(
      title: 'Menor valor publico na LigaOnePiece',
      message: 'Menor preco publicado para esta carta e variante.',
      loading: false,
      price: formattedPrice,
      storeName: store,
      note: note,
      linkUrlFuture: Future<String>.value(snapshot.sourceUrl),
    );
  }

  static String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            const LinearProgressIndicator(minHeight: 4)
          else if (price != null) ...[
            Text(
              price!,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Loja: ${storeName ?? '-'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(message),
            _ResolvedLinkButton(linkUrlFuture: linkUrlFuture),
            if ((note ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ] else ...[
            Text(message),
            _ResolvedLinkButton(linkUrlFuture: linkUrlFuture),
            if (onManualRegister != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: onManualRegister,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Cadastrar manualmente'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ResolvedLinkButton extends StatelessWidget {
  final Future<String>? linkUrlFuture;

  const _ResolvedLinkButton({required this.linkUrlFuture});

  @override
  Widget build(BuildContext context) {
    if (linkUrlFuture == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<String>(
      future: linkUrlFuture,
      builder: (context, snapshot) {
        final linkUrl = snapshot.data?.trim() ?? '';
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 3),
          );
        }

        if (linkUrl.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton.icon(
            onPressed: () => _openLink(context, linkUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir pagina da carta'),
          ),
        );
      },
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel abrir o link da carta.'),
        ),
      );
    }
  }
}

class _ManualLigaCacheDialog extends ConsumerStatefulWidget {
  final OpCard card;
  final String sourceUrl;

  const _ManualLigaCacheDialog({required this.card, required this.sourceUrl});

  @override
  ConsumerState<_ManualLigaCacheDialog> createState() =>
      _ManualLigaCacheDialogState();
}

class _ManualLigaCacheDialogState
    extends ConsumerState<_ManualLigaCacheDialog> {
  late final TextEditingController _sourceUrlController;
  late final TextEditingController _editionCodeController;
  late final TextEditingController _minimumPriceController;
  late final TextEditingController _averagePriceController;
  late final TextEditingController _maximumPriceController;
  late final TextEditingController _listingCountController;
  late final TextEditingController _lowestPriceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _storeNameController;
  late final TextEditingController _storeCityController;
  late final TextEditingController _storeStateController;
  late final TextEditingController _storePhoneController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sourceUrlController = TextEditingController(text: widget.sourceUrl);
    _editionCodeController = TextEditingController();
    _minimumPriceController = TextEditingController();
    _averagePriceController = TextEditingController();
    _maximumPriceController = TextEditingController();
    _listingCountController = TextEditingController();
    _lowestPriceController = TextEditingController();
    _quantityController = TextEditingController(text: '1');
    _storeNameController = TextEditingController();
    _storeCityController = TextEditingController();
    _storeStateController = TextEditingController();
    _storePhoneController = TextEditingController();
  }

  @override
  void dispose() {
    _sourceUrlController.dispose();
    _editionCodeController.dispose();
    _minimumPriceController.dispose();
    _averagePriceController.dispose();
    _maximumPriceController.dispose();
    _listingCountController.dispose();
    _lowestPriceController.dispose();
    _quantityController.dispose();
    _storeNameController.dispose();
    _storeCityController.dispose();
    _storeStateController.dispose();
    _storePhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cadastrar cache manual'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _sourceUrlController,
                decoration: const InputDecoration(labelText: 'Link da carta'),
              ),
              TextField(
                controller: _editionCodeController,
                decoration: const InputDecoration(labelText: 'Edicao'),
              ),
              TextField(
                controller: _minimumPriceController,
                decoration: const InputDecoration(labelText: 'Menor preco'),
              ),
              TextField(
                controller: _averagePriceController,
                decoration: const InputDecoration(labelText: 'Preco medio'),
              ),
              TextField(
                controller: _maximumPriceController,
                decoration: const InputDecoration(labelText: 'Maior preco'),
              ),
              TextField(
                controller: _listingCountController,
                decoration: const InputDecoration(labelText: 'Qtd. de ofertas'),
              ),
              TextField(
                controller: _lowestPriceController,
                decoration: const InputDecoration(labelText: 'Menor oferta'),
              ),
              TextField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantidade'),
              ),
              TextField(
                controller: _storeNameController,
                decoration: const InputDecoration(labelText: 'Loja'),
              ),
              TextField(
                controller: _storeCityController,
                decoration: const InputDecoration(labelText: 'Cidade'),
              ),
              TextField(
                controller: _storeStateController,
                decoration: const InputDecoration(labelText: 'Estado'),
              ),
              TextField(
                controller: _storePhoneController,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });

    try {
      final service = ref.read(ligaOnePieceServiceProvider);
      await service.saveManualSnapshotForCard(
        lookupCode: widget.card.code,
        sourceUrl: _sourceUrlController.text.trim(),
        cardName: widget.card.name,
        cardCode: widget.card.code,
        editionCode: _editionCodeController.text.trim(),
        imageUrl: widget.card.image,
        minimumPrice: _parseDouble(_minimumPriceController.text),
        averagePrice: _parseDouble(_averagePriceController.text),
        maximumPrice: _parseDouble(_maximumPriceController.text),
        listingCount: _parseInt(_listingCountController.text) ?? 0,
        lowestListing: _parseDouble(_lowestPriceController.text) == null
            ? null
            : LigaOnePieceListing(
                id: 0,
                quantity: _parseInt(_quantityController.text) ?? 1,
                price: _parseDouble(_lowestPriceController.text) ?? 0,
                storeId: 0,
                state: _storeStateController.text.trim(),
              ),
        lowestStore: _storeNameController.text.trim().isEmpty
            ? null
            : LigaOnePieceStore(
                name: _storeNameController.text.trim(),
                city: _storeCityController.text.trim(),
                state: _storeStateController.text.trim(),
                phone: _storePhoneController.text.trim(),
              ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel salvar o cache manual desta carta.'),
        ),
      );
      setState(() {
        _saving = false;
      });
    }
  }

  double? _parseDouble(String text) {
    final normalized = text.trim().replaceAll('.', '').replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  int? _parseInt(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }
}
