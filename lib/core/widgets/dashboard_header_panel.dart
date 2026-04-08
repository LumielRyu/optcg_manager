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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
