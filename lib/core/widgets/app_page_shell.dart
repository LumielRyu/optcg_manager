import 'dart:ui';

import 'package:flutter/material.dart';

const Color _shellVoid = Color(0xFF060A10);
const Color _shellPanel = Color(0xFF10232D);
const Color _shellPanelSoft = Color(0xFF173541);
const Color _shellCyan = Color(0xFF28D7E8);
const Color _shellBlue = Color(0xFF4F8CFF);
const Color _shellAmber = Color(0xFFF4B740);

class AppPageShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;

  const AppPageShell({
    super.key,
    required this.child,
    this.maxWidth = 1280,
    this.padding,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 640;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final dark = theme.colorScheme.brightness == Brightness.dark;

    final effectivePadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: compact ? 14 : 28,
          vertical: compact ? 16 : 30,
        );
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, value, animatedChild) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - value)),
                child: animatedChild,
              ),
            );
          },
          child: child,
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        gradient: dark
            ? const LinearGradient(
                colors: [Color(0xFF0F2430), _shellVoid, Color(0xFF070B12)],
                stops: [0, 0.52, 1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  const Color(0xFFF4F7FB),
                  theme.colorScheme.surface,
                  const Color(0xFFE7F8FA),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _ShellGridPainter(dark))),
          Positioned.fill(
            child: CustomPaint(painter: _ShellDepthPainter(dark)),
          ),
          if (scrollable)
            SingleChildScrollView(padding: effectivePadding, child: content)
          else
            Padding(padding: effectivePadding, child: content),
        ],
      ),
    );
  }
}

class _ShellGridPainter extends CustomPainter {
  final bool dark;

  const _ShellGridPainter(this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = (dark ? _shellCyan : const Color(0xFF006B78)).withValues(
        alpha: dark ? 0.05 : 0.04,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 42.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final accentPaint = Paint()
      ..color = (dark ? _shellAmber : _shellBlue).withValues(
        alpha: dark ? 0.1 : 0.055,
      )
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.08),
      Offset(size.width * 0.74, size.height * 0.02),
      accentPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.36, size.height),
      Offset(size.width, size.height * 0.74),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShellDepthPainter extends CustomPainter {
  final bool dark;

  const _ShellDepthPainter(this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final bandPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          (dark ? _shellCyan : const Color(0xFF006B78)).withValues(
            alpha: dark ? 0.1 : 0.055,
          ),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(size.width * 0.66, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.82)
      ..lineTo(size.width * 0.78, size.height)
      ..lineTo(size.width * 0.54, size.height)
      ..close();
    canvas.drawPath(path, bandPaint);

    final strokePaint = Paint()
      ..color = (dark ? _shellBlue : _shellCyan).withValues(
        alpha: dark ? 0.16 : 0.08,
      )
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 5; i++) {
      final shift = i * 44.0;
      canvas.drawLine(
        Offset(size.width * 0.7 + shift, -20),
        Offset(size.width * 0.46 + shift, size.height + 20),
        strokePaint,
      );
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
  final String? visualAsset;

  const AppHeroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent,
    this.badges = const [],
    this.action,
    this.visualAsset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    final dark = theme.colorScheme.brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final leading = Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: dark ? 0.22 : 0.16),
            _shellBlue.withValues(alpha: dark ? 0.12 : 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: dark ? 0.2 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 36),
    );
    final visual = visualAsset == null
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: compact ? double.infinity : 300,
              child: AspectRatio(
                aspectRatio: 10 / 7,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(visualAsset!, fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: dark ? 0.32 : 0.16),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: theme.textTheme.bodyLarge),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: badges),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 8,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: dark ? 0.18 : 0.1)),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _HeroCircuitBackdrop(color: color)),
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(height: 16),
                copy,
                if (visual != null) ...[const SizedBox(height: 16), visual],
                if (action != null) ...[const SizedBox(height: 16), action!],
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 18),
                Expanded(flex: 3, child: copy),
                const SizedBox(width: 18),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: visual == null
                        ? _HeroSignalPanel(color: color, action: action)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              visual,
                              if (action != null) ...[
                                const SizedBox(height: 12),
                                action!,
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class AppPremiumSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  const AppPremiumSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.colorScheme.brightness == Brightness.dark;
    final color = accent ?? theme.colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dark
                  ? [
                      _shellPanelSoft.withValues(alpha: 0.5),
                      _shellPanel.withValues(alpha: 0.72),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.72),
                      color.withValues(alpha: 0.045),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: dark ? 0.14 : 0.08),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AppHoverLift extends StatefulWidget {
  final Widget child;
  final Color? accent;
  final double scale;

  const AppHoverLift({
    super.key,
    required this.child,
    this.accent,
    this.scale = 1.018,
  });

  @override
  State<AppHoverLift> createState() => _AppHoverLiftState();
}

class _AppHoverLiftState extends State<AppHoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.colorScheme.brightness == Brightness.dark;
    final accent = widget.accent ?? theme.colorScheme.primary;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered && !reduceMotion ? widget.scale : 1,
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: _hovered
                      ? (dark ? 0.34 : 0.13)
                      : (dark ? 0.18 : 0.055),
                ),
                blurRadius: _hovered ? 30 : 16,
                offset: Offset(0, _hovered ? 16 : 9),
              ),
              if (_hovered)
                BoxShadow(
                  color: accent.withValues(alpha: dark ? 0.16 : 0.07),
                  blurRadius: 26,
                ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _HeroCircuitBackdrop extends StatelessWidget {
  final Color color;

  const _HeroCircuitBackdrop({required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _HeroCircuitPainter(color)),
    );
  }
}

class _HeroCircuitPainter extends CustomPainter {
  final Color color;

  const _HeroCircuitPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    final top = size.height * 0.16;
    final right = size.width - 18;
    for (var i = 0; i < 4; i++) {
      final y = top + (i * 34);
      canvas.drawLine(Offset(size.width * 0.58, y), Offset(right, y), paint);
      canvas.drawCircle(Offset(right - (i * 28), y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroSignalPanel extends StatelessWidget {
  final Color color;
  final Widget? action;

  const _HeroSignalPanel({required this.color, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 86,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(3, (index) {
                final width = 1.0 - (index * 0.18);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: width,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.85),
                            _shellBlue.withValues(alpha: 0.45),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
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
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
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
    return AppPremiumSurface(
      padding: const EdgeInsets.all(24),
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
    );
  }
}
