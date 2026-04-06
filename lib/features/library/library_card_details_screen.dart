import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/share_link_helper.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../data/models/op_card.dart';
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
                  'Carta não encontrada na biblioteca.',
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
          content: Text('Não foi possível compartilhar o link da carta.'),
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

class _LibraryCardDetailsContent extends StatelessWidget {
  final OpCard card;

  const _LibraryCardDetailsContent({required this.card});

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
              color: theme.colorScheme.outlineVariant.withOpacity(0.45),
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
            _LibraryInfoChip(label: 'Edição', value: card.setName),
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
                color: theme.colorScheme.outlineVariant.withOpacity(0.35),
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
        onTap: imageUrl.trim().isEmpty
            ? null
            : () {
                showDialog<void>(
                  context: context,
                  barrierColor: Colors.black.withOpacity(0.92),
                  builder: (_) => _LibraryCardImageFullscreenDialog(
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
          errorBuilder: (_, __, ___) {
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
