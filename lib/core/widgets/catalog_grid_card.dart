import 'package:flutter/material.dart';

class CatalogGridCard extends StatefulWidget {
  final String code;
  final String title;
  final List<String> metadata;
  final Widget image;
  final VoidCallback? onTap;
  final List<Widget> trailingActions;
  final Widget? footer;
  final int maxMetadataItems;
  final double textScale;

  const CatalogGridCard({
    super.key,
    required this.code,
    required this.title,
    required this.metadata,
    required this.image,
    this.onTap,
    this.trailingActions = const [],
    this.footer,
    this.maxMetadataItems = 4,
    this.textScale = 1,
  });

  @override
  State<CatalogGridCard> createState() => _CatalogGridCardState();
}

class _CatalogGridCardState extends State<CatalogGridCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.colorScheme.brightness == Brightness.dark;
    final safeTextScale = widget.textScale.clamp(0.9, 1.35);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final visibleMetadata = widget.metadata
        .where((line) => line.trim().isNotEmpty)
        .take(widget.maxMetadataItems)
        .toList(growable: false);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: widget.onTap != null,
      label: '${widget.code}, ${widget.title}',
      hint: widget.onTap == null ? null : 'Abrir detalhes da carta',
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _hovered && !reduceMotion ? 1.018 : 1,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: _focused
                  ? Border.all(color: theme.colorScheme.primary, width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _hovered
                        ? (dark ? 0.24 : 0.08)
                        : (dark ? 0.08 : 0.02),
                  ),
                  blurRadius: _hovered ? 22 : 10,
                  offset: Offset(0, _hovered ? 12 : 6),
                ),
              ],
            ),
            child: Material(
              color: theme.colorScheme.surface.withValues(
                alpha: dark ? 0.28 : 0.42,
              ),
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                excludeFromSemantics: true,
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onTap,
                onFocusChange: (focused) {
                  if (_focused != focused) setState(() => _focused = focused);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12 * safeTextScale,
                              ),
                            ),
                          ),
                          if (widget.trailingActions.isNotEmpty)
                            ...widget.trailingActions,
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: _hovered ? 0.46 : 0.34),
                                theme.colorScheme.primary.withValues(
                                  alpha: _hovered ? 0.09 : 0.045,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.transparent),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: widget.image,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5 * safeTextScale,
                        ),
                      ),
                      for (final line in visibleMetadata) ...[
                        const SizedBox(height: 6),
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11.5 * safeTextScale,
                          ),
                        ),
                      ],
                      if (widget.footer != null) ...[
                        const SizedBox(height: 6),
                        widget.footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
