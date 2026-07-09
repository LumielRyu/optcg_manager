import 'package:flutter/material.dart';

class DashboardHeaderPanel extends StatelessWidget {
  final Widget? top;
  final Widget stats;
  final Widget search;
  final Widget? footer;
  final CrossAxisAlignment crossAxisAlignment;

  const DashboardHeaderPanel({
    super.key,
    this.top,
    required this.stats,
    required this.search,
    this.footer,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.96),
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.secondary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.colorScheme.brightness == Brightness.dark
                  ? 0.28
                  : 0.06,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (top != null) ...[top!, const SizedBox(height: 14)],
          stats,
          const SizedBox(height: 14),
          search,
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}
