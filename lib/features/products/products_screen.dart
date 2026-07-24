import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/app_page_shell.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

enum _DeckPart {
  outerBody('Corpo externo'),
  innerCradle('Berço interno'),
  bottom('Base inferior'),
  lid('Tampa e bandeja'),
  tallBases('Bases altas'),
  shortBases('Bases baixas'),
  tokenBody('Base das fichas'),
  tokenDetail('Detalhes das fichas');

  final String label;
  const _DeckPart(this.label);
}

class _FilamentColor {
  final String name;
  final Color color;
  const _FilamentColor(this.name, this.color);
}

const _palette = <_FilamentColor>[
  _FilamentColor('Preto', Color(0xFF17191D)),
  _FilamentColor('Branco', Color(0xFFF1F0E9)),
  _FilamentColor('Verde', Color(0xFF238A52)),
  _FilamentColor('Amarelo', Color(0xFFF1C62E)),
  _FilamentColor('Azul', Color(0xFF2458B8)),
  _FilamentColor('Azul claro', Color(0xFF83CEE4)),
  _FilamentColor('Vermelho', Color(0xFFC93832)),
  _FilamentColor('Roxo', Color(0xFF7440A7)),
  _FilamentColor('Laranja', Color(0xFFE87525)),
  _FilamentColor('Marrom', Color(0xFF76503A)),
  _FilamentColor('Rosa', Color(0xFFE56F9F)),
];

class _ProductsScreenState extends State<ProductsScreen> {
  late final Map<_DeckPart, _FilamentColor> _colors = {
    for (final part in _DeckPart.values) part: _palette.first,
  };

  String get _configurationText {
    final selections = _DeckPart.values
        .map((part) => '• ${part.label}: ${_colors[part]!.name}')
        .join('\n');
    return 'Olá! Gostaria de pedir uma Deck Box One Piece personalizada.\n\n'
        '$selections\n\nConfiguração criada no OPTCG BH.';
  }

  Future<void> _copyConfiguration() async {
    await Clipboard.setData(ClipboardData(text: _configurationText));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Configuração copiada.')));
  }

  Future<void> _shareOnWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_configurationText)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }

  void _applyOneColor() {
    final selected = _colors[_DeckPart.outerBody]!;
    setState(() {
      for (final part in _DeckPart.values) {
        _colors[part] = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos personalizados'),
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () => context.go('/home/one-piece'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: AppPageShell(
        maxWidth: 1280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppHeroPanel(
              eyebrow: 'Produção local • BH',
              title: 'Acessórios feitos para o seu jogo',
              subtitle:
                  'Escolha as cores, veja uma prévia da combinação e envie a configuração do seu produto.',
              icon: Icons.handyman_outlined,
              visualAsset: 'assets/products/deck_box/deck_box_assembled.jpeg',
              badges: const [
                AppBadge(
                  label: 'Impressão 3D',
                  icon: Icons.view_in_ar_outlined,
                ),
                AppBadge(
                  label: 'Cores personalizáveis',
                  icon: Icons.palette_outlined,
                ),
                AppBadge(
                  label: 'Produção sob encomenda',
                  icon: Icons.inventory_2_outlined,
                ),
              ],
            ),
            const SizedBox(height: 28),
            const AppSectionHeading(
              icon: Icons.tune_outlined,
              title: 'Monte sua Deck Box One Piece',
              subtitle:
                  'Personalize cada grupo de peças. A prévia usa tons aproximados dos filamentos disponíveis.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 900;
                final preview = _PreviewPanel(colors: _colors);
                final controls = _ColorControls(
                  colors: _colors,
                  onChanged: (part, color) =>
                      setState(() => _colors[part] = color),
                  onApplyOneColor: _applyOneColor,
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [preview, const SizedBox(height: 16), controls],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: preview),
                    const SizedBox(width: 18),
                    Expanded(flex: 5, child: controls),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            AppPremiumSurface(
              accent: theme.colorScheme.primary,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sua configuração',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A escolha fica pronta para copiar ou enviar. A confirmação de valor e prazo acontece no atendimento.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _copyConfiguration,
                        icon: const Icon(Icons.content_copy_outlined),
                        label: const Text('Copiar configuração'),
                      ),
                      FilledButton.icon(
                        onPressed: _shareOnWhatsApp,
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('Enviar pelo WhatsApp'),
                      ),
                    ],
                  );
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [copy, const SizedBox(height: 14), actions],
                        )
                      : Row(
                          children: [
                            Expanded(child: copy),
                            const SizedBox(width: 20),
                            actions,
                          ],
                        );
                },
              ),
            ),
            const SizedBox(height: 30),
            const AppSectionHeading(
              icon: Icons.photo_library_outlined,
              title: 'Produto real',
              subtitle:
                  'Fotos da primeira versão impressa, montada e com suas partes separadas.',
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cardWidth = width >= 760 ? (width - 16) / 2 : width;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: const _PhotoCard(
                        asset:
                            'assets/products/deck_box/deck_box_assembled.jpeg',
                        title: 'Deck box montada',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const _PhotoCard(
                        asset: 'assets/products/deck_box/deck_box_parts.jpeg',
                        title: 'Conjunto de peças',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),
            const AppSectionHeading(
              icon: Icons.category_outlined,
              title: 'Outros produtos',
              subtitle:
                  'A linha de acessórios continuará crescendo com itens para organizar sua coleção.',
            ),
            const SizedBox(height: 14),
            const _MdfProductCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  final Map<_DeckPart, _FilamentColor> colors;

  const _PreviewPanel({required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPremiumSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Peças originais do arquivo 3MF',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Cada imagem abaixo vem diretamente das placas salvas no projeto da Bambu Lab.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth >= 480
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _ModelPartTile(
                      label: 'Base inferior',
                      asset: 'plate_1.png',
                      color: colors[_DeckPart.bottom]!.color,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _ModelPartTile(
                      label: 'Berço interno',
                      asset: 'plate_2.png',
                      color: colors[_DeckPart.innerCradle]!.color,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _ModelPartTile.tokens(
                      bodyColor: colors[_DeckPart.tokenBody]!.color,
                      detailColor: colors[_DeckPart.tokenDetail]!.color,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _ModelPartTile(
                      label: 'Corpo externo',
                      asset: 'plate_4.png',
                      color: colors[_DeckPart.outerBody]!.color,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _ModelPartTile(
                      label: 'Tampa e bandeja',
                      asset: 'plate_5.png',
                      color: colors[_DeckPart.lid]!.color,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _ModelPartTile(
                      label: 'Bases altas',
                      asset: 'plate_6.png',
                      color: colors[_DeckPart.tallBases]!.color,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _ModelPartTile(
                      label: 'Bases baixas',
                      asset: 'plate_7.png',
                      color: colors[_DeckPart.shortBases]!.color,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'As geometrias são as originais do arquivo. As cores continuam sendo aproximações visuais dos filamentos.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelPartTile extends StatelessWidget {
  static const _assetRoot = 'assets/products/deck_box/model_parts';

  final String label;
  final String? asset;
  final Color? color;
  final Color? tokenBodyColor;
  final Color? tokenDetailColor;

  const _ModelPartTile({
    required this.label,
    required this.asset,
    required this.color,
  }) : tokenBodyColor = null,
       tokenDetailColor = null;

  const _ModelPartTile.tokens({
    required Color bodyColor,
    required Color detailColor,
  }) : label = 'Fichas com ímã',
       asset = null,
       color = null,
       tokenBodyColor = bodyColor,
       tokenDetailColor = detailColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = asset != null
        ? _TintedModelAsset(
            key: ValueKey('model-part-$asset'),
            asset: '$_assetRoot/$asset',
            color: color!,
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              _TintedModelAsset(
                key: const ValueKey('model-part-plate-3-body'),
                asset: '$_assetRoot/plate_3_body.png',
                color: tokenBodyColor!,
              ),
              _TintedModelAsset(
                key: const ValueKey('model-part-plate-3-detail'),
                asset: '$_assetRoot/plate_3_detail.png',
                color: tokenDetailColor!,
              ),
            ],
          );

    return Semantics(
      image: true,
      label: '$label, modelo original do arquivo 3MF',
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface.withValues(alpha: 0.72),
              theme.colorScheme.primary.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Padding(padding: const EdgeInsets.all(7), child: preview),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.62),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TintedModelAsset extends StatelessWidget {
  final String asset;
  final Color color;

  const _TintedModelAsset({
    super.key,
    required this.asset,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.modulate),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image_outlined, size: 38),
          );
        },
      ),
    );
  }
}

class _ColorControls extends StatelessWidget {
  final Map<_DeckPart, _FilamentColor> colors;
  final void Function(_DeckPart part, _FilamentColor color) onChanged;
  final VoidCallback onApplyOneColor;

  const _ColorControls({
    required this.colors,
    required this.onChanged,
    required this.onApplyOneColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cores de cada peça',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onApplyOneColor,
                icon: const Icon(Icons.format_color_fill_outlined, size: 18),
                label: const Text('Usar uma cor'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'As fichas usam duas cores: uma para a base e outra para linhas e escrita.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          ..._DeckPart.values.map(
            (part) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ColorSelector(
                label: part.label,
                selected: colors[part]!,
                onChanged: (color) => onChanged(part, color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSelector extends StatelessWidget {
  final String label;
  final _FilamentColor selected;
  final ValueChanged<_FilamentColor> onChanged;

  const _ColorSelector({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: selected.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.22),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: selected.color.withValues(alpha: 0.35),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<_FilamentColor>(
          value: selected,
          borderRadius: BorderRadius.circular(8),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          items: _palette
              .map(
                (entry) => DropdownMenuItem(
                  value: entry,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: entry.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(entry.name),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _DeckBoxPainter extends CustomPainter {
  final Map<_DeckPart, _FilamentColor> colors;
  final bool exploded;
  final double rotation;
  final Color background;
  final Color foreground;

  const _DeckBoxPainter({
    required this.colors,
    required this.exploded,
    required this.rotation,
    required this.background,
    required this.foreground,
  });

  Color _color(_DeckPart part) => colors[part]!.color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              _color(_DeckPart.outerBody).withValues(alpha: 0.22),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.shortestSide * 0.48),
          );
    canvas.drawCircle(center, size.shortestSide * 0.48, glow);
    final grid = Paint()
      ..color = foreground.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    final gridTop = size.height * 0.75;
    for (var i = -4; i <= 4; i++) {
      final x = center.dx + i * size.width * 0.105;
      canvas.drawLine(
        Offset(x, gridTop),
        Offset(center.dx + i * size.width * 0.035, size.height * 0.96),
        grid,
      );
    }
    for (var i = 0; i < 5; i++) {
      final y = gridTop + i * size.height * 0.048;
      canvas.drawLine(
        Offset(size.width * 0.08, y),
        Offset(size.width * 0.92, y),
        grid,
      );
    }
    exploded ? _paintExploded(canvas, size) : _paintAssembled(canvas, size);
  }

  void _paintAssembled(Canvas canvas, Size size) {
    final w = size.width * 0.34;
    final h = size.height * 0.58;
    final x = size.width * (0.5 - 0.17 + rotation * 0.08);
    final y = size.height * 0.19;
    final depth = size.width * (0.09 + rotation.abs() * 0.04);
    final direction = rotation >= 0 ? 1.0 : -1.0;
    _drawShadow(canvas, Rect.fromLTWH(x - depth, y + h, w + depth * 2, 20));
    final side = Path()
      ..moveTo(direction > 0 ? x + w : x, y)
      ..lineTo(direction > 0 ? x + w + depth : x - depth, y - depth * 0.48)
      ..lineTo(direction > 0 ? x + w + depth : x - depth, y + h - depth * 0.48)
      ..lineTo(direction > 0 ? x + w : x, y + h)
      ..close();
    _fillPanel(canvas, side, _shade(_color(_DeckPart.outerBody), -0.18));
    final front = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(8),
    );
    canvas.drawRRect(front, Paint()..color = _color(_DeckPart.outerBody));
    final inset = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + w * 0.14, y + h * 0.16, w * 0.72, h * 0.66),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      inset,
      Paint()..color = _shade(_color(_DeckPart.innerCradle), -0.2),
    );
    final cardOpening = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + w * 0.34, y + h * 0.16, w * 0.32, h * 0.46),
      const Radius.circular(18),
    );
    canvas.drawRRect(cardOpening, Paint()..color = background);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 3, y + h * 0.83, w + 6, h * 0.17),
        const Radius.circular(6),
      ),
      Paint()..color = _color(_DeckPart.bottom),
    );
    final lidTop = Path()
      ..moveTo(x - 6, y + 3)
      ..lineTo(x + w + 6, y + 3)
      ..lineTo(x + w + direction * depth, y - depth * 0.45)
      ..lineTo(x + direction * depth, y - depth * 0.45)
      ..close();
    _fillPanel(canvas, lidTop, _shade(_color(_DeckPart.lid), 0.08));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 8, y - 2, w + 16, h * 0.1),
        const Radius.circular(5),
      ),
      Paint()..color = _color(_DeckPart.lid),
    );
    _paintTokenBadge(
      canvas,
      Offset(x + w * 0.78, y + h * 0.72),
      size.width * 0.043,
    );
    _paintBaseMarkers(canvas, x, y, w, h);
    _drawOutline(canvas, front.outerRect);
  }

  void _paintExploded(Canvas canvas, Size size) {
    final bodyRect = Rect.fromLTWH(
      size.width * (0.36 + rotation * 0.08),
      size.height * 0.24,
      size.width * 0.3,
      size.height * 0.46,
    );
    _drawShadow(
      canvas,
      Rect.fromLTWH(
        bodyRect.left - 12,
        bodyRect.bottom + 18,
        bodyRect.width + 24,
        16,
      ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(8)),
      Paint()..color = _color(_DeckPart.outerBody),
    );
    final opening = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        bodyRect.left + bodyRect.width * 0.3,
        bodyRect.top + bodyRect.height * 0.12,
        bodyRect.width * 0.4,
        bodyRect.height * 0.58,
      ),
      const Radius.circular(16),
    );
    canvas.drawRRect(opening, Paint()..color = background);
    _drawPartBlock(
      canvas,
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.25,
        size.width * 0.21,
        size.height * 0.38,
      ),
      _color(_DeckPart.innerCradle),
      'BERÇO',
    );
    _drawPartBlock(
      canvas,
      Rect.fromLTWH(
        size.width * 0.37,
        size.height * 0.78,
        size.width * 0.28,
        size.height * 0.1,
      ),
      _color(_DeckPart.bottom),
      'BASE',
    );
    _drawPartBlock(
      canvas,
      Rect.fromLTWH(
        size.width * 0.69,
        size.height * 0.18,
        size.width * 0.23,
        size.height * 0.11,
      ),
      _color(_DeckPart.lid),
      'TAMPA',
    );
    for (var i = 0; i < 4; i++) {
      _paintTokenBadge(
        canvas,
        Offset(
          size.width * (0.73 + (i % 2) * 0.1),
          size.height * (0.42 + (i ~/ 2) * 0.11),
        ),
        size.width * 0.035,
      );
    }
    for (var i = 0; i < 4; i++) {
      final tall = i < 2;
      final x = size.width * (0.7 + i * 0.06);
      final height = size.height * (tall ? 0.17 : 0.09);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height * 0.68, size.width * 0.038, height),
          const Radius.circular(3),
        ),
        Paint()
          ..color = tall
              ? _color(_DeckPart.tallBases)
              : _color(_DeckPart.shortBases),
      );
    }
    _drawLabel(
      canvas,
      'FICHAS + BASES',
      Offset(size.width * 0.7, size.height * 0.9),
    );
  }

  void _paintBaseMarkers(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
  ) {
    for (var i = 0; i < 4; i++) {
      final tall = i.isEven;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + w * (0.13 + i * 0.2),
            y + h * 0.86,
            w * 0.09,
            h * (tall ? 0.09 : 0.055),
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color = tall
              ? _color(_DeckPart.tallBases)
              : _color(_DeckPart.shortBases),
      );
    }
  }

  void _paintTokenBadge(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = _color(_DeckPart.tokenBody),
    );
    canvas.drawCircle(
      center,
      radius * 0.68,
      Paint()
        ..color = _color(_DeckPart.tokenDetail)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, radius * 0.18),
    );
    canvas.drawLine(
      center.translate(-radius * 0.45, 0),
      center.translate(radius * 0.45, 0),
      Paint()
        ..color = _color(_DeckPart.tokenDetail)
        ..strokeWidth = math.max(2, radius * 0.16)
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawPartBlock(Canvas canvas, Rect rect, Color color, String label) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      Paint()..color = color,
    );
    final inner = rect.deflate(math.min(rect.width, rect.height) * 0.13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(5)),
      Paint()..color = _shade(color, -0.22),
    );
    _drawLabel(canvas, label, Offset(rect.left, rect.bottom + 8));
  }

  void _fillPanel(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = foreground.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawOutline(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = foreground.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawShadow(Canvas canvas, Rect rect) {
    canvas.drawOval(
      rect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  void _drawLabel(Canvas canvas, String label, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: foreground.withValues(alpha: 0.7),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  Color _shade(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.04, 0.96))
        .toColor();
  }

  @override
  bool shouldRepaint(covariant _DeckBoxPainter oldDelegate) {
    return oldDelegate.exploded != exploded ||
        oldDelegate.rotation != rotation ||
        oldDelegate.colors.values.map((entry) => entry.color).toString() !=
            colors.values.map((entry) => entry.color).toString() ||
        oldDelegate.background != background ||
        oldDelegate.foreground != foreground;
  }
}

class _PhotoCard extends StatelessWidget {
  final String asset;
  final String title;
  const _PhotoCard({required this.asset, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppHoverLift(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.asset(asset, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.78),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MdfProductCard extends StatelessWidget {
  const _MdfProductCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPremiumSurface(
      accent: const Color(0xFF9A6B3E),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final illustration = Container(
            width: compact ? double.infinity : 250,
            height: 170,
            decoration: BoxDecoration(
              color: const Color(0xFF9A6B3E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 76,
              color: Color(0xFF9A6B3E),
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBadge(
                label: 'Em preparação',
                icon: Icons.construction_outlined,
                color: Color(0xFF9A6B3E),
              ),
              const SizedBox(height: 12),
              Text(
                'Caixa para bulk em MDF',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Uma solução resistente para organizar grandes volumes de cartas. Fotos, medidas e opções de acabamento serão adicionadas em breve.',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [illustration, const SizedBox(height: 16), details],
                )
              : Row(
                  children: [
                    illustration,
                    const SizedBox(width: 22),
                    Expanded(child: details),
                  ],
                );
        },
      ),
    );
  }
}
