import 'package:flutter/material.dart';

const Color _shellInk = Color(0xFF061017);
const Color _shellPanel = Color(0xFF0A1A20);
const Color _shellPanelSoft = Color(0xFF10272D);
const Color _shellGold = Color(0xFFE6A935);

class AppPageShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const AppPageShell({
    super.key,
    required this.child,
    this.maxWidth = 1280,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 640;
    final dark = theme.colorScheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        gradient: dark
            ? const RadialGradient(
                center: Alignment(-0.9, -0.7),
                radius: 1.35,
                colors: [Color(0xFF113543), _shellInk, Color(0xFF02060A)],
                stops: [0, 0.48, 1],
              )
            : LinearGradient(
                colors: [
                  const Color(0xFFF7DCA7),
                  theme.colorScheme.surface,
                  const Color(0xFFEAC47B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: Stack(
        children: [
          if (dark)
            Positioned.fill(child: CustomPaint(painter: _ShellSeaPainter())),
          SingleChildScrollView(
            padding:
                padding ??
                EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 24,
                  vertical: compact ? 14 : 24,
                ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellSeaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _shellGold.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = size.height * 0.18; y < size.height; y += 58) {
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 90) {
        path.quadraticBezierTo(x + 45, y + 12, x + 90, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppHeroPanel extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? accent;
  final List<Widget> badges;
  final Widget? action;

  const AppHeroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent,
    this.badges = const [],
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    final dark = theme.colorScheme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? [
                  _shellPanelSoft.withValues(alpha: 0.92),
                  _shellPanel.withValues(alpha: 0.94),
                  Colors.black.withValues(alpha: 0.46),
                ]
              : [
                  color.withValues(alpha: 0.18),
                  theme.colorScheme.surface.withValues(alpha: 0.96),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: dark ? 0.42 : 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: color, size: 34),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 7),
                Text(subtitle, style: theme.textTheme.bodyLarge),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: badges),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class AppSectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const AppSectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.32),
            ),
          ),
          child: Icon(icon, size: 21, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class AppBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const AppBadge({
    super.key,
    required this.label,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class AppAuthPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const AppAuthPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 29),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}
