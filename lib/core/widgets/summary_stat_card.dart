import 'package:flutter/material.dart';

class SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final double minWidth;
  final double surfaceAlpha;

  const SummaryStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.minWidth = 0,
    this.surfaceAlpha = 0.9,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: minWidth > 0 ? BoxConstraints(minWidth: minWidth) : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withValues(alpha: surfaceAlpha),
            theme.colorScheme.primary.withValues(alpha: 0.055),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.22),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label),
            ],
          ),
        ],
      ),
    );
  }
}
