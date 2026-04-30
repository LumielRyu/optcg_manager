// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/share_link_helper.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../data/models/op_card.dart';
import '../../data/services/liga_one_piece_service.dart';
import '../../data/services/op_api_service.dart';

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

          return _LibraryCardDetailsContent(card: card);
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

class _LibraryCardDetailsContent extends ConsumerStatefulWidget {
  final OpCard card;

  const _LibraryCardDetailsContent({required this.card});

  @override
  ConsumerState<_LibraryCardDetailsContent> createState() =>
      _LibraryCardDetailsContentState();
}

class _LibraryCardDetailsContentState
    extends ConsumerState<_LibraryCardDetailsContent> {
  List<String> _variantBadges(OpCard card) {
    final source = '${card.name} ${card.setName} ${card.image}'.toLowerCase();
    final badges = <String>[];

    if (source.contains('manga')) badges.add('Manga');
    if (source.contains('alternate') || source.contains('alt art')) {
      badges.add('Alternate Art');
    }
    if (source.contains('sp')) badges.add('SP');
    if (source.contains('parallel')) badges.add('Parallel');

    return badges.toSet().toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = widget.card;
    final badges = _variantBadges(card);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 420,
                child: _LibraryZoomableCardImage(
                  imageUrl: card.image,
                  cardCode: card.code,
                  title: card.name,
                ),
              ),
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: badges.map((badge) {
                    return Chip(
                      label: Text(badge),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          card.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          card.code,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _LibraryInfoChip(label: 'Tipo', value: card.type),
            _LibraryInfoChip(label: 'Cor', value: card.color),
            _LibraryInfoChip(label: 'Raridade', value: card.rarity),
            _LibraryInfoChip(label: 'Atributo', value: card.attribute),
            _LibraryInfoChip(label: 'Edicao', value: card.setName),
          ],
        ),
        if (card.text.trim().isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Texto da carta',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Text(card.text),
          ),
        ],
      ],
    );
  }
}

class _LibraryInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _LibraryInfoChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeValue = value.trim().isEmpty ? '-' : value.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            safeValue,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryZoomableCardImage extends StatelessWidget {
  final String imageUrl;
  final String cardCode;
  final String title;

  const _LibraryZoomableCardImage({
    required this.imageUrl,
    required this.cardCode,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            imageUrl.trim().isEmpty
                ? null
                : () {
                  showDialog<void>(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: 0.92),
                    builder:
                        (_) => _LibraryCardImageFullscreenDialog(
                          imageUrl: imageUrl,
                          title: title,
                          cardCode: cardCode,
                        ),
                  );
                },
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, _, _) {
            return const Center(
              child: Icon(Icons.broken_image_outlined),
            );
          },
        ),
      ),
    );
  }
}

class _LibraryCardImageFullscreenDialog extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String cardCode;

  const _LibraryCardImageFullscreenDialog({
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
                  errorBuilder: (_, _, _) {
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

  factory _LibraryMarketplaceInfoCard.data({
    required LigaOnePieceCardSnapshot snapshot,
    required String formattedPrice,
  }) {
    final store = snapshot.lowestStore?.name ?? 'Loja publica';
    final note =
        snapshot.usedVerifiedFallback
            ? snapshot.note
            : 'Base publica da pagina da carta.';

    return _LibraryMarketplaceInfoCard._(
      title: 'Menor valor publico na LigaOnePiece',
      message: 'Menor oferta encontrada em uma loja publica.',
      loading: false,
      price: formattedPrice,
      storeName: store,
      note: note,
      linkUrlFuture: Future<String>.value(snapshot.sourceUrl),
    );
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

  const _ManualLigaCacheDialog({
    required this.card,
    required this.sourceUrl,
  });

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
          child:
              _saving
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
        lowestListing:
            _parseDouble(_lowestPriceController.text) == null
                ? null
                : LigaOnePieceListing(
                  id: 0,
                  quantity: _parseInt(_quantityController.text) ?? 1,
                  price: _parseDouble(_lowestPriceController.text) ?? 0,
                  storeId: 0,
                  state: _storeStateController.text.trim(),
                ),
        lowestStore:
            _storeNameController.text.trim().isEmpty
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
