import 'package:flutter/material.dart';

class CatalogGridCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeTextScale = textScale.clamp(0.9, 1.35);

    final visibleMetadata = metadata
        .where((line) => line.trim().isNotEmpty)
        .take(maxMetadataItems)
        .toList(growable: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        fontSize: 12 * safeTextScale,
                      ),
                    ),
                  ),
                  if (trailingActions.isNotEmpty) ...trailingActions,
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.42,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: image,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
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
              if (footer != null) ...[const SizedBox(height: 6), footer!],
            ],
          ),
        ),
      ),
    );
  }
}
